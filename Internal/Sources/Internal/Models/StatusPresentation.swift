//
//  StatusPresentation.swift
//  Internal
//

import SwiftUI

public extension RepositoryStatus {
	var summary: String {
		switch kind {
		case .unknown: "Not checked"
		case .checking: "Checking…"
		case .cloning: "Cloning…"
		case .clean: "Up to date"
		case .noRemote: "No remote"
		case .pulled: "Pulled \(remoteAhead) commit\(remoteAhead == 1 ? "" : "s")"
		case .discardedAndPulled: "Discarded local, pulled \(remoteAhead)"
		case .needsPush: "\(localAhead) commit\(localAhead == 1 ? "" : "s") to push"
		case .dirty: "\(dirtyFiles.count) uncommitted file\(dirtyFiles.count == 1 ? "" : "s")"
		case .diverged: "Diverged (\(localAhead) ahead / \(remoteAhead) behind)"
		case .error: message ?? "Error"
		}
	}

	var iconName: String {
		switch kind {
		case .unknown: "questionmark.circle"
		case .checking: "arrow.triangle.2.circlepath"
		case .cloning: "arrow.down.circle"
		case .clean, .pulled, .discardedAndPulled: "checkmark.circle.fill"
		case .noRemote: "icloud.slash"
		case .needsPush: "arrow.up.circle.fill"
		case .dirty: "pencil.circle.fill"
		case .diverged: "exclamationmark.triangle.fill"
		case .error: "xmark.octagon.fill"
		}
	}

	var tint: Color {
		switch kind {
		case .clean, .pulled, .discardedAndPulled: .green
		case .needsPush, .cloning: .blue
		case .dirty: .orange
		case .diverged, .error: .red
		case .noRemote: .secondary
		default: .secondary
		}
	}
}
