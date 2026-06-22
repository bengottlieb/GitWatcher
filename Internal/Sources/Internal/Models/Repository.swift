//
//  Repository.swift
//  Internal
//

import Foundation

public struct Repository: Identifiable, Codable, Hashable, Sendable {
	public let id: UUID
	public var tildePath: String
	public var remoteURL: String?

	public init(id: UUID = UUID(), url: URL, remoteURL: String? = nil) {
		self.id = id
		self.tildePath = TildePath.collapse(url)
		self.remoteURL = remoteURL
	}

	public init(id: UUID = UUID(), tildePath: String, remoteURL: String? = nil) {
		self.id = id
		self.tildePath = tildePath
		self.remoteURL = remoteURL
	}

	public var url: URL { TildePath.expand(tildePath) }
	public var name: String { url.lastPathComponent }
	public var displayPath: String { tildePath }
	public var existsOnDisk: Bool { FileManager.default.fileExists(atPath: url.path) }
}
