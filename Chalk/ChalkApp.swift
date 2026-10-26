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
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(SampleData.sampleHistoryLaunchArgument) {
            return SampleData.previewContainer(completedWeeks: 3)
        }
        if arguments.contains(SampleData.emptyStoreLaunchArgument) {
            // A true first launch: forget onboarding and unit choices from earlier runs.
            // (Passing them as launch arguments would pin them and ignore what the app saves.)
            UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
            UserDefaults.standard.removeObject(forKey: "defaultUnit")
            do {
                return try ChalkModelContainer.make(inMemory: true)
            } catch {
                fatalError("Could not create in-memory ModelContainer: \(error)")
            }
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
