import Foundation
import SwiftData

// MARK: - ExerciseStore
/// Service layer for Exercise entity CRUD operations
/// Wraps SwiftData operations and provides query methods for the exercise catalog

@Observable
final class ExerciseStore {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    /// Create a new exercise in the catalog
    func create(_ exercise: Exercise) {
        modelContext.insert(exercise)
        save()
    }
    
    /// Update an existing exercise (calls touch() to update timestamp)
    func update(_ exercise: Exercise) {
        var mutableExercise = exercise
        mutableExercise.touch()
        save()
    }
    
    /// Delete an exercise from the catalog
    func delete(_ exercise: Exercise) {
        modelContext.delete(exercise)
        save()
    }
    
    /// Toggle favorite status
    func toggleFavorite(_ exercise: Exercise) {
        exercise.isFavorite.toggle()
        update(exercise)
    }
    
    // MARK: - Queries
    
    /// Fetch all exercises, sorted by name
    func all() -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Fetch only favorite exercises
    func favorites() -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Search exercises by name or muscle group
    func search(query: String) -> [Exercise] {
        guard !query.isEmpty else { return all() }
        
        let lowercasedQuery = query.lowercased()
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        let allExercises = (try? modelContext.fetch(descriptor)) ?? []
        
        // Filter in memory for complex queries (name + muscle groups)
        return allExercises.filter { exercise in
            exercise.name.lowercased().contains(lowercasedQuery) ||
            exercise.primaryMuscleGroups.contains { $0.rawValue.lowercased().contains(lowercasedQuery) } ||
            exercise.secondaryMuscleGroups.contains { $0.rawValue.lowercased().contains(lowercasedQuery) }
        }
    }
    
    /// Fetch exercises by type
    func byType(_ type: ExerciseType) -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.exerciseType == type },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Fetch exercises by equipment
    func byEquipment(_ equipment: Equipment) -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        let allExercises = (try? modelContext.fetch(descriptor)) ?? []
        
        // Filter in memory since equipment is a simple enum field
        return allExercises.filter { $0.equipment == equipment }
    }
    
    /// Fetch exercises by primary muscle group
    func byMuscleGroup(_ muscleGroup: MuscleGroup) -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        
        let allExercises = (try? modelContext.fetch(descriptor)) ?? []
        
        return allExercises.filter { exercise in
            exercise.primaryMuscleGroups.contains(muscleGroup)
        }
    }
    
    // MARK: - AI Integration
    
    /// Upsert exercises from AI generation
    /// Matches by name: updates if exists, creates if new
    func upsertFromAI(_ exercises: [Exercise]) {
        let existingExercises = all()
        let existingNames = Set(existingExercises.map { $0.name.lowercased() })
        
        for exercise in exercises {
            let lowercasedName = exercise.name.lowercased()
            
            if existingNames.contains(lowercasedName) {
                // Find and update existing
                if let existing = existingExercises.first(where: { $0.name.lowercased() == lowercasedName }) {
                    // Update properties from AI-generated exercise
                    existing.exerciseDescription = exercise.exerciseDescription
                    existing.instructions = exercise.instructions
                    existing.exerciseType = exercise.exerciseType
                    existing.primaryMuscleGroups = exercise.primaryMuscleGroups
                    existing.secondaryMuscleGroups = exercise.secondaryMuscleGroups
                    existing.equipment = exercise.equipment
                    existing.defaultBlockType = exercise.defaultBlockType
                    existing.defaultSets = exercise.defaultSets
                    existing.defaultRepCount = exercise.defaultRepCount
                    existing.defaultDurationSeconds = exercise.defaultDurationSeconds
                    existing.defaultRestBetweenSetsSeconds = exercise.defaultRestBetweenSetsSeconds
                    existing.defaultRestAfterSeconds = exercise.defaultRestAfterSeconds
                    update(existing)
                }
            } else {
                // Create new exercise
                create(exercise)
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Increment usage count when exercise is added to a workout
    func incrementUsage(_ exercise: Exercise) {
        exercise.timesUsed += 1
        update(exercise)
    }
    
    /// Save changes to model context
    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving ExerciseStore context: \(error)")
        }
    }
}
