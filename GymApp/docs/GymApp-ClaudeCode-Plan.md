# Claude Code Execution Plan: GymApp iOS MVP

## Context

You are building an iOS app called GymApp. The Xcode project already exists with a README. You need to scaffold the full MVP architecture. This document is the phased execution plan — work through it top to bottom, completing each phase fully before moving to the next.

The app is SwiftUI + SwiftData, targeting iOS 17+. No third-party dependencies for MVP except llama.cpp (added in Phase 5). No storyboards, no UIKit unless wrapping AVFoundation.

---

## Phase 1: Project Structure & Base Architecture

Create the folder structure and base protocol. Do not create any UI yet.

```
GymApp/
├── App/
│   ├── GymApp.swift              // @main entry, SwiftData modelContainer setup
│   └── ContentView.swift         // Tab-based root navigation
├── Models/
│   ├── BaseEntity.swift          // BaseEntity protocol, newBaseFields() helper
│   ├── Exercise.swift            // Exercise @Model (standalone catalog entity)
│   ├── Workout.swift             // Workout @Model
│   ├── WorkoutEntry.swift        // WorkoutEntry @Model (join between Workout and Exercise)
│   ├── WorkoutSession.swift      // WorkoutSession @Model + EntrySessionLog @Model
│   ├── Share.swift               // Share @Model (future-ready, no UI yet)
│   └── Enums.swift               // All enums: WorkoutCategory, ExerciseType, MuscleGroup, Equipment, BlockType, Difficulty, MovementPattern, TransitionStyle, FlowStyle, WorkoutSource, SessionStatus, BlockOutcome, ShareType, ShareStatus
├── Engine/
│   ├── WorkoutTimerEngine.swift  // State machine: EngineState, BlockPhase, all actions
│   ├── AudioCueService.swift     // AVAudioSession ducking + AVSpeechSynthesizer TTS
│   └── WorkoutAudioBridge.swift  // Bridges engine TransitionEvents to AudioCueService
├── Services/
│   ├── ExerciseStore.swift       // CRUD for Exercise catalog, search, favorites
│   ├── WorkoutStore.swift        // CRUD for Workouts, favorites, sort
│   ├── SessionStore.swift        // CRUD for WorkoutSessions, history queries
│   └── LLMService.swift          // Local LLM inference, JSON parsing, retry logic
├── AI/
│   └── AIWorkoutSchema.swift     // AIWorkoutResponse, AIExerciseEntry Codable structs, toModels(), jsonSchemaPrompt(for:)
├── Views/
│   ├── Library/
│   │   ├── LibraryView.swift
│   │   ├── WorkoutCardView.swift
│   │   └── WorkoutFilterBar.swift
│   ├── Editor/
│   │   ├── WorkoutEditorView.swift
│   │   ├── EntryEditorRow.swift
│   │   ├── ExercisePickerView.swift
│   │   └── ExerciseCatalogView.swift
│   ├── Generator/
│   │   ├── AIGeneratorView.swift
│   │   └── AIPreviewView.swift
│   ├── ActiveWorkout/
│   │   ├── ActiveWorkoutView.swift
│   │   ├── BigButtonPanel.swift
│   │   ├── DeferredQueueSheet.swift
│   │   └── WorkoutCompleteView.swift
│   └── Shared/
│       ├── TimerRingView.swift
│       └── MuscleGroupPicker.swift
└── Resources/
    └── SeedExercises.json        // Built-in exercise catalog (bench press, squat, downward dog, etc.)
```

### Instructions for Phase 1:

1. Create all folders and empty files with placeholder comments.
2. Implement `BaseEntity.swift` with the protocol, `touch()` extension, and `newBaseFields()` helper.
3. Implement `Enums.swift` with ALL enums. Reference the attached model files for the full list. Every enum must conform to `String, Codable`. Enums that need `CaseIterable` (for picker UIs): `MuscleGroup`, `Difficulty`, `Equipment`, `WorkoutCategory`, `ExerciseType`, `FlowStyle`, `TransitionStyle`, `MovementPattern`.
4. Implement all @Model files in Models/. Each model goes in its own file and conforms to BaseEntity. Key relationships:
   - `Workout` has a cascade-delete `@Relationship` to `[WorkoutEntry]`
   - `WorkoutEntry` references `Exercise` via `exerciseId: UUID` (NOT a @Relationship — intentionally loose coupling)
   - `WorkoutEntry` has a denormalized `exerciseName: String`
   - `WorkoutSession` has a cascade-delete `@Relationship` to `[EntrySessionLog]`
   - `Share` references `Workout` via `workoutId: UUID` (NOT a @Relationship)
5. Register ALL @Model types in `GymApp.swift` modelContainer: `Exercise`, `Workout`, `WorkoutEntry`, `WorkoutSession`, `EntrySessionLog`, `Share`.
6. Verify the project compiles with no errors.

---

## Phase 2: Data Layer (Stores)

Implement the service layer that wraps SwiftData operations. These are `@Observable` classes that views will inject via the environment.

### ExerciseStore.swift

```swift
@Observable
final class ExerciseStore {
    private let modelContext: ModelContext

    // CRUD
    func create(_ exercise: Exercise)
    func update(_ exercise: Exercise)  // calls touch(), saves
    func delete(_ exercise: Exercise)

    // Queries
    func all() -> [Exercise]
    func favorites() -> [Exercise]
    func search(query: String) -> [Exercise]  // name + muscle group matching
    func byType(_ type: ExerciseType) -> [Exercise]
    func byEquipment(_ equipment: Equipment) -> [Exercise]

    // Upsert for AI-generated exercises: match by name, update if exists, create if not
    func upsertFromAI(_ exercises: [Exercise])
}
```

### WorkoutStore.swift

```swift
@Observable
final class WorkoutStore {
    private let modelContext: ModelContext

    func create(_ workout: Workout)
    func update(_ workout: Workout)
    func delete(_ workout: Workout)
    func toggleFavorite(_ workout: Workout)

    func all() -> [Workout]
    func favorites() -> [Workout]
    func byCategory(_ category: WorkoutCategory) -> [Workout]

    // Reorder entries within a workout
    func moveEntry(in workout: Workout, from: IndexSet, to: Int)
    // Add an exercise from the catalog to a workout
    func addExercise(_ exercise: Exercise, to workout: Workout)
    // Remove an entry from a workout
    func removeEntry(_ entry: WorkoutEntry, from workout: Workout)
}
```

### SessionStore.swift

```swift
@Observable
final class SessionStore {
    private let modelContext: ModelContext

    func startSession(for workout: Workout) -> WorkoutSession
    func completeSession(_ session: WorkoutSession)
    func abandonSession(_ session: WorkoutSession)
    func logEntry(_ log: EntrySessionLog, to session: WorkoutSession)

    func recentSessions(limit: Int) -> [WorkoutSession]
    func sessionsForWorkout(_ workoutId: UUID) -> [WorkoutSession]
}
```

### Instructions for Phase 2:

1. Implement all three stores. Use `@Query` or `FetchDescriptor` for reads.
2. Each store takes `ModelContext` in its init.
3. Add all three stores to the SwiftUI environment in `GymApp.swift` — create them in the `@main` App struct and inject via `.environment()`.
4. Verify the project compiles.

---

## Phase 3: Timer Engine & Audio

Implement the workout runtime. No UI yet — just the engine and audio services.

### WorkoutTimerEngine.swift

This is a `@MainActor @Observable` class. It manages:

- **5 states**: `idle`, `running`, `paused`, `waitingForUser`, `finishing`
- **4 phases**: `exercise`, `restBetweenSets`, `restAfterBlock`, `waitingForUser`
- **Actions**: `start(workout:)`, `pause()`, `resume()`, `togglePause()`, `skipExercise()`, `deferExercise()`, `markCurrentDone()`, `extendRest(bySeconds:)`, `insertDeferred(at:)`, `endWorkout()`
- **Deferred queue**: exercises skipped with "come back later" accumulate and auto-surface after the main workout ends
- **Callbacks**: `onTransition: ((TransitionEvent) -> Void)?`, `onCountdown: ((Int) -> Void)?`, `onWorkoutComplete: ((WorkoutSession) -> Void)?`
- **Timer**: Uses `Timer.publish(every: 1.0)` via Combine. Ticks decrement `secondsRemaining`, fire countdown cues at 3/2/1, and check mid-exercise cues.

Reference the attached `WorkoutTimerEngine.swift` for the full implementation. Port it exactly, using `WorkoutEntry` instead of `ExerciseBlock`.

### AudioCueService.swift

- Singleton: `AudioCueService.shared`
- Configures `AVAudioSession` with `.playback` category, `.voicePrompt` mode, `[.duckOthers, .mixWithOthers]` options
- Uses `AVSpeechSynthesizer` for TTS with three urgency levels (countdown, normal, encouragement) that vary rate, pitch, and volume
- Fires `UIImpactFeedbackGenerator` haptics alongside speech

### WorkoutAudioBridge.swift

- Takes a `WorkoutTimerEngine` and `AudioCueService`
- Subscribes to `onTransition` and `onCountdown` callbacks
- Maps each `TransitionEvent` to the appropriate `speak()` call
- Handles workout completion: speaks final cue, waits 3s, deactivates audio session

### TransitionEvent enum

Define in its own section or at the bottom of the engine file:
```
exerciseStarted(name:cueText:), restStarted(cueText:), midExerciseCue(text:),
awaitingUserCompletion, skipped(exerciseName:), deferred(exerciseName:),
deferredInserted(exerciseName:), deferredRoundStarted, restExtended(additionalSeconds:),
paused, resumed, workoutComplete
```

### Instructions for Phase 3:

1. Implement all three files referencing the attached code.
2. The engine must be testable without audio — all audio interaction goes through callbacks, never direct calls.
3. Verify the project compiles.

---

## Phase 4: UI — Library & Editor

Now build the user-facing screens. Start with the workout library and editor since these don't depend on the timer engine.

### ContentView.swift

Tab-based navigation with 3 tabs:
1. **Library** (icon: `list.bullet.rectangle.portrait`) — workout list
2. **Exercises** (icon: `figure.strengthtraining.traditional`) — exercise catalog
3. **History** (icon: `clock.arrow.circlepath`) — past sessions (placeholder for now)

### LibraryView.swift

- Shows all workouts in a `List` or `LazyVStack`
- Segmented control at top: All / Favorites / by WorkoutCategory
- Each workout shows: name, category badge, difficulty pill, estimated duration, muscle group tags, favorite star toggle
- Swipe actions: delete, toggle favorite
- Tap navigates to `WorkoutEditorView`
- FAB or toolbar button: "New Workout" (manual) and "Generate with AI"
- Long press or context menu: duplicate workout

### WorkoutEditorView.swift

- **Header section**: name (editable TextField), description, category picker, difficulty picker
- **Entries section**: reorderable `List` with `onMove` and `onDelete`
  - Each row (`EntryEditorRow`) shows: exercise name, sets × reps or duration, rest times, equipment badge
  - Tap a row to expand inline editing: sets stepper, reps stepper or duration picker, rest time steppers, equipment override picker, custom TTS cue text field
- **Add exercise button**: pushes `ExercisePickerView`
- **Toolbar**: Save button (calls `WorkoutStore.update` or `.create`)
- **"Start Workout" button**: prominent, at the bottom. Navigates to `ActiveWorkoutView`.

### ExerciseCatalogView.swift (the Exercises tab)

- Searchable list of all exercises
- Filter chips: by ExerciseType, by Equipment, by MuscleGroup
- Tap to view/edit an exercise
- "New Exercise" button for manual creation
- Each exercise shows: name, type badge, primary muscles, equipment icons, favorite star

### ExercisePickerView.swift

- Presented as a sheet from WorkoutEditorView
- Same search/filter as catalog but with "Add" buttons instead of navigation
- Tapping "Add" creates a `WorkoutEntry(from: exercise)` and appends it to the workout
- Multi-select mode for adding several at once

### Instructions for Phase 4:

1. Build all views. Use `@Environment` to access stores.
2. Navigation: use `NavigationStack` with `navigationDestination` modifiers. No `NavigationView`.
3. Keep styling clean and minimal. System colors, standard SF Symbols, no custom fonts yet.
4. The "Start Workout" button should be visually prominent — large, full-width, tinted.
5. Verify everything compiles and you can create/edit/delete workouts and exercises.

---

## Phase 5: UI — Active Workout Screen

This is the most important screen. The user is at the gym, sweaty, phone in one hand. Everything must be big and tappable.

### ActiveWorkoutView.swift

- **Top bar**: workout name, elapsed time, progress bar (`completionPercentage`)
- **Center**: current exercise name (large, bold, 28pt+), set counter ("Set 2 of 4"), timer display (big circular countdown or large digits)
- **For untimed/rep-based exercises**: show rep target instead of countdown, with a large "Done" button
- **Bottom**: `BigButtonPanel`

### BigButtonPanel.swift

These are the primary controls. Each button should be at minimum 60pt tall with clear labels:

1. **Pause / Resume** — toggle, prominent center position
2. **Skip Exercise** — "Someone's on my machine" — secondary style, with confirmation alert
3. **Come Back Later** — defers exercise to end — secondary style
4. **+30s Rest** — only visible during rest phases
5. **Done** — only visible for untimed/rep-based exercises during exercise phase
6. **End Workout** — destructive style, with confirmation alert ("Are you sure? You've completed X of Y exercises.")

Layout: stack the most-used buttons (Pause, Done/+30s) at the bottom in a 2-column grid. Skip and Come Back as a secondary row above. End Workout tucked in the toolbar or top corner.

### DeferredQueueSheet.swift

- Shows as a small floating badge on the active workout screen: "2 deferred"
- Tapping opens a sheet listing deferred exercises
- Each row has an "Insert Next" button that calls `engine.insertDeferred(at:)`
- Also auto-presents after the main workout finishes if deferred queue is not empty

### WorkoutCompleteView.swift

- Summary screen shown when `engine.state == .finishing`
- Shows: total time, exercises completed vs. skipped vs. deferred, completion percentage
- "Done" button returns to library
- Future: this is where you'll add "save to history" and "share" actions. For now, the session is already persisted by the engine.

### Instructions for Phase 5:

1. Create `ActiveWorkoutView` as a full-screen cover (`.fullScreenCover` from the editor).
2. Initialize `WorkoutTimerEngine` as a `@State` in `ActiveWorkoutView`. Create `WorkoutAudioBridge` in `.onAppear`, call `bridge.activate()`. Call `bridge.deactivate()` in `.onDisappear`.
3. Call `engine.start(workout:)` in `.onAppear`.
4. Bind all UI to `engine`'s published properties.
5. Conditionally show/hide buttons based on `engine.phase` and `engine.state`.
6. Use `.sensoryFeedback(.impact, trigger:)` on button taps for additional haptics.
7. Keep the screen awake during workouts: `UIApplication.shared.isIdleTimerDisabled = true` on appear, restore on disappear.
8. Test the full flow: start workout → exercise ticks down → rest → next exercise → skip → defer → deferred round → complete.

---

## Phase 6: AI Generation

### LLMService.swift

For MVP, stub this with a mock that returns hardcoded JSON. The local LLM integration (llama.cpp or MLX) is a follow-up task. Structure the service so swapping the backend is a one-line change.

```swift
@Observable
final class LLMService {
    enum LLMState {
        case idle
        case loading      // model loading into memory
        case generating   // inference in progress
        case error(String)
    }

    private(set) var state: LLMState = .idle
    private(set) var progress: Double = 0  // 0.0-1.0 during generation

    /// Generate a workout from structured inputs.
    /// Returns the raw AIWorkoutResponse for preview before saving.
    func generate(
        category: WorkoutCategory,
        muscleGroups: [MuscleGroup],
        duration: Int,           // target minutes
        difficulty: Difficulty,
        equipment: [Equipment],
        additionalNotes: String?
    ) async throws -> AIWorkoutResponse
}
```

Implementation for MVP:
1. Build the prompt string from the structured inputs + `AIWorkoutSchema.jsonSchemaPrompt(for: category)`.
2. For now, return a hardcoded `AIWorkoutResponse` that matches the inputs (switch on category to return a strength vs. yoga vs. cardio template).
3. Add a `// TODO: Replace with actual LLM inference` comment with a skeleton showing where llama.cpp or MLX integration goes.
4. Include JSON validation: decode the response, check required fields are present, retry up to 2 times on parse failure.

### AIGeneratorView.swift

- **Inputs** (NOT a freeform text box):
  - Category picker (segmented or grid)
  - Muscle group multi-select (pill chips)
  - Duration slider (15 / 30 / 45 / 60 / 90 min)
  - Difficulty picker
  - Equipment multi-select (checkboxes or chips)
  - Optional notes text field
- **Generate button**: triggers `LLMService.generate()`
- **Loading state**: progress indicator
- **On success**: navigates to `AIPreviewView`

### AIPreviewView.swift

- Shows the generated workout in the same layout as `WorkoutEditorView` but with a banner: "AI Generated — Review & Edit"
- All fields are editable (it's the same editor, just pre-populated)
- **Save button**: calls `AIWorkoutResponse.toModels()`, upserts exercises via `ExerciseStore.upsertFromAI()`, saves workout via `WorkoutStore.create()`
- **Regenerate button**: goes back to generator with same inputs
- **Discard button**: returns to library

### Instructions for Phase 6:

1. Implement `LLMService` with the mock backend.
2. Build `AIGeneratorView` with all structured inputs.
3. Build `AIPreviewView` reusing `WorkoutEditorView` components.
4. Wire the full flow: generator → preview → save → appears in library.
5. Verify you can generate, edit, save, and then run the AI-generated workout through the active workout screen.

---

## Phase 7: Seed Data & Polish

### SeedExercises.json

Create a JSON file with 30-40 common exercises across categories:
- **Strength** (15): bench press, squat, deadlift, overhead press, barbell row, pull-up, dip, bicep curl, tricep pushdown, lateral raise, leg press, romanian deadlift, face pull, cable fly, lunges
- **Cardio** (5): treadmill run, cycling, rowing, jump rope, elliptical
- **Yoga** (10): downward dog, warrior I, warrior II, tree pose, cobra, child's pose, pigeon, chair pose, triangle, bridge
- **Calisthenics** (5): push-up, bodyweight squat, burpee, plank, mountain climber

Each exercise should have: name, description, instructions, exerciseType, primaryMuscleGroups, secondaryMuscleGroups, equipment, defaultBlockType, defaultSets, defaultRepCount or defaultDurationSeconds, defaultRestBetweenSetsSeconds, defaultRestAfterSeconds. Yoga exercises should include defaultHoldSeconds and defaultTransitionStyle.

### Seed loading

In `GymApp.swift`, on first launch (check UserDefaults flag), load `SeedExercises.json`, decode into `[Exercise]`, and insert into SwiftData. Set the flag so it doesn't re-seed.

### Polish

1. Add `.searchable` modifiers to library and catalog views.
2. Add pull-to-refresh where appropriate.
3. Add empty states: "No workouts yet — create one or generate with AI", "No exercises match your search".
4. Add `.confirmationDialog` on all destructive actions (delete workout, end workout early).
5. Ensure all navigation uses `NavigationStack`.
6. Add app icon placeholder and launch screen.

---

## Phase 8: Background Audio & Session Persistence

This phase ensures the app works correctly when the screen locks or the app backgrounds.

1. Enable **Background Modes** in the Xcode target: check "Audio, AirPlay, and Picture in Picture".
2. In `AudioCueService`, ensure the `AVAudioSession` is configured before any speech — this is what keeps the app alive in the background.
3. In `ActiveWorkoutView`, manage `UIApplication.shared.isIdleTimerDisabled` to prevent auto-lock during workouts.
4. If the app is force-quit during a workout, the `WorkoutSession` with `status: .inProgress` persists in SwiftData. On next launch, check for orphaned in-progress sessions and offer to resume or mark as abandoned.

---

## Checklist Before Calling Phase Complete

After each phase, verify:
- [ ] Project compiles with zero errors and zero warnings
- [ ] No force unwraps (`!`) except on known-safe operations (IBOutlet is not a concern in SwiftUI)
- [ ] All @Model types are registered in the modelContainer
- [ ] All stores are injected into the SwiftUI environment
- [ ] Navigation works: you can reach every screen and go back
- [ ] Data persists: kill and relaunch the app, workouts are still there
