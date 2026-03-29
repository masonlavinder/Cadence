import SwiftUI
import SwiftData

// MARK: - ExerciseCreatorView

struct ExerciseCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ExerciseStore.self) private var exerciseStore

    // Core
    @State private var name = ""
    @State private var exerciseDescription = ""
    @State private var instructions = ""
    @State private var exerciseType: ExerciseType = .strength
    @State private var equipment: Equipment = .none
    @State private var movementPattern: MovementPattern? = nil

    // Muscles
    @State private var primaryMuscleGroups: Set<MuscleGroup> = []
    @State private var secondaryMuscleGroups: Set<MuscleGroup> = []

    // Defaults
    @State private var defaultBlockType: BlockType = .repBased
    @State private var defaultSets: Int = 3
    @State private var defaultRepCount: Int = 10
    @State private var defaultDurationSeconds: Int = 45
    @State private var defaultHoldSeconds: Int = 30
    @State private var defaultRestBetweenSets: Int = 60
    @State private var defaultRestAfter: Int = 90

    // Optional editing support
    let existingExercise: Exercise?

    init(exercise: Exercise? = nil) {
        self.existingExercise = exercise

        if let e = exercise {
            _name = State(initialValue: e.name)
            _exerciseDescription = State(initialValue: e.exerciseDescription)
            _instructions = State(initialValue: e.instructions)
            _exerciseType = State(initialValue: e.exerciseType)
            _equipment = State(initialValue: e.equipment)
            _movementPattern = State(initialValue: e.movementPattern)
            _primaryMuscleGroups = State(initialValue: Set(e.primaryMuscleGroups))
            _secondaryMuscleGroups = State(initialValue: Set(e.secondaryMuscleGroups))
            _defaultBlockType = State(initialValue: e.defaultBlockType)
            _defaultSets = State(initialValue: e.defaultSets)
            _defaultRepCount = State(initialValue: e.defaultRepCount ?? 10)
            _defaultDurationSeconds = State(initialValue: e.defaultDurationSeconds ?? 45)
            _defaultHoldSeconds = State(initialValue: e.defaultHoldSeconds ?? 30)
            _defaultRestBetweenSets = State(initialValue: e.defaultRestBetweenSetsSeconds)
            _defaultRestAfter = State(initialValue: e.defaultRestAfterSeconds)
        }
    }

    var body: some View {
        Form {
            // MARK: Basic Info
            Section("Basic Info") {
                TextField("Movement Name", text: $name)
                    .font(.headline)

                TextField("Description (optional)", text: $exerciseDescription, axis: .vertical)
                    .lineLimit(2...4)

                Picker("Type", selection: $exerciseType) {
                    ForEach(ExerciseType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }

                Picker("Equipment", selection: $equipment) {
                    ForEach(Equipment.allCases, id: \.self) { equip in
                        Text(equip.rawValue.capitalized).tag(equip)
                    }
                }

                Picker("Movement Pattern", selection: $movementPattern) {
                    Text("None").tag(MovementPattern?.none)
                    ForEach(MovementPattern.allCases, id: \.self) { pattern in
                        Text(pattern.rawValue.capitalized).tag(MovementPattern?.some(pattern))
                    }
                }
            }

            // MARK: Primary Muscles
            Section("Primary Muscle Groups") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        MuscleToggleChip(
                            label: muscle.rawValue,
                            isSelected: primaryMuscleGroups.contains(muscle)
                        ) {
                            toggleMuscle(muscle, in: &primaryMuscleGroups)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // MARK: Secondary Muscles
            Section("Secondary Muscle Groups") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                    ForEach(MuscleGroup.allCases, id: \.self) { muscle in
                        MuscleToggleChip(
                            label: muscle.rawValue,
                            isSelected: secondaryMuscleGroups.contains(muscle)
                        ) {
                            toggleMuscle(muscle, in: &secondaryMuscleGroups)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            // MARK: Default Configuration
            Section("Default Configuration") {
                Picker("Block Type", selection: $defaultBlockType) {
                    Text("Rep-Based").tag(BlockType.repBased)
                    Text("Timed").tag(BlockType.timed)
                    Text("Hold (Untimed)").tag(BlockType.untimed)
                    Text("Distance").tag(BlockType.distance)
                }

                Stepper("Sets: \(defaultSets)", value: $defaultSets, in: 1...20)

                switch defaultBlockType {
                case .repBased:
                    Stepper("Reps: \(defaultRepCount)", value: $defaultRepCount, in: 1...100)
                case .timed:
                    Stepper("Duration: \(defaultDurationSeconds)s", value: $defaultDurationSeconds, in: 5...600, step: 5)
                case .untimed:
                    Stepper("Hold: \(defaultHoldSeconds)s", value: $defaultHoldSeconds, in: 5...300, step: 5)
                case .distance:
                    EmptyView()
                }
            }

            // MARK: Rest Times
            Section("Rest Times") {
                Stepper("Between sets: \(defaultRestBetweenSets)s", value: $defaultRestBetweenSets, in: 0...300, step: 5)
                Stepper("After exercise: \(defaultRestAfter)s", value: $defaultRestAfter, in: 0...300, step: 5)
            }

            // MARK: Instructions
            Section("Instructions") {
                TextField("Step-by-step instructions (optional)", text: $instructions, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
        .navigationTitle(existingExercise == nil ? "New Movement" : "Edit Movement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(existingExercise == nil ? "Create" : "Save") {
                    save()
                    dismiss()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Helpers

    private func toggleMuscle(_ muscle: MuscleGroup, in set: inout Set<MuscleGroup>) {
        if set.contains(muscle) {
            set.remove(muscle)
        } else {
            set.insert(muscle)
        }
    }

    private func save() {
        if let existing = existingExercise {
            existing.name = name
            existing.exerciseDescription = exerciseDescription
            existing.instructions = instructions
            existing.exerciseType = exerciseType
            existing.equipment = equipment
            existing.movementPattern = movementPattern
            existing.primaryMuscleGroups = Array(primaryMuscleGroups)
            existing.secondaryMuscleGroups = Array(secondaryMuscleGroups)
            existing.defaultBlockType = defaultBlockType
            existing.defaultSets = defaultSets
            existing.defaultRepCount = defaultBlockType == .repBased ? defaultRepCount : nil
            existing.defaultDurationSeconds = defaultBlockType == .timed ? defaultDurationSeconds : nil
            existing.defaultHoldSeconds = defaultBlockType == .untimed ? defaultHoldSeconds : nil
            existing.defaultRestBetweenSetsSeconds = defaultRestBetweenSets
            existing.defaultRestAfterSeconds = defaultRestAfter
            exerciseStore.update(existing)
        } else {
            let exercise = Exercise(
                name: name,
                description: exerciseDescription,
                instructions: instructions,
                exerciseType: exerciseType,
                primaryMuscleGroups: Array(primaryMuscleGroups),
                secondaryMuscleGroups: Array(secondaryMuscleGroups),
                equipment: equipment,
                movementPattern: movementPattern,
                defaultBlockType: defaultBlockType,
                defaultSets: defaultSets,
                defaultRepCount: defaultBlockType == .repBased ? defaultRepCount : nil,
                defaultDurationSeconds: defaultBlockType == .timed ? defaultDurationSeconds : nil,
                defaultRestBetweenSetsSeconds: defaultRestBetweenSets,
                defaultRestAfterSeconds: defaultRestAfter,
                defaultHoldSeconds: defaultBlockType == .untimed ? defaultHoldSeconds : nil
            )
            exerciseStore.create(exercise)
        }
    }
}

// MARK: - MuscleToggleChip

struct MuscleToggleChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.dsTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(isSelected ? theme.primary : theme.secondary.opacity(0.15))
                .foregroundStyle(isSelected ? theme.textOnPrimary : theme.textPrimary)
                .clipShape(Capsule())
        }
        .buttonStyle(.tactile)
    }
}

#Preview("New Exercise") {
    NavigationStack {
        ExerciseCreatorView()
    }
    .modelContainer(for: [Exercise.self], inMemory: true)
    .environment(ExerciseStore(modelContext:
        try! ModelContainer(for: Exercise.self).mainContext))
}
