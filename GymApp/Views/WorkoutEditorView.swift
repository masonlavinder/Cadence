import SwiftUI
import SwiftData

// MARK: - WorkoutEditorView

struct WorkoutEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutStore.self) private var workoutStore
    
    // For editing existing workouts
    let workout: Workout?
    
    // State for workout creation/editing
    @State private var name: String
    @State private var workoutDescription: String
    @State private var category: WorkoutCategory
    @State private var difficulty: Difficulty
    @State private var targetMuscleGroups: [MuscleGroup]
    @State private var requiredEquipment: [Equipment]
    
    // For new workouts that need to be created first
    @State private var createdWorkout: Workout?
    
    // UI State
    @State private var showingExercisePicker = false
    @State private var editingEntry: WorkoutEntry?
    @State private var showingEntryEditor = false
    
    init(workout: Workout?) {
        self.workout = workout
        
        // Initialize state from existing workout or defaults
        _name = State(initialValue: workout?.name ?? "")
        _workoutDescription = State(initialValue: workout?.workoutDescription ?? "")
        _category = State(initialValue: workout?.category ?? .strength)
        _difficulty = State(initialValue: workout?.difficulty ?? .intermediate)
        _targetMuscleGroups = State(initialValue: workout?.targetMuscleGroups ?? [])
        _requiredEquipment = State(initialValue: workout?.requiredEquipment ?? [])
    }
    
    // The active workout being edited (either existing or newly created)
    private var activeWorkout: Workout? {
        workout ?? createdWorkout
    }
    
    var body: some View {
        List {
            // Basic Info Section
            Section("Workout Details") {
                TextField("Workout Name", text: $name)
                    .font(.headline)
                
                TextField("Description (optional)", text: $workoutDescription, axis: .vertical)
                    .lineLimit(3...6)
                
                Picker("Category", selection: $category) {
                    ForEach(WorkoutCategory.allCases, id: \.self) { cat in
                        Text(cat.rawValue.capitalized).tag(cat)
                    }
                }
                
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { diff in
                        Text(diff.rawValue.capitalized).tag(diff)
                    }
                }
            }
            
            // Target Muscle Groups
            Section("Target Muscle Groups") {
                if targetMuscleGroups.isEmpty {
                    Text("No muscle groups selected")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(MuscleGroup.allCases.prefix(12), id: \.self) { muscle in
                        MuscleChip(
                            muscle: muscle,
                            isSelected: targetMuscleGroups.contains(muscle)
                        ) {
                            if targetMuscleGroups.contains(muscle) {
                                targetMuscleGroups.removeAll { $0 == muscle }
                            } else {
                                targetMuscleGroups.append(muscle)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            
            // Required Equipment
            Section("Required Equipment") {
                if requiredEquipment.isEmpty {
                    Text("No equipment required")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach([Equipment.none, .barbell, .dumbbell, .kettlebell, .resistanceBand, .yogaMat, .pullupBar, .benchPress], id: \.self) { equip in
                        EquipmentChip(
                            equipment: equip,
                            isSelected: requiredEquipment.contains(equip)
                        ) {
                            if requiredEquipment.contains(equip) {
                                requiredEquipment.removeAll { $0 == equip }
                            } else {
                                requiredEquipment.append(equip)
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            
            // Exercises Section
            Section {
                if let activeWorkout = activeWorkout, !activeWorkout.entries.isEmpty {
                    ForEach(activeWorkout.entries.sorted(by: { $0.orderIndex < $1.orderIndex })) { entry in
                        EntryEditorRow(entry: entry) {
                            editingEntry = entry
                            showingEntryEditor = true
                        }
                    }
                    .onDelete { indexSet in
                        deleteEntries(at: indexSet)
                    }
                    .onMove { source, destination in
                        if let activeWorkout = activeWorkout {
                            workoutStore.moveEntry(in: activeWorkout, from: source, to: destination)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Exercises",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Add exercises to build your workout")
                    )
                }
            } header: {
                HStack {
                    Text("Exercises")
                    Spacer()
                    Button {
                        ensureWorkoutExists()
                        showingExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle(workout == nil ? "New Workout" : "Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveWorkout()
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
            
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingExercisePicker) {
            NavigationStack {
                ExercisePickerView { exercise in
                    addExercise(exercise)
                }
            }
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                EntryEditorSheet(entry: entry) {
                    showingEntryEditor = false
                    editingEntry = nil
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func ensureWorkoutExists() {
        // If creating a new workout, create it immediately when first exercise is added
        if workout == nil && createdWorkout == nil {
            let newWorkout = Workout(
                name: name.isEmpty ? "Untitled Workout" : name,
                description: workoutDescription,
                category: category,
                difficulty: difficulty,
                targetMuscleGroups: targetMuscleGroups,
                requiredEquipment: requiredEquipment
            )
            workoutStore.create(newWorkout)
            createdWorkout = newWorkout
        }
    }
    
    private func saveWorkout() {
        if let workout = workout {
            // Update existing workout
            workout.name = name
            workout.workoutDescription = workoutDescription
            workout.category = category
            workout.difficulty = difficulty
            workout.targetMuscleGroups = targetMuscleGroups
            workout.requiredEquipment = requiredEquipment
            workoutStore.update(workout)
            workoutStore.recalculateDuration(workout)
        } else if let createdWorkout = createdWorkout {
            // Update the created workout with latest values
            createdWorkout.name = name
            createdWorkout.workoutDescription = workoutDescription
            createdWorkout.category = category
            createdWorkout.difficulty = difficulty
            createdWorkout.targetMuscleGroups = targetMuscleGroups
            createdWorkout.requiredEquipment = requiredEquipment
            workoutStore.update(createdWorkout)
            workoutStore.recalculateDuration(createdWorkout)
        } else {
            // Create new workout (only if no exercises were added)
            let newWorkout = Workout(
                name: name.isEmpty ? "Untitled Workout" : name,
                description: workoutDescription,
                category: category,
                difficulty: difficulty,
                targetMuscleGroups: targetMuscleGroups,
                requiredEquipment: requiredEquipment
            )
            workoutStore.create(newWorkout)
        }
    }
    
    private func addExercise(_ exercise: Exercise) {
        ensureWorkoutExists()
        
        if let activeWorkout = activeWorkout {
            workoutStore.addExercise(exercise, to: activeWorkout)
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        guard let activeWorkout = activeWorkout else { return }
        
        let sortedEntries = activeWorkout.entries.sorted(by: { $0.orderIndex < $1.orderIndex })
        for index in offsets {
            let entry = sortedEntries[index]
            workoutStore.removeEntry(entry, from: activeWorkout)
        }
    }
}

// MARK: - EntryEditorRow

struct EntryEditorRow: View {
    let entry: WorkoutEntry
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Order indicator
                Text("\(entry.orderIndex + 1)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.exerciseName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        // Configuration
                        Text(entry.displayConfiguration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // Rest times
                        if entry.restBetweenSetsSeconds > 0 {
                            Text("• \(entry.restBetweenSetsSeconds)s rest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Notes preview
                    if let notes = entry.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Duration estimate
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(entry.totalEstimatedSeconds / 60)m")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ExercisePickerView

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ExerciseStore.self) private var exerciseStore
    
    @State private var searchText = ""
    @State private var selectedType: ExerciseType?
    @State private var selectedEquipment: Equipment?
    
    let onSelect: (Exercise) -> Void
    
    var filteredExercises: [Exercise] {
        var exercises = exerciseStore.all()
        
        if let type = selectedType {
            exercises = exercises.filter { $0.exerciseType == type }
        }
        
        if let equipment = selectedEquipment {
            exercises = exercises.filter { $0.equipment == equipment }
        }
        
        if !searchText.isEmpty {
            exercises = exerciseStore.search(query: searchText)
        }
        
        return exercises
    }
    
    var body: some View {
        List {
            // Filters
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Menu {
                            Button("All Types") { selectedType = nil }
                            ForEach(ExerciseType.allCases, id: \.self) { type in
                                Button(type.rawValue.capitalized) {
                                    selectedType = type
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.caption2)
                                Text(selectedType?.rawValue.capitalized ?? "Type")
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedType != nil ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(selectedType != nil ? .white : .primary)
                            .clipShape(Capsule())
                        }
                        
                        Menu {
                            Button("All Equipment") { selectedEquipment = nil }
                            ForEach(Equipment.allCases, id: \.self) { equipment in
                                Button(equipment.rawValue.capitalized) {
                                    selectedEquipment = equipment
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "dumbbell")
                                    .font(.caption2)
                                Text(selectedEquipment?.rawValue.capitalized ?? "Equipment")
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedEquipment != nil ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(selectedEquipment != nil ? .white : .primary)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Exercise List
            Section {
                ForEach(filteredExercises) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        ExercisePickerRow(exercise: exercise)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .overlay {
            if filteredExercises.isEmpty {
                ContentUnavailableView.search
            }
        }
    }
}

// MARK: - ExercisePickerRow

struct ExercisePickerRow: View {
    let exercise: Exercise
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on type
            Image(systemName: iconForExerciseType(exercise.exerciseType))
                .font(.title3)
                .foregroundStyle(colorForExerciseType(exercise.exerciseType))
                .frame(width: 40, height: 40)
                .background(colorForExerciseType(exercise.exerciseType).opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    // Equipment
                    HStack(spacing: 2) {
                        Image(systemName: "dumbbell")
                            .font(.caption2)
                        Text(exercise.equipment.rawValue)
                            .font(.caption)
                    }
                    
                    // Primary muscles
                    if let muscle = exercise.primaryMuscleGroups.first {
                        Text("• \(muscle.rawValue)")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.accentColor)
        }
    }
    
    private func iconForExerciseType(_ type: ExerciseType) -> String {
        switch type {
        case .strength: return "dumbbell.fill"
        case .cardio: return "figure.run"
        case .flexibility: return "figure.cooldown"
        case .balance: return "figure.mind.and.body"
        case .plyometrics: return "figure.jumprope"
        case .yoga: return "figure.yoga"
        case .pilates: return "figure.pilates"
        case .calisthenics: return "figure.strengthtraining.traditional"
        case .sport: return "sportscourt"
        case .rehabilitation: return "heart.text.square"
        }
    }
    
    private func colorForExerciseType(_ type: ExerciseType) -> Color {
        switch type {
        case .strength: return .blue
        case .cardio: return .red
        case .flexibility: return .green
        case .balance: return .purple
        case .plyometrics: return .orange
        case .yoga: return .pink
        case .pilates: return .teal
        case .calisthenics: return .cyan
        case .sport: return .indigo
        case .rehabilitation: return .mint
        }
    }
}

// MARK: - EntryEditorSheet

struct EntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: WorkoutEntry
    let onSave: () -> Void
    
    @State private var sets: Int
    @State private var targetReps: Int
    @State private var durationSeconds: Int
    @State private var restBetweenSets: Int
    @State private var restAfterExercise: Int
    @State private var notes: String
    
    init(entry: WorkoutEntry, onSave: @escaping () -> Void) {
        self.entry = entry
        self.onSave = onSave
        
        _sets = State(initialValue: entry.sets)
        _targetReps = State(initialValue: entry.targetReps ?? 10)
        _durationSeconds = State(initialValue: entry.durationSeconds ?? 45)
        _restBetweenSets = State(initialValue: entry.restBetweenSetsSeconds)
        _restAfterExercise = State(initialValue: entry.restAfterExerciseSeconds)
        _notes = State(initialValue: entry.notes ?? "")
    }
    
    var body: some View {
        Form {
            Section("Exercise") {
                Text(entry.exerciseName)
                    .font(.headline)
            }
            
            Section("Configuration") {
                Stepper("Sets: \(sets)", value: $sets, in: 1...20)
                
                if entry.blockType == .repBased {
                    Stepper("Reps: \(targetReps)", value: $targetReps, in: 1...100)
                } else if entry.blockType == .timed {
                    Stepper("Duration: \(durationSeconds)s", value: $durationSeconds, in: 5...300, step: 5)
                }
            }
            
            Section("Rest Times") {
                Stepper("Between sets: \(restBetweenSets)s", value: $restBetweenSets, in: 0...300, step: 5)
                Stepper("After exercise: \(restAfterExercise)s", value: $restAfterExercise, in: 0...300, step: 5)
            }
            
            Section("Notes") {
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("Edit Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveChanges()
                    onSave()
                    dismiss()
                }
            }
        }
    }
    
    private func saveChanges() {
        entry.sets = sets
        entry.targetReps = targetReps
        entry.durationSeconds = durationSeconds
        entry.restBetweenSetsSeconds = restBetweenSets
        entry.restAfterExerciseSeconds = restAfterExercise
        entry.notes = notes.isEmpty ? nil : notes
    }
}

#Preview("New Workout") {
    NavigationStack {
        WorkoutEditorView(workout: nil)
    }
    .modelContainer(for: [Workout.self, Exercise.self], inMemory: true)
}

