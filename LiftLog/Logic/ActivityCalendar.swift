import Foundation

/// 訓練日曆（類似 GitHub contribution graph）的資料
nonisolated enum ActivityCalendar {
    /// 每天的動作數
    static func dailyCounts(_ dates: [Date], calendar: Calendar = .current) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        for d in dates { counts[calendar.startOfDay(for: d), default: 0] += 1 }
        return counts
    }

    /// 由舊到新的週，每週 7 天（從 calendar.firstWeekday 開始）；最後一週包含今天，今天之後為 nil
    static func weeks(endingAt now: Date, count: Int, calendar: Calendar = .current) -> [[Date?]] {
        let today = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: today)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard let thisWeekStart = calendar.date(byAdding: .day, value: -offset, to: today) else { return [] }

        return (0..<count).reversed().map { back in
            let start = calendar.date(byAdding: .weekOfYear, value: -back, to: thisWeekStart)!
            return (0..<7).map { i in
                let day = calendar.date(byAdding: .day, value: i, to: start)!
                return day > today ? nil : day
            }
        }
    }

    /// 0 = 沒練、1...3 = 亮度
    static func level(for count: Int) -> Int {
        min(count, 3)
    }
}
