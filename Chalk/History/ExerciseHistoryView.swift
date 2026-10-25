//
//  ExerciseHistoryView.swift
//  Chalk
//

import Charts
import ChalkCore
import SwiftData
import SwiftUI

/// One exercise over time: prescribed weight as a step line with markers for
/// bumps, deloads, and hand edits, plus every closed block. Covers the whole
/// lineage, so edited exercises read as one.
struct ExerciseHistoryView: View {
    let slot: ExerciseSlot

    var body: some View {
        let outcome = slot.progression()
        let points = WeightHistory.points(from: slot.weightHistory())
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(outcome)
                chartCard(points)
                blocksCard
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .background(Theme.Colors.background)
        .navigationTitle(slot.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ outcome: ProgressionOutcome) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let cycle = outcome.cycle {
                Text("Week \(cycle.week) of \(cycle.length)").eyebrowStyle()
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(outcome.nextWeight.formattedValue)
                    .font(Theme.Fonts.screenTitle)
                    .foregroundStyle(Theme.Colors.weight)
                Text(outcome.nextWeight.unit.symbol)
                    .font(Theme.Fonts.unit)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            .accessibilityElement(children: .combine)
            Text("\(slot.targetSets) × \(slot.targetReps) · \(slot.equipment.displayName)")
                .font(Theme.Fonts.target)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }

    // MARK: Chart

    private func chartCard(_ points: [WeightPoint]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if points.count < 2 {
                Text("Finish a workout to start the chart.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight.value)
                        )
                        .interpolationMethod(.stepEnd)
                        .foregroundStyle(Theme.Colors.weight)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                    }
                    ForEach(points.filter { $0.marker != nil }) { point in
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Weight", point.weight.value)
                        )
                        .symbol {
                            if let marker = point.marker {
                                MarkerSymbol(marker: marker)
                            }
                        }
                        .accessibilityLabel(point.marker.map(label(for:)) ?? "")
                        .accessibilityValue(point.weight.description)
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.Colors.border)
                        AxisValueLabel().foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(Theme.Colors.border)
                        AxisValueLabel().foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .frame(height: 220)

                legend
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Metrics.cardCornerRadius))
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach([WeightMarker.bump, .deload, .edited], id: \.self) { marker in
                HStack(spacing: 6) {
                    MarkerSymbol(marker: marker)
                    Text(label(for: marker))
                        .font(Theme.Fonts.target)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func label(for marker: WeightMarker) -> String {
        switch marker {
        case .bump: "Bump"
        case .deload: "Deload"
        case .edited: "Edited"
        }
    }

    // MARK: Blocks

    private var blocks: [(id: String, block: BlockResult)] {
        slot.lineage.reversed().flatMap { slot in
            slot.blockResults.enumerated().reversed().map { index, block in
                (id: "\(slot.id)-\(index)", block: block)
            }
        }
    }

    private var blocksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Blocks").eyebrowStyle()
            if blocks.isEmpty {
                Text("No blocks finished yet. A block closes after three completed weeks.")
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            ForEach(blocks, id: \.id) { item in
                BlockRow(block: item.block)
                if item.id != blocks.last?.id {
                    Divider().overlay(Theme.Colors.border)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: .rect(cornerRadius: Theme.Metrics.cardCornerRadius))
    }
}

private struct MarkerSymbol: View {
    let marker: WeightMarker

    var body: some View {
        switch marker {
        case .bump:
            Image(systemName: "arrowtriangle.up.fill")
                .foregroundStyle(Theme.Colors.done)
        case .deload:
            Image(systemName: "arrowtriangle.down.fill")
                .foregroundStyle(Theme.Colors.textSecondary)
        case .edited:
            Circle()
                .strokeBorder(Theme.Colors.textPrimary, lineWidth: 2)
                .frame(width: 12, height: 12)
        }
    }
}

private struct BlockRow: View {
    let block: BlockResult

    var body: some View {
        HStack {
            Text(block.weight.description)
                .font(Theme.Fonts.target)
                .foregroundStyle(Theme.Colors.textPrimary)
            HStack(spacing: 4) {
                ForEach(Array(block.weeks.enumerated()), id: \.offset) { _, week in
                    Image(systemName: week == .hit ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(week == .hit ? Theme.Colors.done : Theme.Colors.textSecondary)
                }
            }
            Spacer()
            Text(outcome)
                .font(Theme.Fonts.target)
                .foregroundStyle(block.passed ? Theme.Colors.done : Theme.Colors.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(block.weight.description), \(block.weeks.filter { $0 == .hit }.count) of \(block.weeks.count) weeks hit, \(outcome)")
    }

    private var outcome: String {
        switch block.event {
        case .increased(_, let to): "Up to \(to.formattedValue)"
        case .held: "Held"
        case .deloaded(_, let to): "Deload to \(to.formattedValue)"
        }
    }
}

#if DEBUG
#Preview {
    let container = SampleData.previewContainer(completedWeeks: 6)
    let slot = ProgramLibrary.activePrograms(in: container.mainContext)[0].activeSlots[0]
    return NavigationStack {
        ExerciseHistoryView(slot: slot)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
}
#endif
