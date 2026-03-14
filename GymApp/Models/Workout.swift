import Foundation
import SwiftData

/// A workout is a collection of exercises organized into a specific sequence
@Model
final class Workout: BaseEntity {
    // MARK: - BaseEntity Conformance
    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Core Properties
    var name: String
    var workoutDescription: String  // "description" is reserved
    var category: WorkoutCategory
    var difficulty: Difficulty
    
    // MARK: - Configuration
    var estimatedDurationMinutes: Int  // Calculated from entries
    var targetMuscleGroups: [MuscleGroup]
    var requiredEquipment: [Equipment]
    
    // MARK: - Yoga/Flow-Specific
    var flowStyle: FlowStyle?
    var breathCues: Bool  // Enable breath-synchronized cues
    
    // MARK: - User Preferences
    var isFavorite: Bool
    var timesCompleted: Int  // Increment each time a session completes
    var lastCompletedAt: Date?
    
    // MARK: - Metadata
    var source: WorkoutSource
    var aiGenerationPrompt: String?  // Store the original prompt if AI-generated
    
    // MARK: - Sharing (Future-Ready)
    var isShareable: Bool
    var isPublic: Bool
    var authorId: String?
    var forkedFromId: UUID?
    
    // MARK: - Relationships
    /// Ordered list of exercises in this workout
    /// Cascade delete: if workout is deleted, all entries are deleted
    @Relationship(deleteRule: .cascade, inverse: \WorkoutEntry.workout)
    var entries: [WorkoutEntry]
    
    // MARK: - Initialization
    init(
        name: String,
        description: String = "",
        category: WorkoutCategory,
        difficulty: Difficulty = .intermediate,
        estimatedDurationMinutes: Int = 30,
        targetMuscleGroups: [MuscleGroup] = [],
        requiredEquipment: [Equipment] = [],
        flowStyle: FlowStyle? = nil,
        breathCues: Bool = false,
        isFavorite: Bool = false,
        source: WorkoutSource = .manual,
        aiGenerationPrompt: String? = nil
    ) {
        let (id, createdAt, updatedAt) = newBaseFields()
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        
        self.name = name
        self.workoutDescription = description
        self.category = category
        self.difficulty = difficulty
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.targetMuscleGroups = targetMuscleGroups
        self.requiredEquipment = requiredEquipment
        self.flowStyle = flowStyle
        self.breathCues = breathCues
        self.isFavorite = isFavorite
        self.timesCompleted = 0
        self.lastCompletedAt = nil
        self.source = source
        self.aiGenerationPrompt = aiGenerationPrompt
        self.isShareable = false
        self.isPublic = false
        self.authorId = nil
        self.forkedFromId = nil
        self.entries = []
    }
    
    // MARK: - Computed Properties
    
    /// Calculate total estimated duration from all entries
    func calculateEstimatedDuration() -> Int {
        let totalSeconds = entries.reduce(0) { sum, entry in
            let exerciseTime = entry.estimatedDurationPerSetSeconds * entry.sets
            let restTime = entry.restBetweenSetsSeconds * (entry.sets - 1) + entry.restAfterExerciseSeconds
            return sum + exerciseTime + restTime
        }
        return totalSeconds / 60  // Convert to minutes
    }
    
    /// Completion percentage (0.0 - 1.0)
    var completionPercentage: Double {
        guard !entries.isEmpty else { return 0.0 }
        return Double(timesCompleted) / Double(entries.count)
    }
}
