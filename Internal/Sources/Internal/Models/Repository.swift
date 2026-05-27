//
//  Repository.swift
//  Internal
//

import Foundation

public struct Repository: Identifiable, Codable, Hashable, Sendable {
	public let id: UUID
	public var tildePath: String

	public init(id: UUID = UUID(), url: URL) {
		self.id = id
		self.tildePath = TildePath.collapse(url)
	}

	public init(id: UUID = UUID(), tildePath: String) {
		self.id = id
		self.tildePath = tildePath
	}

	public var url: URL { TildePath.expand(tildePath) }
	public var name: String { url.lastPathComponent }
	public var displayPath: String { tildePath }
	public var existsOnDisk: Bool { FileManager.default.fileExists(atPath: url.path) }
}
