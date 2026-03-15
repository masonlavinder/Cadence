import Foundation
import SwiftUI
import SwiftData

// MARK: - WorkoutStore
/// Service layer for Workout entity CRUD operations
/// Handles workout management, entry reordering, and exercise addition

@Observable
final class WorkoutStore {
    private let modelContext: ModelContext

    /// Revision counter — bumped on every write so SwiftUI re-evaluates queries
    private(set) var revision: Int = 0

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - CRUD Operations
    
    /// Create a new workout
    func create(_ workout: Workout) {
        modelContext.insert(workout)
        save()
    }
    
    /// Update an existing workout (calls touch() to update timestamp)
    func update(_ workout: Workout) {
        var mutableWorkout = workout
        mutableWorkout.touch()
        save()
    }
    
    /// Delete a workout (cascade deletes all WorkoutEntry children)
    func delete(_ workout: Workout) {
        modelContext.delete(workout)
        save()
    }
    
    /// Toggle favorite status
    func toggleFavorite(_ workout: Workout) {
        workout.isFavorite.toggle()
        update(workout)
    }
    
    // MARK: - Queries
    
    /// Fetch all workouts, sorted by name
    func all() -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Fetch only favorite workouts
    func favorites() -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Fetch workouts by category
    func byCategory(_ category: WorkoutCategory) -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.category == category },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Fetch workouts by difficulty
    func byDifficulty(_ difficulty: Difficulty) -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.difficulty == difficulty },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Fetch recent workouts (by last completed date)
    func recentlyCompleted(limit: Int = 10) -> [Workout] {
        let descriptor = FetchDescriptor<Workout>(
            sortBy: [SortDescriptor(\.lastCompletedAt, order: .reverse)]
        )
        
        let workouts = (try? modelContext.fetch(descriptor)) ?? []
        return Array(workouts.filter { $0.lastCompletedAt != nil }.prefix(limit))
    }
    
    // MARK: - Entry Management
    
    /// Reorder entries within a workout
    func moveEntry(in workout: Workout, from source: IndexSet, to destination: Int) {
        var entries = workout.entries
        entries.move(fromOffsets: source, toOffset: destination)
        
        // Update orderIndex for all entries
        for (index, entry) in entries.enumerated() {
            entry.orderIndex = index
        }
        
        workout.entries = entries
        update(workout)
    }
    
    /// Add an exercise from the catalog to a workout
    /// Creates a new WorkoutEntry with the exercise's defaults
    func addExercise(_ exercise: Exercise, to workout: Workout) {
        let orderIndex = workout.entries.count
        let entry = WorkoutEntry(from: exercise, orderIndex: orderIndex)
        
        workout.entries.append(entry)
        modelContext.insert(entry)
        
        // Increment the exercise's usage counter
        exercise.timesUsed += 1
        
        update(workout)
        save()
    }
    
    /// Remove an entry from a workout
    func removeEntry(_ entry: WorkoutEntry, from workout: Workout) {
        if let index = workout.entries.firstIndex(where: { $0.id == entry.id }) {
            workout.entries.remove(at: index)
            modelContext.delete(entry)
            
            // Re-index remaining entries
            for (newIndex, remainingEntry) in workout.entries.enumerated() {
                remainingEntry.orderIndex = newIndex
            }
            
            update(workout)
        }
    }
    
    /// Duplicate a workout (creates a new workout with copied entries)
    func duplicate(_ workout: Workout) -> Workout {
        let newWorkout = Workout(
            name: "\(workout.name) (Copy)",
            description: workout.workoutDescription,
            category: workout.category,
            difficulty: workout.difficulty,
            estimatedDurationMinutes: workout.estimatedDurationMinutes,
            targetMuscleGroups: workout.targetMuscleGroups,
            requiredEquipment: workout.requiredEquipment,
            flowStyle: workout.flowStyle,
            breathCues: workout.breathCues,
            source: workout.source
        )
        
        create(newWorkout)
        
        // Copy all entries
        for oldEntry in workout.entries.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            let newEntry = WorkoutEntry(
                exerciseId: oldEntry.exerciseId,
                exerciseName: oldEntry.exerciseName,
                orderIndex: oldEntry.orderIndex,
                blockType: oldEntry.blockType,
                sets: oldEntry.sets,
                targetReps: oldEntry.targetReps,
                targetWeight: oldEntry.targetWeight,
                durationSeconds: oldEntry.durationSeconds,
                targetDistanceMeters: oldEntry.targetDistanceMeters,
                restBetweenSetsSeconds: oldEntry.restBetweenSetsSeconds,
                restAfterExerciseSeconds: oldEntry.restAfterExerciseSeconds,
                holdSeconds: oldEntry.holdSeconds,
                transitionStyle: oldEntry.transitionStyle,
                breathCycles: oldEntry.breathCycles,
                equipmentOverride: oldEntry.equipmentOverride,
                customCueText: oldEntry.customCueText,
                midExerciseCues: oldEntry.midExerciseCues,
                notes: oldEntry.notes
            )
            
            newWorkout.entries.append(newEntry)
            modelContext.insert(newEntry)
        }
        
        save()
        return newWorkout
    }
    
    /// Increment completion count and update last completed date
    func markCompleted(_ workout: Workout) {
        workout.timesCompleted += 1
        workout.lastCompletedAt = Date()
        update(workout)
    }
    
    // MARK: - Helpers
    
    /// Calculate and update estimated duration based on entries
    func recalculateDuration(_ workout: Workout) {
        workout.estimatedDurationMinutes = workout.calculateEstimatedDuration()
        update(workout)
    }
    
    /// Save changes to model context
    private func save() {
        do {
            try modelContext.save()
            revision += 1
        } catch {
            print("Error saving WorkoutStore context: \(error)")
        }
    }
}
