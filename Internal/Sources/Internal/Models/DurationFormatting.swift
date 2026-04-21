//
//  DurationFormatting.swift
//  Internal
//

import Foundation

enum DurationFormatting {
	static func short(_ duration: Duration) -> String {
		let seconds = Double(duration.components.seconds)
			+ Double(duration.components.attoseconds) / 1e18
		if seconds < 1 { return String(format: "%.0f ms", seconds * 1000) }
		return String(format: "%.1f s", seconds)
	}
}
