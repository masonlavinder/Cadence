import SwiftUI
import SwiftData
import Charts

// MARK: - HomeView

struct HomeView: View {
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(SessionStore.self) private var sessionStore
    @Environment(ExerciseStore.self) private var exerciseStore
    @Environment(\.dsTheme) private var theme

    @State private var workoutToStart: Workout?
    @State private var showingCoach = false
    @State private var showingNewWorkout = false
    @State private var showingAIGenerator = false
    @State private var suggestions: [WorkoutSuggestion] = []
    @State private var showingNamePrompt = false
    @State private var nameInput = ""

    var body: some View {
        // Track store revisions so the view refreshes after workout completion
        let _ = workoutStore.revision
        let _ = sessionStore.revision

        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xxl) {
                // Header
                header

                // Create Workout Buttons
                createButtons

                // Your Workouts (favorites + recents combined)
                yourWorkoutsSection

                // Get Better At
                if !suggestions.isEmpty {
                    getBetterAtSection
                }

                // Fundamentals
                fundamentalsSection

                // Quick Stats
                statsRow
            }
            .padding(.bottom, 64)
        }
        .background(theme.background)
        .navigationBarHidden(true)
        .fullScreenCover(item: $workoutToStart) { workout in
            NavigationStack {
                ActiveWorkoutView(workout: workout)
            }
        }
        .onAppear {
            if suggestions.isEmpty {
                suggestions = buildSuggestions()
            }
            if !UserDefaults.standard.bool(forKey: "Settings.namePromptShown") {
                showingNamePrompt = true
            }
        }
        .alert("What should we call you?", isPresented: $showingNamePrompt) {
            TextField("Your name", text: $nameInput)
            Button("Let's go") {
                let trimmed = String(nameInput.prefix(100))
                UserDefaults.standard.set(trimmed, forKey: "Settings.userName")
                UserDefaults.standard.set(true, forKey: "Settings.namePromptShown")
            }
            Button("Skip", role: .cancel) {
                UserDefaults.standard.set(true, forKey: "Settings.namePromptShown")
            }
        }
        .sheet(isPresented: $showingNewWorkout) {
            NavigationStack {
                WorkoutEditorView()
            }
        }
        .sheet(isPresented: $showingAIGenerator) {
            NavigationStack {
                AIGeneratorView()
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
                .padding(.trailing, DSSpacing.xl)
                .padding(.bottom, DSSpacing.xl)
            }
        }
    }

    // MARK: - Header

    private var userName: String {
        UserDefaults.standard.string(forKey: "Settings.userName") ?? ""
    }

    private var userInitial: String {
        let name = userName
        if let first = name.first {
            return String(first).uppercased()
        }
        return "?"
    }

    private var header: some View {
        HStack {
            Text("cadence")
                .font(.system(size: 28, weight: .medium, design: .default))
                .tracking(3)
                .textCase(.uppercase)
                .foregroundStyle(theme.primary)

            Spacer()

            NavigationLink {
                SettingsView()
            } label: {
                Text(userInitial)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textOnPrimary)
                    .frame(width: 36, height: 36)
                    .background(theme.primary)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            .buttonStyle(.tactile)
        }
        .padding(.horizontal, DSSpacing.xl)
        .padding(.top, DSSpacing.lg)
    }

    // MARK: - Create Buttons

    private var createButtons: some View {
        HStack(spacing: DSSpacing.md) {
            Button {
                showingNewWorkout = true
            } label: {
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("Build Workout")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.md)
                .background(theme.primary)
                .foregroundStyle(theme.textOnPrimary)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
            }
            .buttonStyle(.tactile)

            Button {
                showingAIGenerator = true
            } label: {
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                    Text("AI Generate")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DSSpacing.md)
                .background(.regularMaterial)
                .foregroundStyle(theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.md)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.tactile)
        }
        .padding(.horizontal, DSSpacing.xl)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        VStack(spacing: DSSpacing.md) {
            HStack {
                DSSectionHeader(title: "Quick Stats")
                Spacer()
                NavigationLink {
                    InsightsView()
                } label: {
                    HStack(spacing: 4) {
                        Text("More Insights")
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .font(DSFont.captionBold.font)
                    .foregroundStyle(theme.primary)
                }
                .buttonStyle(.tactile)
            }

            HStack(spacing: DSSpacing.lg) {
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
        }
        .padding(.horizontal, DSSpacing.xl)
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

    // MARK: - Your Workouts (favorites + recents combined)

    private var yourWorkoutsSection: some View {
        let favs = workoutStore.favorites()
        let recent = workoutStore.recentlyCompleted(limit: 5)
        // Combine: favorites first, then recents not already in favorites
        let favIDs = Set(favs.map(\.id))
        let combined = favs + recent.filter { !favIDs.contains($0.id) }

        return VStack(alignment: .leading, spacing: DSSpacing.md) {
            HStack {
                DSSectionHeader(title: "Your Workouts")
                Spacer()
                NavigationLink {
                    WorkoutsTabView()
                } label: {
                    HStack(spacing: 4) {
                        Text("All Workouts")
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .font(DSFont.captionBold.font)
                    .foregroundStyle(theme.primary)
                }
                .buttonStyle(.tactile)
            }
            .padding(.horizontal, DSSpacing.xl)

            if combined.isEmpty {
                DSEmptyState(
                    icon: "dumbbell",
                    title: "No Workouts Yet",
                    message: "Start a workout and it will show up here"
                )
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSSpacing.lg) {
                        ForEach(combined) { workout in
                            workoutCard(workout)
                        }
                    }
                    .padding(.horizontal, DSSpacing.xl)
                }
            }
        }
    }

    private func workoutCard(_ workout: Workout) -> some View {
        NavigationLink {
            WorkoutDetailView(workout: workout)
        } label: {
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
                .buttonStyle(.tactile)
            }
            .frame(width: 200)
            .dsCard(padding: DSSpacing.md)
        }
        .buttonStyle(.tactile)
    }

    // MARK: - Insights Section

    private var insightsSection: some View {
        let weeklyCounts = sessionStore.weeklySessionCounts(weeks: 8)
        let breakdown = sessionStore.categoryBreakdown()
        let hasWeekly = weeklyCounts.contains(where: { $0.count > 0 })

        return VStack(spacing: DSSpacing.xl) {
            if hasWeekly {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    Text("Weekly Activity")
                        .font(DSFont.headline.font)
                        .foregroundStyle(theme.textPrimary)

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
                    .frame(height: 180)
                }
                .dsGlassCard(padding: DSSpacing.lg)
                .padding(.horizontal, DSSpacing.lg)
            }

            if !breakdown.isEmpty {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    Text("Categories")
                        .font(DSFont.headline.font)
                        .foregroundStyle(theme.textPrimary)

                    Chart(breakdown, id: \.category) { item in
                        BarMark(
                            x: .value("Count", item.count),
                            y: .value("Category", item.category.rawValue.capitalized)
                        )
                        .foregroundStyle(DSColors.categoryColor(item.category))
                        .cornerRadius(DSRadius.sm / 2)
                    }
                    .chartXAxis {
                        AxisMarks { _ in
                            AxisGridLine()
                                .foregroundStyle(theme.border)
                            AxisValueLabel()
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .chartYAxis {
                        AxisMarks { _ in
                            AxisValueLabel()
                                .foregroundStyle(theme.textPrimary)
                        }
                    }
                    .frame(height: CGFloat(breakdown.count) * 40 + 20)
                }
                .dsGlassCard(padding: DSSpacing.lg)
                .padding(.horizontal, DSSpacing.lg)
            }
        }
    }

    // MARK: - Get Better At

    private var getBetterAtSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            DSSectionHeader(title: "Get Better At")
                .padding(.horizontal, DSSpacing.xl)

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
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(suggestion.color.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.tactile)
                    }
                }
                .padding(.horizontal, DSSpacing.xl)
            }
        }
    }

    // MARK: - Fundamentals

    private var fundamentalPatterns: [(pattern: MovementPattern, title: String, subtitle: String, icon: String)] {
        [
            (.push, "Push", "Chest, shoulders, triceps", "arrow.up.right"),
            (.pull, "Pull", "Back, biceps, rear delts", "arrow.down.left"),
            (.squat, "Squat", "Quads, glutes, core", "arrow.down"),
            (.hinge, "Hinge", "Hamstrings, glutes, back", "arrow.up.and.down"),
            (.carry, "Carry & Core", "Core, grip, stability", "figure.walk"),
        ]
    }

    private func fundamentalExercises(for pattern: MovementPattern) -> [Exercise] {
        exerciseStore.all().filter { $0.tags.contains("fundamental") && $0.movementPattern == pattern }
    }

    private var fundamentalsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            DSSectionHeader(title: "Fundamentals")
                .padding(.horizontal, DSSpacing.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.lg) {
                    ForEach(fundamentalPatterns, id: \.pattern) { item in
                        let exercises = fundamentalExercises(for: item.pattern)
                        NavigationLink {
                            ExerciseSuggestionList(
                                title: item.title,
                                exercises: exercises
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                                Image(systemName: item.icon)
                                    .font(.title3)
                                    .foregroundStyle(theme.primary)

                                Text(item.title)
                                    .font(DSFont.bodyBold.font)
                                    .foregroundStyle(theme.textPrimary)

                                Text(item.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(theme.textSecondary)

                                Text("\(exercises.count) exercises")
                                    .font(.caption2)
                                    .foregroundStyle(theme.textTertiary)
                            }
                            .frame(width: 160, height: 120, alignment: .leading)
                            .dsCard(padding: DSSpacing.md)
                        }
                        .buttonStyle(.tactile)
                    }
                }
                .padding(.horizontal, DSSpacing.xl)
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

        for muscle in sortedMuscles.prefix(5) {
            if results.count >= 9 { break }
            results.append(WorkoutSuggestion(
                title: muscle.rawValue.capitalized,
                icon: "figure.strengthtraining.traditional",
                color: theme.primary,
                kind: .muscle(muscle)
            ))
        }

        return Array(results.shuffled().prefix(7))
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
                            .buttonStyle(.tactile)

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
