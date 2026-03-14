import Foundation
import SwiftData

// MARK: - SessionStore
/// Service layer for WorkoutSession entity CRUD operations
/// Manages workout execution history and session logging

@Observable
final class SessionStore {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Session Lifecycle
    
    /// Start a new workout session
    /// Creates a WorkoutSession and inserts it into the context
    func startSession(for workout: Workout) -> WorkoutSession {
        let session = WorkoutSession(
            workoutId: workout.id,
            workoutName: workout.name,
            totalExercises: workout.entries.count
        )
        
        modelContext.insert(session)
        save()
        
        return session
    }
    
    /// Mark a session as completed
    /// Updates status, completion time, and total duration
    func completeSession(_ session: WorkoutSession) {
        session.status = .completed
        session.completedAt = Date()
        
        // Calculate actual duration
        let duration = Date().timeIntervalSince(session.startedAt)
        session.totalDurationSeconds = Int(duration)
        
        save()
    }
    
    /// Mark a session as abandoned
    /// Sets status to abandoned but preserves the partial data
    func abandonSession(_ session: WorkoutSession) {
        session.status = .abandoned
        session.completedAt = Date()
        
        // Calculate duration even for abandoned sessions
        let duration = Date().timeIntervalSince(session.startedAt)
        session.totalDurationSeconds = Int(duration)
        
        save()
    }
    
    /// Resume an orphaned in-progress session
    /// Useful if app was force-quit during a workout
    func resumeOrAbandon(_ session: WorkoutSession) -> Bool {
        // If session is older than 24 hours and still in progress, auto-abandon
        let dayAgo = Date().addingTimeInterval(-86400)
        if session.status == .inProgress && session.startedAt < dayAgo {
            abandonSession(session)
            return false
        }
        
        return session.status == .inProgress
    }
    
    // MARK: - Entry Logging
    
    /// Log an entry to a session
    /// Creates or updates an EntrySessionLog for this exercise
    func logEntry(_ log: EntrySessionLog, to session: WorkoutSession) {
        session.entryLogs.append(log)
        modelContext.insert(log)
        
        // Update session counters based on outcome
        switch log.outcome {
        case .completed, .deferredDone:
            session.exercisesCompleted += 1
            session.totalSetsCompleted += log.setsCompleted
            if let reps = log.repsCompleted {
                session.totalRepsCompleted += reps.reduce(0, +)
            }
            if let time = log.timeUnderTensionSeconds {
                session.totalTimeUnderTensionSeconds += time
            }
        case .skipped:
            session.exercisesSkipped += 1
        case .deferred:
            session.exercisesDeferred += 1
        case .pending, .partiallyDone:
            break
        }
        
        save()
    }
    
    /// Update an existing log entry (e.g., when user completes sets)
    func updateLog(_ log: EntrySessionLog) {
        var mutableLog = log
        mutableLog.touch()
        save()
    }
    
    // MARK: - Queries
    
    /// Fetch recent sessions, sorted by start date
    func recentSessions(limit: Int = 20) -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return Array(sessions.prefix(limit))
    }
    
    /// Fetch sessions for a specific workout
    func sessionsForWorkout(_ workoutId: UUID) -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.workoutId == workoutId },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Fetch all completed sessions
    func completedSessions() -> [WorkoutSession] {
        let completedStatus = SessionStatus.completed
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.status == completedStatus },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    /// Find any orphaned in-progress sessions (app was force-quit)
    func findOrphanedSessions() -> [WorkoutSession] {
        let inProgressStatus = SessionStatus.inProgress
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.status == inProgressStatus },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    // MARK: - Statistics
    
    /// Calculate total workout time across all completed sessions
    func totalWorkoutTime() -> Int {
        let completed = completedSessions()
        return completed.reduce(0) { $0 + $1.totalDurationSeconds }
    }
    
    /// Count total completed sessions
    func totalCompletedCount() -> Int {
        return completedSessions().count
    }
    
    /// Get completion rate for a specific workout
    func completionRate(for workoutId: UUID) -> Double {
        let sessions = sessionsForWorkout(workoutId)
        guard !sessions.isEmpty else { return 0.0 }
        
        let completed = sessions.filter { $0.status == .completed }.count
        return Double(completed) / Double(sessions.count)
    }
    
    // MARK: - Helpers
    
    /// Delete a session (for cleanup/testing)
    func delete(_ session: WorkoutSession) {
        modelContext.delete(session)
        save()
    }
    
    /// Save changes to model context
    private func save() {
        do {
            try modelContext.save()
        } catch {
            print("Error saving SessionStore context: \(error)")
        }
    }
}
