//
//  RepositoryListView.swift
//  Internal
//

import SwiftUI

struct RepositoryListView: View {
	let monitor: RepositoryMonitor
	@State private var selection: UUID?
	@State private var typeAheadBuffer: String = ""
	@State private var bufferResetTask: Task<Void, Never>?
	@FocusState private var isListFocused: Bool
	@Environment(\.controlActiveState) private var activeState

	var body: some View {
		Group {
			if monitor.repositories.isEmpty {
				EmptyRepositoriesView()
			} else {
				List(selection: $selection) {
					ForEach(monitor.sortedRepositories) { repo in
						RepositoryRowView(
							repository: repo,
							status: monitor.status(for: repo),
							monitor: monitor
						)
						.tag(repo.id)
					}
					.onDelete(perform: deleteRepositories)
				}
				.tint(.accentColor.opacity(0.35))
				.focused($isListFocused)
				.onKeyPress(phases: .down, action: handleKeyPress)
				.onAppear { focusListSoon() }
				.onChange(of: activeState) { _, new in
					if new == .key { focusListSoon() }
				}
			}
		}
	}

	private func focusListSoon() {
		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(100))
			isListFocused = true
		}
	}

	private func deleteRepositories(at offsets: IndexSet) {
		let sorted = monitor.sortedRepositories
		for index in offsets {
			monitor.removeRepository(id: sorted[index].id)
		}
	}

	private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
		if press.key == .escape {
			typeAheadBuffer = ""
			bufferResetTask?.cancel()
			return .handled
		}
		if press.key == .return {
			return activateSelectedRepository(withOption: press.modifiers.contains(.option))
		}
		let characters = press.characters.lowercased()
		guard !characters.isEmpty, characters.allSatisfy(\.isTypeAhead) else {
			return .ignored
		}
		typeAheadBuffer.append(characters)
		selectFirstMatch()
		scheduleBufferReset()
		return .handled
	}

	private func activateSelectedRepository(withOption: Bool) -> KeyPress.Result {
		guard let id = selection,
		      let repo = monitor.repositories.first(where: { $0.id == id }) else {
			return .ignored
		}
		typeAheadBuffer = ""
		bufferResetTask?.cancel()
		if withOption {
			RepositoryOpener.openProjectOrPackage(repo)
		} else {
			RepositoryOpener.openInTower(repo)
		}
		return .handled
	}

	private func selectFirstMatch() {
		let prefix = typeAheadBuffer
		guard !prefix.isEmpty else { return }
		if let match = monitor.sortedRepositories.first(where: {
			$0.name.lowercased().hasPrefix(prefix)
		}) {
			selection = match.id
		}
	}

	private func scheduleBufferReset() {
		bufferResetTask?.cancel()
		bufferResetTask = Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(800))
			if !Task.isCancelled {
				typeAheadBuffer = ""
			}
		}
	}
}

private extension Character {
	var isTypeAhead: Bool {
		isLetter || isNumber || self == "-" || self == "_" || self == "."
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
