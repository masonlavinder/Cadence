import SwiftUI
import SwiftData

// MARK: - WorkoutsTabView

struct WorkoutsTabView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(ExerciseStore.self) private var exerciseStore
    @Environment(\.dsTheme) private var theme

    enum Segment: String, CaseIterable {
        case library = "Workouts"
        case movements = "Movements"
    }

    @State private var segment: Segment = .library

    // Library state
    @State private var librarySearch = ""
    @State private var selectedCategory: WorkoutCategory? = nil
    @State private var showFavoritesOnly = false
    @State private var showRecentOnly = false
    @State private var showingNewWorkout = false
    @State private var showingAIGenerator = false
    @State private var workoutToStart: Workout?

    // Movements state
    @State private var movementsSearch = ""
    @State private var selectedType: ExerciseType? = nil
    @State private var selectedEquipment: Equipment? = nil
    @State private var showMovementFavorites = false
    @State private var selectedTag: String? = nil
    @State private var showingNewExercise = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                header
                segmentedControl

                switch segment {
                case .library:
                    libraryContent
                case .movements:
                    movementsContent
                }
            }
        }
        .background(theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
        }
        .sheet(isPresented: $showingNewWorkout) {
            NavigationStack {
                WorkoutEditorView(workout: nil)
            }
        }
        .sheet(isPresented: $showingAIGenerator) {
            NavigationStack {
                AIGeneratorView()
            }
        }
        .sheet(isPresented: $showingNewExercise) {
            NavigationStack {
                ExerciseCreatorView()
            }
        }
        .fullScreenCover(item: $workoutToStart) { workout in
            NavigationStack {
                ActiveWorkoutView(workout: workout)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("cadence")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .tracking(4)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.primary)
                    Text("Workouts")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.textPrimary)
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        if segment == .library {
                            showingNewWorkout = true
                        } else {
                            showingNewExercise = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(theme.primary)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.tactile)

                    if segment == .library {
                        Button {
                            showingAIGenerator = true
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .foregroundStyle(theme.primary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.tactile)
                    }
                }
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
                TextField(
                    segment == .library ? "Search workouts..." : "Search movements...",
                    text: segment == .library ? $librarySearch : $movementsSearch
                )
                let activeSearch = segment == .library ? librarySearch : movementsSearch
                if !activeSearch.isEmpty {
                    Button {
                        if segment == .library {
                            librarySearch = ""
                        } else {
                            movementsSearch = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.textSecondary)
                    }
                    .buttonStyle(.tactile)
                }
            }
            .padding(10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        Picker("", selection: $segment) {
            ForEach(Segment.allCases, id: \.self) { seg in
                Text(seg.rawValue).tag(seg)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Library Content

    private var filteredWorkouts: [Workout] {
        let _ = workoutStore.revision

        var workouts: [Workout]
        if showRecentOnly {
            workouts = workoutStore.recentlyCompleted(limit: 20)
        } else if showFavoritesOnly {
            workouts = workoutStore.favorites()
        } else if let category = selectedCategory {
            workouts = workoutStore.byCategory(category)
        } else {
            workouts = workoutStore.all()
        }

        if !librarySearch.isEmpty {
            let query = librarySearch.lowercased()
            workouts = workouts.filter {
                $0.name.lowercased().contains(query)
            }
        }

        return workouts
    }

    private var libraryContent: some View {
        VStack(spacing: 0) {
            // Filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedCategory == nil && !showFavoritesOnly && !showRecentOnly
                    ) {
                        selectedCategory = nil
                        showFavoritesOnly = false
                        showRecentOnly = false
                    }

                    FilterChip(
                        title: "Recent",
                        isSelected: showRecentOnly,
                        icon: "clock"
                    ) {
                        showRecentOnly.toggle()
                        if showRecentOnly {
                            showFavoritesOnly = false
                            selectedCategory = nil
                        }
                    }

                    FilterChip(
                        title: "Favorites",
                        isSelected: showFavoritesOnly,
                        icon: "star.fill"
                    ) {
                        showFavoritesOnly.toggle()
                        if showFavoritesOnly {
                            showRecentOnly = false
                            selectedCategory = nil
                        }
                    }

                    ForEach([WorkoutCategory.strength, .hiit, .flexibility], id: \.self) { category in
                        FilterChip(
                            title: category.rawValue.capitalized,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                            showFavoritesOnly = false
                            showRecentOnly = false
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            // Cards
            if filteredWorkouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts",
                    systemImage: "dumbbell",
                    description: Text("Create a workout or generate one with AI")
                )
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredWorkouts) { workout in
                        WorkoutCardView(workout: workout) {
                            workoutToStart = workout
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .contextMenu {
                            Button {
                                _ = workoutStore.duplicate(workout)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }

                            Button {
                                workoutStore.toggleFavorite(workout)
                            } label: {
                                Label(
                                    workout.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: workout.isFavorite ? "star.slash.fill" : "star.fill"
                                )
                            }

                            Button(role: .destructive) {
                                workoutStore.delete(workout)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Movements Content

    private var filteredExercises: [Exercise] {
        var exercises: [Exercise]

        if showMovementFavorites {
            exercises = exerciseStore.favorites()
        } else {
            exercises = exerciseStore.all()
        }

        if let type = selectedType {
            exercises = exercises.filter { $0.exerciseType == type }
        }

        if let equipment = selectedEquipment {
            exercises = exercises.filter { $0.equipment == equipment }
        }

        if let tag = selectedTag {
            exercises = exercises.filter { $0.tags.contains(tag) }
        }

        if !movementsSearch.isEmpty {
            let query = movementsSearch.lowercased()
            exercises = exercises.filter {
                $0.name.lowercased().contains(query) ||
                $0.primaryMuscleGroups.contains { $0.rawValue.lowercased().contains(query) }
            }
        }

        return exercises
    }

    private var movementsContent: some View {
        VStack(spacing: 0) {
            // Filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "Favorites",
                        isSelected: showMovementFavorites,
                        icon: "star.fill"
                    ) {
                        showMovementFavorites.toggle()
                    }

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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedType != nil ? theme.primary : theme.secondary.opacity(0.15))
                        .foregroundStyle(selectedType != nil ? theme.textOnPrimary : theme.textPrimary)
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedEquipment != nil ? theme.primary : theme.secondary.opacity(0.15))
                        .foregroundStyle(selectedEquipment != nil ? theme.textOnPrimary : theme.textPrimary)
                        .clipShape(Capsule())
                    }

                    FilterChip(
                        title: "Beginner",
                        isSelected: selectedTag == "beginner"
                    ) {
                        selectedTag = selectedTag == "beginner" ? nil : "beginner"
                    }

                    FilterChip(
                        title: "Fundamental",
                        isSelected: selectedTag == "fundamental"
                    ) {
                        selectedTag = selectedTag == "fundamental" ? nil : "fundamental"
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)

            // Exercise List
            if filteredExercises.isEmpty {
                ContentUnavailableView(
                    movementsSearch.isEmpty ? "No Movements" : "No Results",
                    systemImage: "figure.strengthtraining.traditional",
                    description: Text(movementsSearch.isEmpty ? "Add movements to your catalog" : "Try a different search")
                )
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filteredExercises) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                        } label: {
                            ExerciseRow(exercise: exercise)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.tactile)

                        if exercise.id != filteredExercises.last?.id {
                            Divider()
                                .padding(.leading, 68)
                        }
                    }
                }
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }
}
