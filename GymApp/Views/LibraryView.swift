import SwiftUI
import SwiftData

// MARK: - LibraryView

struct LibraryView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    
    @State private var selectedCategory: WorkoutCategory? = nil
    @State private var showFavoritesOnly = false
    @State private var showingNewWorkout = false
    @State private var showingAIGenerator = false
    
    var filteredWorkouts: [Workout] {
        var workouts: [Workout]
        
        if showFavoritesOnly {
            workouts = workoutStore.favorites()
        } else if let category = selectedCategory {
            workouts = workoutStore.byCategory(category)
        } else {
            workouts = workoutStore.all()
        }
        
        return workouts
    }
    
    var body: some View {
        List {
            // Filter Section
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        FilterChip(
                            title: "All",
                            isSelected: selectedCategory == nil && !showFavoritesOnly
                        ) {
                            selectedCategory = nil
                            showFavoritesOnly = false
                        }
                        
                        FilterChip(
                            title: "Favorites",
                            isSelected: showFavoritesOnly,
                            icon: "star.fill"
                        ) {
                            showFavoritesOnly.toggle()
                            if showFavoritesOnly {
                                selectedCategory = nil
                            }
                        }
                        
                        ForEach(WorkoutCategory.allCases, id: \.self) { category in
                            FilterChip(
                                title: category.rawValue.capitalized,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                                showFavoritesOnly = false
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Workouts Section
            Section {
                ForEach(filteredWorkouts) { workout in
                    NavigationLink {
                        WorkoutEditorView(workout: workout)
                    } label: {
                        WorkoutCardView(workout: workout)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            workoutStore.delete(workout)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            workoutStore.toggleFavorite(workout)
                        } label: {
                            Label(
                                workout.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: workout.isFavorite ? "star.slash" : "star"
                            )
                        }
                        .tint(.orange)
                    }
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
                    }
                }
            }
        }
        .navigationTitle("Workouts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingNewWorkout = true
                    } label: {
                        Label("New Workout", systemImage: "plus.circle")
                    }
                    
                    Button {
                        showingAIGenerator = true
                    } label: {
                        Label("Generate with AI", systemImage: "sparkles")
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .overlay {
            if filteredWorkouts.isEmpty {
                ContentUnavailableView(
                    "No Workouts",
                    systemImage: "list.bullet.rectangle.portrait",
                    description: Text("Create a workout or generate one with AI")
                )
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
    }
}

// MARK: - WorkoutCardView

struct WorkoutCardView: View {
    let workout: Workout
    @Environment(WorkoutStore.self) private var workoutStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.name)
                    .font(.headline)
                
                Spacer()
                
                if workout.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
            
            HStack(spacing: 12) {
                // Category Badge
                Text(workout.category.rawValue.capitalized)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor(workout.category).opacity(0.2))
                    .foregroundStyle(categoryColor(workout.category))
                    .clipShape(Capsule())
                
                // Difficulty
                Text(workout.difficulty.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                // Duration
                Image(systemName: "clock")
                    .font(.caption2)
                Text("\(workout.estimatedDurationMinutes) min")
                    .font(.caption2)
                
                Spacer()
            }
            .foregroundStyle(.secondary)
            
            // Muscle Groups
            if !workout.targetMuscleGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(workout.targetMuscleGroups.prefix(5), id: \.self) { muscle in
                            Text(muscle.rawValue)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func categoryColor(_ category: WorkoutCategory) -> Color {
        switch category {
        case .strength: return .blue
        case .hiit: return .red
        case .cardio: return .orange
        case .yoga: return .purple
        case .flexibility: return .green
        case .calisthenics: return .cyan
        case .crossfit: return .pink
        case .custom: return .gray
        }
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        LibraryView()
    }
    .modelContainer(for: [Workout.self], inMemory: true)
    .environment(WorkoutStore(modelContext: 
        try! ModelContainer(for: Workout.self).mainContext))
}
