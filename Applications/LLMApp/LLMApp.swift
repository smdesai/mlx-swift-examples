// Copyright © 2024 Apple Inc.

import SwiftUI

@main
struct LLMApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(DeviceStat())
        }
    }
}
