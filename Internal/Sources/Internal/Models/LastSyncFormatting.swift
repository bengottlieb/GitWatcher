//
//  LastSyncFormatting.swift
//  Internal
//

import Foundation

enum LastSyncFormatting {
	static func label(for date: Date, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> String? {
		let interval = now.timeIntervalSince(date)
		guard interval >= 0 else { return nil }

		let timeStyle = Date.FormatStyle(date: .omitted, time: .shortened)
		if interval < 24 * 3600 {
			return "Last commit: \(date.formatted(timeStyle))"
		}

		let dayDiff = calendar.dateComponents(
			[.day],
			from: calendar.startOfDay(for: date),
			to: calendar.startOfDay(for: now)
		).day ?? 0

		if dayDiff == 1 {
			return "Last commit: yesterday at \(date.formatted(timeStyle))"
		}
		if dayDiff > 1, dayDiff < 7 {
			return "Last commit: \(dayDiff) days ago"
		}
		return nil
	}
}
