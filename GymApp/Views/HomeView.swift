import SwiftUI
import SwiftData
import Charts

// MARK: - HomeView

struct HomeView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(SessionStore.self) private var sessionStore
    @Environment(ExerciseStore.self) private var exerciseStore
    @Environment(\.dsTheme) private var theme

    @Binding var selectedTab: AppTab
    @State private var workoutToStart: Workout?
    @State private var showingCoach = false
    @State private var discoveries: [Exercise] = []
    @State private var suggestions: [WorkoutSuggestion] = []

    var body: some View {
        // Track store revisions so the view refreshes after workout completion
        let _ = workoutStore.revision
        let _ = sessionStore.revision

        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // Header
                header

                // Quick Stats
                statsRow

                // Favorites (horizontal scroll)
                let favs = workoutStore.favorites()
                if !favs.isEmpty {
                    favoritesSection(favs)
                }

                // Recent Workouts
                recentSection

                // Mini Weekly Chart
                let weeklyCounts = sessionStore.weeklySessionCounts(weeks: 4)
                if weeklyCounts.contains(where: { $0.count > 0 }) {
                    miniWeeklyChart(weeklyCounts)
                }

                // Get Better At
                if !suggestions.isEmpty {
                    getBetterAtSection
                }

                // Discover Movements
                if !discoveries.isEmpty {
                    discoverSection(discoveries)
                }
            }
            .padding(.bottom, DSSpacing.xxxl)
        }
        .background(theme.background)
        .navigationBarHidden(true)
        .fullScreenCover(item: $workoutToStart) { workout in
            NavigationStack {
                ActiveWorkoutView(workout: workout)
            }
        }
        .onAppear {
            if discoveries.isEmpty {
                discoveries = Array(exerciseStore.leastUsed(limit: 20).shuffled().prefix(5))
            }
            if suggestions.isEmpty {
                suggestions = buildSuggestions()
            }
        }
        .sheet(isPresented: $showingCoach) {
            NavigationStack {
                ChatView()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if FeatureFlags.coachTab {
                Button {
                    showingCoach = true
                } label: {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.title2)
                        .foregroundStyle(theme.textOnPrimary)
                        .frame(width: 56, height: 56)
                        .background(theme.primary)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                .padding(.trailing, DSSpacing.lg)
                .padding(.bottom, DSSpacing.lg)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("cadence")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .tracking(4)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.primary)
                Text("Home")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(theme.textPrimary)
            }

            Spacer()

            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(theme.primary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.sm)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: DSSpacing.md) {
            statCard(
                title: "Streak",
                value: "\(sessionStore.currentStreak())d",
                icon: "bolt.fill"
            )
            statCard(
                title: "Workouts",
                value: "\(sessionStore.totalCompletedCount())",
                icon: "flame.fill"
            )
            statCard(
                title: "Time",
                value: sessionStore.totalWorkoutTimeFormatted(),
                icon: "clock.fill"
            )
        }
        .padding(.horizontal, DSSpacing.lg)
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(theme.primary)

            Text(value)
                .font(DSFont.headline.font)
                .foregroundStyle(theme.textPrimary)

            Text(title)
                .font(DSFont.caption2.font)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlassCard(padding: DSSpacing.md)
    }

    // MARK: - Favorites

    private func favoritesSection(_ favorites: [Workout]) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSectionHeader(title: "Favorites", actionTitle: "See All") {
                selectedTab = .workouts
            }
            .padding(.horizontal, DSSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.md) {
                    ForEach(favorites) { workout in
                        workoutCard(workout)
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
            }
        }
    }

    private func workoutCard(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(workout.name)
                .font(DSFont.bodyBold.font)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            HStack(spacing: DSSpacing.xs) {
                let catColor = DSColors.categoryColor(workout.category)
                Text(workout.category.rawValue.capitalized)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(catColor.opacity(0.2))
                    .foregroundStyle(catColor)
                    .clipShape(Capsule())

                Text("\(workout.estimatedDurationMinutes) min")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }

            Button {
                workoutToStart = workout
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(theme.primary)
                    .foregroundStyle(theme.textOnPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .frame(width: 160)
        .dsCard(padding: DSSpacing.md)
    }

    // MARK: - Recent Workouts

    private var recentSection: some View {
        let recent = workoutStore.recentlyCompleted(limit: 5)

        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSectionHeader(title: "Recent", actionTitle: "See All") {
                selectedTab = .workouts
            }
            .padding(.horizontal, DSSpacing.lg)

            if recent.isEmpty {
                DSEmptyState(
                    icon: "dumbbell",
                    title: "No Workouts Yet",
                    message: "Start a workout and it will show up here"
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSSpacing.md) {
                        ForEach(recent) { workout in
                            workoutCard(workout)
                        }
                    }
                    .padding(.horizontal, DSSpacing.lg)
                }
            }
        }
    }

    // MARK: - Mini Weekly Chart

    private func miniWeeklyChart(_ weeklyCounts: [(weekStart: Date, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            DSSectionHeader(title: "This Month", actionTitle: "Details") {
                selectedTab = .insights
            }

            Chart(weeklyCounts, id: \.weekStart) { item in
                BarMark(
                    x: .value("Week", item.weekStart, unit: .weekOfYear),
                    y: .value("Sessions", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.primary, theme.primary.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(DSRadius.sm / 2)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(theme.border)
                    AxisValueLabel()
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .frame(height: 120)
        }
        .dsGlassCard(padding: DSSpacing.lg)
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - Get Better At

    private var getBetterAtSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSectionHeader(title: "Get Better At")
                .padding(.horizontal, DSSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.sm) {
                    ForEach(suggestions) { suggestion in
                        NavigationLink {
                            suggestionDestination(suggestion)
                        } label: {
                            HStack(spacing: DSSpacing.sm) {
                                Image(systemName: suggestion.icon)
                                    .font(.caption)
                                    .foregroundStyle(suggestion.color)

                                Text(suggestion.title)
                                    .font(DSFont.caption.font)
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, DSSpacing.md)
                            .padding(.vertical, DSSpacing.sm)
                            .background(suggestion.color.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
            }
        }
    }

    @ViewBuilder
    private func suggestionDestination(_ suggestion: WorkoutSuggestion) -> some View {
        switch suggestion.kind {
        case .muscle(let muscle):
            ExerciseSuggestionList(
                title: suggestion.title,
                exercises: exerciseStore.byMuscleGroup(muscle)
            )
        case .category(let category):
            ExerciseSuggestionList(
                title: suggestion.title,
                exercises: exerciseStore.all().filter {
                    switch category {
                    case .flexibility: return $0.exerciseType == .flexibility || $0.exerciseType == .pose
                    case .hiit: return $0.exerciseType == .interval || $0.exerciseType == .plyometric || $0.exerciseType == .cardio
                    case .strength: return $0.exerciseType == .strength || $0.exerciseType == .isometric
                    default: return true
                    }
                }
            )
        }
    }

    // MARK: - Suggestion Builder

    private func buildSuggestions() -> [WorkoutSuggestion] {
        var results: [WorkoutSuggestion] = []

        // 1. Find underused categories
        let breakdown = sessionStore.categoryBreakdown()
        let usedCategories = Set(breakdown.map(\.category))
        let focusCategories: [WorkoutCategory] = [.strength, .hiit, .flexibility, .yoga]

        for cat in focusCategories where !usedCategories.contains(cat) {
            results.append(WorkoutSuggestion(
                title: cat.rawValue.capitalized,
                icon: iconForCategory(cat),
                color: DSColors.categoryColor(cat),
                kind: .category(cat)
            ))
        }

        // Also suggest categories with low counts relative to the most-done one
        if let topCount = breakdown.first?.count, topCount > 2 {
            for item in breakdown where item.count <= topCount / 3 {
                if focusCategories.contains(item.category) &&
                   !results.contains(where: { if case .category(let c) = $0.kind { return c == item.category } else { return false } }) {
                    results.append(WorkoutSuggestion(
                        title: item.category.rawValue.capitalized,
                        icon: iconForCategory(item.category),
                        color: DSColors.categoryColor(item.category),
                        kind: .category(item.category)
                    ))
                }
            }
        }

        // 2. Find neglected muscle groups
        let allExercises = exerciseStore.all()
        var muscleUsage: [MuscleGroup: Int] = [:]
        for exercise in allExercises {
            for muscle in exercise.primaryMuscleGroups {
                muscleUsage[muscle, default: 0] += exercise.timesUsed
            }
        }

        let interestingMuscles: [MuscleGroup] = [
            .back, .shoulders, .glutes, .hamstrings, .core,
            .chest, .biceps, .triceps, .quads, .calves, .hipFlexors
        ]

        let sortedMuscles = interestingMuscles.sorted { (muscleUsage[$0] ?? 0) < (muscleUsage[$1] ?? 0) }

        for muscle in sortedMuscles.prefix(4) {
            if results.count >= 6 { break }
            results.append(WorkoutSuggestion(
                title: muscle.rawValue.capitalized,
                icon: "figure.strengthtraining.traditional",
                color: theme.primary,
                kind: .muscle(muscle)
            ))
        }

        return Array(results.shuffled().prefix(5))
    }

    private func iconForCategory(_ category: WorkoutCategory) -> String {
        switch category {
        case .strength: return "dumbbell.fill"
        case .hiit: return "bolt.heart.fill"
        case .flexibility: return "figure.cooldown"
        case .yoga: return "figure.yoga"
        case .cardio: return "figure.run"
        case .calisthenics: return "figure.strengthtraining.functional"
        case .crossfit: return "figure.cross.training"
        case .custom: return "star.fill"
        }
    }

    // MARK: - Discover Movements

    private func discoverSection(_ exercises: [Exercise]) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSSectionHeader(title: "Try Something New")
                .padding(.horizontal, DSSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.sm) {
                    ForEach(exercises) { exercise in
                        NavigationLink {
                            ExerciseDetailView(exercise: exercise)
                        } label: {
                            HStack(spacing: DSSpacing.sm) {
                                Image(systemName: iconForType(exercise.exerciseType))
                                    .font(.caption)
                                    .foregroundStyle(DSColors.exerciseTypeColor(exercise.exerciseType))

                                Text(exercise.name)
                                    .font(DSFont.caption.font)
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, DSSpacing.md)
                            .padding(.vertical, DSSpacing.sm)
                            .background(theme.surfaceElevated)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
            }
        }
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
}

// MARK: - AppTab

enum AppTab: Hashable {
    case home, workouts, insights
}

// MARK: - WorkoutSuggestion

struct WorkoutSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let kind: Kind

    enum Kind {
        case muscle(MuscleGroup)
        case category(WorkoutCategory)
    }
}

// MARK: - ExerciseSuggestionList

struct ExerciseSuggestionList: View {
    let title: String
    let exercises: [Exercise]
    @Environment(\.dsTheme) private var theme

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if exercises.isEmpty {
                    ContentUnavailableView(
                        "No Movements",
                        systemImage: "figure.strengthtraining.traditional",
                        description: Text("No movements found for this area")
                    )
                    .padding(.top, 60)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(exercises) { exercise in
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                ExerciseRow(exercise: exercise)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)

                            if exercise.id != exercises.last?.id {
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
        .background(theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
