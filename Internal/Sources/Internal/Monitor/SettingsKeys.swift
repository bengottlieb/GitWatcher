//
//  SettingsKeys.swift
//  Internal
//

import Foundation
import SharedSettings

public struct WhitelistKey: SettingsKey {
	public static let defaultValue: [String] = [
		".DS_Store",
		"Package.resolved",
		"xcuserdata"
	]
	public static let name = "GitWatcher.whitelist"
	public static let location: SettingsLocation = .cloudKit
}

public struct RepositoriesKey: SettingsKey {
	public static let defaultValue: [Repository] = []
	public static let name = "GitWatcher.repositories"
	public static let location: SettingsLocation = .cloudKit
}

public struct SortModeKey: SettingsKey {
	public static let defaultValue: SortMode = .alphabetical
	public static let name = "GitWatcher.sortMode"
	public static let location: SettingsLocation = .userDefaults
}
