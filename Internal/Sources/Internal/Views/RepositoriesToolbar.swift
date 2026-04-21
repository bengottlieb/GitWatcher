//
//  RepositoriesToolbar.swift
//  Internal
//

import SwiftUI

struct RepositoriesToolbar: View {
	let monitor: RepositoryMonitor
	let onAdd: () -> Void
	let onEditWhitelist: () -> Void

	var body: some View {
		HStack {
			Button(action: onAdd) {
				Label("Add Repository", systemImage: "plus")
			}
			Button(action: onEditWhitelist) {
				Label("Whitelist", systemImage: "list.bullet")
			}
			Spacer()
			RefreshStatusView(monitor: monitor)
			Button {
				Task { await monitor.refreshAll() }
			} label: {
				Label("Update All", systemImage: "arrow.triangle.2.circlepath")
			}
			.keyboardShortcut("r", modifiers: [.command])
			.disabled(monitor.repositories.isEmpty || monitor.isRefreshing)
		}
		.padding(10)
	}
}

private struct RefreshStatusView: View {
	let monitor: RepositoryMonitor

	var body: some View {
		if monitor.isRefreshing {
			HStack(spacing: 6) {
				ProgressView().controlSize(.small)
				Text("Refreshing…").font(.caption).foregroundStyle(.secondary)
			}
		} else if let duration = monitor.lastRefreshDuration {
			Text("Refreshed in \(DurationFormatting.short(duration))")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}
}
