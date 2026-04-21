//
//  RepositoryOpener.swift
//  Internal
//

import AppKit
import Foundation

public enum RepositoryOpener {
	public static func openInTower(_ repository: Repository) {
		let tower = URL(fileURLWithPath: "/Applications/Tower.app")
		guard FileManager.default.fileExists(atPath: tower.path(percentEncoded: false)) else {
			NSWorkspace.shared.activateFileViewerSelecting([repository.url])
			return
		}
		NSWorkspace.shared.open(
			[repository.url],
			withApplicationAt: tower,
			configuration: NSWorkspace.OpenConfiguration(),
			completionHandler: nil
		)
	}

	public static func openProjectOrPackage(_ repository: Repository) {
		if let projectURL = xcodeProjectURL(for: repository) {
			NSWorkspace.shared.open(projectURL)
			return
		}
		if packageFileURL(for: repository) != nil {
			openPackage(for: repository)
		}
	}

	public static func xcodeProjectURL(for repository: Repository) -> URL? {
		let contents = try? FileManager.default.contentsOfDirectory(
			at: repository.url,
			includingPropertiesForKeys: nil,
			options: [.skipsHiddenFiles]
		)
		return contents?.first { $0.pathExtension == "xcodeproj" }
	}

	public static func packageFileURL(for repository: Repository) -> URL? {
		let url = repository.url.appending(path: "Package.swift")
		return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
	}

	public static func openPackage(for repository: Repository) {
		let xcode = URL(fileURLWithPath: "/Applications/Xcode.app")
		guard FileManager.default.fileExists(atPath: xcode.path(percentEncoded: false)) else {
			if let url = packageFileURL(for: repository) { NSWorkspace.shared.open(url) }
			return
		}
		NSWorkspace.shared.open(
			[repository.url],
			withApplicationAt: xcode,
			configuration: NSWorkspace.OpenConfiguration(),
			completionHandler: nil
		)
	}
}
