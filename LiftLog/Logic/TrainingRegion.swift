import Foundation

/// 一次訓練（或一天）的部位，決定今天的日曆格子和歷程「訓練頻率」長條的顏色（CHANGE_08 §3、§4）。
/// 依完成的動作分類推算，和 `WorkoutSession.region` 同一套規則（只看上肢和下肢分類）；
/// 補登或編輯過的訓練存的 region 可能沒更新，所以不讀存的值
nonisolated enum DayRegion: String, CaseIterable, Sendable {
    case lower, upper, full
    /// 沒有上肢和下肢的動作：只有有氧（只有核心或補強的少數情況也歸在這裡）
    case cardio

    var title: String {
        switch self {
        case .lower: "下肢"
        case .upper: "上肢"
        case .full: "全身"
        case .cardio: "有氧"
        }
    }

    /// 一次訓練：有完成組的動作的分類；一個都沒有時為 nil（不算一次訓練）
    static func of(categories: [ExerciseCategory]) -> DayRegion? {
        guard !categories.isEmpty else { return nil }
        switch Region.infer(categories) {
        case .lower: return .lower
        case .upper: return .upper
        case .full: return .full
        case .unspecified: return .cardio
        }
    }

    static func of(_ session: PlanHistory.Session) -> DayRegion? {
        of(categories: session.items.filter { !$0.sets.isEmpty }.map(\.category))
    }

    /// 同一天多次訓練：合併後的部位（下肢＋上肢 = 全身；有氧不影響有重訓的日子）
    static func merged(_ regions: [DayRegion]) -> DayRegion? {
        guard !regions.isEmpty else { return nil }
        let lower = regions.contains { $0 == .lower || $0 == .full }
        let upper = regions.contains { $0 == .upper || $0 == .full }
        switch (lower, upper) {
        case (true, true): return .full
        case (true, false): return .lower
        case (false, true): return .upper
        case (false, false): return .cardio
        }
    }
}

/// 歷程「訓練頻率」卡（CHANGE_08 §3）：近 12 週或近 12 個月，每一段的訓練次數依部位分開
nonisolated enum TrainingFrequency {
    enum Period: String, CaseIterable, Identifiable, Sendable {
        case week, month

        var id: String { rawValue }
        var title: String { self == .week ? "週" : "月" }
    }

    struct Bucket: Sendable, Equatable, Identifiable {
        /// 這一段的開始（含）和結束（不含）
        var start: Date
        var end: Date
        var counts: [DayRegion: Int] = [:]

        var id: Date { start }
        var total: Int { counts.values.reduce(0, +) }
    }

    static let bucketCount = 12

    /// sessions：已結束、而且有完成組的訓練（日期和部位）。由舊到新，最後一段是本週或本月
    static func buckets(_ sessions: [(date: Date, region: DayRegion)], period: Period, now: Date = .now,
                        count: Int = bucketCount, calendar: Calendar = .current) -> [Bucket] {
        let component: Calendar.Component = period == .week ? .weekOfYear : .month
        return (0..<count).reversed().compactMap { back -> Bucket? in
            guard let day = calendar.date(byAdding: component, value: -back, to: now),
                  let interval = calendar.dateInterval(of: component, for: day) else { return nil }
            var bucket = Bucket(start: interval.start, end: interval.end)
            for session in sessions where interval.contains(session.date) && session.date < interval.end {
                bucket.counts[session.region, default: 0] += 1
            }
            return bucket
        }
    }

    /// 平均每一段幾次（含還沒過完的本週或本月）
    static func average(_ buckets: [Bucket]) -> Double {
        buckets.isEmpty ? 0 : Double(buckets.map(\.total).reduce(0, +)) / Double(buckets.count)
    }
}
