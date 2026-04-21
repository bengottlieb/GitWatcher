//
//  GitRunner.swift
//  Internal
//

import Foundation

struct GitRunner: Sendable {
	let repoPath: URL

	func run(_ args: String...) async throws -> String {
		try await GitProcess.run(args, in: repoPath)
	}

	func firstRemote() async throws -> String? {
		let output = try await run("remote")
		let remotes = output.split(whereSeparator: \.isNewline).map(String.init)
		return remotes.first.flatMap { $0.isEmpty ? nil : $0 }
	}

	func currentBranch() async throws -> String {
		let out = try await run("rev-parse", "--abbrev-ref", "HEAD")
		return out.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	func fetch(remote: String) async throws {
		_ = try await run("fetch", "--quiet", "--prune", remote)
	}

	func counts(remote: String, branch: String) async throws -> (local: Int, remote: Int) {
		let spec = "\(remote)/\(branch)...HEAD"
		let output = try await run("rev-list", "--left-right", "--count", spec)
		let parts = output
			.trimmingCharacters(in: .whitespacesAndNewlines)
			.split(whereSeparator: \.isWhitespace)
			.compactMap { Int($0) }
		guard parts.count == 2 else { return (0, 0) }
		return (local: parts[1], remote: parts[0])
	}

	func remoteBranchExists(remote: String, branch: String) async throws -> Bool {
		do {
			_ = try await run("rev-parse", "--verify", "\(remote)/\(branch)")
			return true
		} catch {
			return false
		}
	}

	func dirtyFiles() async throws -> [DirtyFile] {
		let output = try await run("status", "--porcelain", "-z")
		return DirtyFile.parse(porcelainZ: output)
	}

	func pull(remote: String, branch: String) async throws {
		_ = try await run("pull", "--ff-only", remote, branch)
	}

	func push(remote: String, branch: String) async throws {
		_ = try await run("push", remote, branch)
	}

	func discard(files: [DirtyFile]) async throws {
		let untracked = files.filter(\.isUntracked).map(\.path)
		let tracked = files.filter { !$0.isUntracked }.map(\.path)
		if !tracked.isEmpty {
			_ = try await run(["checkout", "--", ] + tracked)
		}
		if !untracked.isEmpty {
			_ = try await run(["clean", "-fd", "--"] + untracked)
		}
	}

	private func run(_ args: [String]) async throws -> String {
		try await GitProcess.run(args, in: repoPath)
	}
}
