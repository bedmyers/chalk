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
    /// Every program, archived or not: onboarding only shows when there are none.
    @Query private var allPrograms: [Program]
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var router = Router()
    @State private var isShowingWelcomeBack = false

    var body: some View {
        Group {
            if OnboardingGate.shouldShow(programCount: allPrograms.count, hasSeenOnboarding: hasSeenOnboarding) {
                OnboardingView(onFinish: finishOnboarding)
            } else {
                tabs
            }
        }
        .onChange(of: allPrograms.isEmpty) { wasEmpty, isEmpty in
            // On a new device, programs can arrive from iCloud mid-onboarding.
            // Nothing is created before onboarding's last step, so just step aside.
            if OnboardingGate.isWelcomeBack(hadPrograms: !wasEmpty, hasPrograms: !isEmpty, hasSeenOnboarding: hasSeenOnboarding) {
                hasSeenOnboarding = true
                isShowingWelcomeBack = true
            }
        }
        .alert("Welcome back", isPresented: $isShowingWelcomeBack) {
            Button("Let's Go", role: .cancel) {}
        } message: {
            Text("Your programs synced from iCloud.")
        }
    }

    private func finishOnboarding(_ result: OnboardingResult) {
        hasSeenOnboarding = true
        switch result {
        case .startTraining, .skipped: router.tab = .today
        case .buildProgram: router.showProgram()
        }
    }

    private var tabs: some View {
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
    @State private var isShowingSettings = false

    var body: some View {
        Group {
            if let program = programs.first {
                ProgramView(program: program)
            } else {
                NoProgramView()
                    .background(Theme.Colors.background)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape") {
                    isShowingSettings = true
                }
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
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
