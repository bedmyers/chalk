# Chalk

An iOS app for progressive overload lifting. Users enter their program and starting weights once; the app tells them what to lift each day and automatically increases weights when they earn it.

**Core principle:** remove thinking at the gym. Open the app → today's workout is pre-filled with the right weights → tap through sets. Logging speed beats feature count. Every feature should serve "save workouts and weights, progress automatically."

## Progression rules

Decided (implemented in `ChalkCore`):
- Programs run in **3-week blocks**, tracked per exercise slot.
- **Training weeks, not calendar weeks.** A program is a weekly template of days. A week finishes the moment every day in it is completed or skipped. A missed day stays as the next workout until it's logged or skipped.
- Each exercise slot has a target (sets × reps), an increment, and a starting weight. A slot can appear on several days and shares one weight; every one of those sessions must hit for the week to count.
- A week counts as a **hit only if the first N sets (N = target sets) of every scheduled session reach the target reps**. 8, 8, 8, 7 on a 4×8 target is a miss. Extra sets are recorded but ignored, so 8, 8, 8, 8, 5 is a hit. Fewer than N sets is a miss.
- **Skipping:** the user can skip a single day; skipping a week means skipping its remaining days. Per slot: if all of the slot's sessions in a week were skipped, the week is skipped and **pauses the block**. If only some were, each skipped session counts as no sets, so the week is a miss. A completed session where the exercise was dropped also counts as no sets.
- A block completes after 3 *completed* weeks. If all 3 were hits, the weight increases for the next block. Otherwise it stays the same.
- **Auto-deload:** after 2 consecutive failed blocks on an exercise, drop its weight ~10% (rounded to the nearest loadable weight, always at least one step lighter, never below the minimum) and progress from there.
- **Progression uses the prescribed weight.** Reps are judged against the target; the weight actually lifted is recorded but doesn't change the progression.
- **Increments:** smart defaults (+5 lb / +2.5 kg lower body, +2.5 lb / +1.25 kg upper body), editable per exercise. Increases always **round up** to the next loadable weight.
- **Minimum increase: 5 lb (2.5 kg) for every lift**, so an increment below that is raised to it (bench 185 → 190, not 187.5). **Exception: dumbbells under 20 lb** step by 2.5 lb (and 1 kg under 10 kg). In practice the +2.5 lb upper-body default only applies to light dumbbells. The 2.5 kg minimum is the assumed kg equivalent of 5 lb.
- **Units:** lb and kg. Each program has its own unit; the app setting only sets the default for new programs and never converts existing ones.
- **Equipment types** decide which weights are loadable:
  - **Barbell:** bar plus plate pairs. Defaults: 45 lb bar with 45/35/25/10/5/2.5/1.25 lb plates; 20 kg bar with 25/20/15/10/5/2.5/1.25/0.5/0.25 kg plates. The small plates are still used for deloads and odd starting weights, never for an increase below the minimum.
  - **Dumbbell:** 2.5 lb steps up to 20 lb, then 5 lb steps. 1 kg steps up to 10 kg, then 2.5 kg steps (kg steps are an unconfirmed default).
  - **Machine / cable:** no rounding; the raw increment is applied (at least the 5 lb / 2.5 kg minimum).
  - The plate and dumbbell sets are stored as settings so they can be made editable later.
- **Editing an exercise:** changing sets, reps, increment, equipment, or the current weight archives the slot and starts a successor at the (possibly edited) weight with a fresh 3-week count, so old weeks are never re-judged. The editor warns first ("This restarts your 3-week count"). Name and body region edit in place. Successors share a `lineageID` and are shown in the UI as one continuous exercise.
- **Weight entry:** barbell and dumbbell weights snap to the nearest loadable weight (shown to the user) and never go below the bar or the lightest dumbbell. Machine weights aren't snapped. ± buttons step by the lift's minimum increase.
- **Editing finished workouts:** reps, weight lifted, adding a missed set, and deleting a set are allowed. Because weights are replayed from history, an edit can change a current weight; the editor previews the edit against the engine first and asks before saving, naming each change (e.g. "Bench Press 190 → 185 lb"). Edits to an archived slot's history change nothing current.
- **Onboarding:** shown only on a first launch with no programs at all (active or archived). Steps: welcome → unit → template (Push Pull Legs, Upper / Lower, Full Body) or blank → starting weights. Nothing is created until the last step; if programs arrive from iCloud mid-onboarding, it steps aside with "Welcome back". Starting weights are blank and required, with a per-lift "Not sure? Start light" that fills the lightest valid weight (bar, lightest dumbbell, 20 lb / 10 kg on machines). "Start a New Program" offers the same templates plus a blank program. Template lifts must exist in `ExerciseCatalog`.
- **Programs:** one active program at a time; creating a new one archives the current one after confirmation. Archived programs keep their history and can be restored. Day edits (add, remove, reorder) apply to the current training week immediately. A day with a workout in progress can't be deleted; deleting a day archives exercises that are on no other day.

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
- **Don't hold on to `persistentModelID`** (in drafts, navigation routes, sheet items, or `ForEach` ids). A new object's ID is temporary and changes when it's first saved. Use the model's stable `id: UUID` instead. Comparing two `persistentModelID`s read at the same moment is fine.

## SwiftData + CloudKit model rules

CloudKit is enabled, so every `@Model` must follow these rules or the container will fail to load:
- No `@Attribute(.unique)`
- Every stored property has a default value or is optional
- Every relationship is optional
- Prefer additive schema changes. Once the schema is deployed to production (first TestFlight), fields can't be renamed or deleted, so flag any model change that would be painful after shipping.
- After any model change, push the schema to CloudKit development with the DEBUG launch argument `-ChalkInitializeCloudKitSchema`, then deploy to production in CloudKit Console (see `docs/testflight-checklist.md`).
- `catalogID` on `ExerciseSlot` and `ExerciseLog` stores `CatalogExercise.id`. Catalog IDs are permanent: never change or reuse one. Display names can change.

## Architecture

- **The progression engine is a pure function:** `(history, rules) → next targets`. No SwiftData, no UI, no side effects inside it. It must be fully unit-tested, because a wrong weight bump destroys user trust.
- Keep domain logic (engine, value types) separate from persistence (`@Model` types) and views.
- **Store facts, derive state.** The database stores what the user set up and did. Current weights, block position, and blocks themselves are never stored; the engine recalculates them by replaying history.
- Model hierarchy (`SchemaV1` in `Chalk/Models`):
  - Program (unit, archivedAt) → ProgramDay → DayEntry → ExerciseSlot (target sets/reps, increment, starting weight, equipment, progression rule, lineageID)
  - Program → WorkoutSession (weekNumber, status: inProgress / completed / skipped) → ExerciseLog (snapshot of name, prescribed weight, target sets/reps) → SetLog (reps, weight lifted)
  - Archive is the normal way to retire a program. Hard delete cascades to days, slots, sessions, logs, and sets.
- **Keep sessions generic.** Strength sets are one kind of entry; cardio/triathlon sessions will be added later and shouldn't require a migration-heavy redesign.

## Testing

- Use parameterized tests (`@Test(arguments:)`) for the progression engine, covering a table of scenarios: all hit, one set missed, a missed week, the boundary weeks of a block, and multiple consecutive blocks.
- Any change to progression logic requires tests for the new behavior.

## Design

**Theme: "Leotard After Dark"**: 90s aerobics/workout-tape energy on a near-black background. Funky and loud in the big moments, calm and readable everywhere else.

### Colors

| Token | Hex | Job |
|---|---|---|
| `background` | `#110E1C` | App background |
| `surface` | `#1B1630` | Cards and rows |
| `border` | `#2A2440` | Subtle dividers and outlines |
| `textPrimary` | `#F5F2FF` | Main text |
| `textSecondary` | `#B7AED6` | Secondary text (set/rep targets, captions) |
| `weight` | `#F7FF3C` (highlighter yellow) | Weights, the most important number on screen |
| `done` | `#00E0C6` (teal) | Completed sets, success states |
| `action` | `#FF2D95` (magenta) | Primary buttons and actions |
| `decor` | `#8A4DFF` (grape) | Decoration only: drop-shadows, shapes. Never text |

- **One job per color.** Don't use yellow for anything but weights, or teal for anything but done/success. Users should learn the color language.
- Text on `action` and `done` fills uses `background` (dark), not white.
- Keep contrast at 4.5:1 or better for text. Grape is never used for text.

### Type

- **Display / numbers:** Fugaz One (sporty italic). Weights, screen titles, and the weight-bump moment.
- **Body / labels:** Barlow Condensed (500/600/700). Exercise names in uppercase with wide letter spacing.
- Both are Google Fonts (SIL Open Font License). Bundle the font files in the app and register them in Info.plist.
- Support Dynamic Type: use custom fonts through `Font.custom(_:size:relativeTo:)`.

### The 90s decoration, used sparingly

- **Leotard stripe:** a diagonal repeating stripe of magenta / teal / yellow / grape. Use it only on today's main lift card, the weight-bump moment, onboarding, and the app icon.
- **Memphis shapes** (zigzag, ring, triangle) and **offset drop-shadows** in a second color (e.g. yellow weight with a magenta shadow): only in those same big moments.
- Everything else is plain dark cards with at most one accent color. If a screen looks busy, remove decoration first.

### Rules

- All colors and fonts live in one central theme (e.g. `Theme.swift` with semantic tokens above). Never hardcode colors or font names in views.
- Dark appearance only for v1 (force dark color scheme). A light variant is a later decision.
- Weights are the biggest, brightest thing on the screen, readable from arm's length mid-set.
- Touch targets are at least 44pt; set buttons should be bigger, since users tap them between sets.
- **The weight bump is the emotional payoff:** a full moment with the leotard stripe, the old → new weight in Fugaz One, a haptic, and a short animation. Copy is playful 90s-instructor energy (e.g. "And up! And up!").
- Design mockups for the theme options live in the Chalk Color Schemes canvas (option 14).

## Roadmap (not v1 unless asked)

- AI features: natural-language/voice set logging, a program builder via questionnaire, a stall coach that explains failed blocks, and a chat grounded in the user's log data
  - Set logging uses Apple's on-device Foundation Models (guided generation), with manual logging as the fallback on unsupported devices
  - Program builder, stall coach, and chat use the Claude API through a backend proxy. **Never put an API key in the app.**
- **Exercise info:** a button on each exercise showing how to do it, with a picture or animation of the movement. Mostly content (instructions plus licensed or custom images), keyed by `catalogID`.
- **Exercise substitution:** swap an exercise (e.g. missing equipment) with suggested alternatives. Rule-based first, using catalog metadata (movement pattern, equipment); AI for unusual cases later. A swap works like an exercise edit: a successor slot in the same lineage with a fresh block.
- Rest timer as a Live Activity, HealthKit writes, Apple Watch app
- Cardio / triathlon tracking
