import Foundation

/// 相對日期文字（CHANGE_07 B-4）：今天、昨天、N 天前。App 和小工具都只用這裡的寫法
nonisolated enum RelativeDay {
    /// 0 →「今天」、1 →「昨天」、N →「N 天前」
    static func text(_ days: Int) -> String {
        let p = parts(days)
        return (p.number ?? "") + p.unit
    }

    /// 距離 date 幾個日曆天的文字；沒有日期時為 nil（呼叫端顯示「未練過」等）
    static func text(since date: Date?, now: Date = .now, calendar: Calendar = .current) -> String? {
        days(since: date, now: now, calendar: calendar).map(text)
    }

    /// 小工具用大字顯示數字、小字顯示單位：(「2」,「天前」)；今天、昨天沒有數字
    static func parts(_ days: Int) -> (number: String?, unit: String) {
        switch days {
        case ..<1: (nil, "今天")
        case 1: (nil, "昨天")
        default: (String(days), " 天前")
        }
    }

    /// 以日曆日計算：昨天晚上做的，今天早上看就是 1 天
    static func days(since date: Date?, now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let date else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        return max(0, days)
    }
}
