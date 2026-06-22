//
//  MissingRepositoryTests.swift
//  InternalTests
//

import Foundation
import Testing
@testable import Internal

// The clone URL must prefer a user-entered override, fall back to the
// persisted remote, trim whitespace, and treat blanks as "unknown" so the
// Create button can surface a clear error instead of cloning from nothing.
@Suite struct CloneURLResolutionTests {
	@Test func overrideWins() {
		#expect(RepositoryMonitor.resolveCloneURL(
			override: "git@github.com:a/b.git",
			persisted: "https://example.com/old.git"
		) == "git@github.com:a/b.git")
	}

	@Test func fallsBackToPersistedWhenNoOverride() {
		#expect(RepositoryMonitor.resolveCloneURL(
			override: nil, persisted: "https://example.com/repo.git"
		) == "https://example.com/repo.git")
	}

	@Test func blankOverrideFallsBackToPersisted() {
		#expect(RepositoryMonitor.resolveCloneURL(
			override: "   ", persisted: "https://example.com/repo.git"
		) == "https://example.com/repo.git")
	}

	@Test func overrideIsTrimmed() {
		#expect(RepositoryMonitor.resolveCloneURL(
			override: "  https://example.com/repo.git\n", persisted: nil
		) == "https://example.com/repo.git")
	}

	@Test func nilWhenNothingKnown() {
		#expect(RepositoryMonitor.resolveCloneURL(override: nil, persisted: nil) == nil)
		#expect(RepositoryMonitor.resolveCloneURL(override: "  ", persisted: "") == nil)
	}
}

// Repository data persisted before remoteURL existed (local and iCloud) must
// still decode, otherwise a sync from an older machine would wipe the list.
@Suite struct RepositoryCodableTests {
	@Test func decodesLegacyJSONWithoutRemoteURL() throws {
		let id = UUID()
		let json = #"{"id":"\#(id.uuidString)","tildePath":"~/Code/Repo"}"#
		let repo = try JSONDecoder().decode(Repository.self, from: Data(json.utf8))
		#expect(repo.id == id)
		#expect(repo.tildePath == "~/Code/Repo")
		#expect(repo.remoteURL == nil)
	}

	@Test func roundTripsRemoteURL() throws {
		let original = Repository(tildePath: "~/Code/Repo", remoteURL: "https://example.com/repo.git")
		let data = try JSONEncoder().encode(original)
		let decoded = try JSONDecoder().decode(Repository.self, from: data)
		#expect(decoded.remoteURL == "https://example.com/repo.git")
		#expect(decoded == original)
	}
}

@Suite struct RepositoryListPartitionTests {
	@Test @MainActor func staleDisplayOrderDoesNotShowMissingRepositoryAsExisting() throws {
		let root = FileManager.default.temporaryDirectory
			.appending(path: UUID().uuidString, directoryHint: .isDirectory)
		let existingURL = root.appending(path: "Existing", directoryHint: .isDirectory)
		let missingURL = root.appending(path: "Missing", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: existingURL, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: root) }

		let existing = Repository(url: existingURL)
		let missing = Repository(url: missingURL)
		let displayed = RepositoryListView.displayedRepositories(
			from: [existing, missing],
			displayOrder: [missing.id, existing.id]
		)

		#expect(displayed.map(\.id) == [existing.id])
	}

	@Test @MainActor func cloningRepositoryIsNotShownAsExisting() throws {
		let root = FileManager.default.temporaryDirectory
			.appending(path: UUID().uuidString, directoryHint: .isDirectory)
		let cloningURL = root.appending(path: "Cloning", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: cloningURL, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: root) }

		let cloning = Repository(url: cloningURL)
		let displayed = RepositoryListView.displayedRepositories(
			from: [cloning],
			displayOrder: [cloning.id],
			status: { _ in RepositoryStatus(kind: .cloning) }
		)

		#expect(displayed.isEmpty)
	}
}
