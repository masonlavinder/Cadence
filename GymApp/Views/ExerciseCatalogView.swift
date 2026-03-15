import SwiftUI
import SwiftData

// MARK: - ExerciseCatalogView

struct ExerciseCatalogView: View {
    @Environment(ExerciseStore.self) private var exerciseStore
    
    @State private var searchText = ""
    @State private var selectedType: ExerciseType? = nil
    @State private var selectedEquipment: Equipment? = nil
    @State private var showFavoritesOnly = false
    @State private var showingNewExercise = false
    
    var filteredExercises: [Exercise] {
        var exercises: [Exercise]
        
        if showFavoritesOnly {
            exercises = exerciseStore.favorites()
        } else {
            exercises = exerciseStore.all()
        }
        
        // Apply type filter
        if let type = selectedType {
            exercises = exercises.filter { $0.exerciseType == type }
        }
        
        // Apply equipment filter
        if let equipment = selectedEquipment {
            exercises = exercises.filter { $0.equipment == equipment }
        }
        
        // Apply search
        if !searchText.isEmpty {
            exercises = exerciseStore.search(query: searchText)
        }
        
        return exercises
    }
    
    var body: some View {
        List {
            // Quick Filters
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "Favorites",
                            isSelected: showFavoritesOnly,
                            icon: "star.fill"
                        ) {
                            showFavoritesOnly.toggle()
                        }
                        
                        Menu {
                            Button("All Types") {
                                selectedType = nil
                            }
                            
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
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedType != nil ? Color.accentColor : Color.secondary.opacity(0.1))
                            .foregroundStyle(selectedType != nil ? .white : .primary)
                            .clipShape(Capsule())
                        }
                        
                        Menu {
                            Button("All Equipment") {
                                selectedEquipment = nil
                            }
                            
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
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
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
            
            // Exercises
            Section {
                ForEach(filteredExercises) { exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            exerciseStore.toggleFavorite(exercise)
                        } label: {
                            Label(
                                exercise.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: exercise.isFavorite ? "star.slash" : "star"
                            )
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises...")
        .navigationTitle("Exercises")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewExercise = true
                } label: {
                    Label("New Exercise", systemImage: "plus")
                }
            }
        }
        .overlay {
            if filteredExercises.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Exercises" : "No Results",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text(searchText.isEmpty ? "Add exercises to your catalog" : "Try a different search")
                )
            }
        }
        .sheet(isPresented: $showingNewExercise) {
            NavigationStack {
                ExerciseCreatorView()
            }
        }
    }
}

// MARK: - ExerciseRow

struct ExerciseRow: View {
    let exercise: Exercise
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon based on type
            Image(systemName: iconForType(exercise.exerciseType))
                .font(.title2)
                .foregroundStyle(colorForType(exercise.exerciseType))
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(exercise.name)
                        .font(.headline)
                    
                    if exercise.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                
                HStack(spacing: 8) {
                    // Type badge
                    Text(exercise.exerciseType.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colorForType(exercise.exerciseType).opacity(0.2))
                        .foregroundStyle(colorForType(exercise.exerciseType))
                        .clipShape(Capsule())
                    
                    // Equipment
                    if exercise.equipment != .none {
                        HStack(spacing: 2) {
                            Image(systemName: "dumbbell")
                            Text(exercise.equipment.rawValue)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                
                // Primary muscles
                if !exercise.primaryMuscleGroups.isEmpty {
                    Text(exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func iconForType(_ type: ExerciseType) -> String {
        switch type {
        case .strength: return "figure.strengthtraining.traditional"
        case .cardio: return "figure.run"
        case .flexibility: return "figure.yoga"
        case .balance: return "figure.ballet"
        case .plyometric: return "figure.jumprope"
        case .isometric: return "figure.core.training"
        case .pose: return "figure.mind.and.body"
        case .interval: return "timer"
        case .distance: return "ruler"
        case .breathwork: return "lungs"
        }
    }
    
    private func colorForType(_ type: ExerciseType) -> Color {
        switch type {
        case .strength: return .blue
        case .cardio: return .orange
        case .flexibility, .pose: return .purple
        case .balance: return .green
        case .plyometric: return .red
        case .isometric: return .cyan
        case .interval: return .pink
        case .distance: return .yellow
        case .breathwork: return .mint
        }
    }
}

// MARK: - ExerciseDetailView

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(ExerciseStore.self) private var exerciseStore
    @State private var showingEditor = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(exercise.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button {
                            exerciseStore.toggleFavorite(exercise)
                        } label: {
                            Image(systemName: exercise.isFavorite ? "star.fill" : "star")
                                .foregroundStyle(.orange)
                                .font(.title3)
                        }
                    }
                    
                    if !exercise.exerciseDescription.isEmpty {
                        Text(exercise.exerciseDescription)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section("Details") {
                LabeledContent("Type", value: exercise.exerciseType.rawValue.capitalized)
                LabeledContent("Equipment", value: exercise.equipment.rawValue.capitalized)
                
                if !exercise.primaryMuscleGroups.isEmpty {
                    LabeledContent("Primary Muscles") {
                        Text(exercise.primaryMuscleGroups.map { $0.rawValue }.joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Default Configuration") {
                LabeledContent("Sets", value: "\(exercise.defaultSets)")
                
                switch exercise.defaultBlockType {
                case .repBased:
                    if let reps = exercise.defaultRepCount {
                        LabeledContent("Reps", value: "\(reps)")
                    }
                case .timed:
                    if let duration = exercise.defaultDurationSeconds {
                        LabeledContent("Duration", value: "\(duration)s")
                    }
                case .untimed:
                    if let hold = exercise.defaultHoldSeconds {
                        LabeledContent("Hold", value: "\(hold)s")
                    }
                case .distance:
                    LabeledContent("Type", value: "Distance-based")
                }
            }
            
            if !exercise.instructions.isEmpty {
                Section("Instructions") {
                    Text(exercise.instructions)
                }
            }
        }
        .navigationTitle("Exercise Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                ExerciseCreatorView(exercise: exercise)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseCatalogView()
    }
    .modelContainer(for: [Exercise.self], inMemory: true)
    .environment(ExerciseStore(modelContext: 
        try! ModelContainer(for: Exercise.self).mainContext))
}
