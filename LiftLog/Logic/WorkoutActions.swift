import Foundation
import SwiftData

/// 訓練的操作。每次修改後立即存檔。
enum WorkoutActions {
    static func activeSession(in context: ModelContext) -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endedAt == nil })
        return try? context.fetch(descriptor).first
    }

    /// 開始新訓練：只由 WorkoutLauncher 呼叫，呼叫前要先確認沒有進行中的訓練（補登除外）。
    /// 從建立菜單來的會帶日型與每一格的角色；部位在完成時依動作推算。
    /// backfill 有值時是補登：建立一次已結束的訓練（不會出現在進行中，也不會有休息計時和即時動態）
    @discardableResult
    static func start(with exercises: [Exercise], roles: [Role]? = nil, dayType: DayType? = nil,
                      backfill: DateInterval? = nil, in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(startedAt: backfill?.start ?? .now, endedAt: backfill?.end, dayType: dayType)
        context.insert(session)
        for (index, exercise) in exercises.enumerated() {
            _ = add(exercise, to: session, role: roles?[index], in: context, updateTitle: false)
        }
        session.refreshAutomaticTitle()
        save(context)
        return session
    }

    /// 加入動作；已經在這次訓練裡就直接回傳那張卡片。role 為 nil 時依動作判定。
    /// 組數照上次紀錄，讓「上一次」欄可以逐組對應；沒有上次紀錄時依角色的預設參數。
    /// DE 速度主項的組數固定（深蹲 8、硬舉 6、臥推 8）
    static func add(_ exercise: Exercise, to session: WorkoutSession, role: Role? = nil, in context: ModelContext,
                    updateTitle: Bool = true) -> SessionExercise {
        if let existing = session.items.first(where: { $0.exercise === exercise }) {
            return existing
        }
        let item = SessionExercise(session: session, exercise: exercise, order: (session.items.map(\.order).max() ?? -1) + 1,
                                   role: role)
        context.insert(item)
        let last = exercise.prefillSets(excluding: session, role: item.role)
        let prescription = item.prescription
        let count = prescription.fixedReps != nil || last.isEmpty ? prescription.setCount : last.count
        for i in 0..<count {
            let kind = SetLogic.previous(at: i, lastSets: last)?.kind ?? .normal
            context.insert(SetRecord(sessionExercise: item, order: i, kind: kind))
        }
        if updateTitle { session.refreshAutomaticTitle() }
        save(context)
        return item
    }

    /// 打勾：沒輸入的欄位用預填值；必要欄位不齊時不完成，回傳 false。
    /// 訓練中畫面的 ✓、即時動態的「完成這組」和歷史訓練的 ✓ 都走這裡
    @discardableResult
    static func complete(_ set: SetRecord, placeholder: SetValues?, in context: ModelContext) -> Bool {
        guard apply(placeholder, toComplete: set, at: completionDate(in: set.sessionExercise?.session)) else { return false }
        save(context)
        return true
    }

    /// CHANGE_08 §1：已結束的訓練（包括補登）裡，沒打勾、但已經填了數字的組。
    /// 只列照 ✓ 的規則（沒輸入的欄位用預填值）能完成的組；完全沒填數字的組不列
    static func filledIncompleteSets(in session: WorkoutSession) -> [(set: SetRecord, placeholder: SetValues?)] {
        guard !session.isActive else { return [] }
        return session.orderedItems.flatMap { item -> [(set: SetRecord, placeholder: SetValues?)] in
            guard let exercise = item.exercise else { return [] }
            return item.setHints().compactMap { hint in
                guard !hint.set.isCompleted, SetLogic.hasEnteredValues(hint.set.values) else { return nil }
                let values = SetLogic.resolved(entered: hint.set.values, placeholder: hint.placeholder)
                guard SetLogic.canComplete(values, logType: exercise.logType, equipment: exercise.equipment) else { return nil }
                return (hint.set, hint.placeholder)
            }
        }
    }

    /// 捨棄訓練的確認（CHANGE_10 §0-3）：「取消」不改任何資料，「捨棄訓練」才刪除
    enum DiscardChoice {
        case cancel, discard
    }

    /// 回傳是否刪除了
    @discardableResult
    static func resolveDiscard(_ choice: DiscardChoice, session: WorkoutSession, in context: ModelContext) -> Bool {
        guard choice == .discard else { return false }
        discard(session, in: context)
        return true
    }

    /// 編輯已結束的訓練按「完成」、有沒打勾但填了數字的組時的三個選項（CHANGE_08 §1、CHANGE_09 §0-1）
    enum FilledSetsChoice {
        /// 把這些組標為完成，關閉編輯畫面
        case complete
        /// 不改資料，關閉編輯畫面
        case keepIncomplete
        /// 不改資料，留在編輯畫面
        case continueEditing
    }

    /// 依選項處理沒打勾但填了數字的組；回傳要不要關閉編輯畫面
    @discardableResult
    static func resolveFilledSets(_ choice: FilledSetsChoice, in session: WorkoutSession, context: ModelContext) -> Bool {
        switch choice {
        case .complete:
            completeFilledSets(in: session, context: context)
            return true
        case .keepIncomplete:
            return true
        case .continueEditing:
            return false
        }
    }

    /// 把 filledIncompleteSets 標為完成，完成時間記成那次訓練的結束時間；回傳標了幾組
    @discardableResult
    static func completeFilledSets(in session: WorkoutSession, context: ModelContext) -> Int {
        // 預填要在改動之前算好：後面的組會沿用前一組的值
        let pending = filledIncompleteSets(in: session)
        let date = completionDate(in: session)
        let count = pending.filter { apply($0.placeholder, toComplete: $0.set, at: date) }.count
        save(context)
        return count
    }

    /// 完成時間：進行中的訓練是現在；在已結束的歷史訓練裡打勾，記成那次訓練的時間，
    /// 不然那個動作的「幾天前」會變成今天
    static func completionDate(in session: WorkoutSession?, now: Date = .now) -> Date {
        guard let session, !session.isActive else { return now }
        return session.endedAt ?? session.startedAt
    }

    /// 用輸入（沒輸入的欄位用預填值）把這組標成完成；必要欄位不齊時不改任何東西，回傳 false
    private static func apply(_ placeholder: SetValues?, toComplete set: SetRecord, at date: Date) -> Bool {
        guard let exercise = set.sessionExercise?.exercise else { return false }
        let values = SetLogic.resolved(entered: set.values, placeholder: placeholder)
        guard SetLogic.canComplete(values, logType: exercise.logType, equipment: exercise.equipment) else { return false }
        set.weightKg = values.weightKg
        set.reps = values.reps
        set.incline = values.incline
        set.speed = values.speed
        set.minutes = values.minutes
        set.seconds = values.seconds
        set.isCompleted = true
        set.completedAt = date
        return true
    }

    static func addSet(to item: SessionExercise, in context: ModelContext) {
        let order = (item.sets.map(\.order).max() ?? -1) + 1
        context.insert(SetRecord(sessionExercise: item, order: order))
        save(context)
    }

    static func delete(_ set: SetRecord, in context: ModelContext) {
        let item = set.sessionExercise
        context.delete(set)
        if let item { renumber(item.orderedSets.filter { $0 !== set }) }
        save(context)
    }

    /// 換動作；role 為 nil 時保留原本的角色（位置不變）
    static func replace(_ item: SessionExercise, with exercise: Exercise, role: Role? = nil, in context: ModelContext) {
        guard let session = item.session else { return }
        item.exercise = exercise
        if let role { item.role = role }
        session.refreshAutomaticTitle()
        save(context)
    }

    static func move(_ item: SessionExercise, by offset: Int, in context: ModelContext) {
        guard let session = item.session else { return }
        var items = session.orderedItems
        guard let index = items.firstIndex(where: { $0 === item }),
              items.indices.contains(index + offset) else { return }
        items.swapAt(index, index + offset)
        for (i, it) in items.enumerated() { it.order = i }
        session.refreshAutomaticTitle()
        save(context)
    }

    static func remove(_ item: SessionExercise, in context: ModelContext) {
        guard let session = item.session else { return }
        context.delete(item)
        for (i, it) in session.orderedItems.filter({ $0 !== item }).enumerated() { it.order = i }
        session.refreshAutomaticTitle(excluding: item)
        save(context)
    }

    /// 完成訓練：處理未打勾的組、移除沒有完成組的動作、寫入 endedAt。
    /// 「全部標為完成」和直接按 ✓ 一樣，沒輸入的欄位用灰字預填；連預填都不夠的組（例如第一次做的動作沒填數字）刪除。
    /// 回傳 false 代表沒有任何完成的組，整次訓練已刪除。
    @discardableResult
    static func finish(_ session: WorkoutSession, choice: SetLogic.IncompleteChoice, in context: ModelContext) -> Bool {
        let now = Date.now
        var remaining: [SessionExercise] = []
        for item in session.orderedItems {
            let sets = item.orderedSets
            if choice == .completeAll {
                // 預填要在改動之前算好：後面的組會沿用前一組的值
                let placeholders = Dictionary(uniqueKeysWithValues: item.setHints().map { ($0.set.id, $0.placeholder) })
                for set in sets where !set.isCompleted {
                    _ = apply(placeholders[set.id] ?? nil, toComplete: set, at: now)
                }
            }
            for set in sets where !set.isCompleted { context.delete(set) }
            let kept = sets.filter(\.isCompleted)
            if kept.isEmpty {
                context.delete(item)
            } else {
                renumber(kept)
                remaining.append(item)
            }
        }
        guard !remaining.isEmpty else {
            context.delete(session)
            save(context)
            return false
        }
        for (i, item) in remaining.enumerated() { item.order = i }
        if session.modeID == nil {
            session.region = Region.infer(remaining.compactMap { $0.exercise?.category })
        }
        // 只做有氧的訓練不算日型
        if !remaining.contains(where: { $0.exercise?.category != .cardio }) {
            session.dayType = nil
        }
        session.refreshAutomaticTitle()
        session.endedAt = now
        save(context)
        return true
    }

    static func discard(_ session: WorkoutSession, in context: ModelContext) {
        context.delete(session)
        save(context)
    }

    static func save(_ context: ModelContext) {
        try? context.save()
    }

    private static func renumber(_ sets: [SetRecord]) {
        for (i, set) in sets.enumerated() { set.order = i }
    }
}
