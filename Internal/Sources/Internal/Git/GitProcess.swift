//
//  GitProcess.swift
//  Internal
//

import Foundation

public struct GitError: Error, LocalizedError, Sendable {
	public let code: Int32
	public let stderr: String
	public let command: String
	public var errorDescription: String? {
		"git \(command) failed (\(code)): \(stderr)"
	}
}

enum GitProcess {
	static func run(_ args: [String], in directory: URL) async throws -> String {
		try await GitInvocation(args: args, directory: directory).run()
	}
}
