import Foundation
import Combine

// MARK: - WorkoutTimerEngine

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

    // MARK: - Observable Properties

    private(set) var state: State = .idle
    private(set) var phase: Phase = .exercise

    private(set) var currentEntryIndex: Int = 0
    private(set) var currentSet: Int = 1
    private(set) var secondsRemaining: Int = 0
    private(set) var totalElapsedSeconds: Int = 0

    private(set) var deferredQueue: [WorkoutEntry] = []

    // MARK: - Workout Data

    private var entries: [WorkoutEntry] = []
    private var completedEntryCount: Int = 0
    private var skippedEntryCount: Int = 0
    private var totalEstimatedWorkoutSeconds: Int = 0

    var currentEntry: WorkoutEntry? {
        guard currentEntryIndex < entries.count else { return nil }
        return entries[currentEntryIndex]
    }

    var currentExerciseName: String {
        currentEntry?.exerciseName ?? "—"
    }

    var nextEntry: WorkoutEntry? {
        let nextIndex = currentEntryIndex + 1
        guard nextIndex < entries.count else { return nil }
        return entries[nextIndex]
    }

    /// Time-based completion: elapsed / estimated total.
    var completionPercentage: Double {
        guard totalEstimatedWorkoutSeconds > 0 else { return 0 }
        return min(1.0, Double(totalElapsedSeconds) / Double(totalEstimatedWorkoutSeconds))
    }

    var totalEntryCount: Int {
        entries.count + deferredQueue.count
    }

    // MARK: - Callbacks

    var onWorkoutComplete: ((WorkoutSession?) -> Void)?

    // MARK: - Timer

    private var timer: Timer?

    // MARK: - Start

    func start(workout: Workout) {
        entries = workout.entries.sorted { $0.orderIndex < $1.orderIndex }
        currentEntryIndex = 0
        currentSet = 1
        totalElapsedSeconds = 0
        completedEntryCount = 0
        skippedEntryCount = 0
        deferredQueue = []
        totalEstimatedWorkoutSeconds = entries.reduce(0) { $0 + $1.totalEstimatedSeconds }

        guard !entries.isEmpty else {
            state = .finishing
            return
        }

        beginCurrentEntry()
        startTimer()
    }

    // MARK: - Timer Management

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard state == .running || state == .waitingForUser else { return }

        totalElapsedSeconds += 1

        // waitingForUser doesn't count down — user must tap Done
        guard state == .running else { return }

        if secondsRemaining > 0 {
            secondsRemaining -= 1
        }

        if secondsRemaining == 0 {
            phaseCompleted()
        }
    }

    // MARK: - Phase Transitions

    private func phaseCompleted() {
        guard let entry = currentEntry else { return }

        switch phase {
        case .exercise:
            // Finished one set
            if currentSet < entry.sets {
                // More sets remain — rest between sets
                phase = .restBetweenSets
                secondsRemaining = entry.restBetweenSetsSeconds
                if secondsRemaining == 0 {
                    // No rest configured, go straight to next set
                    currentSet += 1
                    beginExercisePhase()
                }
            } else {
                // All sets done for this entry
                completedEntryCount += 1
                advanceToNextEntry()
            }

        case .restBetweenSets:
            // Rest done — start next set
            currentSet += 1
            beginExercisePhase()

        case .restAfterBlock:
            // Rest done — start next exercise
            beginCurrentEntry()

        case .waitingForUser:
            // Handled by markCurrentDone()
            break
        }
    }

    private func beginCurrentEntry() {
        guard let entry = currentEntry else {
            finishWorkout()
            return
        }

        currentSet = 1

        // Untimed exercises wait for user input
        if entry.blockType == .untimed {
            phase = .waitingForUser
            state = .waitingForUser
            secondsRemaining = 0
        } else {
            beginExercisePhase()
        }
    }

    private func beginExercisePhase() {
        guard let entry = currentEntry else { return }
        phase = .exercise
        state = .running

        switch entry.blockType {
        case .repBased:
            // Estimate ~3 seconds per rep
            secondsRemaining = (entry.targetReps ?? 10) * 3
        case .timed:
            secondsRemaining = entry.durationSeconds ?? 45
        case .untimed:
            // Should not reach here — handled by beginCurrentEntry
            phase = .waitingForUser
            state = .waitingForUser
            secondsRemaining = 0
        case .distance:
            secondsRemaining = entry.estimatedDurationPerSetSeconds
        }
    }

    private func advanceToNextEntry() {
        guard let entry = currentEntry else {
            finishWorkout()
            return
        }

        let restAfter = entry.restAfterExerciseSeconds
        currentEntryIndex += 1

        // Check if there are more entries
        guard currentEntryIndex < entries.count else {
            // No more regular entries — check deferred queue
            if !deferredQueue.isEmpty {
                appendDeferredEntries()
            } else {
                finishWorkout()
            }
            return
        }

        if restAfter > 0 {
            phase = .restAfterBlock
            state = .running
            secondsRemaining = restAfter
        } else {
            beginCurrentEntry()
        }
    }

    private func appendDeferredEntries() {
        entries.append(contentsOf: deferredQueue)
        deferredQueue.removeAll()
        beginCurrentEntry()
    }

    private func finishWorkout() {
        state = .finishing
        phase = .exercise
        timer?.invalidate()
        timer = nil
        onWorkoutComplete?(nil)
    }

    // MARK: - User Actions

    func togglePause() {
        switch state {
        case .running:
            state = .paused
        case .paused:
            state = .running
        default:
            break
        }
    }

    func markCurrentDone() {
        guard state == .waitingForUser else { return }

        completedEntryCount += 1

        if currentSet < (currentEntry?.sets ?? 1) {
            // More sets — rest between sets
            currentSet += 1
            if let entry = currentEntry, entry.restBetweenSetsSeconds > 0 {
                phase = .restBetweenSets
                state = .running
                secondsRemaining = entry.restBetweenSetsSeconds
            } else {
                // No rest, stay in waitingForUser for next set
                // (completedEntryCount was already incremented above, undo for mid-entry)
                completedEntryCount -= 1
            }
        } else {
            // All sets done
            advanceToNextEntry()
        }
    }

    func skipExercise() {
        guard currentEntryIndex < entries.count else { return }
        skippedEntryCount += 1
        advanceToNextEntry()
    }

    func deferExercise() {
        guard let entry = currentEntry, currentEntryIndex < entries.count else { return }
        deferredQueue.append(entry)
        entries.remove(at: currentEntryIndex)

        // Don't increment currentEntryIndex — next entry is now at the same index
        if currentEntryIndex < entries.count {
            beginCurrentEntry()
        } else if !deferredQueue.isEmpty {
            appendDeferredEntries()
        } else {
            finishWorkout()
        }
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
