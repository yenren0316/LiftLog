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

    /// 「上一次」（CHANGE_10 §0-6）：最近一次「已結束」訓練中的這個動作。指定 session（進行中或正在編輯的那次）時，
    /// 只取那次訓練開始「之前」的紀錄，編輯過去的訓練才不會拿到之後的紀錄（CHANGE_07 A-4）。
    /// 優先找同一個角色的紀錄；同角色沒有紀錄時，改用任何角色最近的一次，otherRole 是那次的角色（「40×3・ME」）。
    /// role 為 nil 時取最近的一次
    func previousItem(excluding session: WorkoutSession? = nil, role: Role? = nil) -> (item: SessionExercise, otherRole: Role?)? {
        let ended = completedItems.filter { item in
            guard let s = item.session, s !== session, !s.isActive else { return false }
            return session.map { s.startedAt < $0.startedAt } ?? true
        }
        guard let role else { return ended.first.map { ($0, nil) } }
        if let same = ended.first(where: { $0.role == role }) { return (same, nil) }
        return ended.first.map { ($0, $0.role) }
    }

    /// 上次紀錄的這個動作（previousItem 的規則）
    func lastItem(excluding session: WorkoutSession? = nil, role: Role? = nil) -> SessionExercise? {
        previousItem(excluding: session, role: role)?.item
    }

    /// 上次紀錄中已完成的組，依順序
    func lastSets(excluding session: WorkoutSession? = nil, role: Role? = nil) -> [SetValues] {
        lastItem(excluding: session, role: role)?.completedSets.map(\.values) ?? []
    }

    /// 預填和組數用的上次的組：ME、DE 主項不拿其他角色的紀錄（速度和最大重量的數字差很多），
    /// 只在「上一次」欄顯示；其他角色照樣用
    func prefillSets(excluding session: WorkoutSession? = nil, role: Role?) -> [SetValues] {
        guard let found = previousItem(excluding: session, role: role) else { return [] }
        if found.otherRole != nil, role == .maxEffort || role == .dynamicEffort { return [] }
        return found.item.completedSets.map(\.values)
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
    /// 「上一次」來自其他角色時，那次的角色（「40×3・ME」）；同角色為 nil
    var previousRole: Role? = nil
    var placeholder: SetValues?
}

extension SessionExercise {
    /// 依組的順序算出每一組的「上一次」和預填值（訓練中畫面和即時動態共用）。
    /// DE 速度主項有建議重量時（CHANGE_10 §0-5），每一組都灰字預填建議重量和固定次數（輸入過的組往下沿用）
    /// 「上一次」同角色優先，沒有就用其他角色最近的一次並標出角色（CHANGE_10 §0-6）
    func setHints() -> [SetHint] {
        let found = exercise?.previousItem(excluding: session, role: role)
        let last = found?.item.completedSets.map(\.values) ?? []
        var prior: SetValues?
        var prefillFrom = exercise?.prefillSets(excluding: session, role: role) ?? []
        if let reps = prescription.fixedReps, let weight = advice(unit: .current).speedWeightKg {
            prior = SetValues(weightKg: weight, reps: reps)
            prefillFrom = []
        } else if prefillFrom.isEmpty, let reps = prescription.fixedReps {
            prior = SetValues(reps: reps)
        }
        return orderedSets.enumerated().map { index, set in
            let previous = SetLogic.previous(at: index, lastSets: last)
            let placeholder = SetLogic.placeholder(previous: SetLogic.previous(at: index, lastSets: prefillFrom),
                                                   priorInSession: prior)
            prior = SetLogic.resolved(entered: set.values, placeholder: placeholder)
            return SetHint(set: set, previous: previous, previousRole: previous == nil ? nil : found?.otherRole,
                           placeholder: placeholder)
        }
    }
}

extension SetRecord {
    /// 這一組的灰字預填值（和訓練畫面同一份 setHints）：打勾時沒輸入的欄位用它，即時動態也用它顯示要記錄的值
    var placeholder: SetValues? {
        sessionExercise?.setHints().first { $0.set === self }?.placeholder
    }
}

extension WorkoutSession {
    /// 目前的組（即時動態的「下一組」）：依動作順序，第一個還沒打勾的組；全部打勾時為 nil
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
