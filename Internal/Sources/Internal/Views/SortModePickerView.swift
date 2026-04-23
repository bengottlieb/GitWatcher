//
//  SortModePickerView.swift
//  Internal
//

import SharedSettings
import SwiftUI

struct SortModePickerView: View {
	@Setting(SortModeKey.self) private var sortMode

	var body: some View {
		Picker("Sort", selection: $sortMode) {
			ForEach(SortMode.allCases, id: \.self) { mode in
				Text(mode.label).tag(mode)
			}
		}
		.pickerStyle(.segmented)
		.labelsHidden()
	}
}
