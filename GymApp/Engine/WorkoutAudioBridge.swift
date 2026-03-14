import Foundation

// MARK: - WorkoutAudioBridge
// TODO Phase 3: Implement bridge between timer engine and audio service
// - Takes a WorkoutTimerEngine and AudioCueService
// - Subscribes to onTransition and onCountdown callbacks
// - Maps each TransitionEvent to the appropriate speak() call
// - Handles workout completion with final cue and audio session deactivation

/// Placeholder for WorkoutAudioBridge
/// See Phase 3 in GymApp-ClaudeCode-Plan.md for full implementation details
final class WorkoutAudioBridge {
    // TODO: Implement in Phase 3

    private let engine: WorkoutTimerEngine
    private let audioService: AudioCueService

    init(engine: WorkoutTimerEngine, audioService: AudioCueService = .shared) {
        self.engine = engine
        self.audioService = audioService
    }

    func activate() {
        // TODO: Activate audio session and start listening to engine events
    }

    func deactivate() {
        // TODO: Deactivate audio session and stop listening
    }
}

// MARK: - TransitionEvent
// TODO Phase 3: Define all transition events for audio cues
enum TransitionEvent {
    case exerciseStarted(name: String, cueText: String?)
    case restStarted(cueText: String)
    case midExerciseCue(text: String)
    case awaitingUserCompletion
    case skipped(exerciseName: String)
    case deferred(exerciseName: String)
    case deferredInserted(exerciseName: String)
    case deferredRoundStarted
    case restExtended(additionalSeconds: Int)
    case paused
    case resumed
    case workoutComplete
}
