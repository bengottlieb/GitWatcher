//
//  MissingRepositoryRowView.swift
//  Internal
//

import SwiftUI

struct MissingRepositoryRowView: View {
	let repository: Repository
	let status: RepositoryStatus
	let monitor: RepositoryMonitor
	@State private var isPrompting = false
	@State private var urlText = ""

	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: "folder.badge.questionmark")
				.font(.body)
				.foregroundStyle(.secondary)
				.frame(width: 18, height: 18)
			VStack(alignment: .leading, spacing: 2) {
				Text(repository.name)
					.font(.body).lineLimit(1).truncationMode(.middle)
				Text(detailText)
					.font(.caption).foregroundStyle(detailTint)
					.lineLimit(1).truncationMode(.middle)
			}
			Spacer(minLength: 8)
			if status.kind == .cloning {
				ProgressView().controlSize(.small)
			} else {
				Button("Create") { createTapped() }
					.buttonStyle(.borderedProminent)
					.help("Clone, check out, and update this repository")
			}
		}
		.padding(.vertical, 1)
		.contextMenu {
			Button("Remove", role: .destructive) {
				monitor.removeRepository(id: repository.id)
			}
		}
		.alert("Clone Repository", isPresented: $isPrompting) {
			TextField("Remote URL", text: $urlText)
			Button("Cancel", role: .cancel) {}
			Button("Create") { startClone(remoteOverride: urlText) }
		} message: {
			Text("Enter the git remote URL for “\(repository.name)”.")
		}
	}

	private var hasKnownRemote: Bool {
		repository.remoteURL?.isEmpty == false
	}

	private var detailText: String {
		switch status.kind {
		case .cloning: "Cloning…"
		case .error: status.message ?? "Clone failed"
		default: repository.displayPath
		}
	}

	private var detailTint: Color {
		status.kind == .error ? .red : .secondary
	}

	private func createTapped() {
		if hasKnownRemote {
			startClone(remoteOverride: nil)
		} else {
			urlText = ""
			isPrompting = true
		}
	}

	private func startClone(remoteOverride: String?) {
		Task { await monitor.cloneAndRefresh(repositoryID: repository.id, remoteURLOverride: remoteOverride) }
	}
}
