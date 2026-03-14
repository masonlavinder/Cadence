import Foundation
import SwiftData

/// Join entity between Workout and Exercise
/// Represents a single exercise slot within a workout with its configuration
@Model
final class WorkoutEntry: BaseEntity {
    // MARK: - BaseEntity Conformance
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Exercise Reference (Intentionally Loose Coupling)
    /// UUID of the Exercise in the catalog
    /// NOT a @Relationship — allows exercises to be deleted from catalog without breaking workouts
    var exerciseId: UUID
    
    /// Denormalized exercise name for display even if catalog exercise is deleted
    var exerciseName: String
    
    // MARK: - Position
    var orderIndex: Int  // Position within the workout (0-based)
    
    // MARK: - Block Configuration
    var blockType: BlockType
    var sets: Int
    
    // Rep-based configuration
    var targetReps: Int?
    var targetWeight: Double?  // For future tracking
    
    // Timed configuration
    var durationSeconds: Int?
    
    // Distance configuration
    var targetDistanceMeters: Double?
    
    // MARK: - Rest Configuration
    var restBetweenSetsSeconds: Int
    var restAfterExerciseSeconds: Int  // Rest before next exercise
    
    // MARK: - Yoga/Flow-Specific
    var holdSeconds: Int?
    var transitionStyle: TransitionStyle?
    var breathCycles: Int?  // Number of breaths to hold the pose
    
    // MARK: - Equipment Override
    /// Allows user to override the exercise's default equipment for this specific workout
    var equipmentOverride: Equipment?
    
    // MARK: - Audio Cues
    var customCueText: String?  // Override exercise's default TTS cue
    var midExerciseCues: [String]?  // Additional cues during exercise (e.g., "halfway done")
    
    // MARK: - Notes
    var notes: String?
    
    // MARK: - Relationships
    var workout: Workout?  // Back-reference to parent workout
    
    // MARK: - Initialization
    init(
        exerciseId: UUID,
        exerciseName: String,
        orderIndex: Int,
        blockType: BlockType = .repBased,
        sets: Int = 3,
        targetReps: Int? = 10,
        targetWeight: Double? = nil,
        durationSeconds: Int? = nil,
        targetDistanceMeters: Double? = nil,
        restBetweenSetsSeconds: Int = 60,
        restAfterExerciseSeconds: Int = 90,
        holdSeconds: Int? = nil,
        transitionStyle: TransitionStyle? = nil,
        breathCycles: Int? = nil,
        equipmentOverride: Equipment? = nil,
        customCueText: String? = nil,
        midExerciseCues: [String]? = nil,
        notes: String? = nil
    ) {
        let (id, createdAt, updatedAt) = newBaseFields()
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.blockType = blockType
        self.sets = sets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.durationSeconds = durationSeconds
        self.targetDistanceMeters = targetDistanceMeters
        self.restBetweenSetsSeconds = restBetweenSetsSeconds
        self.restAfterExerciseSeconds = restAfterExerciseSeconds
        self.holdSeconds = holdSeconds
        self.transitionStyle = transitionStyle
        self.breathCycles = breathCycles
        self.equipmentOverride = equipmentOverride
        self.customCueText = customCueText
        self.midExerciseCues = midExerciseCues
        self.notes = notes
    }
    
    // MARK: - Convenience Initializer from Exercise
    convenience init(from exercise: Exercise, orderIndex: Int) {
        self.init(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            orderIndex: orderIndex,
            blockType: exercise.defaultBlockType,
            sets: exercise.defaultSets,
            targetReps: exercise.defaultRepCount,
            durationSeconds: exercise.defaultDurationSeconds,
            restBetweenSetsSeconds: exercise.defaultRestBetweenSetsSeconds,
            restAfterExerciseSeconds: exercise.defaultRestAfterSeconds,
            holdSeconds: exercise.defaultHoldSeconds,
            transitionStyle: exercise.defaultTransitionStyle,
            customCueText: exercise.cueText
        )
    }
    
    // MARK: - Computed Properties
    
    /// Estimated duration per set in seconds
    var estimatedDurationPerSetSeconds: Int {
        switch blockType {
        case .repBased:
            // Rough estimate: 3 seconds per rep
            return (targetReps ?? 10) * 3
        case .timed:
            return durationSeconds ?? 45
        case .untimed:
            return holdSeconds ?? 30
        case .distance:
            // Rough estimate: 5 min/km pace
            let distanceKm = (targetDistanceMeters ?? 400) / 1000
            return Int(distanceKm * 300)  // 300 seconds per km
        }
    }
    
    /// Total estimated time for this entry including rest
    var totalEstimatedSeconds: Int {
        let exerciseTime = estimatedDurationPerSetSeconds * sets
        let restTime = restBetweenSetsSeconds * (sets - 1) + restAfterExerciseSeconds
        return exerciseTime + restTime
    }
    
    /// Display string for the exercise configuration (e.g., "3 × 10" or "3 × 45s")
    var displayConfiguration: String {
        switch blockType {
        case .repBased:
            if let reps = targetReps {
                return "\(sets) × \(reps)"
            }
            return "\(sets) sets"
        case .timed:
            if let duration = durationSeconds {
                return "\(sets) × \(duration)s"
            }
            return "\(sets) sets"
        case .untimed:
            if let hold = holdSeconds {
                return "\(sets) × \(hold)s hold"
            }
            return "\(sets) sets"
        case .distance:
            if let distance = targetDistanceMeters {
                return "\(sets) × \(Int(distance))m"
            }
            return "\(sets) sets"
        }
    }
}
