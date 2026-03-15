import SwiftUI
import SwiftData
import Charts

// MARK: - InsightsView

struct InsightsView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dsTheme) private var theme

    var body: some View {
        let completed = sessionStore.completedSessions()
        let hasData = !completed.isEmpty

        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                // Wordmark + title
                VStack(alignment: .leading, spacing: 2) {
                    Text("cadence")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .tracking(4)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.primary)
                    Text("Insights")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.textPrimary)
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.sm)

                // Stats summary 2x2 grid
                statsGrid

                if hasData {
                    // Weekly activity chart
                    weeklyActivityChart

                    // Category breakdown chart
                    let breakdown = sessionStore.categoryBreakdown()
                    if !breakdown.isEmpty {
                        categoryBreakdownChart(breakdown)
                    }
                }

                // Recent sessions
                recentSessionsList(completed)
            }
            .padding(.bottom, DSSpacing.xxl)
        }
        .background(theme.background)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let columns = [
            GridItem(.flexible(), spacing: DSSpacing.md),
            GridItem(.flexible(), spacing: DSSpacing.md)
        ]

        return LazyVGrid(columns: columns, spacing: DSSpacing.md) {
            statCard(
                title: "Total Workouts",
                value: "\(sessionStore.totalCompletedCount())",
                icon: "flame.fill"
            )
            statCard(
                title: "Total Time",
                value: sessionStore.totalWorkoutTimeFormatted(),
                icon: "clock.fill"
            )
            statCard(
                title: "Avg Completion",
                value: sessionStore.totalCompletedCount() > 0
                    ? "\(Int(sessionStore.averageCompletionRate() * 100))%"
                    : "--",
                icon: "checkmark.circle.fill"
            )
            statCard(
                title: "Current Streak",
                value: "\(sessionStore.currentStreak()) days",
                icon: "bolt.fill"
            )
        }
        .padding(.horizontal, DSSpacing.lg)
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(DSColors.primary)

            Text(value)
                .font(DSFont.title2.font)
                .foregroundStyle(DSColors.textPrimary)

            Text(title)
                .font(DSFont.caption.font)
                .foregroundStyle(DSColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlassCard()
    }

    // MARK: - Weekly Activity Chart

    private var weeklyActivityChart: some View {
        let weeklyCounts = sessionStore.weeklySessionCounts()

        return VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Weekly Activity")
                .font(DSFont.headline.font)
                .foregroundStyle(DSColors.textPrimary)

            Chart(weeklyCounts, id: \.weekStart) { item in
                BarMark(
                    x: .value("Week", item.weekStart, unit: .weekOfYear),
                    y: .value("Sessions", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [DSColors.primary, DSColors.primary.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(DSRadius.sm / 2)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(DSColors.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                        .foregroundStyle(DSColors.border)
                    AxisValueLabel()
                        .foregroundStyle(DSColors.textSecondary)
                }
            }
            .frame(height: 200)
        }
        .padding(.horizontal, DSSpacing.lg)
        .dsGlassCard(padding: DSSpacing.lg)
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - Category Breakdown Chart

    private func categoryBreakdownChart(_ breakdown: [(category: WorkoutCategory, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Category Breakdown")
                .font(DSFont.headline.font)
                .foregroundStyle(DSColors.textPrimary)

            Chart(breakdown, id: \.category) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Category", item.category.rawValue.capitalized)
                )
                .foregroundStyle(DSColors.categoryColor(item.category))
                .cornerRadius(DSRadius.sm / 2)
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                        .foregroundStyle(DSColors.border)
                    AxisValueLabel()
                        .foregroundStyle(DSColors.textSecondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(DSColors.textPrimary)
                }
            }
            .frame(height: CGFloat(breakdown.count) * 40 + 20)
        }
        .padding(.horizontal, DSSpacing.lg)
        .dsGlassCard(padding: DSSpacing.lg)
        .padding(.horizontal, DSSpacing.lg)
    }

    // MARK: - Recent Sessions List

    private func recentSessionsList(_ completed: [WorkoutSession]) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text("Recent Sessions")
                .font(DSFont.headline.font)
                .foregroundStyle(DSColors.textPrimary)
                .padding(.horizontal, DSSpacing.lg)

            if completed.isEmpty {
                ContentUnavailableView(
                    "No Workouts Yet",
                    systemImage: "chart.bar.fill",
                    description: Text("Complete a workout to see your insights")
                )
                .frame(minHeight: 200)
            } else {
                LazyVStack(spacing: DSSpacing.sm) {
                    ForEach(Array(completed.prefix(20))) { session in
                        sessionRow(session)
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
            }
        }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        HStack(spacing: DSSpacing.md) {
            // Category color dot
            Circle()
                .fill(DSColors.categoryColor(session.workoutCategory))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.workoutName)
                    .font(DSFont.bodyBold.font)
                    .foregroundStyle(DSColors.textPrimary)

                HStack(spacing: DSSpacing.xs) {
                    Text(session.startedAt, style: .relative)
                    Text("·")
                    Text(session.formattedDuration)
                    Text("·")
                    Text("\(Int(session.completionPercentage * 100))%")
                }
                .font(DSFont.caption.font)
                .foregroundStyle(DSColors.textSecondary)
            }

            Spacer()
        }
        .padding(DSSpacing.md)
        .background(DSColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
    .environment(SessionStore(modelContext:
        try! ModelContainer(for: WorkoutSession.self).mainContext))
}
