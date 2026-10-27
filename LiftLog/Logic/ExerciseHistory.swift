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

    /// 上次紀錄：最近一次「已結束」訓練中的這個動作。指定 session（進行中或正在編輯的那次）時，
    /// 只取那次訓練開始「之前」的紀錄，編輯過去的訓練才不會拿到之後的紀錄。
    /// 速度和最大重量的數字差很多：DE 主項只看上次 DE；ME 主項先看上次 ME，沒有就看 DE 以外的紀錄
    func lastItem(excluding session: WorkoutSession? = nil, role: Role? = nil) -> SessionExercise? {
        let ended = completedItems.filter { item in
            guard let s = item.session, s !== session, !s.isActive else { return false }
            return session.map { s.startedAt < $0.startedAt } ?? true
        }
        switch role {
        case .dynamicEffort?: return ended.first { $0.role == .dynamicEffort }
        case .maxEffort?: return ended.first { $0.role == .maxEffort } ?? ended.first { $0.role != .dynamicEffort }
        default: return ended.first
        }
    }

    /// 「上一次」欄與預填用的組：上次紀錄中已完成的組，依順序
    func lastSets(excluding session: WorkoutSession? = nil, role: Role? = nil) -> [SetValues] {
        lastItem(excluding: session, role: role)?.completedSets.map(\.values) ?? []
    }

    /// 已結束訓練裡的紀錄，由新到舊（ME 紀錄、建議重量用）；指定 session 時只取那次開始之前的
    func logs(excluding session: WorkoutSession? = nil) -> [ExerciseLog] {
        completedItems.compactMap { item in
            guard let s = item.session, s !== session, !s.isActive, session.map({ s.startedAt < $0.startedAt }) ?? true
            else { return nil }
            return ExerciseLog(date: s.startedAt, role: item.role, sets: item.completedSets.map(\.values))
        }
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
    /// 依組的順序算出每一組的「上一次」和預填值（訓練中畫面和即時動態共用）。
    /// DE 速度主項有建議重量時（CHANGE_10 §0-5），每一組都灰字預填建議重量和固定次數（輸入過的組往下沿用）
    func setHints() -> [SetHint] {
        let last = exercise?.lastSets(excluding: session, role: role) ?? []
        var prior: SetValues?
        var prefillFrom = last
        if let reps = prescription.fixedReps, let weight = advice(unit: .current).speedWeightKg {
            prior = SetValues(weightKg: weight, reps: reps)
            prefillFrom = []
        } else if last.isEmpty, let reps = prescription.fixedReps {
            prior = SetValues(reps: reps)
        }
        return orderedSets.enumerated().map { index, set in
            let previous = SetLogic.previous(at: index, lastSets: last)
            let placeholder = SetLogic.placeholder(previous: SetLogic.previous(at: index, lastSets: prefillFrom),
                                                   priorInSession: prior)
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

extension SessionExercise {
    /// 預設參數和建議重量（訓練中畫面、預填用）
    func advice(unit: WeightUnit) -> SlotAdvice {
        guard let exercise else { return SlotAdvice(prescription: prescription) }
        return SlotAdvice.make(role: role, exercise: PlanExercise(exercise), logs: exercise.logs(excluding: session), unit: unit)
    }
}

extension Exercise {
    /// 首頁動作清單：上次日期，加上「主」動作的最近一次 ME 紀錄（還沒有 ME 紀錄時和其他動作一樣顯示上次紀錄）
    func homeSummary(unit: WeightUnit) -> (date: Date, text: String)? {
        guard let last = lastSummary(unit: unit) else { return nil }
        guard tags.contains(.main), let record = MaxEffortRecords.records(logs()).first else { return last }
        return (last.date, "ME \(unit.formatWithUnit(kg: record.weightKg)) × \(record.reps)・估 1RM \(unit.formatWithUnit(kg: record.estimated1RM))")
    }
}
