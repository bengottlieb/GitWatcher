//
//  RecentActivityBadge.swift
//  Internal
//

import SwiftUI

/// Marks a repository that has received commits within the last 24 hours.
struct RecentActivityBadge: View {
	var body: some View {
		Text("24h")
			.font(.caption2.weight(.semibold))
			.foregroundStyle(.white)
			.padding(.horizontal, 6)
			.padding(.vertical, 2)
			.background(Color.green, in: Capsule())
			.help("Committed within the last 24 hours")
	}
}
