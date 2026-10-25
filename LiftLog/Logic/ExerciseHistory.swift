import Foundation

/// 從「訓練 → 動作 → 組」推導動作的歷史
extension Exercise {
    /// 所有出現過這個動作、而且有已完成組的訓練項目，由新到舊
    var completedItems: [SessionExercise] {
        sessionItems
            .filter { !$0.completedSets.isEmpty && $0.session != nil }
            .sorted { ($0.session?.startedAt ?? .distantPast) > ($1.session?.startedAt ?? .distantPast) }
    }

    /// 「幾天前」只計算已完成的組
    var lastCompletedDate: Date? {
        SetLogic.lastCompletedDate(sessionItems.flatMap { $0.sets.map(\.values) })
    }

    /// 上次紀錄：最近一次「已結束」訓練中的這個動作（排除指定的訓練，例如進行中的這次）
    func lastItem(excluding session: WorkoutSession? = nil) -> SessionExercise? {
        completedItems.first { $0.session !== session && $0.session?.isActive == false }
    }

    /// 「上一次」欄與預填用的組：上次紀錄中已完成的組，依順序
    func lastSets(excluding session: WorkoutSession? = nil) -> [SetValues] {
        lastItem(excluding: session)?.completedSets.map(\.values) ?? []
    }

    /// 首頁與詳情用的精簡上次紀錄
    var lastSummary: (date: Date, text: String)? {
        guard let item = completedItems.first, let date = item.session?.startedAt else { return nil }
        return (date, SetFormat.compact(item.completedSets.map(\.values), logType: logType))
    }
}

extension SessionExercise {
    var summary: String {
        SetFormat.compact(completedSets.map(\.values), logType: exercise?.logType ?? .weight)
    }
}

extension WorkoutSession {
    var duration: TimeInterval? {
        guard hasTime, let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    /// 1:05:30 或 42:10
    static func format(duration: TimeInterval) -> String {
        let total = max(0, Int(duration))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
