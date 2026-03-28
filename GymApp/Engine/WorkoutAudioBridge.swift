import Foundation

// MARK: - WorkoutAudioBridge

@MainActor
final class WorkoutAudioBridge {
    private let engine: WorkoutTimerEngine
    private let audio: AudioCueService

    init(engine: WorkoutTimerEngine, audioService: AudioCueService = .shared) {
        self.engine = engine
        self.audio = audioService
    }

    func activate() {
        audio.activate()

        engine.onTransition = { [weak self] event in
            self?.handle(event)
        }
    }

    func deactivate() {
        engine.onTransition = nil
        audio.deactivate()
    }

    // MARK: - Transition Handling

    private func handle(_ event: TransitionEvent) {
        switch event {
        case .exerciseStarted(let name, let cueText, let set, let totalSets, let isFirst, let remaining):
            audio.hapticPulse()
            if let cue = cueText {
                audio.speak(cue)
            } else if isFirst {
                audio.speak(pick(Self.workoutStartCues, with: name))
            } else if remaining <= 2 {
                audio.speak(pick(Self.nearEndCues, with: name))
            } else if set > 1 {
                audio.speak(pick(Self.nextSetCues, with: name, set: set, totalSets: totalSets))
            } else {
                audio.speak(pick(Self.newExerciseCues, with: name))
            }

        case .restBetweenSets(let seconds, let nextSet, let totalSets, let name):
            audio.hapticTick()
            let rest = Self.formatDuration(seconds)
            let cue = pick(Self.restBetweenSetsCues, with: name, rest: rest, set: nextSet, totalSets: totalSets)
            audio.speak(cue, urgency: .low)

        case .restAfterExercise(let seconds, let nextName):
            audio.hapticSuccess()
            let rest = Self.formatDuration(seconds)
            if let next = nextName {
                audio.speak(pick(Self.restAfterExerciseCues, with: next, rest: rest), urgency: .low)
            } else {
                audio.speak(pick(Self.exerciseDonePraise) + " Take \(rest).", urgency: .low)
            }

        case .midExerciseCue(let text):
            audio.speak(text)

        case .awaitingUserCompletion:
            audio.hapticPulse()
            audio.speak(pick(Self.awaitingCues), urgency: .low)

        case .skipped(let name):
            audio.hapticTick()
            audio.speak(pick(Self.skippedCues, with: name), urgency: .low)

        case .deferred(let name):
            audio.hapticTick()
            audio.speak(pick(Self.deferredCues, with: name), urgency: .low)

        case .deferredInserted(let name):
            audio.hapticTick()
            audio.speak(pick(Self.deferredInsertedCues, with: name))

        case .deferredRoundStarted:
            audio.hapticAlert()
            audio.speak(pick(Self.deferredRoundCues), urgency: .high)

        case .restExtended(let seconds):
            audio.hapticTick()
            audio.speak(pick(Self.restExtendedCues, with: "\(seconds)"), urgency: .low)

        case .paused:
            audio.hapticWarning()

        case .resumed:
            audio.hapticPulse()
            audio.speak(pick(Self.resumedCues))

        case .workoutComplete:
            audio.hapticSuccess()
            audio.speak(pick(Self.workoutCompleteCues), urgency: .high)
        }
    }

    // MARK: - Phrase Helpers

    private func pick(_ phrases: [String]) -> String {
        phrases.randomElement()!
    }

    private func pick(_ phrases: [String], with name: String) -> String {
        pick(phrases).replacingOccurrences(of: "{name}", with: name)
    }

    private func pick(_ phrases: [String], with name: String, rest: String) -> String {
        pick(phrases)
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{rest}", with: rest)
    }

    private func pick(_ phrases: [String], with name: String, set: Int, totalSets: Int) -> String {
        pick(phrases)
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{set}", with: "\(set)")
            .replacingOccurrences(of: "{total}", with: "\(totalSets)")
    }

    private func pick(_ phrases: [String], with name: String, rest: String, set: Int, totalSets: Int) -> String {
        pick(phrases)
            .replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{rest}", with: rest)
            .replacingOccurrences(of: "{set}", with: "\(set)")
            .replacingOccurrences(of: "{total}", with: "\(totalSets)")
    }

    private static func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s > 0 ? "\(m) minute\(m == 1 ? "" : "s") \(s)" : "\(m) minute\(m == 1 ? "" : "s")"
        }
        return "\(seconds) seconds"
    }

    // MARK: - Coaching Phrases

    // --- Workout start (first exercise) ---
    private static let workoutStartCues = [
        "Let's get going with {name}.",
        "Alright, starting off with {name}. Let's go.",
        "Here we go. {name} first up.",
        "Time to work. Kicking it off with {name}.",
        "Let's do this. {name} to start.",
    ]

    // --- New exercise (not the first) ---
    private static let newExerciseCues = [
        "Next up, {name}.",
        "Moving on to {name}.",
        "Alright, {name}. Let's go.",
        "Here we go, {name}.",
        "{name} is up. Get into position.",
        "Switching over to {name}.",
    ]

    // --- Next set of the same exercise ---
    private static let nextSetCues = [
        "Set {set} of {total}. Back to {name}.",
        "Okay, back to it. Set {set} of {name}.",
        "Another set of {name}. Let's go.",
        "Round {set}. {name} again.",
        "Set {set}. You got this.",
    ]

    // --- Near end of workout (1–2 exercises left) ---
    private static let nearEndCues = [
        "Almost there. {name} to close it out.",
        "Home stretch. Let's finish strong with {name}.",
        "Just about done. {name} and we're wrapping up.",
        "Final push. {name}, let's go.",
        "Only a little more. Heading into {name}.",
    ]

    // --- Rest between sets (same exercise) ---
    private static let restBetweenSetsCues = [
        "Nice set. Rest for {rest}, then set {set} of {total}.",
        "Good work. Take {rest}. Set {set} coming up.",
        "Solid. Catch your breath, {rest}. Then back to {name}.",
        "That's it. {rest} rest, then we go again.",
        "Clean set. {rest} break, then set {set}.",
    ]

    // --- Rest after finishing an exercise (before next exercise) ---
    private static let restAfterExerciseCues = [
        "{name} is next. Take {rest} and get ready.",
        "Good stuff. Rest {rest}, then we're on to {name}.",
        "Take {rest}. {name} is coming up.",
        "Nice work on that one. {rest} break, then {name}.",
        "Well done. Grab {rest} rest before {name}.",
    ]

    // --- Praise after a finished set (used as prefix) ---
    private static let exerciseDonePraise = [
        "That's a wrap on that one.",
        "Crushed it.",
        "Nice work.",
        "Solid effort.",
        "Well done.",
        "Good stuff.",
        "Strong finish.",
    ]

    // --- Waiting for user to tap done ---
    private static let awaitingCues = [
        "Go at your own pace. Tap done when you're finished.",
        "Take your time. Hit done when you're ready.",
        "Whenever you're done, just tap it.",
        "Your pace. Tap done to move on.",
    ]

    // --- Skipped ---
    private static let skippedCues = [
        "Skipping {name}. Moving on.",
        "No worries, skipping {name}.",
        "Alright, we'll skip {name} for now.",
    ]

    // --- Deferred ---
    private static let deferredCues = [
        "Pushing {name} to later. We'll come back to it.",
        "Saving {name} for later.",
        "No problem, we'll circle back to {name}.",
    ]

    // --- Deferred inserted ---
    private static let deferredInsertedCues = [
        "{name} is queued up next.",
        "Bringing {name} back in. You're up next.",
        "{name} coming right up.",
    ]

    // --- Deferred round ---
    private static let deferredRoundCues = [
        "Time to circle back. Let's knock out those deferred exercises.",
        "Alright, finishing up the exercises we pushed back.",
        "Coming back around to the ones we saved.",
    ]

    // --- Rest extended ---
    private static let restExtendedCues = [
        "No rush. Added {name} more seconds.",
        "Take your time. {name} more seconds on the clock.",
        "Extra {name} seconds. Recover well.",
    ]

    // --- Resumed ---
    private static let resumedCues = [
        "Welcome back. Let's pick up where we left off.",
        "Alright, we're back.",
        "Let's get back to it.",
    ]

    // --- Workout complete ---
    private static let workoutCompleteCues = [
        "And that's a wrap. Great session.",
        "Workout complete. You killed it today.",
        "Done! Solid work in there.",
        "That's it. Awesome job today.",
        "All done. Way to push through.",
    ]
}

// MARK: - TransitionEvent

enum TransitionEvent {
    case exerciseStarted(name: String, cueText: String?, set: Int, totalSets: Int, isFirstExercise: Bool, exercisesRemaining: Int)
    case restBetweenSets(seconds: Int, nextSet: Int, totalSets: Int, exerciseName: String)
    case restAfterExercise(seconds: Int, nextExerciseName: String?)
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
