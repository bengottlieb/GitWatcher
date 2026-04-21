//
//  GitWatcherApp.swift
//  GitWatcher
//

import SwiftUI
import Internal

@main
struct GitWatcherApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

	var body: some Scene {
		Window("GitWatcher", id: WindowID.main) {
			RepositoriesScreen()
				.background(WindowOpenerBridgeView())
		}
		.defaultSize(width: 640, height: 420)
	}
}

enum WindowID {
	static let main = "repositories"
}

private struct WindowOpenerBridgeView: View {
	@Environment(\.openWindow) private var openWindow

	var body: some View {
		Color.clear
			.frame(width: 0, height: 0)
			.onAppear {
				AppDelegate.shared?.openMainWindow = {
					openWindow(id: WindowID.main)
				}
			}
	}
}
