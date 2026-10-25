import Foundation

/// 一次訓練中某個動作的組（數據頁的輸入，不依賴 SwiftData）
nonisolated struct SessionSets: Sendable {
    var sessionID: UUID
    var date: Date
    var sets: [SetValues]
}

// MARK: - 個人紀錄

nonisolated enum PersonalRecords {
    enum ValueKind: Equatable { case weight, reps, seconds }

    struct Record: Equatable, Identifiable {
        var title: String
        var value: Double
        var kind: ValueKind
        /// 重量紀錄的次數（顯示「60 kg × 3」）
        var reps: Int?
        var date: Date
        var sessionID: UUID
        /// 例如估算 1RM 在 90 天內沒有紀錄時標示「全期」
        var caption: String?
        var id: String { title }
    }

    static let estimateWindowDays = 90

    /// Epley：重量 × (1 + 次數 / 30)
    static func epley(weight: Double, reps: Int) -> Double {
        weight * (1 + Double(reps) / 30)
    }

    /// 估算 1RM 用的組：已完成、非熱身、1–10 下、有重量
    static func countsForEstimate(_ s: SetValues) -> Bool {
        s.isCompleted && s.kind != .warmup && s.weightKg != nil && (1...10).contains(s.reps ?? 0)
    }

    /// 估算 1RM：最近 90 天的最大值；90 天內沒有就取全期（isAllTime = true）
    static func estimated1RM(_ sessions: [SessionSets], now: Date = .now,
                             calendar: Calendar = .current) -> (record: Record, isAllTime: Bool)? {
        let cutoff = calendar.date(byAdding: .day, value: -estimateWindowDays, to: now) ?? now
        func best(in list: [SessionSets]) -> Record? {
            var result: Record?
            for s in list {
                for set in s.sets where countsForEstimate(set) {
                    let value = epley(weight: set.weightKg!, reps: set.reps!)
                    if value > (result?.value ?? 0) {
                        result = Record(title: "估算 1RM", value: value, kind: .weight, reps: nil,
                                        date: s.date, sessionID: s.sessionID)
                    }
                }
            }
            return result
        }
        if let recent = best(in: sessions.filter { $0.date >= cutoff }) {
            return (recent, false)
        }
        guard var allTime = best(in: sessions) else { return nil }
        allTime.caption = "近 90 天沒有紀錄，取全期"
        return (allTime, true)
    }

    static func records(_ sessions: [SessionSets], logType: LogType, now: Date = .now) -> [Record] {
        let all = sessions.flatMap { s in s.sets.filter(SetLogic.countsForRecord).map { (set: $0, session: s) } }

        func best(_ title: String, kind: ValueKind, lowerIsBetter: Bool = false,
                  where include: (SetValues) -> Bool = { _ in true },
                  value: (SetValues) -> Double?) -> Record? {
            var result: Record?
            for (set, session) in all where include(set) {
                guard let v = value(set) else { continue }
                let better = result.map { lowerIsBetter ? v < $0.value : v > $0.value } ?? true
                if better {
                    result = Record(title: title, value: v, kind: kind, reps: kind == .weight ? set.reps : nil,
                                    date: session.date, sessionID: session.sessionID)
                }
            }
            return result
        }

        switch logType {
        case .weight:
            var list = [best("最重單次", kind: .weight) { $0.weightKg }]
            for n in [1, 3, 5] {
                list.append(best("\(n)RM 最佳", kind: .weight, where: { ($0.reps ?? 0) >= n }) { $0.weightKg })
            }
            list.append(estimated1RM(sessions, now: now)?.record)
            return list.compactMap { $0 }
        case .assisted:
            return [best("5 下以上最低輔助", kind: .weight, lowerIsBetter: true, where: { ($0.reps ?? 0) >= 5 }) { $0.weightKg }]
                .compactMap { $0 }
        case .bodyweight:
            return [
                best("單組最多次數", kind: .reps) { $0.reps.map(Double.init) },
                best("最重負重", kind: .weight) { $0.weightKg },
            ].compactMap { $0 }
        case .timed:
            return [
                best("最長秒數", kind: .seconds) { $0.seconds },
                best("最重負重", kind: .weight) { $0.weightKg },
            ].compactMap { $0 }
        case .cardio:
            return []
        }
    }
}

// MARK: - 折線圖

nonisolated enum ChartMetric: String, CaseIterable, Identifiable {
    case heaviest, estimated1RM, reps, seconds, load, speed, incline, minutes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heaviest: "最重組"
        case .estimated1RM: "估算 1RM"
        case .reps: "次數"
        case .seconds: "秒數"
        case .load: "負重"
        case .speed: "速度"
        case .incline: "坡度"
        case .minutes: "時間"
        }
    }

    /// 縱軸是重量（要依 kg／lbs 換算）
    var isWeight: Bool { [.heaviest, .estimated1RM, .load].contains(self) }

    /// 這個紀錄類型可以切換的指標
    static func options(for logType: LogType) -> [ChartMetric] {
        switch logType {
        case .weight: [.heaviest, .estimated1RM]
        case .cardio: [.speed, .incline, .minutes]
        default: []
        }
    }

    static func defaultMetric(for logType: LogType, sessions: [SessionSets]) -> ChartMetric {
        switch logType {
        case .weight, .assisted: .heaviest
        case .bodyweight: .reps
        case .timed:
            // 有負重的動作用最重負重，沒有的用最長秒數
            sessions.contains { $0.sets.contains { $0.weightKg != nil } } ? .load : .seconds
        case .cardio: .speed
        }
    }
}

nonisolated enum ChartRange: String, CaseIterable, Identifiable {
    case threeMonths, sixMonths, oneYear, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threeMonths: "3 個月"
        case .sixMonths: "6 個月"
        case .oneYear: "1 年"
        case .all: "全部"
        }
    }

    func start(now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .threeMonths: calendar.date(byAdding: .month, value: -3, to: now)
        case .sixMonths: calendar.date(byAdding: .month, value: -6, to: now)
        case .oneYear: calendar.date(byAdding: .year, value: -1, to: now)
        case .all: nil
        }
    }
}

nonisolated enum ChartPoints {
    struct Point: Equatable, Identifiable {
        var sessionID: UUID
        var date: Date
        /// 重量一律為 kg，畫圖時再換算
        var value: Double
        var isMax: Bool
        var id: UUID { sessionID }
    }

    /// assisted 型縱軸反向（越低越好）
    static func isReversed(_ logType: LogType) -> Bool {
        logType == .assisted
    }

    /// 每次訓練一個點；排除熱身組與未完成的組
    static func points(_ sessions: [SessionSets], logType: LogType, metric: ChartMetric) -> [Point] {
        sessions.compactMap { s in
            let sets = s.sets.filter(SetLogic.countsForRecord)
            guard let (value, set) = pick(sets, logType: logType, metric: metric) else { return nil }
            return Point(sessionID: s.sessionID, date: s.date, value: value, isMax: set.kind == .max)
        }
        .sorted { $0.date < $1.date }
    }

    static func filter(_ points: [Point], range: ChartRange, now: Date = .now) -> [Point] {
        guard let start = range.start(now: now) else { return points }
        return points.filter { $0.date >= start }
    }

    private static func pick(_ sets: [SetValues], logType: LogType, metric: ChartMetric) -> (Double, SetValues)? {
        let candidates: [(Double, SetValues)] = sets.compactMap { s in
            let v: Double? = switch metric {
            case .heaviest, .load: s.weightKg
            case .estimated1RM: PersonalRecords.countsForEstimate(s)
                ? PersonalRecords.epley(weight: s.weightKg!, reps: s.reps!) : nil
            case .reps: s.reps.map(Double.init)
            case .seconds: s.seconds
            case .speed: s.speed
            case .incline: s.incline
            case .minutes: s.minutes
            }
            return v.map { ($0, s) }
        }
        // assisted 的最重組 = 輔助最少
        if logType == .assisted && metric == .heaviest {
            return candidates.min { $0.0 < $1.0 }
        }
        return candidates.max { $0.0 < $1.0 }
    }
}

// MARK: - 強度換算表

nonisolated enum IntensityTable {
    static let percents = [60, 65, 70, 75, 80, 85, 90, 95]

    struct Row: Equatable, Identifiable {
        var percent: Int
        /// 目前單位、已進位
        var weight: Double
        var purposes: [String]
        var id: Int { percent }
    }

    /// 區間會重疊，照實列出
    static func purposes(_ percent: Int) -> [String] {
        var list: [String] = []
        if (60...70).contains(percent) { list.append("爆發力") }
        if (65...85).contains(percent) { list.append("肌肥大") }
        if percent >= 85 { list.append("最大肌力") }
        return list
    }

    /// 預設進位：槓鈴 2.5 kg／5 lb，其他 1 kg／2.5 lb
    static func defaultStep(equipment: Equipment, unit: WeightUnit) -> Double {
        switch (equipment == .barbell, unit) {
        case (true, .kg): 2.5
        case (true, .lbs): 5
        case (false, .kg): 1
        case (false, .lbs): 2.5
        }
    }

    /// 進位到最接近、實際掛得出來的重量
    static func rounded(_ value: Double, step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    static func rows(base1RMKg: Double, unit: WeightUnit, step: Double) -> [Row] {
        let base = unit.fromKg(base1RMKg)
        return percents.map { p in
            Row(percent: p, weight: rounded(base * Double(p) / 100, step: step), purposes: purposes(p))
        }
    }
}
