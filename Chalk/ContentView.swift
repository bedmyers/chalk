//
//  ContentView.swift
//  Chalk
//
//  Created by Blair Myers on 10/13/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            TodayView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .program(let program): ProgramView(program: program)
                    case .day(let day): DayView(day: day)
                    }
                }
        }
        .environment(router)
        .tint(Theme.Colors.action)
    }
}

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer())
        .preferredColorScheme(.dark)
}
#endif
