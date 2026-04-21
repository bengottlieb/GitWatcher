//
//  DirtyFile.swift
//  Internal
//

import Foundation

public struct DirtyFile: Hashable, Sendable {
	public let path: String
	public let statusCode: String

	public var isUntracked: Bool { statusCode == "??" }
	public var basename: String { (path as NSString).lastPathComponent }

	static func parse(porcelainZ raw: String) -> [DirtyFile] {
		var entries: [DirtyFile] = []
		var iterator = raw.split(separator: "\0", omittingEmptySubsequences: true).makeIterator()
		while let next = iterator.next() {
			let entry = String(next)
			guard entry.count >= 3 else { continue }
			let code = String(entry.prefix(2))
			let remainder = String(entry.dropFirst(3))
			entries.append(DirtyFile(path: remainder, statusCode: code))
			if code.first == "R" || code.first == "C" {
				_ = iterator.next()
			}
		}
		return entries
	}
}
