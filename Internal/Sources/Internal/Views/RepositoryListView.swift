//
//  RepositoryListView.swift
//  Internal
//

import SwiftUI

struct RepositoryListView: View {
	let monitor: RepositoryMonitor
	let sortMode: SortMode
	@State private var selection: UUID?
	@State private var typeAheadBuffer: String = ""
	@State private var bufferResetTask: Task<Void, Never>?
	@State private var displayOrder: [UUID] = []
	@FocusState private var isListFocused: Bool
	@Environment(\.controlActiveState) private var activeState

	private var displayedRepos: [Repository] {
		let byID = Dictionary(uniqueKeysWithValues: monitor.repositories.map { ($0.id, $0) })
		var result = displayOrder.compactMap { byID[$0] }
		let seen = Set(displayOrder)
		result.append(contentsOf: monitor.repositories.filter { !seen.contains($0.id) && $0.existsOnDisk })
		return result
	}

	var body: some View {
		Group {
			if displayedRepos.isEmpty {
				EmptyRepositoriesView()
			} else {
				ScrollViewReader { proxy in
					List(selection: $selection) {
						ForEach(displayedRepos) { repo in
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
					.onAppear {
						rebuildOrder()
						scrollToTop(proxy: proxy)
						focusListSoon()
					}
					.onChange(of: activeState) { _, new in
						if new == .key { focusListSoon() }
					}
					.onChange(of: sortMode) { _, _ in
						rebuildOrder()
						scrollToTop(proxy: proxy)
					}
					.onChange(of: monitor.isRefreshing) { _, refreshing in
						if !refreshing { rebuildOrder() }
					}
					.onChange(of: monitor.repositories) { _, _ in
						if !monitor.isRefreshing { rebuildOrder() }
					}
				}
			}
		}
	}

	private func scrollToTop(proxy: ScrollViewProxy) {
		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(50))
			guard let firstID = displayOrder.first else { return }
			withAnimation(.easeOut(duration: 0.2)) {
				proxy.scrollTo(firstID, anchor: .top)
			}
		}
	}

	private func rebuildOrder() {
		displayOrder = monitor.sortedRepositories(mode: sortMode).map(\.id)
	}

	private func focusListSoon() {
		Task { @MainActor in
			try? await Task.sleep(for: .milliseconds(100))
			isListFocused = true
		}
	}

	private func deleteRepositories(at offsets: IndexSet) {
		let displayed = displayedRepos
		for index in offsets {
			monitor.removeRepository(id: displayed[index].id)
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
		if let match = displayedRepos.first(where: {
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
