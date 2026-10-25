//
//  ContentView.swift
//  Chalk
//
//  Created by Blair Myers on 10/13/26.
//

import SwiftData
import SwiftUI

/// Today, History, and Program tabs. The sidebar-adaptable style shows a tab bar
/// on iPhone and adapts to a sidebar where the system supports one.
struct ContentView: View {
    @State private var router = Router()

    var body: some View {
        TabView(selection: $router.tab) {
            Tab("Today", systemImage: "figure.strengthtraining.traditional", value: AppTab.today) {
                TodayView()
            }

            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                NavigationStack(path: $router.historyPath) {
                    HistoryView()
                        .chalkDestinations()
                }
            }

            Tab("Program", systemImage: "list.bullet.clipboard", value: AppTab.program) {
                NavigationStack(path: $router.programPath) {
                    ProgramTab()
                        .chalkDestinations()
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .environment(router)
        .tint(Theme.Colors.action)
    }
}

/// The Program tab's root: the active program, or a prompt to create or restore one.
struct ProgramTab: View {
    @Query(filter: #Predicate<Program> { $0.archivedAt == nil }, sort: \Program.createdAt)
    private var programs: [Program]

    var body: some View {
        if let program = programs.first {
            ProgramView(program: program)
        } else {
            NoProgramView()
                .background(Theme.Colors.background)
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(SampleData.previewContainer())
        .preferredColorScheme(.dark)
}
#endif
