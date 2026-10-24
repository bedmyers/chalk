//
//  SampleData.swift
//  Chalk
//
//  A Push / Pull / Legs program for previews and debug builds.
//

#if DEBUG
import ChalkCore
import SwiftData

enum SampleData {
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
                    startingWeight: .pounds(exercise.pounds)
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

    /// An in-memory container with the sample program. `setsLogged` starts the
    /// first day and logs those reps on its main lift.
    static func previewContainer(setsLogged: [Int] = []) -> ModelContainer {
        do {
            let container = try ChalkModelContainer.make(inMemory: true)
            let context = container.mainContext
            let program = insertProgram(into: context)
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
