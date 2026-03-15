import Foundation
import HealthKit

// MARK: - HealthKitService

@Observable
final class HealthKitService {
    private let healthStore = HKHealthStore()
    private(set) var isAuthorized = false

    /// Whether HealthKit is available on this device
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Request permission to write workouts
    func requestAuthorization() async {
        guard isAvailable else { return }

        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: [])
            isAuthorized = true
        } catch {
            print("HealthKit authorization failed: \(error)")
        }
    }

    /// Save a completed workout session to HealthKit
    func saveWorkout(_ session: WorkoutSession) async {
        guard isAvailable, isAuthorized else { return }
        guard session.status == .completed,
              let endDate = session.completedAt else { return }

        let activityType = hkActivityType(for: session.workoutCategory)
        let duration = TimeInterval(session.totalDurationSeconds)

        let workout = HKWorkout(
            activityType: activityType,
            start: session.startedAt,
            end: endDate,
            duration: duration,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: [
                "CadenceWorkoutId": session.workoutId.uuidString,
                "CadenceWorkoutName": session.workoutName
            ]
        )

        do {
            try await healthStore.save(workout)
        } catch {
            print("HealthKit save failed: \(error)")
        }
    }

    // MARK: - Mapping

    private func hkActivityType(for category: WorkoutCategory) -> HKWorkoutActivityType {
        switch category {
        case .strength:      return .traditionalStrengthTraining
        case .hiit:          return .highIntensityIntervalTraining
        case .cardio:        return .running
        case .yoga:          return .yoga
        case .flexibility:   return .flexibility
        case .calisthenics:  return .functionalStrengthTraining
        case .crossfit:      return .crossTraining
        case .custom:        return .other
        }
    }
}
