import SwiftUI

// MARK: - ActiveWorkoutView

struct ActiveWorkoutView: View {
    let workout: Workout

    @Environment(SessionStore.self) private var sessionStore
    @Environment(WorkoutStore.self) private var workoutStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dsTheme) private var theme

    @State private var engine = WorkoutTimerEngine()
    @State private var audioBridge: WorkoutAudioBridge?
    @State private var session: WorkoutSession?

    @State private var showingEndConfirmation = false
    @State private var showingDeferredQueue = false
    @State private var showingVoiceUpgrade = false

    // Prep countdown
    @State private var prepCountdown: Int = 10
    @State private var isPreparing = true
    @State private var prepTimer: Timer?

    /// The background color for the entire screen, driven by phase.
    private var screenBackground: Color {
        if isPreparing {
            return DSColors.background
        }
        if engine.state == .finishing {
            return DSColors.background
        }
        switch engine.phase {
        case .exercise, .waitingForUser:
            return theme.primary
        case .restBetweenSets, .restAfterBlock:
            return DSColors.background
        }
    }

    /// Text/icon color that contrasts with the current background.
    private var screenForeground: Color {
        if isPreparing || engine.state == .finishing {
            return theme.textPrimary
        }
        switch engine.phase {
        case .exercise, .waitingForUser:
            return theme.textOnPrimary
        case .restBetweenSets, .restAfterBlock:
            return theme.textPrimary
        }
    }

    /// Secondary text color that contrasts with the current background.
    private var screenForegroundSecondary: Color {
        if isPreparing || engine.state == .finishing {
            return theme.textSecondary
        }
        switch engine.phase {
        case .exercise, .waitingForUser:
            return theme.textOnPrimary.opacity(0.6)
        case .restBetweenSets, .restAfterBlock:
            return theme.textSecondary
        }
    }

    var body: some View {
        ZStack {
            // Full-screen background
            screenBackground
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: engine.phase)
                .animation(.easeInOut(duration: 0.5), value: isPreparing)
                .animation(.easeInOut(duration: 0.5), value: engine.state)

            VStack(spacing: 0) {
                if isPreparing {
                    // Close button for prep
                    HStack {
                        Button {
                            cancelPrep()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundStyle(theme.textSecondary)
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .padding(.leading, 16)
                        .padding(.top, 8)
                        Spacer()
                    }
                    Spacer()
                    prepScreen
                    Spacer()
                } else if engine.state == .finishing {
                    // Completion screen
                    Spacer()
                    WorkoutCompleteView(
                        session: session,
                        onDismiss: { dismiss() }
                    )
                    Spacer()
                } else {
                    // Active workout
                    topBar
                    Spacer()
                    mainContent
                    Spacer()
                    BigButtonPanel(engine: engine, isExercisePhase: engine.phase == .exercise || engine.phase == .waitingForUser)
                        .padding()
                }
            }
        }
        .navigationBarHidden(true)
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
            WorkoutFlowSheet(engine: engine)
        }
        .alert(
            "Improve Voice Quality",
            isPresented: $showingVoiceUpgrade
        ) {
            Button("Open Settings") {
                AudioCueService.shared.voicePromptDismissed = true
                if let url = URL(string: "App-prefs:ACCESSIBILITY&path=SPEECH_TITLE") {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {
                AudioCueService.shared.voicePromptDismissed = true
            }
        } message: {
            Text("Download a higher-quality voice for better coaching audio. Go to Voices → English → Ava or Samantha and tap the download button.")
        }
        .onAppear {
            startPrep()
        }
        .onDisappear {
            cancelPrep()
            audioBridge?.deactivate()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Prep Screen

    private var prepScreen: some View {
        VStack(spacing: 40) {
            Text("cadence")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .tracking(6)
                .textCase(.uppercase)
                .foregroundStyle(theme.primary)

            Text(workout.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            ZStack {
                Circle()
                    .stroke(theme.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: Double(10 - prepCountdown) / 10.0)
                    .stroke(theme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: prepCountdown)

                Text("\(prepCountdown)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                    .contentTransition(.numericText())
            }

            // First exercise hint
            if let first = workout.entries.sorted(by: { $0.orderIndex < $1.orderIndex }).first {
                VStack(spacing: 4) {
                    Text("FIRST UP")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(theme.textSecondary)
                    Text(first.exerciseName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.textPrimary)
                    Text(first.displayConfiguration)
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            // Skip prep button
            Button {
                cancelPrep()
                beginWorkout()
            } label: {
                Text("Skip")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(theme.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 6) {
            // Top row: close button, branding + name, deferred badge
            HStack {
                Button {
                    showingEndConfirmation = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(screenForegroundSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("cadence")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .tracking(3)
                        .textCase(.uppercase)
                        .foregroundStyle(screenForegroundSecondary)
                    Text(workout.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(screenForeground)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    showingDeferredQueue = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(screenForegroundSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 16)

            // Stats row
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text(formatTime(engine.totalElapsedSeconds))
                        .font(.caption2)
                        .monospacedDigit()
                }

                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .font(.caption2)
                    Text("\(Int(engine.completionPercentage * 100))%")
                        .font(.caption2)
                        .monospacedDigit()
                }

                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption2)
                    Text("\(engine.currentEntryIndex + 1)/\(workout.entries.count)")
                        .font(.caption2)
                        .monospacedDigit()
                }
            }
            .foregroundStyle(screenForegroundSecondary)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 30) {
            // Exercise name — always shows current exercise
            Text(engine.currentExerciseName)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(screenForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Set & reps info — adapts based on phase
            exerciseInfo

            timerDisplay
        }
    }

    private var exerciseInfo: some View {
        Group {
            if let entry = engine.currentEntry {
                switch engine.phase {
                case .exercise:
                    // Current set + reps
                    VStack(spacing: 6) {
                        Text("Set \(engine.currentSet) of \(entry.sets)")
                            .font(.title3)
                            .foregroundStyle(screenForegroundSecondary)
                        if let reps = entry.targetReps, entry.blockType == .repBased {
                            Text("\(reps) reps")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(screenForeground)
                        }
                    }

                case .restBetweenSets:
                    // Next set preview inline
                    HStack(spacing: 8) {
                        Text("Set \(engine.currentSet + 1) of \(entry.sets)")
                            .font(.title3)
                            .foregroundStyle(screenForeground)
                        if let reps = entry.targetReps, entry.blockType == .repBased {
                            Text("· \(reps) reps")
                                .font(.title3)
                                .foregroundStyle(screenForegroundSecondary)
                        }
                        Text("Next up")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .textCase(.uppercase)
                            .tracking(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(screenForeground.opacity(0.1))
                            .foregroundStyle(screenForegroundSecondary)
                            .clipShape(Capsule())
                    }

                case .restAfterBlock:
                    // Next exercise preview inline
                    if let next = engine.nextEntry {
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Text(next.exerciseName)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(screenForeground)
                                Text("Next up")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(screenForeground.opacity(0.1))
                                    .foregroundStyle(screenForegroundSecondary)
                                    .clipShape(Capsule())
                            }
                            Text(next.displayConfiguration)
                                .font(.subheadline)
                                .foregroundStyle(screenForegroundSecondary)
                        }
                    } else {
                        Text("Last exercise!")
                            .font(.title3)
                            .foregroundStyle(screenForegroundSecondary)
                    }

                case .waitingForUser:
                    VStack(spacing: 6) {
                        Text("Set \(engine.currentSet) of \(entry.sets)")
                            .font(.title3)
                            .foregroundStyle(screenForegroundSecondary)
                        if let reps = entry.targetReps, entry.blockType == .repBased {
                            Text("\(reps) reps")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(screenForeground)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 50)
    }

    private var timerDisplay: some View {
        ZStack {
            Circle()
                .stroke(screenForegroundSecondary.opacity(0.2), lineWidth: 12)
                .frame(width: 250, height: 250)

            Circle()
                .trim(from: 0, to: timerProgress)
                .stroke(
                    timerRingColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 250, height: 250)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: timerProgress)

            VStack(spacing: 4) {
                Text("\(engine.secondsRemaining)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(screenForeground)
                    .contentTransition(.numericText())

                Text(phaseLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(screenForegroundSecondary)
            }
        }
    }

    // MARK: - Prep Management

    private func startPrep() {
        isPreparing = true
        prepCountdown = 10
        UIApplication.shared.isIdleTimerDisabled = true

        prepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if prepCountdown > 1 {
                    withAnimation { prepCountdown -= 1 }
                } else {
                    cancelPrep()
                    beginWorkout()
                }
            }
        }
    }

    private func cancelPrep() {
        prepTimer?.invalidate()
        prepTimer = nil
    }

    private func beginWorkout() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isPreparing = false
        }

        session = sessionStore.startSession(for: workout)
        audioBridge = WorkoutAudioBridge(engine: engine)
        audioBridge?.activate()
        engine.start(workout: workout)

        if AudioCueService.shared.shouldPromptForVoiceUpgrade {
            showingVoiceUpgrade = true
        }

        engine.onWorkoutComplete = { _ in
            if let session = session {
                sessionStore.completeSession(session)
            }
            workoutStore.markCompleted(workout)
        }
    }

    // MARK: - Helpers

    private var timerProgress: Double {
        guard let entry = engine.currentEntry else { return 0 }

        let base: Double
        switch engine.phase {
        case .exercise:
            base = Double(entry.estimatedDurationPerSetSeconds)
        case .restBetweenSets:
            base = Double(entry.restBetweenSetsSeconds)
        case .restAfterBlock:
            base = Double(entry.restAfterExerciseSeconds)
        case .waitingForUser:
            return 1.0
        }

        let remaining = Double(engine.secondsRemaining)
        // Use the larger of base or remaining so +30s extends the ring instead of overflowing
        let total = max(base, remaining)
        guard total > 0 else { return 0 }
        return 1.0 - (remaining / total)
    }

    /// Color for the timer ring only — distinct from the background.
    private var timerRingColor: Color {
        switch engine.phase {
        case .exercise:
            // Color change when countdown is close to done
            let countdownSetting = UserDefaults.standard.object(forKey: "Settings.countdownSeconds") != nil
                ? UserDefaults.standard.integer(forKey: "Settings.countdownSeconds") : 3
            if countdownSetting > 0 && engine.secondsRemaining <= countdownSetting {
                return theme.warning
            }
            return screenForeground
        case .restBetweenSets, .restAfterBlock:
            return theme.primary
        case .waitingForUser:
            return screenForeground
        }
    }

    private var phaseLabel: String {
        switch engine.phase {
        case .exercise:
            return "Go"
        case .restBetweenSets:
            return "Rest"
        case .restAfterBlock:
            return "Rest"
        case .waitingForUser:
            return "Tap Done"
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
    var isExercisePhase: Bool
    @Environment(\.dsTheme) private var theme

    /// On peach background, buttons use dark fills; on dark background, buttons use peach.
    private var primaryButtonBg: Color {
        isExercisePhase ? theme.textOnPrimary : theme.primary
    }
    private var primaryButtonFg: Color {
        isExercisePhase ? theme.primary : theme.textOnPrimary
    }
    private var secondaryButtonBg: Color {
        isExercisePhase ? theme.textOnPrimary.opacity(0.2) : theme.secondary.opacity(0.2)
    }
    private var secondaryButtonFg: Color {
        isExercisePhase ? theme.textOnPrimary : theme.textPrimary
    }

    var body: some View {
        VStack(spacing: 12) {
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
                    .background(primaryButtonBg)
                    .foregroundStyle(primaryButtonFg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Second primary button — always present for stable layout
                if engine.state == .waitingForUser {
                    Button {
                        engine.markCurrentDone()
                    } label: {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(primaryButtonBg)
                            .foregroundStyle(primaryButtonFg)
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
                            .background(theme.warning)
                            .foregroundStyle(theme.textOnPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    // Exercise phase — skip as second primary
                    Button {
                        engine.skipExercise()
                    } label: {
                        Label("Skip", systemImage: "forward.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(secondaryButtonBg)
                            .foregroundStyle(secondaryButtonFg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            Button {
                engine.deferExercise()
            } label: {
                Label("Push Movement", systemImage: "arrow.uturn.right")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(secondaryButtonBg)
                    .foregroundStyle(secondaryButtonFg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: - WorkoutFlowSheet

struct WorkoutFlowSheet: View {
    @Bindable var engine: WorkoutTimerEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dsTheme) private var theme

    private var firstMovableIndex: Int {
        engine.currentEntryIndex + 1
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(engine.flowEntries, id: \.id) { entry in
                    let status = engine.statusFor(entry)

                    WorkoutFlowRow(
                        entry: entry,
                        status: status,
                        isPushed: engine.deferredEntryIDs.contains(entry.id)
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 4))
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(rowBackground(for: status))
                            .padding(.vertical, 2)
                    )
                    .moveDisabled(status == .completed || status == .active || status == .skipped)
                }
                .onMove { source, destination in
                    engine.moveFlowEntry(from: source, to: destination)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            .background(theme.background)
            .scrollContentBackground(.hidden)
            .tint(theme.textTertiary)
            .navigationTitle("Workout Flow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func rowBackground(for status: WorkoutTimerEngine.EntryStatus) -> Color {
        switch status {
        case .active: return theme.primary.opacity(0.1)
        case .skipped: return theme.surfaceElevated.opacity(0.5)
        default: return theme.surfaceElevated
        }
    }
}

struct WorkoutFlowRow: View {
    let entry: WorkoutEntry
    let status: WorkoutTimerEngine.EntryStatus
    let isPushed: Bool
    @Environment(\.dsTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.exerciseName)
                    .font(.subheadline)
                    .fontWeight(status == .active ? .bold : .medium)
                    .foregroundStyle(textColor)

                Text(entry.displayConfiguration)
                    .font(.caption)
                    .foregroundStyle(subtextColor)
            }

            Spacer()

            // Status badge
            if isPushed {
                Text("Pushed")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.warning.opacity(0.15))
                    .foregroundStyle(theme.warning)
                    .clipShape(Capsule())
            } else if status == .skipped {
                Text("Skipped")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.secondary.opacity(0.15))
                    .foregroundStyle(theme.textTertiary)
                    .clipShape(Capsule())
            } else if status == .active {
                Text("Now")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.primary.opacity(0.15))
                    .foregroundStyle(theme.primary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var textColor: Color {
        switch status {
        case .completed: return theme.textSecondary
        case .active: return theme.textPrimary
        case .upcoming: return theme.textPrimary
        case .skipped: return theme.textDisabled
        case .deferred: return theme.textPrimary
        }
    }

    private var subtextColor: Color {
        switch status {
        case .skipped: return theme.textDisabled
        default: return theme.textTertiary
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(theme.success)
        case .active:
            Image(systemName: "play.circle.fill")
                .foregroundStyle(theme.primary)
        case .upcoming:
            Image(systemName: "circle")
                .foregroundStyle(theme.textTertiary)
        case .skipped:
            Image(systemName: "forward.circle.fill")
                .foregroundStyle(theme.textDisabled)
        case .deferred:
            Image(systemName: "circle")
                .foregroundStyle(theme.textTertiary)
        }
    }
}

// MARK: - WorkoutCompleteView

struct WorkoutCompleteView: View {
    let session: WorkoutSession?
    let onDismiss: () -> Void
    @Environment(\.dsTheme) private var theme

    var body: some View {
        VStack(spacing: 30) {
            Text("cadence")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .tracking(5)
                .textCase(.uppercase)
                .foregroundStyle(theme.primary)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(theme.success)

            Text("Workout Complete!")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            if let session = session {
                VStack(spacing: 12) {
                    StatRow(
                        icon: "timer",
                        label: "Duration",
                        value: session.formattedDuration
                    )
                    StatRow(
                        icon: "figure.strengthtraining.traditional",
                        label: "Movements",
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
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                onDismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.primary)
                    .foregroundStyle(theme.textOnPrimary)
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
    @Environment(\.dsTheme) private var theme

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
                .foregroundStyle(theme.textSecondary)
            Text(label)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(theme.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        Text("Preview placeholder")
    }
}
