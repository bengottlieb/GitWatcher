//
//  RepositoryListView.swift
//  Internal
//

import SwiftUI

struct RepositoryListView: View {
	let monitor: RepositoryMonitor

	var body: some View {
		Group {
			if monitor.repositories.isEmpty {
				EmptyRepositoriesView()
			} else {
				List {
					ForEach(monitor.sortedRepositories) { repo in
						RepositoryRowView(
							repository: repo,
							status: monitor.status(for: repo),
							monitor: monitor
						)
					}
					.onDelete(perform: deleteRepositories)
				}
			}
		}
	}

	private func deleteRepositories(at offsets: IndexSet) {
		let sorted = monitor.sortedRepositories
		for index in offsets {
			monitor.removeRepository(id: sorted[index].id)
		}
	}
}

private struct EmptyRepositoriesView: View {
	var body: some View {
		ContentUnavailableView(
			"No Repositories",
			systemImage: "folder.badge.plus",
			description: Text("Add a local git repository to start tracking it.")
		)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}
