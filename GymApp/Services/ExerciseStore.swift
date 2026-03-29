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
    
    /// Fetch exercises sorted by lowest usage (for discovery)
    func leastUsed(limit: Int = 5) -> [Exercise] {
        Array(all().sorted { $0.timesUsed < $1.timesUsed }.prefix(limit))
    }

    // MARK: - Built-in Defaults

    /// Returns the built-in default for an exercise by name, or nil if it's user-created.
    func builtInDefault(for exercise: Exercise) -> (String, String, ExerciseType, [MuscleGroup], [MuscleGroup], Equipment, BlockType, MovementPattern?, [String])? {
        let name = exercise.name.lowercased()
        return Self.builtInExercises.first { $0.0.lowercased() == name }
    }

    /// Whether a built-in exercise has been modified from its defaults.
    func isModified(_ exercise: Exercise) -> Bool {
        guard let defaults = builtInDefault(for: exercise) else { return false }
        return exercise.exerciseDescription != defaults.1
            || exercise.exerciseType != defaults.2
            || exercise.primaryMuscleGroups != defaults.3
            || exercise.secondaryMuscleGroups != defaults.4
            || exercise.equipment != defaults.5
            || exercise.defaultBlockType != defaults.6
            || exercise.movementPattern != defaults.7
    }

    /// Reset a built-in exercise back to its Cadence defaults.
    func resetToDefault(_ exercise: Exercise) {
        guard let defaults = builtInDefault(for: exercise) else { return }
        exercise.exerciseDescription = defaults.1
        exercise.exerciseType = defaults.2
        exercise.primaryMuscleGroups = defaults.3
        exercise.secondaryMuscleGroups = defaults.4
        exercise.equipment = defaults.5
        exercise.defaultBlockType = defaults.6
        exercise.movementPattern = defaults.7
        exercise.tags = defaults.8
        exercise.defaultSets = 3
        exercise.defaultRepCount = defaults.6 == .repBased ? 10 : nil
        exercise.defaultDurationSeconds = defaults.6 == .timed ? 45 : nil
        exercise.isCustom = false
        update(exercise)
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

    private static let seedVersion = 4
    private static let seedVersionKey = "ExerciseStore.seedVersion"

    /// Seed the catalog with built-in exercises. Upserts by name so new
    /// exercises are added on app update without duplicating existing ones.
    func seedIfNeeded() {
        let currentVersion = UserDefaults.standard.integer(forKey: Self.seedVersionKey)
        guard currentVersion < Self.seedVersion else { return }

        let existing = all()
        let existingByName = Dictionary(existing.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })

        for (name, desc, type, primary, secondary, equipment, blockType, pattern, tags) in Self.builtInExercises {
            if let exercise = existingByName[name.lowercased()] {
                // Update tags on existing exercises
                exercise.tags = tags
            } else {
                let exercise = Exercise(
                    name: name,
                    description: desc,
                    exerciseType: type,
                    primaryMuscleGroups: primary,
                    secondaryMuscleGroups: secondary,
                    equipment: equipment,
                    movementPattern: pattern,
                    defaultBlockType: blockType,
                    defaultSets: 3,
                    defaultRepCount: blockType == .repBased ? 10 : nil,
                    defaultDurationSeconds: blockType == .timed ? 45 : nil,
                    tags: tags,
                    isCustom: false
                )
                modelContext.insert(exercise)
            }
        }
        save()
        UserDefaults.standard.set(Self.seedVersion, forKey: Self.seedVersionKey)
    }

    // swiftlint:disable function_body_length
    private static let builtInExercises: [(String, String, ExerciseType, [MuscleGroup], [MuscleGroup], Equipment, BlockType, MovementPattern?, [String])] = [

        // =====================================================================
        // MARK: Bodyweight Strength
        // =====================================================================
        ("Push-ups", "Classic upper body push exercise", .strength, [.chest, .triceps], [.shoulders, .core], .none, .repBased, .push, ["fundamental", "beginner"]),
        ("Wide Push-ups", "Wider grip targeting outer chest", .strength, [.chest], [.triceps, .shoulders], .none, .repBased, .push, []),
        ("Diamond Push-ups", "Close grip targeting triceps", .strength, [.triceps, .chest], [.shoulders], .none, .repBased, .push, []),
        ("Decline Push-ups", "Feet elevated for upper chest emphasis", .strength, [.chest, .shoulders], [.triceps, .core], .none, .repBased, .push, []),
        ("Pike Push-ups", "Vertical push bodyweight variation", .strength, [.shoulders, .triceps], [.core], .none, .repBased, .push, []),
        ("Squats", "Fundamental lower body exercise", .strength, [.quads, .glutes], [.hamstrings, .core], .none, .repBased, .squat, ["fundamental", "beginner"]),
        ("Jump Squats", "Explosive squat with jump", .plyometric, [.quads, .glutes], [.calves, .core], .none, .repBased, .squat, []),
        ("Pistol Squats", "Single-leg squat for balance and strength", .strength, [.quads, .glutes], [.hamstrings, .core], .none, .repBased, .squat, []),
        ("Lunges", "Unilateral leg exercise", .strength, [.quads, .glutes], [.hamstrings], .none, .repBased, .squat, ["fundamental", "beginner"]),
        ("Reverse Lunges", "Step-back lunge variation", .strength, [.quads, .glutes], [.hamstrings], .none, .repBased, .squat, ["beginner"]),
        ("Walking Lunges", "Forward stepping lunge pattern", .strength, [.quads, .glutes], [.hamstrings, .core], .none, .repBased, .squat, []),
        ("Bulgarian Split Squats", "Rear foot elevated single-leg squat", .strength, [.quads, .glutes], [.hamstrings, .core], .none, .repBased, .squat, ["fundamental"]),
        ("Step-ups", "Step onto elevated surface", .strength, [.quads, .glutes], [.hamstrings], .none, .repBased, .squat, ["beginner"]),
        ("Glute Bridges", "Hip extension exercise", .strength, [.glutes, .hamstrings], [.core], .none, .repBased, .hinge, ["fundamental", "beginner"]),
        ("Single-Leg Glute Bridge", "Unilateral hip extension", .strength, [.glutes, .hamstrings], [.core], .none, .repBased, .hinge, []),
        ("Hip Thrusts", "Loaded hip extension for glutes", .strength, [.glutes], [.hamstrings, .core], .none, .repBased, .hinge, ["fundamental", "beginner"]),
        ("Tricep Dips", "Bodyweight tricep exercise", .strength, [.triceps], [.chest, .shoulders], .none, .repBased, .push, []),
        ("Inverted Rows", "Bodyweight horizontal pull", .strength, [.back, .biceps], [.core, .forearms], .none, .repBased, .pull, ["fundamental", "beginner"]),
        ("Calf Raises", "Calf isolation exercise", .strength, [.calves], [], .none, .repBased, nil, ["beginner"]),
        ("Single-Leg Calf Raise", "Unilateral calf isolation", .strength, [.calves], [], .none, .repBased, nil, []),
        ("Bicycle Crunches", "Rotational core exercise", .strength, [.core], [], .none, .repBased, .rotate, []),
        ("Crunches", "Basic abdominal flexion", .strength, [.core], [], .none, .repBased, nil, ["beginner"]),
        ("Sit-ups", "Full range abdominal flexion", .strength, [.core], [.hipFlexors], .none, .repBased, nil, []),
        ("Leg Raises", "Lower abdominal exercise", .strength, [.core], [.hipFlexors], .none, .repBased, nil, []),
        ("Hanging Leg Raises", "Advanced lower ab exercise", .strength, [.core], [.hipFlexors, .forearms], .pullUpBar, .repBased, nil, []),
        ("Russian Twists", "Seated rotational core exercise", .strength, [.core], [], .none, .repBased, .rotate, []),
        ("V-ups", "Full body crunch exercise", .strength, [.core], [.hipFlexors], .none, .repBased, nil, []),
        ("Flutter Kicks", "Alternating leg raise for lower abs", .strength, [.core], [.hipFlexors], .none, .timed, nil, []),
        ("Dead Bugs", "Anti-extension core stability drill", .strength, [.core], [], .none, .repBased, nil, ["fundamental", "beginner"]),
        ("Bear Crawl", "Quadruped crawling pattern", .strength, [.core, .shoulders], [.quads], .none, .timed, nil, []),

        // =====================================================================
        // MARK: Isometric / Holds
        // =====================================================================
        ("Plank", "Core stabilization hold", .isometric, [.core], [.shoulders], .none, .timed, nil, ["fundamental", "beginner"]),
        ("Side Plank", "Oblique stabilization hold", .isometric, [.core], [.shoulders], .none, .timed, nil, ["fundamental"]),
        ("Superman Hold", "Lower back and glute hold", .isometric, [.back, .glutes], [], .none, .timed, nil, []),
        ("Wall Sit", "Isometric quad hold", .isometric, [.quads, .glutes], [], .none, .timed, nil, ["beginner"]),
        ("Hollow Body Hold", "Gymnastic core position", .isometric, [.core], [], .none, .timed, nil, ["fundamental"]),
        ("L-Sit", "Advanced isometric core hold", .isometric, [.core, .hipFlexors], [.triceps], .none, .timed, nil, []),
        ("Glute Bridge Hold", "Isometric hip extension hold", .isometric, [.glutes, .hamstrings], [.core], .none, .timed, nil, ["beginner"]),
        ("Dead Hang", "Grip and shoulder decompression", .isometric, [.forearms], [.shoulders, .back], .pullUpBar, .timed, nil, []),

        // =====================================================================
        // MARK: Plyometric / Explosive
        // =====================================================================
        ("Burpees", "Full body explosive movement", .plyometric, [.fullBody], [], .none, .repBased, nil, []),
        ("Box Jumps", "Explosive jump onto platform", .plyometric, [.quads, .glutes], [.calves], .none, .repBased, nil, []),
        ("Broad Jumps", "Horizontal explosive jump", .plyometric, [.quads, .glutes], [.calves, .core], .none, .repBased, nil, []),
        ("Tuck Jumps", "Explosive jump with knee tuck", .plyometric, [.quads, .glutes], [.calves, .core], .none, .repBased, nil, []),
        ("Skater Jumps", "Lateral bounding exercise", .plyometric, [.quads, .glutes], [.calves], .none, .repBased, nil, []),
        ("Plyo Push-ups", "Explosive push-up with hand lift", .plyometric, [.chest, .triceps], [.shoulders], .none, .repBased, .push, []),
        ("Lunge Jumps", "Alternating jump lunges", .plyometric, [.quads, .glutes], [.calves, .core], .none, .repBased, .squat, []),

        // =====================================================================
        // MARK: Cardio / Conditioning
        // =====================================================================
        ("Mountain Climbers", "Dynamic core and cardio drill", .cardio, [.core, .quads], [], .none, .timed, nil, []),
        ("Jumping Jacks", "Full body warm-up cardio", .cardio, [.fullBody], [], .none, .timed, nil, []),
        ("High Knees", "Cardio sprint drill", .cardio, [.quads, .core], [], .none, .timed, .run, []),
        ("Butt Kicks", "Hamstring activation cardio drill", .cardio, [.hamstrings], [.calves], .none, .timed, .run, []),
        ("Jump Rope", "Classic cardio conditioning", .cardio, [.calves, .fullBody], [.shoulders, .forearms], .jumpRope, .timed, nil, []),
        ("Battle Ropes", "Upper body cardio conditioning", .cardio, [.shoulders, .back], [.core, .forearms], .battleRopes, .timed, nil, []),
        ("Treadmill Run", "Steady-state or interval running", .cardio, [.quads, .hamstrings], [.calves, .core], .treadmill, .timed, .run, []),
        ("Treadmill Walk", "Low intensity walking", .cardio, [.quads], [.calves, .glutes], .treadmill, .timed, nil, []),
        ("Incline Treadmill Walk", "Walking at an incline for glute and cardio work", .cardio, [.glutes, .quads], [.calves, .hamstrings], .treadmill, .timed, nil, []),
        ("Rowing Machine", "Full body cardio pull", .cardio, [.back, .quads], [.biceps, .core], .rower, .timed, .row, []),
        ("Stationary Bike", "Low impact cycling", .cardio, [.quads, .hamstrings], [.calves], .bike, .timed, .cycle, []),
        ("Elliptical", "Full body low impact cardio", .cardio, [.quads, .glutes], [.shoulders, .core], .elliptical, .timed, nil, []),
        ("Stair Climber", "Step-based cardio conditioning", .cardio, [.quads, .glutes], [.calves], .other, .timed, nil, []),
        ("Outdoor Walk", "Walking outdoors at a steady pace", .cardio, [.quads], [.calves, .glutes], .none, .timed, nil, []),
        ("Outdoor Run", "Running outdoors", .cardio, [.quads, .hamstrings], [.calves, .core], .none, .timed, .run, []),
        ("Sprint Intervals", "Alternating sprint and recovery", .interval, [.quads, .hamstrings], [.calves, .core, .glutes], .none, .timed, .run, []),

        // =====================================================================
        // MARK: Barbell
        // =====================================================================
        ("Bench Press", "Primary chest compound lift", .strength, [.chest, .triceps], [.shoulders], .barbell, .repBased, .push, ["fundamental"]),
        ("Incline Bench Press", "Upper chest focused press", .strength, [.chest, .shoulders], [.triceps], .barbell, .repBased, .push, ["fundamental"]),
        ("Close-Grip Bench Press", "Tricep-focused pressing", .strength, [.triceps, .chest], [.shoulders], .barbell, .repBased, .push, []),
        ("Barbell Squat", "King of lower body exercises", .strength, [.quads, .glutes], [.hamstrings, .core], .barbell, .repBased, .squat, ["fundamental"]),
        ("Front Squat", "Quad-dominant squat variation", .strength, [.quads], [.glutes, .core], .barbell, .repBased, .squat, []),
        ("Deadlift", "Full posterior chain compound lift", .strength, [.hamstrings, .back, .glutes], [.core, .forearms], .barbell, .repBased, .hinge, ["fundamental"]),
        ("Sumo Deadlift", "Wide stance deadlift for inner thighs and glutes", .strength, [.glutes, .quads], [.hamstrings, .back, .core], .barbell, .repBased, .hinge, []),
        ("Trap Bar Deadlift", "Neutral grip deadlift variation", .strength, [.quads, .hamstrings, .glutes], [.back, .core], .barbell, .repBased, .hinge, []),
        ("Romanian Deadlift", "Hamstring-focused hip hinge", .strength, [.hamstrings, .glutes], [.back], .barbell, .repBased, .hinge, ["fundamental"]),
        ("Overhead Press", "Standing shoulder press", .strength, [.shoulders, .triceps], [.core], .barbell, .repBased, .push, ["fundamental"]),
        ("Push Press", "Explosive overhead press with leg drive", .strength, [.shoulders, .triceps], [.quads, .core], .barbell, .repBased, .push, []),
        ("Barbell Row", "Horizontal pull for back thickness", .strength, [.back, .biceps], [.forearms], .barbell, .repBased, .pull, ["fundamental"]),
        ("Pendlay Row", "Strict bent-over row from floor", .strength, [.back], [.biceps, .core], .barbell, .repBased, .pull, []),
        ("Barbell Shrug", "Trap isolation with barbell", .strength, [.traps], [.forearms], .barbell, .repBased, nil, []),
        ("Barbell Curl", "Standing bicep curl with barbell", .strength, [.biceps], [.forearms], .barbell, .repBased, .pull, []),
        ("Skull Crushers", "Lying tricep extension", .strength, [.triceps], [], .barbell, .repBased, nil, []),
        ("Hip Thrust (Barbell)", "Loaded hip extension for glutes", .strength, [.glutes], [.hamstrings, .core], .barbell, .repBased, .hinge, ["fundamental"]),
        ("Good Mornings", "Barbell hip hinge for posterior chain", .strength, [.hamstrings, .back], [.glutes, .core], .barbell, .repBased, .hinge, []),
        ("Barbell Hack Squat", "Behind-body barbell squat", .strength, [.quads], [.glutes], .barbell, .repBased, .squat, []),
        ("Power Clean", "Olympic explosive pull to shoulders", .plyometric, [.hamstrings, .glutes, .back], [.shoulders, .core, .traps], .barbell, .repBased, .hinge, []),
        ("Hang Clean", "Olympic pull from hang position", .plyometric, [.hamstrings, .glutes], [.back, .shoulders, .traps], .barbell, .repBased, .hinge, []),
        ("Clean and Press", "Full body power movement", .plyometric, [.fullBody], [.core], .barbell, .repBased, .hinge, []),
        ("Snatch", "Olympic full extension pull overhead", .plyometric, [.fullBody], [.core, .shoulders], .barbell, .repBased, nil, []),

        // =====================================================================
        // MARK: Dumbbell
        // =====================================================================
        ("Dumbbell Curl", "Bicep isolation exercise", .strength, [.biceps], [.forearms], .dumbbell, .repBased, .pull, ["beginner"]),
        ("Hammer Curl", "Neutral grip bicep curl", .strength, [.biceps, .forearms], [], .dumbbell, .repBased, .pull, []),
        ("Concentration Curl", "Seated single-arm bicep isolation", .strength, [.biceps], [], .dumbbell, .repBased, .pull, []),
        ("Incline Dumbbell Curl", "Bicep curl on incline bench", .strength, [.biceps], [], .dumbbell, .repBased, .pull, []),
        ("Dumbbell Lateral Raise", "Shoulder isolation for side delts", .strength, [.shoulders], [], .dumbbell, .repBased, nil, ["beginner"]),
        ("Dumbbell Front Raise", "Anterior deltoid isolation", .strength, [.shoulders], [], .dumbbell, .repBased, nil, []),
        ("Dumbbell Rear Delt Fly", "Posterior deltoid isolation", .strength, [.shoulders, .rhomboids], [.traps], .dumbbell, .repBased, nil, []),
        ("Dumbbell Fly", "Chest isolation exercise", .strength, [.chest], [.shoulders], .dumbbell, .repBased, nil, []),
        ("Incline Dumbbell Fly", "Upper chest fly on incline", .strength, [.chest], [.shoulders], .dumbbell, .repBased, nil, []),
        ("Dumbbell Bench Press", "Chest press with dumbbells", .strength, [.chest, .triceps], [.shoulders], .dumbbell, .repBased, .push, ["fundamental", "beginner"]),
        ("Incline Dumbbell Press", "Upper chest press on incline", .strength, [.chest, .shoulders], [.triceps], .dumbbell, .repBased, .push, []),
        ("Dumbbell Shoulder Press", "Seated or standing shoulder press", .strength, [.shoulders, .triceps], [], .dumbbell, .repBased, .push, ["fundamental", "beginner"]),
        ("Arnold Press", "Rotational shoulder press", .strength, [.shoulders, .triceps], [], .dumbbell, .repBased, .push, []),
        ("Dumbbell Lunge", "Weighted unilateral leg exercise", .strength, [.quads, .glutes], [.hamstrings], .dumbbell, .repBased, .squat, ["beginner"]),
        ("Dumbbell Row", "Single-arm back row", .strength, [.back, .biceps], [.forearms], .dumbbell, .repBased, .pull, ["fundamental", "beginner"]),
        ("Dumbbell Pullover", "Lats and chest stretch under load", .strength, [.lats, .chest], [.triceps], .dumbbell, .repBased, nil, []),
        ("Dumbbell Shrug", "Trap isolation with dumbbells", .strength, [.traps], [.forearms], .dumbbell, .repBased, nil, []),
        ("Dumbbell Tricep Extension", "Overhead tricep isolation", .strength, [.triceps], [], .dumbbell, .repBased, nil, []),
        ("Dumbbell Kickback", "Tricep kickback isolation", .strength, [.triceps], [], .dumbbell, .repBased, nil, []),
        ("Dumbbell Romanian Deadlift", "Dumbbell hip hinge for hamstrings", .strength, [.hamstrings, .glutes], [.back], .dumbbell, .repBased, .hinge, ["beginner"]),
        ("Farmer's Walk", "Loaded carry for grip and core", .strength, [.forearms, .core], [.traps, .shoulders], .dumbbell, .timed, .carry, ["fundamental"]),
        ("Renegade Row", "Plank position alternating rows", .strength, [.back, .core], [.biceps, .shoulders], .dumbbell, .repBased, .pull, []),
        ("Dumbbell Thruster", "Squat to overhead press", .strength, [.quads, .shoulders], [.glutes, .triceps, .core], .dumbbell, .repBased, nil, []),

        // =====================================================================
        // MARK: Kettlebell
        // =====================================================================
        ("Goblet Squat", "Front-loaded squat variation", .strength, [.quads, .glutes], [.core], .kettlebell, .repBased, .squat, ["fundamental", "beginner"]),
        ("Kettlebell Swing", "Explosive hip hinge movement", .plyometric, [.glutes, .hamstrings], [.core, .shoulders], .kettlebell, .repBased, .hinge, ["fundamental"]),
        ("Kettlebell Clean", "Single-arm clean to rack position", .plyometric, [.hamstrings, .glutes], [.shoulders, .core], .kettlebell, .repBased, .hinge, []),
        ("Kettlebell Snatch", "Single-arm snatch overhead", .plyometric, [.shoulders, .glutes], [.hamstrings, .core], .kettlebell, .repBased, nil, []),
        ("Kettlebell Turkish Get-Up", "Full body ground-to-standing movement", .strength, [.core, .shoulders], [.glutes, .quads], .kettlebell, .repBased, nil, []),
        ("Kettlebell Windmill", "Overhead stability with lateral bend", .flexibility, [.core, .shoulders], [.hamstrings, .hipFlexors], .kettlebell, .repBased, nil, []),
        ("Kettlebell Halo", "Shoulder mobility and stability circle", .strength, [.shoulders], [.core], .kettlebell, .repBased, .rotate, []),

        // =====================================================================
        // MARK: Pull-up Bar
        // =====================================================================
        ("Pull-ups", "Vertical pull for back width", .strength, [.back, .biceps], [.forearms, .core], .pullUpBar, .repBased, .pull, ["fundamental"]),
        ("Chin-ups", "Supinated grip vertical pull", .strength, [.biceps, .back], [.forearms], .pullUpBar, .repBased, .pull, []),
        ("Wide-Grip Pull-ups", "Lat-focused wide pull-up", .strength, [.lats, .back], [.biceps, .forearms], .pullUpBar, .repBased, .pull, []),
        ("Neutral-Grip Pull-ups", "Parallel grip pull-up variation", .strength, [.back, .biceps], [.forearms], .pullUpBar, .repBased, .pull, []),
        ("Muscle-ups", "Pull-up transitioning over the bar", .strength, [.back, .chest, .triceps], [.shoulders, .core], .pullUpBar, .repBased, .pull, []),
        ("Knee Raises", "Hanging knee tuck for core", .strength, [.core], [.hipFlexors], .pullUpBar, .repBased, nil, []),
        ("Toes to Bar", "Hanging toe touch for core", .strength, [.core], [.hipFlexors, .forearms], .pullUpBar, .repBased, nil, []),

        // =====================================================================
        // MARK: Cable Machine
        // =====================================================================
        ("Cable Fly", "Chest isolation with constant tension", .strength, [.chest], [.shoulders], .cableMachine, .repBased, nil, []),
        ("Cable Crossover", "Standing cable chest fly", .strength, [.chest], [.shoulders], .cableMachine, .repBased, nil, []),
        ("Lat Pulldown", "Vertical pull machine exercise", .strength, [.back, .biceps], [], .cableMachine, .repBased, .pull, ["fundamental", "beginner"]),
        ("Close-Grip Lat Pulldown", "Lat pulldown with narrow grip", .strength, [.lats, .biceps], [], .cableMachine, .repBased, .pull, []),
        ("Tricep Pushdown", "Cable tricep isolation", .strength, [.triceps], [], .cableMachine, .repBased, .push, []),
        ("Overhead Tricep Extension (Cable)", "Cable overhead tricep stretch", .strength, [.triceps], [], .cableMachine, .repBased, nil, []),
        ("Face Pull", "Rear delt and upper back exercise", .strength, [.shoulders, .back], [.rhomboids, .traps], .cableMachine, .repBased, .pull, ["fundamental"]),
        ("Cable Row", "Seated horizontal cable pull", .strength, [.back, .biceps], [.forearms], .cableMachine, .repBased, .pull, ["beginner"]),
        ("Cable Curl", "Bicep curl with cable", .strength, [.biceps], [.forearms], .cableMachine, .repBased, .pull, []),
        ("Cable Lateral Raise", "Constant tension side delt raise", .strength, [.shoulders], [], .cableMachine, .repBased, nil, []),
        ("Cable Woodchop", "Rotational core movement", .strength, [.core], [.shoulders], .cableMachine, .repBased, .rotate, []),
        ("Cable Pull-Through", "Cable hip hinge for glutes", .strength, [.glutes, .hamstrings], [.core], .cableMachine, .repBased, .hinge, []),
        ("Cable Crunch", "Weighted cable abdominal crunch", .strength, [.core], [], .cableMachine, .repBased, nil, []),

        // =====================================================================
        // MARK: Smith Machine / Leg Press / Machines
        // =====================================================================
        ("Smith Machine Squat", "Guided barbell squat", .strength, [.quads, .glutes], [.hamstrings], .smithMachine, .repBased, .squat, []),
        ("Smith Machine Bench Press", "Guided barbell bench press", .strength, [.chest, .triceps], [.shoulders], .smithMachine, .repBased, .push, []),
        ("Leg Press", "Machine-based lower body press", .strength, [.quads, .glutes], [.hamstrings], .legPress, .repBased, .squat, ["fundamental", "beginner"]),
        ("Leg Extension", "Quad isolation machine", .strength, [.quads], [], .other, .repBased, nil, ["beginner"]),
        ("Leg Curl", "Hamstring isolation machine", .strength, [.hamstrings], [], .other, .repBased, nil, ["beginner"]),
        ("Seated Calf Raise", "Machine calf isolation", .strength, [.calves], [], .other, .repBased, nil, []),
        ("Hip Abduction Machine", "Outer thigh and glute med", .strength, [.glutes], [], .other, .repBased, nil, ["beginner"]),
        ("Hip Adduction Machine", "Inner thigh isolation", .strength, [.quads], [], .other, .repBased, nil, []),
        ("Chest Press Machine", "Machine-guided chest press", .strength, [.chest, .triceps], [.shoulders], .other, .repBased, .push, ["beginner"]),
        ("Shoulder Press Machine", "Machine-guided overhead press", .strength, [.shoulders, .triceps], [], .other, .repBased, .push, ["beginner"]),
        ("Pec Deck", "Machine chest fly", .strength, [.chest], [.shoulders], .other, .repBased, nil, []),
        ("Reverse Pec Deck", "Machine rear delt fly", .strength, [.shoulders, .rhomboids], [.traps], .other, .repBased, nil, []),

        // =====================================================================
        // MARK: Resistance Band
        // =====================================================================
        ("Band Pull-Apart", "Rear delt and upper back activation", .strength, [.shoulders, .rhomboids], [.traps], .resistanceBand, .repBased, .pull, []),
        ("Banded Squat", "Squat with band resistance", .strength, [.quads, .glutes], [.hamstrings], .resistanceBand, .repBased, .squat, ["beginner"]),
        ("Banded Lateral Walk", "Glute med activation drill", .strength, [.glutes], [], .resistanceBand, .repBased, nil, ["beginner"]),
        ("Banded Good Morning", "Light hip hinge with band", .strength, [.hamstrings, .back], [.glutes], .resistanceBand, .repBased, .hinge, []),
        ("Banded Face Pull", "Rear delt band pull", .strength, [.shoulders, .rhomboids], [.traps], .resistanceBand, .repBased, .pull, []),
        ("Banded Bicep Curl", "Bicep curl with resistance band", .strength, [.biceps], [.forearms], .resistanceBand, .repBased, .pull, []),
        ("Banded Tricep Pushdown", "Tricep extension with band", .strength, [.triceps], [], .resistanceBand, .repBased, .push, []),

        // =====================================================================
        // MARK: TRX / Suspension
        // =====================================================================
        ("TRX Row", "Suspension bodyweight row", .strength, [.back, .biceps], [.core], .trx, .repBased, .pull, []),
        ("TRX Chest Press", "Suspension push-up variation", .strength, [.chest, .triceps], [.core, .shoulders], .trx, .repBased, .push, []),
        ("TRX Pike", "Suspended pike for core and shoulders", .strength, [.core, .shoulders], [], .trx, .repBased, nil, []),
        ("TRX Hamstring Curl", "Supine hamstring curl on straps", .strength, [.hamstrings, .glutes], [.core], .trx, .repBased, nil, []),
        ("TRX Y-Fly", "Shoulder and upper back suspension exercise", .strength, [.shoulders, .back], [.core], .trx, .repBased, nil, []),

        // =====================================================================
        // MARK: Yoga Poses
        // =====================================================================
        ("Downward Dog", "Foundational yoga inversion", .pose, [.hamstrings, .shoulders], [.calves], .yogaMat, .timed, .hold, []),
        ("Upward Dog", "Chest opening backbend", .pose, [.chest, .shoulders], [.back], .yogaMat, .timed, .hold, []),
        ("Warrior I", "Standing lunge with arms overhead", .pose, [.quads, .shoulders], [.hipFlexors, .core], .yogaMat, .timed, .hold, []),
        ("Warrior II", "Standing hip opener and leg strengthener", .pose, [.quads, .shoulders], [.core], .yogaMat, .timed, .hold, []),
        ("Warrior III", "Single-leg balance with forward lean", .pose, [.hamstrings, .glutes], [.core, .shoulders], .yogaMat, .timed, .hold, []),
        ("Triangle Pose", "Standing lateral stretch and hip opener", .pose, [.hamstrings], [.core, .shoulders], .yogaMat, .timed, .hold, []),
        ("Extended Side Angle", "Deep lateral lunge with reach", .pose, [.quads, .core], [.shoulders], .yogaMat, .timed, .hold, []),
        ("Half Moon Pose", "Balancing lateral standing pose", .pose, [.glutes, .core], [.hamstrings, .shoulders], .yogaMat, .timed, .hold, []),
        ("Tree Pose", "Single-leg balance pose", .pose, [.core], [.calves, .quads], .yogaMat, .timed, .hold, []),
        ("Eagle Pose", "Standing balance with arm and leg wrap", .pose, [.shoulders, .quads], [.core, .calves], .yogaMat, .timed, .hold, []),
        ("Chair Pose", "Standing squat hold", .pose, [.quads, .glutes], [.core, .shoulders], .yogaMat, .timed, .hold, []),
        ("Boat Pose", "Seated V-shape core hold", .pose, [.core, .hipFlexors], [], .yogaMat, .timed, .hold, []),
        ("Crow Pose", "Arm balance for core and shoulders", .pose, [.core, .shoulders], [.forearms], .yogaMat, .timed, .hold, []),
        ("Bridge Pose", "Supine backbend for spine and glutes", .pose, [.glutes, .back], [.core], .yogaMat, .timed, .hold, []),
        ("Camel Pose", "Kneeling backbend chest opener", .pose, [.chest, .hipFlexors], [.back, .shoulders], .yogaMat, .timed, .hold, []),
        ("Cobra Pose", "Prone backbend for spine extension", .pose, [.back, .chest], [], .yogaMat, .timed, .hold, []),
        ("Locust Pose", "Prone back and glute strengthener", .pose, [.back, .glutes], [.hamstrings], .yogaMat, .timed, .hold, []),
        ("Plough Pose", "Supine inversion with legs overhead", .pose, [.hamstrings, .back], [.core], .yogaMat, .timed, .hold, []),
        ("Shoulder Stand", "Inverted pose for circulation and core", .pose, [.core, .shoulders], [.back], .yogaMat, .timed, .hold, []),
        ("Headstand", "Full inversion on head and forearms", .pose, [.core, .shoulders], [.forearms], .yogaMat, .timed, .hold, []),
        ("Corpse Pose", "Final relaxation and body scan", .pose, [.fullBody], [], .yogaMat, .timed, nil, []),
        ("Cat-Cow", "Spinal flexion and extension flow", .pose, [.back, .core], [], .yogaMat, .timed, .flow, []),
        ("Sun Salutation A", "Classic warm-up yoga flow sequence", .pose, [.fullBody], [], .yogaMat, .timed, .flow, []),
        ("Sun Salutation B", "Extended flow with warrior and chair", .pose, [.fullBody], [], .yogaMat, .timed, .flow, []),

        // =====================================================================
        // MARK: Flexibility / Stretching
        // =====================================================================
        ("Child's Pose", "Resting stretch for back and hips", .flexibility, [.back], [.hipFlexors], .yogaMat, .timed, .stretch, []),
        ("Pigeon Pose", "Deep hip flexor and glute stretch", .flexibility, [.hipFlexors, .glutes], [], .yogaMat, .timed, .hold, []),
        ("Seated Forward Fold", "Hamstring and lower back stretch", .flexibility, [.hamstrings, .back], [], .yogaMat, .timed, .stretch, []),
        ("Standing Forward Fold", "Standing hamstring and spine stretch", .flexibility, [.hamstrings, .back], [.calves], .yogaMat, .timed, .stretch, []),
        ("Lizard Pose", "Deep hip flexor and groin stretch", .flexibility, [.hipFlexors, .quads], [.hamstrings], .yogaMat, .timed, .hold, []),
        ("Frog Stretch", "Inner thigh and groin opener", .flexibility, [.quads], [.hipFlexors], .yogaMat, .timed, .stretch, []),
        ("Figure Four Stretch", "Supine glute and piriformis stretch", .flexibility, [.glutes], [.hipFlexors], .yogaMat, .timed, .stretch, []),
        ("Supine Spinal Twist", "Lying rotation for spine mobility", .flexibility, [.back, .core], [], .yogaMat, .timed, .stretch, []),
        ("Thread the Needle", "Thoracic rotation stretch", .flexibility, [.back, .shoulders], [], .yogaMat, .timed, .stretch, []),
        ("Quad Stretch (Standing)", "Standing quadricep stretch", .flexibility, [.quads], [.hipFlexors], .none, .timed, .stretch, []),
        ("Hamstring Stretch (Standing)", "Standing single-leg hamstring stretch", .flexibility, [.hamstrings], [.calves], .none, .timed, .stretch, []),
        ("Hip Flexor Stretch", "Kneeling or standing hip flexor stretch", .flexibility, [.hipFlexors], [.quads], .yogaMat, .timed, .stretch, []),
        ("Chest Stretch (Doorway)", "Pec and anterior shoulder stretch", .flexibility, [.chest, .shoulders], [], .none, .timed, .stretch, []),
        ("Lat Stretch", "Overhead or side bend lat stretch", .flexibility, [.lats], [.core], .none, .timed, .stretch, []),
        ("Tricep Stretch", "Overhead tricep and shoulder stretch", .flexibility, [.triceps, .shoulders], [], .none, .timed, .stretch, []),
        ("Neck Rolls", "Gentle cervical mobility stretch", .flexibility, [.traps], [], .none, .timed, .stretch, []),
        ("Shoulder Circles", "Shoulder joint warm-up mobility", .flexibility, [.shoulders], [], .none, .timed, .stretch, []),
        ("Wrist Circles", "Wrist joint mobility warm-up", .flexibility, [.forearms], [], .none, .timed, .stretch, []),
        ("Ankle Circles", "Ankle joint mobility warm-up", .flexibility, [.calves], [], .none, .timed, .stretch, []),
        ("World's Greatest Stretch", "Multi-joint hip, thoracic, and hamstring opener", .flexibility, [.hipFlexors, .hamstrings, .back], [.core], .none, .timed, .stretch, []),
        ("90/90 Hip Stretch", "Internal and external hip rotation stretch", .flexibility, [.glutes, .hipFlexors], [], .yogaMat, .timed, .stretch, []),
        ("Couch Stretch", "Intense quad and hip flexor stretch", .flexibility, [.quads, .hipFlexors], [], .none, .timed, .stretch, []),

        // =====================================================================
        // MARK: Foam Rolling / Recovery
        // =====================================================================
        ("Foam Roll Quads", "Quad myofascial release", .flexibility, [.quads], [], .foamRoller, .timed, nil, []),
        ("Foam Roll IT Band", "Lateral thigh myofascial release", .flexibility, [.quads], [], .foamRoller, .timed, nil, []),
        ("Foam Roll Hamstrings", "Hamstring myofascial release", .flexibility, [.hamstrings], [], .foamRoller, .timed, nil, []),
        ("Foam Roll Glutes", "Glute myofascial release", .flexibility, [.glutes], [], .foamRoller, .timed, nil, []),
        ("Foam Roll Upper Back", "Thoracic spine myofascial release", .flexibility, [.back], [.rhomboids], .foamRoller, .timed, nil, []),
        ("Foam Roll Calves", "Calf myofascial release", .flexibility, [.calves], [], .foamRoller, .timed, nil, []),
        ("Foam Roll Lats", "Lat myofascial release", .flexibility, [.lats], [], .foamRoller, .timed, nil, []),
        ("Lacrosse Ball Pec Release", "Targeted pec myofascial release", .flexibility, [.chest], [], .lacrosseBall, .timed, nil, []),
        ("Lacrosse Ball Glute Release", "Deep glute trigger point work", .flexibility, [.glutes], [], .lacrosseBall, .timed, nil, []),

        // =====================================================================
        // MARK: Breathwork
        // =====================================================================
        ("Box Breathing", "Inhale, hold, exhale, hold — equal counts", .breathwork, [.core], [], .none, .timed, nil, []),
        ("Diaphragmatic Breathing", "Deep belly breathing for recovery", .breathwork, [.core], [], .none, .timed, nil, []),
        ("4-7-8 Breathing", "Calming breath pattern for cooldown", .breathwork, [.core], [], .none, .timed, nil, []),
        ("Wim Hof Breathing", "Power breathing with retention holds", .breathwork, [.core], [], .none, .timed, nil, []),
    ]
    // swiftlint:enable function_body_length

    /// Save changes to model context
    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving ExerciseStore context: \(error)")
        }
    }
}
