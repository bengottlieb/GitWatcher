//
//  SortMode.swift
//  Internal
//

import Foundation

public enum SortMode: String, CaseIterable, Codable, Sendable {
	case alphabetical
	case chronological

	public var label: String {
		switch self {
		case .alphabetical: "Alphabetical"
		case .chronological: "Chronological"
		}
	}
}
