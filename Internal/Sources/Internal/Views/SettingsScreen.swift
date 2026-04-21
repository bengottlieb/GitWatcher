//
//  SettingsScreen.swift
//  Internal
//

import ServiceManagement
import SwiftUI

public struct SettingsScreen: View {
	@State private var loginItem = LoginItem.shared
	@State private var showingWhitelist = false
	@State private var registrationError: String?

	public init() {}

	public var body: some View {
		Form {
			Section {
				LaunchAtLoginToggle(
					loginItem: loginItem,
					onError: { registrationError = $0 }
				)
				if loginItem.requiresApproval {
					Text("Approval needed in System Settings → General → Login Items.")
						.font(.caption)
						.foregroundStyle(.orange)
				}
				if let error = registrationError {
					Text(error)
						.font(.caption)
						.foregroundStyle(.red)
				}
			}
			Section {
				Button("Edit Whitelist…") { showingWhitelist = true }
			}
		}
		.formStyle(.grouped)
		.frame(minWidth: 420, minHeight: 220)
		.sheet(isPresented: $showingWhitelist) { WhitelistEditorScreen() }
		.onAppear { loginItem.refresh() }
	}
}

private struct LaunchAtLoginToggle: View {
	let loginItem: LoginItem
	let onError: (String) -> Void

	var body: some View {
		Toggle("Launch at login", isOn: Binding(
			get: { loginItem.isEnabled },
			set: { newValue in
				do {
					try loginItem.setEnabled(newValue)
					onError("")
				} catch {
					onError(error.localizedDescription)
				}
			}
		))
	}
}
