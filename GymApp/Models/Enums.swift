import Foundation

// ============================================================================
// MARK: - Workout-Level Enums
// ============================================================================

enum WorkoutCategory: String, Codable, CaseIterable {
    case strength        // traditional gym: bench, squat, deadlift
    case hiit            // high-intensity intervals
    case cardio          // running, cycling, rowing
    case yoga            // flows, poses, stretching
    case flexibility     // stretching, mobility work
    case calisthenics    // bodyweight strength
    case crossfit        // mixed modality
    case custom          // user-defined, doesn't fit a category
}

enum FlowStyle: String, Codable, CaseIterable {
    case vinyasa         // flowing, breath-linked
    case hatha           // slower, hold-focused
    case power           // strength-oriented yoga
    case restorative     // gentle, long holds
    case custom
}

enum WorkoutSource: String, Codable {
    case manual
    case aiGenerated
    case aiEdited
    case imported
    case builtIn         // ships with the app (e.g., "Beginner Yoga Flow")
}

// ============================================================================
// MARK: - Exercise-Level Enums
// ============================================================================

enum ExerciseType: String, Codable, CaseIterable {
    case strength        // load-bearing: bench press, squats
    case cardio          // sustained effort: running, cycling
    case flexibility     // stretching, mobility
    case balance         // single-leg, stability work
    case plyometric      // explosive: box jumps, burpees
    case isometric       // static holds: planks, wall sits
    case pose            // yoga pose
    case interval        // work/rest cycling (HIIT rounds)
    case distance        // distance-based: run 400m, row 500m
    case breathwork      // breathing exercises (yoga, recovery)
}

enum MovementPattern: String, Codable, CaseIterable {
    // Strength patterns
    case push, pull, squat, hinge, carry, rotate
    // Cardio patterns
    case run, cycle, row, swim
    // Flexibility/yoga patterns
    case stretch, hold, flow, transition
}

enum TransitionStyle: String, Codable, CaseIterable {
    case flow            // smooth movement into next pose
    case hold            // hold current, then switch
    case vinyasa         // sun-salutation linking sequence
    case rest            // come to rest, then begin next
}

// ============================================================================
// MARK: - Shared Enums
// ============================================================================

enum MuscleGroup: String, Codable, CaseIterable {
    case chest, back, shoulders, biceps, triceps, forearms
    case quads, hamstrings, glutes, calves
    case core, fullBody, cardio
    case hipFlexors, lats, traps, rhomboids  // useful for yoga/mobility
}

enum Difficulty: String, Codable, CaseIterable {
    case beginner, intermediate, advanced, brutal
}

enum Equipment: String, Codable, CaseIterable {
    case none
    case barbell, dumbbell, kettlebell
    case cableMachine, smithMachine, legPress
    case pullUpBar, dipStation, bench
    case resistanceBand, trx
    case treadmill, bike, rower, elliptical
    case yogaMat, yogaBlock, yogaStrap
    case foamRoller, lacrosseBall
    case jumpRope, medicineBall, battleRopes
    case other
}

enum BlockType: String, Codable {
    case timed       // hold for X seconds (planks, yoga poses, HIIT)
    case repBased    // do X reps (bench press, curls)
    case untimed     // go until done / failure
    case distance    // cover X meters (running intervals, rowing)
}

// ============================================================================
// MARK: - Session-Level Enums
// ============================================================================

enum SessionStatus: String, Codable {
    case inProgress
    case completed
    case abandoned
}

enum BlockOutcome: String, Codable {
    case pending
    case completed
    case skipped
    case deferred
    case deferredDone
    case partiallyDone
}

// ============================================================================
// MARK: - Sharing Enums
// ============================================================================

enum ShareType: String, Codable {
    case link
    case directSend
    case publicListing
}

enum ShareStatus: String, Codable {
    case active
    case revoked
    case expired
}
