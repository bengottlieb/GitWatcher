//
//  StatusBadgeView.swift
//  Internal
//

import SwiftUI

struct StatusBadgeView: View {
	let status: RepositoryStatus

	var body: some View {
		Image(systemName: status.iconName)
			.font(.body)
			.foregroundStyle(status.tint)
			.symbolEffect(.rotate, options: .repeat(.continuous), isActive: status.isBusy)
			.frame(width: 18, height: 18)
	}
}
