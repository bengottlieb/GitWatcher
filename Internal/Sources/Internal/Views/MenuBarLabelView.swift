//
//  MenuBarLabelView.swift
//  Internal
//

import SwiftUI

public struct MenuBarLabelView: View {
	@State private var monitor = RepositoryMonitor.shared

	public init() {}

	public var body: some View {
		Image(systemName: iconName)
			.foregroundStyle(iconColor)
			.symbolEffect(.rotate, options: .repeat(.continuous), isActive: monitor.isRefreshing)
			.accessibilityLabel(accessibilityText)
	}

	private var iconName: String {
		if monitor.hasProblems { return "exclamationmark.arrow.triangle.2.circlepath" }
		if monitor.hasPendingPushes { return "arrow.up.circle.fill" }
		return "arrow.triangle.2.circlepath"
	}

	private var iconColor: Color {
		if monitor.hasProblems { return .red }
		if monitor.hasPendingPushes { return .blue }
		return .primary
	}

	private var accessibilityText: String {
		if monitor.hasProblems { return "Repositories have problems" }
		if monitor.hasPendingPushes { return "Repositories have changes to push" }
		return "All repositories up to date"
	}
}
