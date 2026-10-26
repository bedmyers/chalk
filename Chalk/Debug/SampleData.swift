//
//  SampleData.swift
//  Chalk
//
//  A Push / Pull / Legs program for previews and debug builds.
//

#if DEBUG
import ChalkCore
import Foundation
import SwiftData

enum SampleData {
    /// Launch argument that starts the app with the sample program and three
    /// weeks of history in memory. For UI tests.
    static let sampleHistoryLaunchArgument = "-ChalkSampleHistory"

    /// Launch argument that starts the app like a first launch: an empty in-memory
    /// store and no saved onboarding or unit choice. For onboarding UI tests.
    static let emptyStoreLaunchArgument = "-ChalkEmptyStore"

    private struct SampleExercise {
        let name: String
        let equipment: Equipment
        let bodyRegion: BodyRegion
        let sets: Int
        let reps: Int
        let pounds: Double
    }

    private static let days: [(name: String, exercises: [SampleExercise])] = [
        ("Push Day", [
            SampleExercise(name: "Bench Press", equipment: .barbell, bodyRegion: .upper, sets: 4, reps: 8, pounds: 185),
            SampleExercise(name: "Overhead Press", equipment: .barbell, bodyRegion: .upper, sets: 4, reps: 8, pounds: 115),
            SampleExercise(name: "Incline DB Press", equipment: .dumbbell, bodyRegion: .upper, sets: 3, reps: 10, pounds: 60),
        ]),
        ("Pull Day", [
            SampleExercise(name: "Barbell Row", equipment: .barbell, bodyRegion: .upper, sets: 4, reps: 8, pounds: 155),
            SampleExercise(name: "Lat Pulldown", equipment: .machine, bodyRegion: .upper, sets: 3, reps: 10, pounds: 120),
            SampleExercise(name: "DB Curl", equipment: .dumbbell, bodyRegion: .upper, sets: 3, reps: 12, pounds: 25),
        ]),
        ("Leg Day", [
            SampleExercise(name: "Squat", equipment: .barbell, bodyRegion: .lower, sets: 4, reps: 8, pounds: 225),
            SampleExercise(name: "Romanian Deadlift", equipment: .barbell, bodyRegion: .lower, sets: 3, reps: 10, pounds: 185),
            SampleExercise(name: "Leg Press", equipment: .machine, bodyRegion: .lower, sets: 3, reps: 12, pounds: 270),
        ]),
    ]

    @discardableResult
    static func insertProgram(into context: ModelContext) -> Program {
        let program = Program(name: "Push Pull Legs", unit: .pounds)
        context.insert(program)

        for (dayIndex, sample) in days.enumerated() {
            let day = ProgramDay(name: sample.name, order: dayIndex)
            context.insert(day)
            day.program = program

            for (order, exercise) in sample.exercises.enumerated() {
                let slot = ExerciseSlot(
                    name: exercise.name,
                    equipment: exercise.equipment,
                    bodyRegion: exercise.bodyRegion,
                    targetSets: exercise.sets,
                    targetReps: exercise.reps,
                    increment: exercise.bodyRegion.defaultIncrement(in: .pounds),
                    startingWeight: .pounds(exercise.pounds),
                    catalogID: ExerciseCatalog.matching(name: exercise.name)?.id
                )
                context.insert(slot)
                slot.program = program

                let entry = DayEntry(order: order)
                context.insert(entry)
                entry.day = day
                entry.slot = slot
            }
        }
        return program
    }

    /// Logs `weeks` training weeks of the sample program in the past, two days apart.
    /// Every set hits except bench in week 5, so history has a bump and a held block.
    static func insertHistory(weeks: Int, for program: Program, into context: ModelContext) {
        guard weeks > 0 else { return }
        let days = program.sortedDays
        let gap: TimeInterval = 2 * 86_400
        var date = Date.now.addingTimeInterval(-gap * Double(weeks * days.count + 1))
        for week in 1...weeks {
            for day in days {
                let session = program.startSession(for: day, week: week, in: context)
                for log in session.sortedExerciseLogs {
                    for index in 0..<log.targetSets {
                        let short = week == 5 && log.exerciseName == "Bench Press" && index == log.targetSets - 1
                        log.logSet(reps: short ? log.targetReps - 2 : log.targetReps, in: context)
                    }
                }
                session.complete()
                session.startedAt = date
                session.completedAt = date
                date = date.addingTimeInterval(gap)
            }
        }
    }

    /// An in-memory container with the sample program. `completedWeeks` adds past
    /// workouts; `setsLogged` starts the next day and logs those reps on its main lift.
    static func previewContainer(completedWeeks: Int = 0, setsLogged: [Int] = []) -> ModelContainer {
        do {
            let container = try ChalkModelContainer.make(inMemory: true)
            let context = container.mainContext
            let program = insertProgram(into: context)
            insertHistory(weeks: completedWeeks, for: program, into: context)
            if !setsLogged.isEmpty, let day = program.sortedDays.first {
                let session = program.startSession(for: day, week: 1, in: context)
                if let log = session.sortedExerciseLogs.first {
                    for reps in setsLogged {
                        log.logSet(reps: reps, in: context)
                    }
                }
            }
            return container
        } catch {
            fatalError("Could not create preview container: \(error)")
        }
    }
}
#endif
