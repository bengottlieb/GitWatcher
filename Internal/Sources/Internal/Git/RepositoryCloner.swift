//
//  RepositoryCloner.swift
//  Internal
//

import Foundation

struct RepositoryCloner: Sendable {
	let repository: Repository
	let remoteURL: String

	func clone() async throws {
		let destination = repository.url
		if hasContents(at: destination) {
			throw CloneError.destinationNotEmpty(repository.displayPath)
		}
		let parent = destination.deletingLastPathComponent()
		try FileManager.default.createDirectory(
			at: parent, withIntermediateDirectories: true
		)
		_ = try await GitProcess.run(["clone", remoteURL, destination.path], in: parent)
	}

	private func hasContents(at url: URL) -> Bool {
		let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path)
		return contents?.isEmpty == false
	}
}

enum CloneError: LocalizedError {
	case destinationNotEmpty(String)

	var errorDescription: String? {
		switch self {
		case .destinationNotEmpty(let path): "A non-empty folder already exists at \(path)."
		}
	}
}
