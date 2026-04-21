//
//  RepositoriesScreen.swift
//  Internal
//

import SwiftUI

public struct RepositoriesScreen: View {
	@State private var monitor = RepositoryMonitor.shared
	@State private var optionKey = OptionKeyObserver()
	@State private var isPickingFolder = false
	@State private var showingWhitelist = false
	@State private var isDropTargeted = false
	@Environment(\.controlActiveState) private var activeState

	public init() {}

	public var body: some View {
		VStack(spacing: 0) {
			RepositoryListView(monitor: monitor)
			Divider()
			RepositoriesToolbar(
				monitor: monitor,
				onAdd: { isPickingFolder = true },
				onEditWhitelist: { showingWhitelist = true }
			)
		}
		.environment(\.isOptionKeyHeld, optionKey.isHeld)
		.frame(minWidth: 480, minHeight: 320)
		.onChange(of: activeState) { _, newValue in
			if newValue == .key {
				Task { await monitor.refreshAll() }
			}
		}
		.fileImporter(
			isPresented: $isPickingFolder,
			allowedContentTypes: [.folder],
			allowsMultipleSelection: true
		) { result in
			handlePickedFolders(result)
		}
		.sheet(isPresented: $showingWhitelist) {
			WhitelistEditorScreen()
		}
		.dropDestination(for: URL.self) { urls, _ in
			handleDrop(urls: urls)
		} isTargeted: { isDropTargeted = $0 }
		.overlay {
			if isDropTargeted { DropTargetOverlayView() }
		}
	}

	private func handlePickedFolders(_ result: Result<[URL], Error>) {
		guard case .success(let urls) = result else { return }
		for url in urls {
			monitor.addRepository(at: url)
		}
	}

	private func handleDrop(urls: [URL]) -> Bool {
		let directories = urls.filter { isDirectory($0) }
		for url in directories {
			monitor.addRepository(at: url)
		}
		return !directories.isEmpty
	}

	private func isDirectory(_ url: URL) -> Bool {
		(try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
	}
}
