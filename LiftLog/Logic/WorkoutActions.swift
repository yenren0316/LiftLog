import Foundation
import SwiftData

/// 訓練的操作。每次修改後立即存檔。
enum WorkoutActions {
    static func activeSession(in context: ModelContext) -> WorkoutSession? {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endedAt == nil })
        return try? context.fetch(descriptor).first
    }

    /// 開始新訓練。呼叫前要先確認沒有進行中的訓練。
    @discardableResult
    static func start(with exercises: [Exercise], in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(startedAt: .now, title: SessionTitle.automatic(exercises.map(\.name)))
        context.insert(session)
        for exercise in exercises {
            _ = add(exercise, to: session, in: context, updateTitle: false)
        }
        save(context)
        return session
    }

    /// 加入動作；已經在這次訓練裡就直接回傳那張卡片。
    /// 組數照上次紀錄（至少一組），讓「上一次」欄可以逐組對應
    static func add(_ exercise: Exercise, to session: WorkoutSession, in context: ModelContext,
                    updateTitle: Bool = true) -> SessionExercise {
        if let existing = session.items.first(where: { $0.exercise === exercise }) {
            return existing
        }
        let before = names(session)
        let item = SessionExercise(session: session, exercise: exercise, order: (session.items.map(\.order).max() ?? -1) + 1)
        context.insert(item)
        let count = max(1, exercise.lastSets(excluding: session).count)
        for i in 0..<count {
            context.insert(SetRecord(sessionExercise: item, order: i, kind: kindForNewSet(exercise, index: i, session: session)))
        }
        if updateTitle { refreshTitle(session, before: before) }
        save(context)
        return item
    }

    /// 新的組沿用上次同一組的種類（例如上次第一組是熱身）
    private static func kindForNewSet(_ exercise: Exercise, index: Int, session: WorkoutSession) -> SetKind {
        SetLogic.previous(at: index, lastSets: exercise.lastSets(excluding: session))?.kind ?? .normal
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

    static func replace(_ item: SessionExercise, with exercise: Exercise, in context: ModelContext) {
        guard let session = item.session else { return }
        let before = names(session)
        item.exercise = exercise
        refreshTitle(session, before: before)
        save(context)
    }

    static func move(_ item: SessionExercise, by offset: Int, in context: ModelContext) {
        guard let session = item.session else { return }
        var items = session.orderedItems
        guard let index = items.firstIndex(where: { $0 === item }),
              items.indices.contains(index + offset) else { return }
        let before = names(session)
        items.swapAt(index, index + offset)
        for (i, it) in items.enumerated() { it.order = i }
        refreshTitle(session, before: before)
        save(context)
    }

    static func remove(_ item: SessionExercise, in context: ModelContext) {
        guard let session = item.session else { return }
        let before = names(session)
        context.delete(item)
        for (i, it) in session.orderedItems.filter({ $0 !== item }).enumerated() { it.order = i }
        refreshTitle(session, before: before, excluding: item)
        save(context)
    }

    /// 完成訓練：處理未打勾的組、移除沒有完成組的動作、寫入 endedAt。
    /// 回傳 false 代表沒有任何完成的組，整次訓練已刪除。
    @discardableResult
    static func finish(_ session: WorkoutSession, choice: SetLogic.IncompleteChoice, in context: ModelContext) -> Bool {
        let now = Date.now
        var remaining: [SessionExercise] = []
        for item in session.orderedItems {
            let sets = item.orderedSets
            let kept: [SetRecord]
            switch choice {
            case .deleteIncomplete:
                for set in sets where !set.isCompleted { context.delete(set) }
                kept = sets.filter(\.isCompleted)
            case .completeAll:
                for set in sets where !set.isCompleted {
                    set.isCompleted = true
                    set.completedAt = now
                }
                kept = sets
            }
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

    // MARK: - 標題

    private static func names(_ session: WorkoutSession, excluding: SessionExercise? = nil) -> [String] {
        session.orderedItems.filter { $0 !== excluding && !$0.isDeleted }.compactMap { $0.exercise?.name }
    }

    /// 標題還是自動產生的才跟著動作更新；使用者改過就不動
    private static func refreshTitle(_ session: WorkoutSession, before: [String], excluding: SessionExercise? = nil) {
        guard session.title.isEmpty || session.title == SessionTitle.automatic(before) else { return }
        session.title = SessionTitle.automatic(names(session, excluding: excluding))
    }

    private static func renumber(_ sets: [SetRecord]) {
        for (i, set) in sets.enumerated() { set.order = i }
    }
}
