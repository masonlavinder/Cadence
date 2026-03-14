import SwiftUI

// MARK: - ActiveWorkoutView

struct ActiveWorkoutView: View {
    let workout: Workout
    
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var engine = WorkoutTimerEngine()
    @State private var audioBridge: WorkoutAudioBridge?
    @State private var session: WorkoutSession?
    
    @State private var showingEndConfirmation = false
    @State private var showingDeferredQueue = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.accentColor.opacity(0.1), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                topBar
                
                Spacer()
                
                // Main Content
                if engine.state == .finishing {
                    WorkoutCompleteView(
                        session: session,
                        onDismiss: {
                            dismiss()
                        }
                    )
                } else {
                    mainContent
                }
                
                Spacer()
                
                // Control Panel
                if engine.state != .finishing {
                    BigButtonPanel(engine: engine)
                        .padding()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingEndConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if !engine.deferredQueue.isEmpty {
                    Button {
                        showingDeferredQueue = true
                    } label: {
                        Label("\(engine.deferredQueue.count) deferred", systemImage: "clock.badge")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .confirmationDialog(
            "End Workout?",
            isPresented: $showingEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Workout", role: .destructive) {
                engine.endWorkout()
                if let session = session {
                    sessionStore.abandonSession(session)
                }
                dismiss()
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You've completed \(Int(engine.completionPercentage * 100))% of the workout.")
        }
        .sheet(isPresented: $showingDeferredQueue) {
            DeferredQueueSheet(engine: engine)
        }
        .onAppear {
            setupWorkout()
        }
        .onDisappear {
            audioBridge?.deactivate()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        VStack(spacing: 8) {
            Text(workout.name)
                .font(.headline)
                .lineLimit(1)
            
            HStack(spacing: 20) {
                // Elapsed Time
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption)
                    Text(formatTime(engine.totalElapsedSeconds))
                        .font(.caption)
                        .monospacedDigit()
                }
                
                // Progress
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption)
                    Text("\(Int(engine.completionPercentage * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                }
                
                // Exercise Counter
                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption)
                    Text("\(engine.currentEntryIndex + 1)/\(workout.entries.count)")
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 30) {
            // Exercise Name
            Text(engine.currentExerciseName)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Set Counter
            if let entry = engine.currentEntry {
                Text("Set \(engine.currentSet) of \(entry.sets)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // Timer Display
            timerDisplay
            
            // Phase Indicator
            phaseIndicator
        }
    }
    
    private var timerDisplay: some View {
        ZStack {
            // Background Circle
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                .frame(width: 250, height: 250)
            
            // Progress Circle
            Circle()
                .trim(from: 0, to: timerProgress)
                .stroke(
                    timerColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 250, height: 250)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: timerProgress)
            
            // Time Text
            VStack(spacing: 4) {
                Text("\(engine.secondsRemaining)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                
                Text("seconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var phaseIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: phaseIcon)
                .font(.title3)
            Text(phaseText)
                .font(.headline)
        }
        .foregroundStyle(timerColor)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(timerColor.opacity(0.1))
        .clipShape(Capsule())
    }
    
    // MARK: - Helpers
    
    private func setupWorkout() {
        // Create session
        session = sessionStore.startSession(for: workout)
        
        // Setup audio
        audioBridge = WorkoutAudioBridge(engine: engine)
        audioBridge?.activate()
        
        // Prevent screen lock
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Start workout
        engine.start(workout: workout)
        
        // Setup completion callback
        engine.onWorkoutComplete = { completedSession in
            if let session = session {
                sessionStore.completeSession(session)
            }
        }
    }
    
    private var timerProgress: Double {
        guard let entry = engine.currentEntry else { return 0 }
        
        let total: Double
        switch engine.phase {
        case .exercise:
            total = Double(entry.estimatedDurationPerSetSeconds)
        case .restBetweenSets:
            total = Double(entry.restBetweenSetsSeconds)
        case .restAfterBlock:
            total = Double(entry.restAfterExerciseSeconds)
        case .waitingForUser:
            return 1.0
        }
        
        let remaining = Double(engine.secondsRemaining)
        return 1.0 - (remaining / total)
    }
    
    private var timerColor: Color {
        switch engine.phase {
        case .exercise:
            return engine.secondsRemaining <= 3 ? .red : .blue
        case .restBetweenSets, .restAfterBlock:
            return .green
        case .waitingForUser:
            return .orange
        }
    }
    
    private var phaseIcon: String {
        switch engine.phase {
        case .exercise:
            return "figure.strengthtraining.traditional"
        case .restBetweenSets, .restAfterBlock:
            return "pause.circle.fill"
        case .waitingForUser:
            return "hand.raised.fill"
        }
    }
    
    private var phaseText: String {
        switch engine.phase {
        case .exercise:
            return "Exercise"
        case .restBetweenSets:
            return "Rest Between Sets"
        case .restAfterBlock:
            return "Rest Before Next Exercise"
        case .waitingForUser:
            return "Tap Done When Complete"
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - BigButtonPanel

struct BigButtonPanel: View {
    @Bindable var engine: WorkoutTimerEngine
    
    var body: some View {
        VStack(spacing: 12) {
            // Primary Controls
            HStack(spacing: 12) {
                // Pause/Resume
                Button {
                    engine.togglePause()
                } label: {
                    Label(
                        engine.state == .paused ? "Resume" : "Pause",
                        systemImage: engine.state == .paused ? "play.fill" : "pause.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Done (for untimed exercises) or +30s Rest
                if engine.state == .waitingForUser {
                    Button {
                        engine.markCurrentDone()
                    } label: {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else if engine.phase == .restBetweenSets || engine.phase == .restAfterBlock {
                    Button {
                        engine.extendRest(bySeconds: 30)
                    } label: {
                        Label("+30s", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            
            // Secondary Controls
            HStack(spacing: 12) {
                Button {
                    engine.skipExercise()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.2))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                Button {
                    engine.deferExercise()
                } label: {
                    Label("Later", systemImage: "clock.badge")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.secondary.opacity(0.2))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

// MARK: - DeferredQueueSheet

struct DeferredQueueSheet: View {
    @Bindable var engine: WorkoutTimerEngine
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(engine.deferredQueue.enumerated()), id: \.element.id) { index, entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.exerciseName)
                                .font(.headline)
                            
                            Text("\(entry.sets) × \(entry.displayConfiguration)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            engine.insertDeferred(at: index)
                            if engine.deferredQueue.isEmpty {
                                dismiss()
                            }
                        } label: {
                            Text("Insert Next")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .navigationTitle("Deferred Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if engine.deferredQueue.isEmpty {
                    ContentUnavailableView(
                        "No Deferred Exercises",
                        systemImage: "checkmark.circle",
                        description: Text("All exercises completed!")
                    )
                }
            }
        }
    }
}

// MARK: - WorkoutCompleteView

struct WorkoutCompleteView: View {
    let session: WorkoutSession?
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("Workout Complete!")
                .font(.system(size: 36, weight: .bold))
            
            if let session = session {
                VStack(spacing: 12) {
                    StatRow(
                        icon: "timer",
                        label: "Duration",
                        value: session.formattedDuration
                    )
                    
                    StatRow(
                        icon: "figure.strengthtraining.traditional",
                        label: "Exercises",
                        value: "\(session.exercisesCompleted) completed"
                    )
                    
                    StatRow(
                        icon: "chart.bar.fill",
                        label: "Completion",
                        value: "\(Int(session.completionPercentage * 100))%"
                    )
                    
                    if session.exercisesSkipped > 0 {
                        StatRow(
                            icon: "forward.fill",
                            label: "Skipped",
                            value: "\(session.exercisesSkipped)"
                        )
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    NavigationStack {
        Text("Preview placeholder")
        // ActiveWorkoutView requires a real workout
    }
}
