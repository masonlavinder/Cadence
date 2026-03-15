import SwiftUI
import SwiftData

// MARK: - WorkoutDetailView

struct WorkoutDetailView: View {
    let workout: Workout

    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(SessionStore.self) private var sessionStore
    @State private var showingEditor = false
    @State private var showingActiveWorkout = false
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var sortedEntries: [WorkoutEntry] {
        workout.entries.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        List {
            // Overview
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    if !workout.workoutDescription.isEmpty {
                        Text(workout.workoutDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        DetailBadge(icon: "flame.fill", label: workout.category.rawValue.capitalized, color: .orange)
                        DetailBadge(icon: "speedometer", label: workout.difficulty.rawValue.capitalized, color: .blue)
                        DetailBadge(icon: "clock", label: "\(workout.estimatedDurationMinutes) min", color: .green)
                    }

                    if workout.timesCompleted > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                            Text("Completed \(workout.timesCompleted) time\(workout.timesCompleted == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Target Muscles
            if !workout.targetMuscleGroups.isEmpty {
                Section("Target Muscles") {
                    FlowLayout(spacing: 6) {
                        ForEach(workout.targetMuscleGroups, id: \.self) { muscle in
                            Text(muscle.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            // Exercise Sequence
            Section("Exercises (\(sortedEntries.count))") {
                if sortedEntries.isEmpty {
                    Text("No exercises added yet")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                        ExerciseSequenceRow(index: index, entry: entry)
                    }
                }
            }

            // Stats
            if !sortedEntries.isEmpty {
                Section("Summary") {
                    LabeledContent("Total Exercises", value: "\(sortedEntries.count)")
                    LabeledContent("Total Sets", value: "\(sortedEntries.reduce(0) { $0 + $1.sets })")

                    let totalSeconds = sortedEntries.reduce(0) { $0 + $1.totalEstimatedSeconds }
                    LabeledContent("Estimated Duration", value: "\(totalSeconds / 60) min")
                }
            }

            // Start Button
            if !sortedEntries.isEmpty {
                Section {
                    Button {
                        showingActiveWorkout = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Start Workout", systemImage: "play.fill")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .foregroundStyle(.white)
                    .listRowBackground(Color.accentColor)
                }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Workout", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            "Delete \"\(workout.name)\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                workoutStore.delete(workout)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This workout and all its exercises will be permanently removed.")
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                WorkoutEditorView(workout: workout)
            }
        }
        .fullScreenCover(isPresented: $showingActiveWorkout) {
            NavigationStack {
                ActiveWorkoutView(workout: workout)
            }
        }
    }
}

// MARK: - ExerciseSequenceRow

struct ExerciseSequenceRow: View {
    let index: Int
    let entry: WorkoutEntry

    var body: some View {
        HStack(spacing: 12) {
            // Order number
            Text("\(index + 1)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(entry.displayConfiguration)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if entry.restBetweenSetsSeconds > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "pause.circle")
                                .font(.caption2)
                            Text("\(entry.restBetweenSetsSeconds)s rest")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.totalEstimatedSeconds / 60)m")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - DetailBadge

struct DetailBadge: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}

#Preview {
    NavigationStack {
        Text("Detail preview requires a workout")
    }
}
