import Foundation
import HealthKit

extension HealthStore {
    /// Saves a finished strength session to Apple Health as a workout.
    func saveStrengthWorkout(start: Date, end: Date) async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: start)
        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
    }

    /// Saves a run entered by hand. Watch runs are never re-saved, so nothing is doubled.
    func saveManualRun(start: Date, seconds: Double, miles: Double, indoor: Bool) async throws {
        let end = start.addingTimeInterval(seconds)
        let config = HKWorkoutConfiguration()
        config.activityType = .running
        config.locationType = indoor ? .indoor : .outdoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: start)
        if miles > 0 {
            let distance = HKQuantitySample(type: HKQuantityType(.distanceWalkingRunning),
                                            quantity: HKQuantity(unit: .mile(), doubleValue: miles),
                                            start: start, end: end)
            try await builder.addSamples([distance])
        }
        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
        await refresh()
    }
}
