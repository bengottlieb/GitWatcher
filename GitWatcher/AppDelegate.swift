//
//  AppDelegate.swift
//  GitWatcher
//

import AppKit
import Observation
import SwiftUI
import Internal

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	static weak var shared: AppDelegate?

	var openMainWindow: (() -> Void)?
	var openSettings: (() -> Void)?

	private var statusItem: NSStatusItem?
	private var popover: NSPopover?

	override init() {
		super.init()
		AppDelegate.shared = self
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		installStatusItem()
		installPopover()
		trackIconState()
	}

	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		false
	}

	private func installStatusItem() {
		let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		item.button?.target = self
		item.button?.action = #selector(statusItemClicked(_:))
		item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
		statusItem = item
	}

	private func installPopover() {
		let popover = NSPopover()
		popover.contentSize = NSSize(width: 560, height: 420)
		popover.behavior = .transient
		popover.contentViewController = NSHostingController(
			rootView: MenuBarContentView { [weak self] in
				self?.showMainWindow(nil)
				self?.popover?.performClose(nil)
			}
		)
		self.popover = popover
	}

	private func trackIconState() {
		updateStatusIcon()
		withObservationTracking {
			_ = RepositoryMonitor.shared.attentionCount
		} onChange: { [weak self] in
			Task { @MainActor [weak self] in
				self?.trackIconState()
			}
		}
	}

	private func updateStatusIcon() {
		let count = RepositoryMonitor.shared.attentionCount
		statusItem?.button?.image = StatusItemIcon.image(
			badgeCount: count,
			appearance: statusItem?.button?.effectiveAppearance
		)
	}

	@objc private func statusItemClicked(_ sender: NSStatusBarButton) {
		let event = NSApp.currentEvent
		let isRightClick = event?.type == .rightMouseUp
		let isOptionClick = event?.modifierFlags.contains(.option) == true
		if isRightClick || isOptionClick {
			showAlternateMenu(from: sender)
		} else {
			togglePopover(from: sender)
		}
	}

	private func togglePopover(from button: NSStatusBarButton) {
		guard let popover else { return }
		if popover.isShown {
			popover.performClose(nil)
			return
		}
		NSApp.activate(ignoringOtherApps: true)
		popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
	}

	private func showAlternateMenu(from button: NSStatusBarButton) {
		let menu = NSMenu()
		menu.autoenablesItems = false

		let openItem = NSMenuItem(title: "Open Window", action: #selector(showMainWindow(_:)), keyEquivalent: "o")
		openItem.target = self
		menu.addItem(openItem)

		let refreshItem = NSMenuItem(title: "Refresh All", action: #selector(refreshAll), keyEquivalent: "r")
		refreshItem.target = self
		refreshItem.isEnabled = !RepositoryMonitor.shared.repositories.isEmpty
			&& !RepositoryMonitor.shared.isRefreshing
		menu.addItem(refreshItem)

		menu.addItem(.separator())

		let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
		settingsItem.target = self
		menu.addItem(settingsItem)

		menu.addItem(.separator())

		menu.addItem(
			withTitle: "Quit GitWatcher",
			action: #selector(NSApplication.terminate(_:)),
			keyEquivalent: "q"
		)

		statusItem?.menu = menu
		button.performClick(nil)
		statusItem?.menu = nil
	}

	@objc private func showMainWindow(_ sender: Any?) {
		NSApp.activate(ignoringOtherApps: true)
		if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue.contains(WindowID.main) == true }) {
			existing.makeKeyAndOrderFront(nil)
			return
		}
		openMainWindow?()
	}

	@objc private func refreshAll() {
		Task { @MainActor in
			await RepositoryMonitor.shared.refreshAll()
		}
	}

	@objc private func showSettings(_ sender: Any?) {
		NSApp.activate(ignoringOtherApps: true)
		if let openSettings {
			openSettings()
			return
		}
		showMainWindow(nil)
		DispatchQueue.main.async { [weak self] in
			self?.openSettings?()
		}
	}
}
