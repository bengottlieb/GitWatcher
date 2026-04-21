//
//  LoginItem.swift
//  Internal
//

import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
public final class LoginItem {
	public static let shared = LoginItem()

	public private(set) var status: SMAppService.Status
	public var isEnabled: Bool { status == .enabled }
	public var requiresApproval: Bool { status == .requiresApproval }

	private init() {
		self.status = SMAppService.mainApp.status
	}

	public func refresh() {
		status = SMAppService.mainApp.status
	}

	public func setEnabled(_ enabled: Bool) throws {
		if enabled {
			try SMAppService.mainApp.register()
		} else {
			try SMAppService.mainApp.unregister()
		}
		refresh()
	}
}
