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
			_ = RepositoryMonitor.shared.hasProblems
			_ = RepositoryMonitor.shared.hasPendingPushes
			_ = RepositoryMonitor.shared.isRefreshing
		} onChange: { [weak self] in
			Task { @MainActor in
				self?.trackIconState()
			}
		}
	}

	private func updateStatusIcon() {
		let monitor = RepositoryMonitor.shared
		let (symbol, tint): (String, NSColor?)
		if monitor.hasProblems {
			symbol = "exclamationmark.arrow.triangle.2.circlepath"
			tint = .systemRed
		} else if monitor.hasPendingPushes {
			symbol = "arrow.up.circle.fill"
			tint = .systemBlue
		} else {
			symbol = "arrow.triangle.2.circlepath"
			tint = nil
		}
		guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: "GitWatcher") else { return }
		if let tint {
			let config = NSImage.SymbolConfiguration(paletteColors: [tint])
			let image = base.withSymbolConfiguration(config) ?? base
			image.isTemplate = false
			statusItem?.button?.image = image
		} else {
			base.isTemplate = true
			statusItem?.button?.image = base
		}
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
}
