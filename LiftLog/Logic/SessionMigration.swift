import Foundation

/// 把舊格式（一筆紀錄 = 一個動作一天）轉成「訓練 → 動作 → 組」
nonisolated enum SessionMigration {
    struct LegacyEntry: Sendable {
        var date: Date
        var exerciseID: UUID
        var weightKg: Double?
        var sets: Int?
        var reps: Int?
        var isMax: Bool
        var incline: Double?
        var speed: Double?
        var minutes: Double?
        var note: String
        var healthWorkoutID: UUID?

        var isCardio: Bool { incline != nil || speed != nil || minutes != nil }
    }

    struct PlannedSet: Equatable, Sendable {
        var values: SetValues
        var healthWorkoutID: UUID?
    }

    struct PlannedItem: Sendable {
        var exerciseID: UUID
        var note: String
        var sets: [PlannedSet]
    }

    struct PlannedSession: Sendable {
        var startedAt: Date
        var items: [PlannedItem]
    }

    /// 展開規則：
    /// - 跑步機：一組，存坡度、速度、分鐘
    /// - MAX：一組 MAX；不知道次數記 1 下
    /// - 「AxB」：B 組，每組 A 下，重量相同
    /// - 只知道組數：B 組，次數空白；只知道次數或都不知道：一組，保留已知欄位
    /// 匯入的組一律已完成，completedAt 為該次訓練的日期
    static func expand(_ e: LegacyEntry, completedAt: Date) -> [PlannedSet] {
        func set(_ kind: SetKind, reps: Int?) -> PlannedSet {
            PlannedSet(values: SetValues(kind: kind, weightKg: e.weightKg, reps: reps, incline: e.incline,
                                         speed: e.speed, minutes: e.minutes, isCompleted: true, completedAt: completedAt),
                       healthWorkoutID: e.healthWorkoutID)
        }
        if e.isCardio {
            return [set(.normal, reps: nil)]
        }
        if e.isMax {
            return [set(.max, reps: e.reps ?? 1)]
        }
        if let count = e.sets, count > 0 {
            return Array(repeating: set(.normal, reps: e.reps), count: count)
        }
        return [set(.normal, reps: e.reps)]
    }

    /// 依日期分組成訓練；同一天同一個動作合併成一張卡片（例如「35 3x5 + 30 3x2」），順序照原本的順序
    static func plan(_ entries: [LegacyEntry], calendar: Calendar = .current) -> [PlannedSession] {
        let byDay = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) }
        return byDay.keys.sorted().map { day in
            let dayEntries = byDay[day]!.sorted { $0.date < $1.date }
            let startedAt = dayEntries[0].date
            var items: [PlannedItem] = []
            for e in dayEntries {
                let sets = expand(e, completedAt: startedAt)
                if let i = items.firstIndex(where: { $0.exerciseID == e.exerciseID }) {
                    items[i].sets += sets
                    if !e.note.isEmpty {
                        items[i].note = [items[i].note, e.note].filter { !$0.isEmpty }.joined(separator: "；")
                    }
                } else {
                    items.append(PlannedItem(exerciseID: e.exerciseID, note: e.note, sets: sets))
                }
            }
            return PlannedSession(startedAt: startedAt, items: items)
        }
    }
}
