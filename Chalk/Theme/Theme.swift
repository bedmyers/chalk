//
//  Theme.swift
//  Chalk
//
//  "Leotard After Dark": every color and font in the app comes from here.
//  One job per color, so users learn the color language. See CLAUDE.md → Design.
//

import SwiftUI
import UIKit

enum Theme {
    enum Colors {
        /// App background.
        static let background = Color(hex: 0x110E1C)
        /// Cards and rows.
        static let surface = Color(hex: 0x1B1630)
        /// Subtle dividers and outlines.
        static let border = Color(hex: 0x2A2440)
        /// Main text.
        static let textPrimary = Color(hex: 0xF5F2FF)
        /// Set/rep targets, captions.
        static let textSecondary = Color(hex: 0xB7AED6)
        /// Highlighter yellow. Weights only: the most important number on screen.
        static let weight = Color(hex: 0xF7FF3C)
        /// Teal. Completed sets and success states only.
        static let done = Color(hex: 0x00E0C6)
        /// Magenta. Primary buttons and actions only.
        static let action = Color(hex: 0xFF2D95)
        /// Grape. Decoration only (shapes, drop-shadows). Never text.
        static let decor = Color(hex: 0x8A4DFF)
        /// Text drawn on `action` and `done` fills.
        static let onFill = background
        /// The leotard stripe, in order.
        static let stripe: [Color] = [action, done, weight, decor]
    }

    enum Fonts {
        /// The weight on a workout-mode page, readable from across the bench.
        static let focusWeight = custom(.fugazOne, 150, relativeTo: .largeTitle)
        /// Exercise name on a workout-mode page. Use with uppercase and tracking.
        static let focusName = custom(.barlowBold, 38, relativeTo: .title)
        /// The rest countdown.
        static let timer = custom(.fugazOne, 40, relativeTo: .title)
        /// Today's main lift weight.
        static let heroWeight = custom(.fugazOne, 96, relativeTo: .largeTitle)
        /// Screen titles ("PUSH DAY").
        static let screenTitle = custom(.fugazOne, 52, relativeTo: .largeTitle)
        /// Weights in exercise rows.
        static let rowWeight = custom(.fugazOne, 40, relativeTo: .title)
        /// Rep counts inside set buttons.
        static let setReps = custom(.fugazOne, 24, relativeTo: .title2)
        /// The unit beside a hero weight ("LB").
        static let unit = custom(.barlowBold, 28, relativeTo: .title3)
        /// Exercise names. Use with `.exerciseNameStyle()` for case and tracking.
        static let exerciseName = custom(.barlowBold, 22, relativeTo: .headline)
        /// Small uppercase labels above titles. Use with `.eyebrowStyle()`.
        static let eyebrow = custom(.barlowBold, 17, relativeTo: .subheadline)
        /// Set × rep targets.
        static let target = custom(.barlowSemiBold, 20, relativeTo: .subheadline)
        /// Body copy.
        static let body = custom(.barlowMedium, 19, relativeTo: .body)
        /// Button labels.
        static let button = custom(.barlowBold, 22, relativeTo: .headline)

        /// Custom fonts scale with Dynamic Type relative to `textStyle`.
        private static func custom(_ name: FontName, _ size: CGFloat, relativeTo textStyle: Font.TextStyle) -> Font {
            Font.custom(name.rawValue, size: size, relativeTo: textStyle)
        }
    }

    enum Metrics {
        static let cardCornerRadius: CGFloat = 28
        static let screenPadding: CGFloat = 20
        /// Offset for hard drop-shadows on display type.
        static let popShadowOffset: CGFloat = 4
    }
}

/// PostScript names of the bundled fonts, registered under UIAppFonts in Info.plist.
enum FontName: String, CaseIterable {
    case fugazOne = "FugazOne-Regular"
    case barlowMedium = "BarlowCondensed-Medium"
    case barlowSemiBold = "BarlowCondensed-SemiBold"
    case barlowBold = "BarlowCondensed-Bold"

    /// Bundled fonts that UIKit can't load by PostScript name.
    static var missing: [FontName] {
        allCases.filter { UIFont(name: $0.rawValue, size: 12) == nil }
    }

    #if DEBUG
    /// Fails fast in debug builds if a font file is missing or misnamed,
    /// instead of silently falling back to the system font.
    static func assertAllLoad() {
        let missing = missing
        assert(missing.isEmpty, "Bundled fonts failed to load: \(missing.map(\.rawValue))")
    }
    #endif
}

// MARK: - Text styles

extension View {
    /// Uppercase, wide-tracked exercise name.
    func exerciseNameStyle() -> some View {
        font(Theme.Fonts.exerciseName)
            .textCase(.uppercase)
            .tracking(2)
            .foregroundStyle(Theme.Colors.textPrimary)
    }

    /// Small uppercase label above a title.
    func eyebrowStyle() -> some View {
        font(Theme.Fonts.eyebrow)
            .textCase(.uppercase)
            .tracking(3)
            .foregroundStyle(Theme.Colors.textSecondary)
    }

    /// A hard, offset drop-shadow in a second color. Big moments only.
    func popShadow(_ color: Color = Theme.Colors.decor, offset: CGFloat = Theme.Metrics.popShadowOffset) -> some View {
        shadow(color: color, radius: 0, x: offset, y: offset)
    }
}

extension Color {
    /// A color from a 24-bit RGB hex literal, e.g. `0xFF2D95`.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
