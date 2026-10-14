//
//  ChalkApp.swift
//  Chalk
//
//  Created by Blair Myers on 10/13/26.
//

import SwiftData
import SwiftUI

@main
struct ChalkApp: App {
    let modelContainer: ModelContainer = {
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
