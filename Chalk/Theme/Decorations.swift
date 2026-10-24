//
//  Decorations.swift
//  Chalk
//
//  The 90s decoration. Use sparingly: today's main lift card, the weight bump,
//  onboarding, and the app icon only.
//

import SwiftUI

/// A diagonal repeating stripe of magenta / teal / yellow / grape.
struct LeotardStripe: View {
    var stripeWidth: CGFloat = 16

    var body: some View {
        Canvas { context, size in
            let colors = Theme.Colors.stripe
            var x = -size.height
            var index = 0
            while x < size.width {
                var band = Path()
                band.move(to: CGPoint(x: x, y: size.height))
                band.addLine(to: CGPoint(x: x + size.height, y: 0))
                band.addLine(to: CGPoint(x: x + size.height + stripeWidth, y: 0))
                band.addLine(to: CGPoint(x: x + stripeWidth, y: size.height))
                band.closeSubpath()
                context.fill(band, with: .color(colors[index % colors.count]))
                x += stripeWidth
                index += 1
            }
        }
        .accessibilityHidden(true)
    }
}

/// A Memphis zigzag line.
nonisolated struct ZigZag: Shape {
    var peaks: Int = 4

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let segment = rect.width / CGFloat(peaks * 2)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for index in 1...(peaks * 2) {
            let y = index.isMultiple(of: 2) ? rect.maxY : rect.minY
            path.addLine(to: CGPoint(x: rect.minX + segment * CGFloat(index), y: y))
        }
        return path
    }
}

/// A Memphis triangle.
nonisolated struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Zigzag, ring, and triangle, for the corner of a big-moment screen.
struct MemphisCluster: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZigZag()
                .stroke(Theme.Colors.decor, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .frame(width: 120, height: 28)
            Circle()
                .stroke(Theme.Colors.decor, lineWidth: 6)
                .frame(width: 34, height: 34)
                .offset(x: -20, y: 56)
            Triangle()
                .fill(Theme.Colors.decor)
                .frame(width: 30, height: 26)
                .offset(x: -84, y: 92)
        }
        .frame(width: 130, height: 120, alignment: .topTrailing)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 32) {
        LeotardStripe().frame(height: 24)
        MemphisCluster()
        Text("BENCH 185 → 190")
            .font(Theme.Fonts.screenTitle)
            .foregroundStyle(Theme.Colors.weight)
            .popShadow(Theme.Colors.action)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.background)
}
