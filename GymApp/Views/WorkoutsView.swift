import SwiftUI
import SwiftData

// MARK: - WorkoutsView

struct WorkoutsView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(\.dsTheme) private var theme

    @State private var selectedCategory: WorkoutCategory? = nil
    @State private var showFavoritesOnly = false
    @State private var searchText = ""
    @State private var showingNewWorkout = false
    @State private var showingAIGenerator = false
    @State private var workoutToStart: Workout?

    var filteredWorkouts: [Workout] {
        let _ = workoutStore.revision

        var workouts: [Workout]
        if showFavoritesOnly {
            workouts = workoutStore.favorites()
        } else if let category = selectedCategory {
            workouts = workoutStore.byCategory(category)
        } else {
            workouts = workoutStore.all()
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            workouts = workouts.filter {
                $0.name.lowercased().contains(query)
            }
        }

        return workouts
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Header
                PageHeaderView(
                    title: "Workouts",
                    buttonLabel: "New",
                    buttonIcon: "plus.circle.fill",
                    onButtonTap: { showingNewWorkout = true },
                    searchText: $searchText,
                    searchPrompt: "Search workouts...",
                    filters: { workoutFilters },
                    secondaryButtonLabel: "AI",
                    secondaryButtonIcon: "sparkles",
                    onSecondaryButtonTap: { showingAIGenerator = true }
                )

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
        .background(theme.background)
        .navigationBarHidden(true)
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
        .fullScreenCover(item: $workoutToStart) { workout in
            NavigationStack {
                ActiveWorkoutView(workout: workout)
            }
        }
    }

    // MARK: - Filters

    @ViewBuilder
    private var workoutFilters: some View {
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

        ForEach([WorkoutCategory.strength, .hiit, .flexibility], id: \.self) { category in
            FilterChip(
                title: category.rawValue.capitalized,
                isSelected: selectedCategory == category
            ) {
                selectedCategory = category
                showFavoritesOnly = false
            }
        }
    }
}

// MARK: - WorkoutCardView

struct WorkoutCardView: View {
    let workout: Workout
    let onStart: () -> Void
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(\.dsTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Button {
                        workoutStore.toggleFavorite(workout)
                    } label: {
                        Image(systemName: workout.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(workout.isFavorite ? theme.warning : theme.textTertiary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)

                    Text(workout.name)
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                HStack(spacing: 8) {
                    let catColor = DSColors.categoryColor(workout.category)
                    Text(workout.category.rawValue.capitalized)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(catColor.opacity(0.2))
                        .foregroundStyle(catColor)
                        .clipShape(Capsule())

                    Text("\(workout.estimatedDurationMinutes) min")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)

                    Text("·")
                        .foregroundStyle(theme.textTertiary)

                    Text(workout.difficulty.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            // Action Buttons
            HStack(spacing: 10) {
                NavigationLink {
                    WorkoutDetailView(workout: workout)
                } label: {
                    Label("Details", systemImage: "info.circle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(theme.secondary.opacity(0.15))
                        .foregroundStyle(theme.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                Button {
                    onStart()
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(theme.primary)
                        .foregroundStyle(theme.textOnPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    let action: () -> Void
    @Environment(\.dsTheme) private var theme

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
            .background(isSelected ? theme.primary : theme.secondary.opacity(0.15))
            .foregroundStyle(isSelected ? theme.textOnPrimary : theme.textPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
