//
//  DropTargetOverlayView.swift
//  Internal
//

import SwiftUI

struct DropTargetOverlayView: View {
	var body: some View {
		RoundedRectangle(cornerRadius: 16)
			.strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
			.background(
				RoundedRectangle(cornerRadius: 16)
					.fill(Color.accentColor.opacity(0.1))
			)
			.overlay {
				Label("Drop repositories to add", systemImage: "plus.rectangle.on.folder")
					.font(.title3.bold())
					.foregroundStyle(Color.accentColor)
					.padding()
					.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
			}
			.padding(12)
			.allowsHitTesting(false)
	}
}
