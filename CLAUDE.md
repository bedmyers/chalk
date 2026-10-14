# Chalk

An iOS app for progressive overload lifting. Users enter their program and starting weights once; the app tells them what to lift each day and automatically increases weights when they earn it.

**Core principle:** remove thinking at the gym. Open the app → today's workout is pre-filled with the right weights → tap through sets. Logging speed beats feature count. Every feature should serve "save workouts and weights, progress automatically."

## Progression rules

Decided:
- Programs run in **3-week blocks**.
- Each exercise slot has a target (sets × reps) and a weight.
- A week counts as a **hit only if every set reaches the target reps**. 8, 8, 8, 7 on a 4×8 target is a miss.
- If the user hits all 3 weeks of a block, the weight increases for the next block. Otherwise it stays the same.
- **Skipped weeks pause the block.** A block completes after 3 *completed* weeks, not 3 calendar weeks.
- **Auto-deload:** after 2 consecutive failed blocks on an exercise, drop its weight ~10% (rounded to loadable plates) and progress from there.
- **Increments:** smart defaults (+5 lb / +2.5 kg lower body, +2.5 lb / +1.25 kg upper body), editable per exercise.
- **Units:** lb and kg, chosen by the user in settings. Increments and plate math follow the chosen unit.
- **Plate rounding:** weights round to what's loadable with a default standard plate set (including small plates). The bar weight and plate set are stored as settings so they can be made editable later.

Open (don't implement until decided; ask if a task depends on one):
- Which progression schemes ship in v1 beyond the 3-week rule (e.g. double progression with rep ranges). Either way, design the rule as a swappable strategy per exercise so schemes can be added without reworking the engine.

## Tech stack

- SwiftUI, Swift 6 language mode (strict concurrency)
- App target uses MainActor default actor isolation
- SwiftData with CloudKit sync (iCloud private database)
- Swift Testing for unit tests; XCTest only for UI tests
- Plain SwiftUI + `@Observable` view models where a screen needs real logic, and `@Query` in views. **No TCA.**
- No third-party dependencies without asking first

## Project structure

- **`ChalkCore`** (local Swift package): the progression engine, plate math, and value types. It must not import SwiftUI or SwiftData. Types are `Sendable` structs and enums, nonisolated. All engine tests live here so they run without a simulator.
- **App target**: SwiftData `@Model` types, views, and app wiring. The app converts `@Model` data into ChalkCore value snapshots before calling the engine; never pass `@Model` objects into ChalkCore.
- `@Model` objects and `ModelContext` aren't `Sendable`. Keep them on the main actor. For background work, use `@ModelActor` and pass `PersistentIdentifier`s.

## SwiftData + CloudKit model rules

CloudKit is enabled, so every `@Model` must follow these rules or the container will fail to load:
- No `@Attribute(.unique)`
- Every stored property has a default value or is optional
- Every relationship is optional
- Prefer additive schema changes. Once the schema is deployed to production (first TestFlight), fields can't be renamed or deleted, so flag any model change that would be painful after shipping.

## Architecture

- **The progression engine is a pure function:** `(history, rules) → next targets`. No SwiftData, no UI, no side effects inside it. It must be fully unit-tested, because a wrong weight bump destroys user trust.
- Keep domain logic (engine, value types) separate from persistence (`@Model` types) and views.
- Model hierarchy (rough, refine as needed): Program → Block → Day → ExerciseSlot (target sets/reps, increment, progression rule) and WorkoutSession → SetLog.
- **Keep sessions generic.** Strength sets are one kind of entry; cardio/triathlon sessions will be added later and shouldn't require a migration-heavy redesign.

## Testing

- Use parameterized tests (`@Test(arguments:)`) for the progression engine, covering a table of scenarios: all hit, one set missed, a missed week, the boundary weeks of a block, and multiple consecutive blocks.
- Any change to progression logic requires tests for the new behavior.

## Design

- The visual direction is **funky and loud**: bold color, big numbers, playful energy. The exact palette is undecided (candidates: high-contrast black/acid lime/hot pink; retro purple/tangerine/cyan; risograph cream/fluoro pink/blue).
- Put colors and fonts in a central theme so the palette can be swapped in one place. Don't hardcode colors in views.
- The weight-increase moment should feel like an event (animation, haptic). It's the app's emotional payoff.

## Roadmap (not v1 unless asked)

- AI features: natural-language/voice set logging, a program builder via questionnaire, a stall coach that explains failed blocks, and a chat grounded in the user's log data
  - Set logging uses Apple's on-device Foundation Models (guided generation), with manual logging as the fallback on unsupported devices
  - Program builder, stall coach, and chat use the Claude API through a backend proxy. **Never put an API key in the app.**
- Rest timer as a Live Activity, HealthKit writes, Apple Watch app
- Cardio / triathlon tracking
