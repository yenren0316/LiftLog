import Foundation
import CoreGraphics

/// 訓練日曆（類似 GitHub contribution graph）的資料
nonisolated enum ActivityCalendar {
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
}

/// 今天的訓練日曆的格子大小（CHANGE_08 §4）：格子固定大小，週數依寬度決定。
/// 每一欄是一週，從週一開始（TrainingCount.weekCalendar）
nonisolated enum CalendarGrid {
    static let cell: CGFloat = 12
    static let gap: CGFloat = 3
    /// 最上面月份的文字
    static let monthLabel: CGFloat = 14
    /// 格子上方的月份那一列（含和格子的間距）
    static let monthRow: CGFloat = monthLabel + 4

    static var height: CGFloat { monthRow + 7 * cell + 6 * gap }

    /// 寬度放得下幾週
    static func weekCount(width: CGFloat) -> Int {
        max(1, Int((width + gap) / (cell + gap)))
    }
}
