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
				Button(actionTitle) { primaryActionTapped() }
					.buttonStyle(.borderedProminent)
					.help(actionHelp)
			}
		}
		.padding(.vertical, 1)
		.contextMenu {
			Button("Change Source URL…") { promptForURL() }
			Button("Remove", role: .destructive) {
				monitor.removeRepository(id: repository.id)
			}
		}
		.alert("Source URL", isPresented: $isPrompting) {
			TextField("Remote URL", text: $urlText)
			Button("Cancel", role: .cancel) { urlText = "" }
			Button(confirmTitle) { startClone(remoteOverride: urlText) }
				.disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
		} message: {
			Text("Enter the git remote URL to clone “\(repository.name)”.")
		}
	}

	private var hasKnownRemote: Bool {
		repository.remoteURL?.isEmpty == false
	}

	private var actionTitle: String {
		status.kind == .error ? "Change URL…" : "Create"
	}

	private var confirmTitle: String {
		status.kind == .error ? "Retry" : "Create"
	}

	private var actionHelp: String {
		status.kind == .error
			? "Enter a new remote URL and try cloning again"
			: "Clone, check out, and update this repository"
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

	private func primaryActionTapped() {
		if status.kind == .error || !hasKnownRemote {
			promptForURL()
		} else {
			startClone(remoteOverride: nil)
		}
	}

	private func promptForURL() {
		if urlText.isEmpty { urlText = repository.remoteURL ?? "" }
		isPrompting = true
	}

	private func startClone(remoteOverride: String?) {
		Task { await monitor.cloneAndRefresh(repositoryID: repository.id, remoteURLOverride: remoteOverride) }
	}
}
