import Foundation

/// 距離上次訓練的冷落程度
nonisolated enum Staleness: Equatable {
    case never   // 從沒做過
    case fresh   // 60 天內
    case stale   // 超過 60 天
    case cold    // 超過 180 天
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

    /// 最久沒做的排前面：從沒做過 → 日期由舊到新；同一天或都沒做過時依名稱
    static func sortedByNeglect<T>(
        _ items: [T],
        lastDate: (T) -> Date?,
        name: (T) -> String
    ) -> [T] {
        items.sorted { a, b in
            switch (lastDate(a), lastDate(b)) {
            case (nil, nil): return name(a) < name(b)
            case (nil, _): return true
            case (_, nil): return false
            case let (da?, db?):
                return da == db ? name(a) < name(b) : da < db
            }
        }
    }

    /// 最近 `days` 天內，每個部位有訓練的天數（同一天同部位做多個動作只算一次）
    static func trainingDaysByGroup(
        _ records: [(date: Date, group: MuscleGroup)],
        now: Date = .now,
        days: Int = 30,
        calendar: Calendar = .current
    ) -> [MuscleGroup: Int] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today)
        else { return [:] }

        var seen: [MuscleGroup: Set<Date>] = [:]
        for r in records where r.date >= start && r.date < end {
            seen[r.group, default: []].insert(calendar.startOfDay(for: r.date))
        }
        return seen.mapValues(\.count)
    }
}
