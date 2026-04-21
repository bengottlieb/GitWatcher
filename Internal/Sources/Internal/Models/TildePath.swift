//
//  TildePath.swift
//  Internal
//

import Foundation

enum TildePath {
	static func collapse(_ url: URL) -> String {
		collapse(url.path(percentEncoded: false))
	}

	static func collapse(_ path: String) -> String {
		let home = FileManager.default.homeDirectoryForCurrentUser
			.path(percentEncoded: false)
		if path == home { return "~" }
		if path.hasPrefix(home + "/") {
			return "~" + path.dropFirst(home.count)
		}
		return path
	}

	static func expand(_ stored: String) -> URL {
		URL(fileURLWithPath: (stored as NSString).expandingTildeInPath)
	}
}
