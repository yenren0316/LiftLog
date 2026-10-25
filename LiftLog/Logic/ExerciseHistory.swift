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
    func lastSummary(unit: WeightUnit) -> (date: Date, text: String)? {
        guard let item = completedItems.first, let date = item.session?.startedAt else { return nil }
        return (date, SetFormat.compact(item.completedSets.map(\.values), logType: logType, unit: unit))
    }
}

extension SessionExercise {
    func summary(unit: WeightUnit) -> String {
        SetFormat.compact(completedSets.map(\.values), logType: exercise?.logType ?? .weight, unit: unit)
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

extension Exercise {
    /// 有這個動作（而且有完成組）的訓練次數
    var trainingCount: Int {
        sessionItems.filter { !$0.completedSets.isEmpty }.count
    }
}

extension Exercise {
    /// 數據頁用：每次訓練的已完成組，由舊到新
    var sessionSets: [SessionSets] {
        completedItems.reversed().compactMap { item in
            guard let session = item.session else { return nil }
            return SessionSets(sessionID: session.id, date: session.startedAt, sets: item.completedSets.map(\.values))
        }
    }

    /// 最近 N 天有這個動作的訓練次數
    func trainingCount(withinDays days: Int, now: Date = .now) -> Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        return completedItems.filter { ($0.session?.startedAt ?? .distantPast) >= cutoff }.count
    }
}

/// 一組的「上一次」和灰字預填值
nonisolated struct SetHint {
    var set: SetRecord
    var previous: SetValues?
    var placeholder: SetValues?
}

extension SessionExercise {
    /// 依組的順序算出每一組的「上一次」和預填值（訓練中畫面和即時動態共用）
    func setHints() -> [SetHint] {
        let last = exercise?.lastSets(excluding: session) ?? []
        var prior: SetValues?
        return orderedSets.enumerated().map { index, set in
            let previous = SetLogic.previous(at: index, lastSets: last)
            let placeholder = SetLogic.placeholder(previous: previous, priorInSession: prior)
            prior = SetLogic.resolved(entered: set.values, placeholder: placeholder)
            return SetHint(set: set, previous: previous, placeholder: placeholder)
        }
    }
}

extension WorkoutSession {
    /// 目前的組：依動作順序，第一個還沒打勾的組；全部打勾時為 nil
    var currentSet: (item: SessionExercise, set: SetRecord, index: Int)? {
        let items = orderedItems.filter { $0.exercise != nil }
        guard let position = SetLogic.currentSet(items.map { $0.orderedSets.map(\.isCompleted) }) else { return nil }
        let item = items[position.item]
        return (item, item.orderedSets[position.set], position.set)
    }
}
