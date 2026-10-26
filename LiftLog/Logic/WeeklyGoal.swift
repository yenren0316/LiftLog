import Foundation

/// 全 App 唯一的訓練次數規則（CHANGE_09 §2）：今天的日曆（本週 N 次、達標的小點）、歷程的訓練頻率卡、
/// 每週目標都從 `days` 算出來，數字才會一致
nonisolated enum TrainingCount {
    /// 一週從週一開始（和今天的日曆的欄位一致），不管手機的地區設定
    static func weekCalendar(_ base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    /// 算進次數的日子（那天 0 點）和那天合併後的部位：
    /// - 只算有完成組的已結束訓練（sessions 來自 PlanHistory：已經排除進行中的訓練，每個動作只留完成的組）
    /// - 以天為單位：同一天練兩次只算 1 次
    /// - cardioOnlyCounts 關閉時，只有有氧動作有完成組的訓練不算；那天只要有任何一個非有氧動作的完成組，那天就算
    static func days(_ sessions: [PlanHistory.Session], cardioOnlyCounts: Bool,
                     calendar: Calendar = .current) -> [Date: DayRegion] {
        var regions: [Date: [DayRegion]] = [:]
        for session in sessions {
            let categories = session.items.filter { !$0.sets.isEmpty }.map(\.category)
            guard let region = DayRegion.of(categories: categories),
                  cardioOnlyCounts || categories.contains(where: { $0 != .cardio }) else { continue }
            regions[calendar.startOfDay(for: session.date), default: []].append(region)
        }
        return regions.compactMapValues(DayRegion.merged)
    }

    /// 每週算進次數的天數，key 是那週週一 0 點；calendar 用 weekCalendar
    static func weeks(_ days: [Date: DayRegion], calendar: Calendar) -> [Date: Int] {
        var weeks: [Date: Int] = [:]
        for day in days.keys {
            if let start = weekStart(of: day, calendar: calendar) { weeks[start, default: 0] += 1 }
        }
        return weeks
    }

    static func weekStart(of date: Date, calendar: Calendar) -> Date? {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
    }
}

/// 每週目標（CHANGE_09 §1、§2）：達標＝那一週算進次數的天數大於等於目標。目標改了之後，過去每一週都用新的目標重新判斷
nonisolated enum WeeklyGoal {
    /// 「只有有氧的訓練也算」，預設關閉
    static let cardioOnlyCountsKey = "weeklyGoal.cardioOnlyCounts"
    /// 使用者設定的目標；0（沒有這個值）表示從來沒設定過，用自動算的預設值
    static let goalKey = "weeklyGoal.goal"
    static let range = 1...7
    /// 近 12 週完全沒有紀錄時的預設值
    static let fallback = 3

    /// 預設值：近 12 個已經過完的週（不含本週）平均每週幾天，四捨五入，限制在 1–7；這 12 週都沒有紀錄時是 3
    static func automatic(weeks: [Date: Int], now: Date = .now, calendar: Calendar) -> Int {
        guard let thisWeek = TrainingCount.weekStart(of: now, calendar: calendar) else { return fallback }
        let total = (1...TrainingFrequency.bucketCount).reduce(0) { sum, back in
            guard let day = calendar.date(byAdding: .day, value: -7 * back, to: thisWeek),
                  let start = TrainingCount.weekStart(of: day, calendar: calendar) else { return sum }
            return sum + (weeks[start] ?? 0)
        }
        guard total > 0 else { return fallback }
        let average = (Double(total) / Double(TrainingFrequency.bucketCount)).rounded()
        return min(max(Int(average), range.lowerBound), range.upperBound)
    }

    /// 目前的目標：設定過就用設定的，從來沒設定過才用預設值
    static func goal(stored: Int, automatic: Int) -> Int {
        range.contains(stored) ? stored : automatic
    }

    static func goal(automatic: Int, defaults: UserDefaults = .standard) -> Int {
        goal(stored: defaults.integer(forKey: goalKey), automatic: automatic)
    }

    struct Progress: Equatable, Sendable {
        /// 本週算進次數的天數
        var count: Int
        var goal: Int
        /// 連續達標的週數：從上週往回數；本週已經達標也算進去，本週還沒達標不會中斷
        var streak: Int

        var isMet: Bool { count >= goal }

        /// 「本週 2/3・連續 5 週達標」；本週已達標「本週 3/3 ✓・連續 6 週達標」；連續 0 週只寫「本週 1/3」
        var text: String {
            let week = "本週 \(count)/\(goal)\(isMet ? " ✓" : "")"
            return streak > 0 ? "\(week)・連續 \(streak) 週達標" : week
        }
    }

    /// weeks：TrainingCount.weeks 的結果
    static func isMet(week start: Date, weeks: [Date: Int], goal: Int) -> Bool {
        (weeks[start] ?? 0) >= goal
    }

    static func progress(weeks: [Date: Int], goal: Int, now: Date = .now, calendar: Calendar) -> Progress {
        let goal = max(goal, 1)
        guard let thisWeek = TrainingCount.weekStart(of: now, calendar: calendar) else {
            return Progress(count: 0, goal: goal, streak: 0)
        }
        let count = weeks[thisWeek] ?? 0
        var streak = count >= goal ? 1 : 0
        var week = thisWeek
        // 目標至少 1，往回數到第一個沒達標的週就停（再往前沒有紀錄的週一定沒達標）
        while let day = calendar.date(byAdding: .day, value: -7, to: week),
              let previous = TrainingCount.weekStart(of: day, calendar: calendar),
              isMet(week: previous, weeks: weeks, goal: goal) {
            streak += 1
            week = previous
        }
        return Progress(count: count, goal: goal, streak: streak)
    }
}
