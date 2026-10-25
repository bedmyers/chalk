//
//  Navigation.swift
//  Chalk
//

import Foundation
import Observation
import SwiftUI

/// The app's top-level tabs.
enum AppTab: Hashable {
    case today
    case history
    case program
}

/// Screens pushed within a tab's navigation stack.
enum Route: Hashable {
    case day(ProgramDay)
    case archivedPrograms
    case workout(WorkoutSession)
    case exerciseHistory(ExerciseSlot)

    /// Identity for hashing: the case plus its model's stable `id`. Written out because
    /// synthesized conformance over model payloads isn't reliable, and not keyed by
    /// `persistentModelID`, which changes when a new object is first saved.
    private var key: (String, UUID?) {
        switch self {
        case .day(let day): ("day", day.id)
        case .archivedPrograms: ("archivedPrograms", nil)
        case .workout(let session): ("workout", session.id)
        case .exerciseHistory(let slot): ("exerciseHistory", slot.id)
        }
    }

    static func == (lhs: Route, rhs: Route) -> Bool {
        lhs.key == rhs.key
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key.0)
        hasher.combine(key.1)
    }
}

/// The selected tab and each tab's navigation path, shared through the environment.
@Observable
final class Router {
    var tab = AppTab.today
    var historyPath: [Route] = []
    var programPath: [Route] = []

    /// Switches to the Program tab, at its root or at `route`.
    func showProgram(_ route: Route? = nil) {
        tab = .program
        programPath = route.map { [$0] } ?? []
    }
}

extension View {
    /// Destinations for every `Route`, for each tab's navigation stack.
    func chalkDestinations() -> some View {
        navigationDestination(for: Route.self) { route in
            switch route {
            case .day(let day): DayView(day: day)
            case .archivedPrograms: ArchivedProgramsView()
            case .workout(let session): WorkoutDetailView(session: session)
            case .exerciseHistory(let slot): ExerciseHistoryView(slot: slot)
            }
        }
    }

    /// Dark list styling for editor screens.
    func chalkListStyle() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .font(Theme.Fonts.body)
            .foregroundStyle(Theme.Colors.textPrimary)
    }

    /// A list row on a surface card.
    func chalkRow() -> some View {
        listRowBackground(Theme.Colors.surface)
    }
}
