import Foundation
import CoreGraphics

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

/// 今天的訓練日曆的格子位置（CHANGE_08 §4）：格子固定大小，週數依寬度決定；點和拖曳時把手指的位置換成那一天。
/// 每一欄是一週，從週一開始（TrainingCount.weekCalendar）
nonisolated enum CalendarGrid {
    static let cell: CGFloat = 12
    static let gap: CGFloat = 3
    /// 最上面月份的文字
    static let monthLabel: CGFloat = 14
    /// 月份下面「這週達標」的小點（CHANGE_09 §3）
    static let dot: CGFloat = 5
    /// 格子上方的月份和小點兩列（含間距）
    static let monthRow: CGFloat = monthLabel + 2 + dot + 3

    static var height: CGFloat { monthRow + 7 * cell + 6 * gap }

    /// 寬度放得下幾週
    static func weekCount(width: CGFloat) -> Int {
        max(1, Int((width + gap) / (cell + gap)))
    }

    /// 格子的左上角
    static func origin(week: Int, day: Int) -> CGPoint {
        CGPoint(x: CGFloat(week) * (cell + gap), y: monthRow + CGFloat(day) * (cell + gap))
    }

    /// 手指的位置是第幾週、一週裡的第幾天；格子右邊和下面的空隙算前一格；超出格子範圍為 nil
    static func cell(at point: CGPoint, weeks: Int) -> (week: Int, day: Int)? {
        let y = point.y - monthRow
        guard point.x >= 0, y >= 0 else { return nil }
        let week = Int(point.x / (cell + gap)), day = Int(y / (cell + gap))
        guard week < weeks, day < 7 else { return nil }
        return (week, day)
    }

    /// 手指位置的那一天（今天之後、超出範圍為 nil）；weeks 是 ActivityCalendar.weeks 的結果
    static func date(at point: CGPoint, in weeks: [[Date?]]) -> Date? {
        guard let position = cell(at: point, weeks: weeks.count) else { return nil }
        return weeks[position.week][position.day]
    }

    /// 浮出的標籤：「10/23 週五・下肢最大肌力・深蹲」；同一天多次「10/24 週六・2 次訓練」；沒有訓練為 nil
    static func peekText(day: Date, titles: [String], calendar: Calendar = .current) -> String? {
        guard !titles.isEmpty else { return nil }
        let parts = calendar.dateComponents([.month, .day, .weekday], from: day)
        let weekdays = ["週日", "週一", "週二", "週三", "週四", "週五", "週六"]
        let head = "\(parts.month ?? 0)/\(parts.day ?? 0) \(weekdays[((parts.weekday ?? 1) - 1) % 7])"
        return titles.count == 1 ? "\(head)・\(titles[0])" : "\(head)・\(titles.count) 次訓練"
    }
}
