import Foundation

// MARK: - AI Workout Schema
// TODO Phase 6: Implement AI response structures and conversion logic

/// Placeholder for AIWorkoutResponse
/// This Codable struct represents the JSON response from the LLM
/// See Phase 6 in GymApp-ClaudeCode-Plan.md for full implementation details
struct AIWorkoutResponse: Codable {
    var workoutName: String
    var description: String
    var category: WorkoutCategory
    var difficulty: Difficulty
    var estimatedDurationMinutes: Int
    var exercises: [AIExerciseEntry]
    
    /// Convert the AI response into SwiftData models
    func toModels() -> (Workout, [Exercise]) {
        // TODO: Implement in Phase 6
        fatalError("Not implemented - see Phase 6")
    }
    
    /// Generate the JSON schema prompt for the LLM
    static func jsonSchemaPrompt(for category: WorkoutCategory) -> String {
        // TODO: Implement in Phase 6
        return """
        Generate a \(category.rawValue) workout in JSON format...
        """
    }
}

/// Placeholder for AIExerciseEntry
/// Represents a single exercise in the AI-generated workout
struct AIExerciseEntry: Codable {
    var name: String
    var description: String
    var sets: Int
    var reps: Int?
    var durationSeconds: Int?
    var restBetweenSetsSeconds: Int
    var restAfterExerciseSeconds: Int
    var equipment: Equipment
    var primaryMuscles: [MuscleGroup]
    var instructions: String?
}
