import Foundation
import AVFoundation

// MARK: - WorkoutTimerEngine
// TODO Phase 3: Implement the full workout runtime state machine
// This is a @MainActor @Observable class that manages:
// - 5 states: idle, running, paused, waitingForUser, finishing
// - 4 phases: exercise, restBetweenSets, restAfterBlock, waitingForUser
// - Actions: start, pause, resume, skip, defer, markDone, extendRest, endWorkout
// - Deferred queue management
// - Callbacks for transitions and countdown events
// - Timer using Timer.publish(every: 1.0)

/// Placeholder for WorkoutTimerEngine
/// See Phase 3 in GymApp-ClaudeCode-Plan.md for full implementation details
@MainActor
@Observable
final class WorkoutTimerEngine {

    // MARK: - State & Phase Enums

    enum State: Equatable {
        case idle
        case running
        case paused
        case waitingForUser
        case finishing
    }

    enum Phase: Equatable {
        case exercise
        case restBetweenSets
        case restAfterBlock
        case waitingForUser
    }

    // MARK: - Published Properties

    private(set) var state: State = .idle
    private(set) var phase: Phase = .exercise

    private(set) var currentEntryIndex: Int = 0
    private(set) var currentSet: Int = 1
    private(set) var secondsRemaining: Int = 0
    private(set) var totalElapsedSeconds: Int = 0

    private(set) var deferredQueue: [WorkoutEntry] = []

    // MARK: - Workout Data

    private var entries: [WorkoutEntry] = []

    var currentEntry: WorkoutEntry? {
        guard currentEntryIndex < entries.count else { return nil }
        return entries[currentEntryIndex]
    }

    var currentExerciseName: String {
        currentEntry?.exerciseName ?? "—"
    }

    var completionPercentage: Double {
        guard !entries.isEmpty else { return 0 }
        return Double(currentEntryIndex) / Double(entries.count)
    }

    // MARK: - Callbacks

    var onWorkoutComplete: ((WorkoutSession?) -> Void)?

    // MARK: - Timer

    private var timer: Timer?

    // MARK: - Actions (TODO: Implement in Phase 3)

    func start(workout: Workout) {
        entries = workout.entries.sorted { $0.orderIndex < $1.orderIndex }
        currentEntryIndex = 0
        currentSet = 1
        totalElapsedSeconds = 0
        deferredQueue = []
        state = .running
        phase = .exercise
        secondsRemaining = currentEntry?.estimatedDurationPerSetSeconds ?? 0
        // TODO: start timer
    }

    func togglePause() {
        if state == .paused {
            state = .running
        } else if state == .running {
            state = .paused
        }
        // TODO: pause/resume timer
    }

    func markCurrentDone() {
        // TODO: Implement in Phase 3
    }

    func skipExercise() {
        // TODO: Implement in Phase 3
    }

    func deferExercise() {
        // TODO: Implement in Phase 3
    }

    func extendRest(bySeconds seconds: Int) {
        secondsRemaining += seconds
    }

    func insertDeferred(at index: Int) {
        guard index < deferredQueue.count else { return }
        let entry = deferredQueue.remove(at: index)
        entries.insert(entry, at: currentEntryIndex + 1)
    }

    func endWorkout() {
        state = .finishing
        timer?.invalidate()
        timer = nil
    }
}
