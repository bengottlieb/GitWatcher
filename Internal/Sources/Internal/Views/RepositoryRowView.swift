//
//  RepositoryRowView.swift
//  Internal
//

import AppKit
import SwiftUI

struct RepositoryRowView: View {
	let repository: Repository
	let status: RepositoryStatus
	let monitor: RepositoryMonitor
	@Environment(\.isOptionKeyHeld) private var showPath

	var body: some View {
		HStack(spacing: 10) {
			HStack(spacing: 8) {
				StatusBadgeView(status: status)
				Text(showPath ? repository.displayPath : repository.name)
					.font(.body)
					.lineLimit(1)
					.truncationMode(.middle)
				Text(status.summary)
					.font(.caption)
					.foregroundStyle(status.tint)
					.lineLimit(1)
				Spacer(minLength: 8)
			}
			.contentShape(Rectangle())
			.onTapGesture { openInTower() }
			.help("Click to open in Tower")
			RowActionsView(repository: repository, status: status, monitor: monitor)
		}
		.padding(.vertical, 1)
		.contextMenu {
			Button("Refresh") {
				Task { await monitor.refresh(repositoryID: repository.id) }
			}
			if let projectURL = xcodeProjectURL {
				Button("Open Project") { NSWorkspace.shared.open(projectURL) }
			}
			if packageFileURL != nil {
				Button("Open Package") { openPackageInXcode() }
			}
			Button("Reveal in Finder") {
				NSWorkspace.shared.activateFileViewerSelecting([repository.url])
			}
			Divider()
			Button("Remove", role: .destructive) {
				monitor.removeRepository(id: repository.id)
			}
		}
	}

	private var xcodeProjectURL: URL? {
		let contents = try? FileManager.default.contentsOfDirectory(
			at: repository.url,
			includingPropertiesForKeys: nil,
			options: [.skipsHiddenFiles]
		)
		return contents?.first { $0.pathExtension == "xcodeproj" }
	}

	private var packageFileURL: URL? {
		let url = repository.url.appending(path: "Package.swift")
		return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
	}

	private func openPackageInXcode() {
		let xcode = URL(fileURLWithPath: "/Applications/Xcode.app")
		guard FileManager.default.fileExists(atPath: xcode.path(percentEncoded: false)) else {
			if let url = packageFileURL { NSWorkspace.shared.open(url) }
			return
		}
		NSWorkspace.shared.open(
			[repository.url],
			withApplicationAt: xcode,
			configuration: NSWorkspace.OpenConfiguration(),
			completionHandler: nil
		)
	}

	private func openInTower() {
		let tower = URL(fileURLWithPath: "/Applications/Tower.app")
		guard FileManager.default.fileExists(atPath: tower.path(percentEncoded: false)) else {
			NSWorkspace.shared.activateFileViewerSelecting([repository.url])
			return
		}
		NSWorkspace.shared.open(
			[repository.url],
			withApplicationAt: tower,
			configuration: NSWorkspace.OpenConfiguration(),
			completionHandler: nil
		)
	}
}

private struct RowActionsView: View {
	let repository: Repository
	let status: RepositoryStatus
	let monitor: RepositoryMonitor

	var body: some View {
		HStack(spacing: 6) {
			if status.needsPush {
				Button("Push") {
					Task { await monitor.push(repositoryID: repository.id) }
				}
				.buttonStyle(.borderedProminent)
			}
			Button {
				Task { await monitor.refresh(repositoryID: repository.id) }
			} label: {
				Image(systemName: "arrow.clockwise")
			}
			.buttonStyle(.borderless)
			.help("Refresh")
		}
	}
}
