import Foundation
import SwiftData

/// A session represents a single execution of a workout
/// Created when user starts a workout, tracks progress and completion
@Model
final class WorkoutSession: BaseEntity {
    // MARK: - BaseEntity Conformance
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Workout Reference
    /// UUID of the workout that was performed
    /// NOT a @Relationship — allows workouts to be deleted without losing session history
    var workoutId: UUID
    
    /// Denormalized workout name for history display
    var workoutName: String
    
    // MARK: - Session Status
    var status: SessionStatus
    
    // MARK: - Timing
    var startedAt: Date
    var completedAt: Date?
    var totalDurationSeconds: Int  // Actual elapsed time
    
    // MARK: - Progress Tracking
    var totalExercises: Int
    var exercisesCompleted: Int
    var exercisesSkipped: Int
    var exercisesDeferred: Int
    
    // MARK: - Performance Metrics
    var totalSetsCompleted: Int
    var totalRepsCompleted: Int  // For rep-based exercises
    var totalTimeUnderTensionSeconds: Int  // For timed exercises
    
    // MARK: - Notes
    var sessionNotes: String?
    var completionNotes: String?  // User notes at the end
    
    // MARK: - Relationships
    /// Log entries for each exercise performed
    @Relationship(deleteRule: .cascade, inverse: \EntrySessionLog.session)
    var entryLogs: [EntrySessionLog]
    
    // MARK: - Initialization
    init(
        workoutId: UUID,
        workoutName: String,
        totalExercises: Int
    ) {
        let (id, createdAt, updatedAt) = newBaseFields()
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        self.workoutId = workoutId
        self.workoutName = workoutName
        self.status = .inProgress
        self.startedAt = Date()
        self.completedAt = nil
        self.totalDurationSeconds = 0
        self.totalExercises = totalExercises
        self.exercisesCompleted = 0
        self.exercisesSkipped = 0
        self.exercisesDeferred = 0
        self.totalSetsCompleted = 0
        self.totalRepsCompleted = 0
        self.totalTimeUnderTensionSeconds = 0
        self.sessionNotes = nil
        self.completionNotes = nil
        self.entryLogs = []
    }
    
    // MARK: - Computed Properties
    
    /// Completion percentage (0.0 - 1.0)
    var completionPercentage: Double {
        guard totalExercises > 0 else { return 0.0 }
        return Double(exercisesCompleted) / Double(totalExercises)
    }
    
    /// Formatted duration string (e.g., "45:32")
    var formattedDuration: String {
        let minutes = totalDurationSeconds / 60
        let seconds = totalDurationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - EntrySessionLog

/// Log entry for a single exercise within a workout session
/// Tracks what was actually performed vs. what was planned
@Model
final class EntrySessionLog: BaseEntity {
    // MARK: - BaseEntity Conformance
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Entry Reference
    var entryId: UUID  // WorkoutEntry ID
    var exerciseId: UUID  // Exercise ID from catalog
    var exerciseName: String  // Denormalized for display
    
    // MARK: - Outcome
    var outcome: BlockOutcome
    var orderIndex: Int  // Original position in workout
    var actualOrderIndex: Int  // Actual position performed (differs if deferred)
    
    // MARK: - Timing
    var startedAt: Date?
    var completedAt: Date?
    var durationSeconds: Int  // Actual time spent on this exercise
    
    // MARK: - Performance Data
    var setsCompleted: Int
    var plannedSets: Int
    
    // Rep-based tracking
    var repsCompleted: [Int]?  // Array of reps per set (e.g., [10, 8, 6])
    var plannedReps: Int?
    var weightUsed: Double?
    
    // Timed tracking
    var timeUnderTensionSeconds: Int?
    var plannedDurationSeconds: Int?
    
    // MARK: - Notes
    var performanceNotes: String?  // User notes about how it felt
    var skipReason: String?  // Why it was skipped/deferred
    
    // MARK: - Relationships
    var session: WorkoutSession?
    
    // MARK: - Initialization
    init(
        entryId: UUID,
        exerciseId: UUID,
        exerciseName: String,
        outcome: BlockOutcome,
        orderIndex: Int,
        actualOrderIndex: Int,
        plannedSets: Int,
        plannedReps: Int? = nil,
        plannedDurationSeconds: Int? = nil
    ) {
        let (id, createdAt, updatedAt) = newBaseFields()
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        self.entryId = entryId
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.outcome = outcome
        self.orderIndex = orderIndex
        self.actualOrderIndex = actualOrderIndex
        self.startedAt = nil
        self.completedAt = nil
        self.durationSeconds = 0
        self.setsCompleted = 0
        self.plannedSets = plannedSets
        self.repsCompleted = nil
        self.plannedReps = plannedReps
        self.weightUsed = nil
        self.timeUnderTensionSeconds = nil
        self.plannedDurationSeconds = plannedDurationSeconds
        self.performanceNotes = nil
        self.skipReason = nil
    }
    
    // MARK: - Convenience Initializer from WorkoutEntry
    convenience init(from entry: WorkoutEntry, orderIndex: Int, actualOrderIndex: Int, outcome: BlockOutcome) {
        self.init(
            entryId: entry.id,
            exerciseId: entry.exerciseId,
            exerciseName: entry.exerciseName,
            outcome: outcome,
            orderIndex: orderIndex,
            actualOrderIndex: actualOrderIndex,
            plannedSets: entry.sets,
            plannedReps: entry.targetReps,
            plannedDurationSeconds: entry.durationSeconds
        )
    }
}
