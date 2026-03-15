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

    // MARK: - Seeding

    /// Seed the catalog with built-in exercises on first launch
    func seedIfNeeded() {
        guard all().isEmpty else { return }

        let defaults: [(String, String, ExerciseType, [MuscleGroup], [MuscleGroup], Equipment, BlockType, MovementPattern?)] = [
            // Bodyweight
            ("Push-ups", "Classic upper body push exercise", .strength, [.chest, .triceps], [.shoulders, .core], .none, .repBased, .push),
            ("Squats", "Fundamental lower body exercise", .strength, [.quads, .glutes], [.hamstrings, .core], .none, .repBased, .squat),
            ("Lunges", "Unilateral leg exercise", .strength, [.quads, .glutes], [.hamstrings], .none, .repBased, .squat),
            ("Plank", "Core stabilization hold", .isometric, [.core], [.shoulders], .none, .timed, nil),
            ("Burpees", "Full body explosive movement", .plyometric, [.fullBody], [], .none, .repBased, nil),
            ("Mountain Climbers", "Dynamic core and cardio drill", .cardio, [.core, .quads], [], .none, .timed, nil),
            ("Jumping Jacks", "Full body warm-up cardio", .cardio, [.fullBody], [], .none, .timed, nil),
            ("Glute Bridges", "Hip extension exercise", .strength, [.glutes, .hamstrings], [.core], .none, .repBased, .hinge),
            ("Tricep Dips", "Bodyweight tricep exercise", .strength, [.triceps], [.chest, .shoulders], .none, .repBased, .push),
            ("Superman Hold", "Lower back and glute hold", .isometric, [.back, .glutes], [], .none, .timed, nil),
            ("Bicycle Crunches", "Rotational core exercise", .strength, [.core], [], .none, .repBased, .rotate),
            ("High Knees", "Cardio sprint drill", .cardio, [.quads, .core], [], .none, .timed, .run),
            ("Wall Sit", "Isometric quad hold", .isometric, [.quads, .glutes], [], .none, .timed, nil),
            ("Calf Raises", "Calf isolation exercise", .strength, [.calves], [], .none, .repBased, nil),
            ("Side Plank", "Oblique stabilization hold", .isometric, [.core], [.shoulders], .none, .timed, nil),

            // Barbell
            ("Bench Press", "Primary chest compound lift", .strength, [.chest, .triceps], [.shoulders], .barbell, .repBased, .push),
            ("Barbell Squat", "King of lower body exercises", .strength, [.quads, .glutes], [.hamstrings, .core], .barbell, .repBased, .squat),
            ("Deadlift", "Full posterior chain compound lift", .strength, [.hamstrings, .back, .glutes], [.core, .forearms], .barbell, .repBased, .hinge),
            ("Overhead Press", "Standing shoulder press", .strength, [.shoulders, .triceps], [.core], .barbell, .repBased, .push),
            ("Barbell Row", "Horizontal pull for back thickness", .strength, [.back, .biceps], [.forearms], .barbell, .repBased, .pull),
            ("Romanian Deadlift", "Hamstring-focused hip hinge", .strength, [.hamstrings, .glutes], [.back], .barbell, .repBased, .hinge),

            // Dumbbell
            ("Dumbbell Curl", "Bicep isolation exercise", .strength, [.biceps], [.forearms], .dumbbell, .repBased, .pull),
            ("Dumbbell Lateral Raise", "Shoulder isolation for side delts", .strength, [.shoulders], [], .dumbbell, .repBased, nil),
            ("Dumbbell Fly", "Chest isolation exercise", .strength, [.chest], [.shoulders], .dumbbell, .repBased, nil),
            ("Dumbbell Shoulder Press", "Seated or standing shoulder press", .strength, [.shoulders, .triceps], [], .dumbbell, .repBased, .push),
            ("Dumbbell Lunge", "Weighted unilateral leg exercise", .strength, [.quads, .glutes], [.hamstrings], .dumbbell, .repBased, .squat),

            // Kettlebell
            ("Goblet Squat", "Front-loaded squat variation", .strength, [.quads, .glutes], [.core], .kettlebell, .repBased, .squat),
            ("Kettlebell Swing", "Explosive hip hinge movement", .plyometric, [.glutes, .hamstrings], [.core, .shoulders], .kettlebell, .repBased, .hinge),

            // Pull-up bar
            ("Pull-ups", "Vertical pull for back width", .strength, [.back, .biceps], [.forearms, .core], .pullUpBar, .repBased, .pull),
            ("Chin-ups", "Supinated grip vertical pull", .strength, [.biceps, .back], [.forearms], .pullUpBar, .repBased, .pull),

            // Cable
            ("Cable Fly", "Chest isolation with constant tension", .strength, [.chest], [.shoulders], .cableMachine, .repBased, nil),
            ("Lat Pulldown", "Vertical pull machine exercise", .strength, [.back, .biceps], [], .cableMachine, .repBased, .pull),
            ("Tricep Pushdown", "Cable tricep isolation", .strength, [.triceps], [], .cableMachine, .repBased, .push),
            ("Face Pull", "Rear delt and upper back exercise", .strength, [.shoulders, .back], [.rhomboids, .traps], .cableMachine, .repBased, .pull),

            // Yoga / Flexibility
            ("Downward Dog", "Foundational yoga inversion", .pose, [.hamstrings, .shoulders], [.calves], .yogaMat, .timed, .hold),
            ("Warrior II", "Standing hip opener and leg strengthener", .pose, [.quads, .shoulders], [.core], .yogaMat, .timed, .hold),
            ("Child's Pose", "Resting stretch for back and hips", .flexibility, [.back], [.hipFlexors], .yogaMat, .timed, .stretch),
            ("Pigeon Pose", "Deep hip flexor and glute stretch", .flexibility, [.hipFlexors, .glutes], [], .yogaMat, .timed, .hold),

            // Cardio machines
            ("Treadmill Run", "Steady-state or interval running", .cardio, [.quads, .hamstrings], [.calves, .core], .treadmill, .timed, .run),
            ("Rowing Machine", "Full body cardio pull", .cardio, [.back, .quads], [.biceps, .core], .rower, .timed, .row),
        ]

        for (name, desc, type, primary, secondary, equipment, blockType, pattern) in defaults {
            let exercise = Exercise(
                name: name,
                description: desc,
                exerciseType: type,
                primaryMuscleGroups: primary,
                secondaryMuscleGroups: secondary,
                equipment: equipment,
                movementPattern: pattern,
                defaultBlockType: blockType,
                defaultSets: blockType == .timed ? 3 : 3,
                defaultRepCount: blockType == .repBased ? 10 : nil,
                defaultDurationSeconds: blockType == .timed ? 45 : nil,
                isCustom: false
            )
            modelContext.insert(exercise)
        }
        save()
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
