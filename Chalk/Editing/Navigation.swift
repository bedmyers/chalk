//
//  Navigation.swift
//  Chalk
//

import Observation
import SwiftUI

/// Screens pushed on the app's navigation stack.
enum Route: Hashable {
    case program(Program)
    case day(ProgramDay)
}

/// The app's navigation path, shared through the environment.
@Observable
final class Router {
    var path: [Route] = []
}

extension View {
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
