import Foundation
import HealthKit

/// 從「健康」讀到的一次室內步行／跑步
nonisolated struct TreadmillWorkout: Identifiable, Sendable {
    var id: UUID
    var start: Date
    var seconds: TimeInterval
    var distanceKm: Double?
    var isRunning: Bool
    var source: String

    var minutes: Double { TreadmillMath.minutes(seconds: seconds) }
    var speedKmh: Double? { TreadmillMath.averageSpeed(distanceKm: distanceKm, seconds: seconds) }
}

nonisolated enum TreadmillMath {
    /// 平均速度（km/h），取到小數一位；距離或時間無效時為 nil
    static func averageSpeed(distanceKm: Double?, seconds: TimeInterval) -> Double? {
        guard let distanceKm, distanceKm > 0, seconds >= 60 else { return nil }
        return (distanceKm / (seconds / 3600) * 10).rounded() / 10
    }

    /// 時間取整數分鐘（四捨五入）
    static func minutes(seconds: TimeInterval) -> Double {
        (seconds / 60).rounded()
    }
}

/// 讀取 Apple Watch／健身 App 存在「健康」裡的室內步行與跑步
enum HealthWorkouts {
    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static let store = HKHealthStore()
    private static let distanceType = HKQuantityType(.distanceWalkingRunning)

    /// 第一次會跳出健康權限視窗。iOS 不會告訴 App 使用者是否拒絕讀取，拒絕時查詢結果是空的。
    static func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType(), distanceType])
    }

    static func recentIndoorWalksAndRuns(days: Int = 7) async throws -> [TreadmillWorkout] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: nil),
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                HKQuery.predicateForWorkouts(with: .walking),
                HKQuery.predicateForWorkouts(with: .running),
            ]),
        ])
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let workouts = try await descriptor.result(for: store)

        return workouts
            .filter { ($0.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) == true }
            .map { w in
                TreadmillWorkout(
                    id: w.uuid,
                    start: w.startDate,
                    seconds: w.duration,
                    distanceKm: w.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)),
                    isRunning: w.workoutActivityType == .running,
                    source: w.sourceRevision.source.name
                )
            }
    }
}
