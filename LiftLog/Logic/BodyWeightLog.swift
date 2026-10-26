import Foundation
import SwiftData

/// 體重（CHANGE_07 D-2）：同一天只保留一筆，圖表另外畫 7 日平均
nonisolated enum BodyWeightLog {
    struct Entry: Equatable, Identifiable, Sendable {
        var date: Date
        var kg: Double
        var id: Date { date }
    }

    /// 每天一筆（同一天有多筆時取最晚記的），由舊到新
    static func perDay(_ entries: [Entry], calendar: Calendar = .current) -> [Entry] {
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return grouped.values.compactMap { $0.max { $0.date < $1.date } }.sorted { $0.date < $1.date }
    }

    /// 每一筆的 7 日平均：那天和前 6 天內的紀錄平均
    static func movingAverage(_ entries: [Entry], days: Int = 7, calendar: Calendar = .current) -> [Entry] {
        let daily = perDay(entries, calendar: calendar)
        return daily.map { entry in
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: entry.date)) ?? entry.date
            let window = daily.filter { $0.date >= start && $0.date <= entry.date }
            return Entry(date: entry.date, kg: window.map(\.kg).reduce(0, +) / Double(window.count))
        }
    }

    /// 最新一筆和 30 天前（那天或之前最近的一筆）的差距；沒有比較對象、或最新一筆本身就在 30 天前時為 nil
    static func change(_ entries: [Entry], days: Int = 30, now: Date = .now, calendar: Calendar = .current) -> Double? {
        let daily = perDay(entries, calendar: calendar)
        // 30 天前那天結束的時間點
        guard let latest = daily.last,
              let cutoff = calendar.date(byAdding: .day, value: 1 - days, to: calendar.startOfDay(for: now)),
              let before = daily.last(where: { $0.date < cutoff }),
              before.date != latest.date
        else { return nil }
        return latest.kg - before.kg
    }

    static func filter(_ entries: [Entry], range: ChartRange, now: Date = .now) -> [Entry] {
        guard let start = range.start(now: now) else { return entries }
        return entries.filter { $0.date >= start }
    }
}

extension BodyWeightLog {
    /// 那天已經有的紀錄
    static func existing(on day: Date, in context: ModelContext, calendar: Calendar = .current) -> BodyWeight? {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<BodyWeight>(predicate: #Predicate { $0.date >= start && $0.date < end },
                                                     sortBy: [SortDescriptor(\.date, order: .reverse)])
        return try? context.fetch(descriptor).first
    }

    /// 記錄那天的體重：同一天只保留一筆，已經有的就覆蓋（覆蓋前的確認由畫面負責）
    static func save(kg: Double, on day: Date, in context: ModelContext, calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let sameDay = (try? context.fetch(FetchDescriptor<BodyWeight>(predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
        if let first = sameDay.first {
            first.kg = kg
            sameDay.dropFirst().forEach(context.delete)
        } else {
            context.insert(BodyWeight(date: day, kg: kg))
        }
        try? context.save()
    }
}
