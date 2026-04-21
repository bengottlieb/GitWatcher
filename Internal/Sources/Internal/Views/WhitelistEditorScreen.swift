//
//  WhitelistEditorScreen.swift
//  Internal
//

import SwiftUI

struct WhitelistEditorScreen: View {
	@Environment(\.dismiss) private var dismiss
	@State private var monitor = RepositoryMonitor.shared
	@State private var newEntry: String = ""

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text("Whitelist")
				.font(.title3).bold()
				.padding([.horizontal, .top])
			Text("Files listed here will be discarded on update when the remote has new commits.")
				.font(.caption)
				.foregroundStyle(.secondary)
				.padding(.horizontal)
			List {
				ForEach(monitor.whitelist, id: \.self) { entry in
					Text(entry).font(.body.monospaced())
				}
				.onDelete(perform: delete)
			}
			WhitelistAddRowView(text: $newEntry, onAdd: add)
				.padding(10)
			HStack {
				Spacer()
				Button("Done") { dismiss() }
					.keyboardShortcut(.defaultAction)
			}
			.padding([.horizontal, .bottom])
		}
		.frame(minWidth: 360, minHeight: 360)
	}

	private func add() {
		let trimmed = newEntry.trimmingCharacters(in: .whitespaces)
		guard !trimmed.isEmpty, !monitor.whitelist.contains(trimmed) else { return }
		monitor.whitelist.append(trimmed)
		newEntry = ""
	}

	private func delete(at offsets: IndexSet) {
		var list = monitor.whitelist
		list.remove(atOffsets: offsets)
		monitor.whitelist = list
	}
}

private struct WhitelistAddRowView: View {
	@Binding var text: String
	let onAdd: () -> Void

	var body: some View {
		HStack {
			TextField("Filename (e.g. Package.resolved)", text: $text)
				.textFieldStyle(.roundedBorder)
				.onSubmit(onAdd)
			Button("Add", action: onAdd)
				.disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
		}
	}
}
