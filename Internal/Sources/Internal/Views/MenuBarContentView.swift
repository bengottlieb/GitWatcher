//
//  MenuBarContentView.swift
//  Internal
//

import SwiftUI

public struct MenuBarContentView: View {
	let openWindow: () -> Void

	public init(openWindow: @escaping () -> Void) {
		self.openWindow = openWindow
	}

	public var body: some View {
		VStack(spacing: 0) {
			HStack {
				SortModePickerView()
				Spacer()
			}
			.padding(.horizontal, 10)
			.padding(.top, 8)
			.padding(.bottom, 4)
			RepositoriesScreen()
			Divider()
			MenuBarAppBar(openWindow: openWindow)
		}
		.frame(minWidth: 520, minHeight: 360)
	}
}

private struct MenuBarAppBar: View {
	let openWindow: () -> Void

	var body: some View {
		HStack {
			Button("Open Window", action: openWindow)
			Spacer()
			Button("Quit") { NSApp.terminate(nil) }
				.keyboardShortcut("q", modifiers: [.command])
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
	}
}
