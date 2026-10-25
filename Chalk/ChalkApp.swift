//
//  ChalkApp.swift
//  Chalk
//
//  Created by Blair Myers on 10/13/26.
//

import Foundation
import SwiftData
import SwiftUI

@main
struct ChalkApp: App {
    let modelContainer: ModelContainer = {
        #if DEBUG
        // UI tests launch with sample history in a throwaway in-memory store.
        if ProcessInfo.processInfo.arguments.contains(SampleData.sampleHistoryLaunchArgument) {
            return SampleData.previewContainer(completedWeeks: 3)
        }
        #endif
        do {
            return try ChalkModelContainer.make()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        #if DEBUG
        FontName.assertAllLoad()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Dark appearance only for v1.
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
