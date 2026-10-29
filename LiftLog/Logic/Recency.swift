import Foundation

/// 距離上次訓練的冷落程度
nonisolated enum Staleness: Equatable {
    case never   // 從沒做過
    case fresh   // 60 天內
    case stale   // 超過 60 天
    case cold    // 超過 180 天

    /// 很久沒練（超過 60 天）：畫面上用 warning 色提醒（CHANGE_13 §3）
    var isNeglected: Bool { self == .stale || self == .cold }
}

nonisolated enum Recency {
    static let staleAfterDays = 60
    static let coldAfterDays = 180

    /// 以日曆日計算：昨天晚上做的，今天早上看就是 1 天前
    static func daysSince(_ date: Date?, now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let date else { return nil }
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
        ).day ?? 0
        return max(0, days)
    }

    static func staleness(days: Int?) -> Staleness {
        guard let days else { return .never }
        if days > coldAfterDays { return .cold }
        if days > staleAfterDays { return .stale }
        return .fresh
    }

    /// 最久沒做的排前面：日期由舊到新；同一天或都沒做過時依名稱。
    /// 從沒做過的預設排最前面；untrainedLast 為 true 時排最後
    static func sortedByNeglect<T>(
        _ items: [T],
        lastDate: (T) -> Date?,
        name: (T) -> String,
        untrainedLast: Bool = false
    ) -> [T] {
        items.sorted { a, b in
            switch (lastDate(a), lastDate(b)) {
            case (nil, nil): return name(a) < name(b)
            case (nil, _): return !untrainedLast
            case (_, nil): return untrainedLast
            case let (da?, db?):
                return da == db ? name(a) < name(b) : da < db
            }
        }
    }

    /// 依分類順序分區，沒有動作的分類不出現；每區內最久沒做的排前面
    static func sections<T>(
        _ items: [T],
        category: (T) -> ExerciseCategory,
        lastDate: (T) -> Date?,
        name: (T) -> String,
        untrainedLast: Bool = false
    ) -> [(category: ExerciseCategory, items: [T])] {
        let grouped = Dictionary(grouping: items, by: category)
        return ExerciseCategory.allCases.compactMap { c in
            guard let members = grouped[c], !members.isEmpty else { return nil }
            return (c, sortedByNeglect(members, lastDate: lastDate, name: name, untrainedLast: untrainedLast))
        }
    }
}
