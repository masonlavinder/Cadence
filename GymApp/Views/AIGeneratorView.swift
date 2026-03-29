import SwiftUI
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - AIGeneratorView

struct AIGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(ExerciseStore.self) private var exerciseStore
    @Environment(\.dsTheme) private var theme

    @State private var category: WorkoutCategory = .strength
    @State private var selectedMuscles: Set<MuscleGroup> = []
    @State private var duration: Double = 30
    @State private var difficulty: Difficulty = .intermediate
    @State private var selectedEquipment: Set<Equipment> = []
    @State private var additionalNotes: String = ""

    // AI state
    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var modelAvailability: ModelAvailability = .checking

    #if canImport(FoundationModels)
    private let model = SystemLanguageModel.default
    #endif

    enum ModelAvailability: Equatable {
        case checking
        case available
        case unavailableUsingLocal(String)
    }

    private var isModelAvailable: Bool {
        // Always return true - we'll use local generation as fallback
        return true
    }

    var body: some View {
        Form {
            Section {
                Text("AI Workout Generator")
                    .font(.title2)
                    .fontWeight(.bold)

                switch modelAvailability {
                case .checking:
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking AI availability...")
                            .foregroundStyle(theme.textSecondary)
                    }
                case .available:
                    Text("Generate a personalized workout using on-device AI")
                        .foregroundStyle(theme.textSecondary)
                case .unavailableUsingLocal(let reason):
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Using Smart Generator", systemImage: "brain")
                            .foregroundStyle(theme.primary)
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            if modelAvailability != .checking {
                Section("Configuration") {
                    Picker("Category", selection: $category) {
                        ForEach(WorkoutCategory.allCases.filter { $0 != .custom }, id: \.self) { cat in
                            Text(cat.rawValue.capitalized)
                        }
                    }

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { diff in
                            Text(diff.rawValue.capitalized)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Duration: \(formattedDuration)")
                        Slider(value: $duration, in: 5...240, step: 5)
                            .tint(theme.primary)
                    }
                }

                Section("Muscle Groups") {
                    Text("Select target muscles")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(MuscleGroup.allCases.prefix(10), id: \.self) { muscle in
                            MuscleChip(
                                muscle: muscle,
                                isSelected: selectedMuscles.contains(muscle)
                            ) {
                                if selectedMuscles.contains(muscle) {
                                    selectedMuscles.remove(muscle)
                                } else {
                                    selectedMuscles.insert(muscle)
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Equipment") {
                    Text("Available equipment")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach([Equipment.none, .barbell, .dumbbell, .kettlebell, .resistanceBand, .yogaMat], id: \.self) { equip in
                            EquipmentChip(
                                equipment: equip,
                                isSelected: selectedEquipment.contains(equip)
                            ) {
                                if selectedEquipment.contains(equip) {
                                    selectedEquipment.remove(equip)
                                } else {
                                    selectedEquipment.insert(equip)
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Additional Notes") {
                    TextField("Any special requests or injuries to avoid?", text: $additionalNotes, axis: .vertical)
                        .lineLimit(3...5)
                }

                if let error = generationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(theme.destructive)
                    }
                }
            }
        }
        .navigationTitle("Generate Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isGenerating)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(isGenerating ? "Generating..." : "Generate") {
                    Task {
                        await generateWorkout()
                    }
                }
                .disabled(isGenerating || !isModelAvailable)
            }
        }
        .task {
            checkModelAvailability()
        }
    }

    // MARK: - AI Generation

    private var formattedDuration: String {
        let mins = Int(duration)
        if mins < 60 {
            return "\(mins) minutes"
        }
        let hours = mins / 60
        let remainder = mins % 60
        if remainder == 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
        return "\(hours) hour\(hours == 1 ? "" : "s") and \(remainder) minutes"
    }

    private func checkModelAvailability() {
        #if canImport(FoundationModels)
        switch model.availability {
        case .available:
            modelAvailability = .available
            return
        default:
            break
        }
        #endif

        // Fallback to local generation
        modelAvailability = .unavailableUsingLocal("Using intelligent workout builder based on fitness science")
    }

    private func generateWorkout() async {
        isGenerating = true
        generationError = nil

        do {
            #if canImport(FoundationModels)
            // Try Apple Intelligence first
            if case .available = modelAvailability {
                do {
                    try await generateWithAppleIntelligence()
                    dismiss()
                    return
                } catch {
                    // Apple Intelligence failed — fall back to local generation
                    print("Apple Intelligence generation failed: \(error). Falling back to local generator.")
                }
            }
            #endif

            // Use local rule-based generation
            try await generateWithLocalAlgorithm()
            dismiss()
        } catch {
            generationError = "Failed to generate workout: \(error.localizedDescription)"
            isGenerating = false
        }
    }

    #if canImport(FoundationModels)
    private func generateWithAppleIntelligence() async throws {
        let instructions = createAIInstructions()
        let session = LanguageModelSession(instructions: instructions)

        let prompt = createPrompt()
        let response = try await session.respond(to: prompt, generating: WorkoutPlan.self)

        createWorkoutFromAIPlan(response.content)
    }

    private func createAIInstructions() -> String {
        """
        You are a professional fitness trainer and workout planner.
        Your task is to create personalized workout plans based on user preferences.

        Guidelines:
        - Create workouts that match the user's fitness level
        - Select exercises that target the specified muscle groups
        - Consider available equipment limitations
        - Ensure proper exercise progression and rest periods
        - Keep workouts within the specified duration
        - Provide brief, practical instructions
        - Be safety-conscious and recommend proper form

        Respond with a structured workout plan in the requested format.
        """
    }

    private func createPrompt() -> String {
        var prompt = """
        Create a \(difficulty.rawValue) level \(category.rawValue) workout that is approximately \(Int(duration)) minutes long.
        """

        if !selectedMuscles.isEmpty {
            let muscleList = selectedMuscles.map { $0.rawValue }.joined(separator: ", ")
            prompt += "\nTarget these muscle groups: \(muscleList)"
        }

        if !selectedEquipment.isEmpty {
            let equipmentList = selectedEquipment.map { $0.rawValue }.joined(separator: ", ")
            prompt += "\nUse only this available equipment: \(equipmentList)"
        } else {
            prompt += "\nNo equipment is available - use bodyweight exercises only."
        }

        if !additionalNotes.isEmpty {
            prompt += "\nAdditional notes: \(additionalNotes)"
        }

        prompt += "\n\nProvide a structured workout plan with exercise names, sets, reps (or duration), and rest periods."

        return prompt
    }
    #endif

    // MARK: - Local Workout Generation

    private func generateWithLocalAlgorithm() async throws {
        // Simulate a brief delay to make it feel natural
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        let generator = LocalWorkoutGenerator(
            category: category,
            difficulty: difficulty,
            duration: Int(duration),
            targetMuscles: Array(selectedMuscles),
            availableEquipment: Array(selectedEquipment),
            exerciseStore: exerciseStore
        )

        let plan = generator.generate()
        createWorkoutFromLocalPlan(plan)
    }

    #if canImport(FoundationModels)
    private func createWorkoutFromAIPlan(_ plan: WorkoutPlan) {
        // Create the workout
        let workout = Workout(
            name: plan.name,
            description: plan.description,
            category: category,
            difficulty: difficulty,
            targetMuscleGroups: Array(selectedMuscles),
            requiredEquipment: Array(selectedEquipment)
        )

        // Add to store
        workoutStore.create(workout)

        // Get all available exercises for matching
        let availableExercises = exerciseStore.all()

        // Add exercises from the plan
        for aiExercise in plan.exercises {
            // Try to find matching exercise in database
            let matchedExercise = findMatchingExercise(
                for: aiExercise.name,
                in: availableExercises
            )

            if let exercise = matchedExercise {
                // Add the exercise to the workout
                workoutStore.addExercise(exercise, to: workout)

                // Get the entry that was just created
                if let entry = workout.entries.first(where: { $0.exerciseName == exercise.name }) {
                    // Update with AI-generated configuration
                    entry.sets = aiExercise.sets
                    entry.targetReps = aiExercise.reps
                    entry.durationSeconds = aiExercise.durationSeconds
                    entry.restBetweenSetsSeconds = aiExercise.restSeconds
                    entry.notes = aiExercise.notes
                }
            }
        }

        // Recalculate total duration
        workoutStore.recalculateDuration(workout)
    }
    #endif

    private func createWorkoutFromLocalPlan(_ plan: LocalWorkoutPlan) {
        // Create the workout
        let workout = Workout(
            name: plan.name,
            description: plan.description,
            category: category,
            difficulty: difficulty,
            targetMuscleGroups: Array(selectedMuscles),
            requiredEquipment: Array(selectedEquipment)
        )

        // Add to store
        workoutStore.create(workout)

        // Add exercises from the plan
        for exerciseConfig in plan.exercises {
            workoutStore.addExercise(exerciseConfig.exercise, to: workout)

            // Get the entry that was just created
            if let entry = workout.entries.first(where: { $0.exerciseName == exerciseConfig.exercise.name }) {
                // Update with generated configuration
                entry.sets = exerciseConfig.sets
                entry.targetReps = exerciseConfig.reps
                entry.durationSeconds = exerciseConfig.durationSeconds
                entry.restBetweenSetsSeconds = exerciseConfig.restBetweenSets
                entry.restAfterExerciseSeconds = exerciseConfig.restAfterExercise
                entry.notes = exerciseConfig.notes
            }
        }

        // Recalculate total duration
        workoutStore.recalculateDuration(workout)
    }

    private func findMatchingExercise(for name: String, in exercises: [Exercise]) -> Exercise? {
        let normalizedName = name.lowercased().trimmingCharacters(in: .whitespaces)

        // Try exact match first
        if let exact = exercises.first(where: { $0.name.lowercased() == normalizedName }) {
            return exact
        }

        // Try partial match
        if let partial = exercises.first(where: { $0.name.lowercased().contains(normalizedName) || normalizedName.contains($0.name.lowercased()) }) {
            return partial
        }

        // If no match, create a basic exercise (you could enhance this)
        return exercises.first // Fallback to any exercise for now
    }
}

// MARK: - Local Workout Generator

struct LocalWorkoutPlan {
    var name: String
    var description: String
    var exercises: [LocalExerciseConfig]
}

struct LocalExerciseConfig {
    var exercise: Exercise
    var sets: Int
    var reps: Int?
    var durationSeconds: Int?
    var restBetweenSets: Int
    var restAfterExercise: Int
    var notes: String?
}

class LocalWorkoutGenerator {
    let category: WorkoutCategory
    let difficulty: Difficulty
    let duration: Int
    let targetMuscles: [MuscleGroup]
    let availableEquipment: [Equipment]
    let exerciseStore: ExerciseStore

    init(category: WorkoutCategory, difficulty: Difficulty, duration: Int,
         targetMuscles: [MuscleGroup], availableEquipment: [Equipment],
         exerciseStore: ExerciseStore) {
        self.category = category
        self.difficulty = difficulty
        self.duration = duration
        self.targetMuscles = targetMuscles
        self.availableEquipment = availableEquipment
        self.exerciseStore = exerciseStore
    }

    func generate() -> LocalWorkoutPlan {
        // Get all available exercises
        var allExercises = exerciseStore.all()

        // Filter by equipment
        if !availableEquipment.isEmpty && !availableEquipment.contains(.none) {
            allExercises = allExercises.filter { exercise in
                availableEquipment.contains(exercise.equipment)
            }
        } else if availableEquipment.contains(.none) {
            // Only bodyweight exercises
            allExercises = allExercises.filter { $0.equipment == .none }
        }

        // Filter by target muscles if specified
        var filteredExercises = allExercises
        if !targetMuscles.isEmpty {
            filteredExercises = allExercises.filter { exercise in
                !Set(exercise.primaryMuscleGroups).isDisjoint(with: targetMuscles) ||
                !Set(exercise.secondaryMuscleGroups).isDisjoint(with: targetMuscles)
            }
        }

        // If filtering by muscles resulted in too few exercises, use all
        if filteredExercises.count < 5 {
            filteredExercises = allExercises
        }

        // Calculate exercise count based on duration
        let exerciseCount = calculateExerciseCount(duration: duration)

        // Select diverse exercises
        let selectedExercises = selectDiverseExercises(
            from: filteredExercises,
            count: exerciseCount
        )

        // Create exercise configurations
        let exerciseConfigs = selectedExercises.map { exercise in
            createExerciseConfig(for: exercise)
        }

        // Generate workout name and description
        let name = generateWorkoutName()
        let description = generateWorkoutDescription()

        return LocalWorkoutPlan(
            name: name,
            description: description,
            exercises: exerciseConfigs
        )
    }

    private func calculateExerciseCount(duration: Int) -> Int {
        // Estimate 5-7 minutes per exercise including rest
        switch duration {
        case 0..<20: return 4
        case 20..<35: return 6
        case 35..<50: return 8
        case 50..<70: return 10
        default: return 12
        }
    }

    private func selectDiverseExercises(from exercises: [Exercise], count: Int) -> [Exercise] {
        guard !exercises.isEmpty else { return [] }

        var selected: [Exercise] = []
        var remaining = exercises
        var usedMuscleGroups: Set<MuscleGroup> = []

        // Try to select exercises with diverse muscle groups
        while selected.count < count && !remaining.isEmpty {
            // Prefer exercises that target new muscle groups
            let prioritized = remaining.sorted { ex1, ex2 in
                let ex1NewMuscles = Set(ex1.primaryMuscleGroups).subtracting(usedMuscleGroups).count
                let ex2NewMuscles = Set(ex2.primaryMuscleGroups).subtracting(usedMuscleGroups).count
                return ex1NewMuscles > ex2NewMuscles
            }

            if let next = prioritized.first {
                selected.append(next)
                usedMuscleGroups.formUnion(next.primaryMuscleGroups)
                remaining.removeAll { $0.id == next.id }
            } else {
                break
            }
        }

        return selected
    }

    private func createExerciseConfig(for exercise: Exercise) -> LocalExerciseConfig {
        // Determine sets based on difficulty
        let sets: Int
        switch difficulty {
        case .beginner: sets = 3
        case .intermediate: sets = 4
        case .advanced: sets = 5
        case .brutal: sets = 6
        }

        // Determine reps/duration based on exercise type and difficulty
        var reps: Int?
        var durationSeconds: Int?
        var notes: String?

        switch exercise.exerciseType {
        case .strength:
            switch difficulty {
            case .beginner: reps = 10
            case .intermediate: reps = 12
            case .advanced: reps = 15
            case .brutal: reps = 20
            }
            notes = "Focus on form over speed"

        case .cardio, .plyometric:
            durationSeconds = difficulty == .beginner ? 30 : difficulty == .intermediate ? 45 : 60
            notes = "Maintain consistent pace"

        case .flexibility, .pose:
            durationSeconds = difficulty == .beginner ? 30 : difficulty == .intermediate ? 45 : 60
            notes = "Breathe deeply and hold the position"

        case .isometric:
            durationSeconds = difficulty == .beginner ? 20 : difficulty == .intermediate ? 30 : 45
            notes = "Hold position with good form"

        case .interval:
            durationSeconds = 30
            notes = "Alternate between high and low intensity"

        default:
            reps = 12
        }

        // Rest periods based on difficulty
        let restBetween: Int
        let restAfter: Int

        switch difficulty {
        case .beginner:
            restBetween = 90
            restAfter = 120
        case .intermediate:
            restBetween = 60
            restAfter = 90
        case .advanced:
            restBetween = 45
            restAfter = 60
        case .brutal:
            restBetween = 30
            restAfter = 45
        }

        return LocalExerciseConfig(
            exercise: exercise,
            sets: sets,
            reps: reps,
            durationSeconds: durationSeconds,
            restBetweenSets: restBetween,
            restAfterExercise: restAfter,
            notes: notes
        )
    }

    private func generateWorkoutName() -> String {
        let difficultyPrefix = difficulty.rawValue.capitalized
        let categoryName = category.rawValue.capitalized

        if !targetMuscles.isEmpty {
            let muscleText = targetMuscles.first?.rawValue.capitalized ?? "Full Body"
            return "\(difficultyPrefix) \(muscleText) \(categoryName)"
        } else {
            return "\(difficultyPrefix) \(categoryName)"
        }
    }

    private func generateWorkoutDescription() -> String {
        var description = "A \(difficulty.rawValue) level \(category.rawValue) workout"

        if !targetMuscles.isEmpty {
            let muscleList = targetMuscles.prefix(3).map { $0.rawValue }.joined(separator: ", ")
            description += " targeting \(muscleList)"
        }

        if !availableEquipment.isEmpty && !availableEquipment.contains(.none) {
            let equipList = availableEquipment.prefix(2).map { $0.rawValue }.joined(separator: ", ")
            description += " using \(equipList)"
        } else if availableEquipment.contains(.none) {
            description += " using bodyweight exercises"
        }

        description += ". Designed to be completed in approximately \(duration) minutes."

        return description
    }
}

// MARK: - AI Response Models (Apple Intelligence Only)

#if canImport(FoundationModels)
@Generable(description: "A complete workout plan with exercises")
struct WorkoutPlan {
    @Guide(description: "Name of the workout (e.g., 'Full Body Strength')")
    var name: String

    @Guide(description: "Brief description of the workout and its benefits")
    var description: String

    @Guide(description: "List of exercises in the workout", .count(5...12))
    var exercises: [WorkoutExercise]
}

@Generable(description: "A single exercise in a workout plan")
struct WorkoutExercise {
    @Guide(description: "Name of the exercise (e.g., 'Push-ups', 'Squats')")
    var name: String

    @Guide(description: "Number of sets to perform", .range(1...5))
    var sets: Int

    @Guide(description: "Number of repetitions per set (use 0 if time-based)", .range(0...50))
    var reps: Int?

    @Guide(description: "Duration in seconds if time-based (use 0 if rep-based)", .range(0...300))
    var durationSeconds: Int?

    @Guide(description: "Rest time between sets in seconds", .range(30...180))
    var restSeconds: Int

    @Guide(description: "Brief notes about form or modifications")
    var notes: String?
}
#endif

// MARK: - MuscleChip

struct MuscleChip: View {
    let muscle: MuscleGroup
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.dsTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(muscle.rawValue)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? theme.primary : theme.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? theme.textOnPrimary : theme.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EquipmentChip

struct EquipmentChip: View {
    let equipment: Equipment
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.dsTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "dumbbell")
                    .font(.caption2)
                Text(equipment.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? theme.primary : theme.secondary.opacity(0.15))
            .foregroundStyle(isSelected ? theme.textOnPrimary : theme.textPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AIGeneratorView()
    }
}
