import Foundation
import Combine
import SwiftUI

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

    // MARK: - Entry Status Tracking

    enum EntryStatus {
        case completed
        case active
        case upcoming
        case skipped
        case deferred
    }

    /// The live ordered list of entries including pushed movements repositioned at the end.
    var flowEntries: [WorkoutEntry] {
        var result = entries
        result.append(contentsOf: deferredQueue)
        return result
    }
    /// IDs of completed entries.
    private(set) var completedEntryIDs: Set<UUID> = []
    /// IDs of skipped entries.
    private(set) var skippedEntryIDs: Set<UUID> = []
    /// IDs of currently deferred entries.
    private(set) var deferredEntryIDs: Set<UUID> = []

    func statusFor(_ entry: WorkoutEntry) -> EntryStatus {
        if completedEntryIDs.contains(entry.id) { return .completed }
        if skippedEntryIDs.contains(entry.id) { return .skipped }
        if deferredEntryIDs.contains(entry.id) { return .deferred }
        if entry.id == currentEntry?.id { return .active }
        return .upcoming
    }

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
    var onTransition: ((TransitionEvent) -> Void)?

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
        completedEntryIDs = []
        skippedEntryIDs = []
        deferredEntryIDs = []
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
                } else {
                    onTransition?(.restBetweenSets(seconds: secondsRemaining, nextSet: currentSet + 1, totalSets: entry.sets, exerciseName: entry.exerciseName))
                }
            } else {
                // All sets done for this entry
                completedEntryCount += 1
                if let entry = currentEntry { completedEntryIDs.insert(entry.id) }
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
            onTransition?(.awaitingUserCompletion)
        } else {
            beginExercisePhase()
        }
    }

    private func beginExercisePhase() {
        guard let entry = currentEntry else { return }
        phase = .exercise
        state = .running
        onTransition?(.exerciseStarted(
            name: entry.exerciseName,
            cueText: entry.customCueText,
            set: currentSet,
            totalSets: entry.sets,
            isFirstExercise: currentEntryIndex == 0 && currentSet == 1,
            exercisesRemaining: (entries.count + deferredQueue.count) - currentEntryIndex
        ))

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
            let nextName = currentEntry?.exerciseName
            onTransition?(.restAfterExercise(seconds: restAfter, nextExerciseName: nextName))
        } else {
            beginCurrentEntry()
        }
    }

    private func appendDeferredEntries() {
        for entry in deferredQueue {
            deferredEntryIDs.remove(entry.id)
        }
        entries.append(contentsOf: deferredQueue)
        deferredQueue.removeAll()
        onTransition?(.deferredRoundStarted)
        beginCurrentEntry()
    }

    private func finishWorkout() {
        state = .finishing
        phase = .exercise
        timer?.invalidate()
        timer = nil
        onTransition?(.workoutComplete)
        onWorkoutComplete?(nil)
    }

    // MARK: - User Actions

    func togglePause() {
        switch state {
        case .running:
            state = .paused
            onTransition?(.paused)
        case .paused:
            state = .running
            onTransition?(.resumed)
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
            if let entry = currentEntry { completedEntryIDs.insert(entry.id) }
            advanceToNextEntry()
        }
    }

    func skipExercise() {
        guard currentEntryIndex < entries.count else { return }
        let name = currentEntry?.exerciseName ?? ""
        if let entry = currentEntry { skippedEntryIDs.insert(entry.id) }
        skippedEntryCount += 1
        onTransition?(.skipped(exerciseName: name))
        advanceToNextEntry()
    }

    func deferExercise() {
        guard let entry = currentEntry, currentEntryIndex < entries.count else { return }
        onTransition?(.deferred(exerciseName: entry.exerciseName))
        deferredEntryIDs.insert(entry.id)
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
        onTransition?(.restExtended(additionalSeconds: seconds))
    }

    func insertDeferred(at index: Int) {
        guard index < deferredQueue.count else { return }
        let entry = deferredQueue.remove(at: index)
        deferredEntryIDs.remove(entry.id)
        entries.insert(entry, at: currentEntryIndex + 1)
        onTransition?(.deferredInserted(exerciseName: entry.exerciseName))
    }

    /// Reorder upcoming entries (everything after the current entry + deferred queue).
    /// `from` and `to` are indices into `flowEntries`, but only moves within
    /// the upcoming region (index > currentEntryIndex) are allowed.
    func moveFlowEntry(from source: IndexSet, to destination: Int) {
        // Build the full mutable flow list
        var flow = entries
        flow.append(contentsOf: deferredQueue)

        // The first movable index is currentEntryIndex + 1
        let firstMovable = currentEntryIndex + 1

        // Only allow moves within the upcoming region
        for idx in source {
            guard idx >= firstMovable else { return }
        }
        let clampedDestination = max(firstMovable, destination)

        flow.move(fromOffsets: source, toOffset: clampedDestination)

        // Split back into entries and deferredQueue
        // entries = everything up to entries.count, deferredQueue = the rest
        // But since deferred items may have been interleaved, we rebuild:
        // Keep the first `currentEntryIndex + 1` entries as-is (completed/active),
        // then the rest become the new upcoming entries list.
        let entriesCount = entries.count
        let totalCount = flow.count

        entries = Array(flow.prefix(entriesCount))
        deferredQueue = Array(flow.suffix(totalCount - entriesCount))

        // Update deferred tracking — anything in deferredQueue is deferred
        deferredEntryIDs = Set(deferredQueue.map(\.id))
    }

    func endWorkout() {
        state = .finishing
        timer?.invalidate()
        timer = nil
    }
}
