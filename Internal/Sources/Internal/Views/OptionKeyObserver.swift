//
//  OptionKeyObserver.swift
//  Internal
//

import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class OptionKeyObserver {
	var isHeld: Bool

	@ObservationIgnored nonisolated(unsafe) private var monitor: Any?

	init() {
		self.isHeld = NSEvent.modifierFlags.contains(.option)
		monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
			let held = event.modifierFlags.contains(.option)
			Task { @MainActor [weak self] in
				self?.isHeld = held
			}
			return event
		}
	}

	deinit {
		if let monitor { NSEvent.removeMonitor(monitor) }
	}
}

private struct OptionKeyHeldEnvironmentKey: EnvironmentKey {
	static let defaultValue = false
}

extension EnvironmentValues {
	var isOptionKeyHeld: Bool {
		get { self[OptionKeyHeldEnvironmentKey.self] }
		set { self[OptionKeyHeldEnvironmentKey.self] = newValue }
	}
}
