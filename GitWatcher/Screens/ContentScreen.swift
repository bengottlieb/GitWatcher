//
//  ContentScreen.swift
//  GitWatcher
//
//  Created by Ben Gottlieb on 4/21/26.
//

import SwiftUI

struct ContentScreen: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentScreen()
}
