import Foundation

// MARK: - LLMService
// TODO Phase 6: Implement local LLM inference service
// For MVP, this should return hardcoded/mock JSON responses
// The actual LLM integration (llama.cpp or MLX) comes later

/// Placeholder for LLMService
/// See Phase 6 in GymApp-ClaudeCode-Plan.md for full implementation details
@Observable
final class LLMService {
    enum LLMState {
        case idle
        case loading      // model loading into memory
        case generating   // inference in progress
        case error(String)
    }
    
    private(set) var state: LLMState = .idle
    private(set) var progress: Double = 0  // 0.0-1.0 during generation
    
    /// Generate a workout from structured inputs
    /// For MVP, returns a hardcoded template based on category
    /// TODO: Replace with actual LLM inference in future phase
    func generate(
        category: WorkoutCategory,
        muscleGroups: [MuscleGroup],
        duration: Int,           // target minutes
        difficulty: Difficulty,
        equipment: [Equipment],
        additionalNotes: String?
    ) async throws -> AIWorkoutResponse {
        // TODO: Implement in Phase 6
        fatalError("Not implemented - see Phase 6")
    }
}
