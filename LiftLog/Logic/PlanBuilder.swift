import Foundation

// 建立菜單（共軛訓練）：三個問題的預設值、依日型和動作數決定的格子、每格的候選排序、主項輪替、ME 紀錄與建議重量。
// 全部是純邏輯，輸入是訓練紀錄的快照，方便測試。

// MARK: - 輸入

/// 已結束訓練的快照
nonisolated struct PlanHistory: Sendable {
    struct Item: Sendable {
        var exerciseID: UUID
        var category: ExerciseCategory
        var tags: [ExerciseTag] = []
        var role: Role
        /// 已完成的組
        var sets: [SetValues] = []
    }

    struct Session: Sendable {
        var id = UUID()
        var date: Date
        /// 訓練名稱（日曆的標籤用）
        var title = ""
        var region: Region = .unspecified
        var dayType: DayType?
        var items: [Item]

        /// 只做有氧的訓練不算重訓
        var isStrength: Bool { items.contains { $0.category != .cardio } }
    }

    /// 由新到舊
    let sessions: [Session]

    init(_ sessions: [Session]) {
        self.sessions = sessions.sorted { $0.date > $1.date }
    }

    /// 近 30 天的起點（RecentWindow：含今天共 30 個日曆日）
    static func windowStart(now: Date, calendar: Calendar = .current) -> Date {
        RecentWindow.start(now: now, calendar: calendar)
    }

    /// 近 30 天有幾次訓練符合條件
    func sessionCount(within now: Date, where match: (Item) -> Bool) -> Int {
        let start = Self.windowStart(now: now)
        return sessions.filter { $0.date >= start && $0.items.contains(where: match) }.count
    }

    /// 近 30 天符合條件的動作完成了幾組（不含熱身）
    func setCount(within now: Date, where match: (Item) -> Bool) -> Int {
        setCount(in: Self.windowStart(now: now)..<Date.distantFuture, where: match)
    }

    /// 這段期間符合條件的動作完成了幾組：打勾的正式組和 MAX 組，不含熱身（sessions 只有已結束的訓練）。
    /// 首頁的近 30 天和「訓練狀態」的本週、上週同期共用這一個
    func setCount(in range: Range<Date>, where match: (Item) -> Bool) -> Int {
        let items: [Item] = sessions.filter { range.contains($0.date) }.flatMap(\.items).filter(match)
        let sets: [SetValues] = items.flatMap(\.sets)
        return sets.filter { $0.isCompleted && $0.kind != .warmup }.count
    }

    /// 這段期間跑步機（有氧分類）完成的分鐘數：歷程的有氧卡和「訓練狀態」共用
    func cardioMinutes(in range: Range<Date>) -> Double {
        let items: [Item] = sessions.filter { range.contains($0.date) }.flatMap(\.items).filter { $0.category == .cardio }
        let sets: [SetValues] = items.flatMap(\.sets)
        return sets.filter(\.isCompleted).compactMap(\.minutes).reduce(0, +)
    }

    /// 某個動作每次訓練的紀錄，由新到舊
    func logs(for exerciseID: UUID) -> [ExerciseLog] {
        sessions.flatMap { s in
            s.items.filter { $0.exerciseID == exerciseID }.map { ExerciseLog(date: s.date, role: $0.role, sets: $0.sets) }
        }
    }
}

/// 一個動作在一次訓練裡的紀錄
nonisolated struct ExerciseLog: Sendable {
    var date: Date
    var role: Role
    var sets: [SetValues]
}

/// 候選動作的快照
nonisolated struct PlanExercise: Sendable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var category: ExerciseCategory
    var tags: [ExerciseTag]
    var isArchived = false
    var lastDate: Date?
    var meRotation: Int?
    var deRotation: Int?
    var logType: LogType = .weight
    /// 建議重量的進位依器材（槓鈴或其他）
    var equipment: Equipment = .other

    func has(_ tag: ExerciseTag) -> Bool { tags.contains(tag) }
}

// MARK: - 第一步：三個問題

nonisolated struct PlanAnswers: Equatable, Sendable {
    var dayType: DayType
    var count: Int
    var cardio: Bool

    static let countOptions = [1, 2, 3]
}

nonisolated enum PlanDefaults {
    /// 沒有任何紀錄時的動作數
    static let countWithoutHistory = 3

    static func answers(_ history: PlanHistory) -> PlanAnswers {
        var answers = PlanAnswers(dayType: dayType(history), count: countWithoutHistory, cardio: false)
        // 動作數：上次重訓的動作數，不計有氧，限制在 1–3
        if let last = history.sessions.first(where: \.isStrength) {
            answers.count = min(max(last.items.filter { $0.category != .cardio }.count, 1), 3)
        }
        answers.cardio = history.sessions.first?.items.contains { $0.category == .cardio } ?? false
        return answers
    }

    /// 最近一次有日型的訓練的下一個日型；只做有氧的訓練和沒有日型的舊紀錄不算，都沒有時從 ME 下肢開始
    static func dayType(_ history: PlanHistory) -> DayType {
        history.sessions.lazy.compactMap(\.dayType).first?.next ?? .meLower
    }
}

// MARK: - 第二步：格子

/// 菜單裡的一格
nonisolated enum Slot: String, Hashable, Sendable, CaseIterable {
    case maxEffort, dynamicEffort, lowerAssist, pull, push, core, accessory, cardio

    var role: Role {
        switch self {
        case .maxEffort: .maxEffort
        case .dynamicEffort: .dynamicEffort
        case .lowerAssist: .lowerAssist
        case .pull: .pull
        case .push: .push
        case .core: .core
        case .accessory: .accessory
        case .cardio: .cardio
        }
    }

    var title: String { role.title }

    static func main(for dayType: DayType) -> Slot {
        dayType.isMaxEffort ? .maxEffort : .dynamicEffort
    }

    /// 訓練中換動作：依卡片的角色找回格子；CHANGE_04 的舊角色當作下肢輔助
    init(role: Role) {
        switch role {
        case .maxEffort: self = .maxEffort
        case .dynamicEffort: self = .dynamicEffort
        case .lowerAssist, .main, .explosive, .unilateral: self = .lowerAssist
        case .pull: self = .pull
        case .push: self = .push
        case .core: self = .core
        case .accessory: self = .accessory
        case .cardio: self = .cardio
        }
    }

    /// 下肢日：主項 → 下肢輔助 → 核心；上肢日：主項 → 拉 → 補強；加跑步機時最後再一格有氧。
    /// 主項本身是拉的動作（DE 上肢的爆發划船）時，「拉」改成「推」
    static func slots(for answers: PlanAnswers, mainCategory: ExerciseCategory?) -> [Slot] {
        let mainIsPull = mainCategory == .horizontalPull || mainCategory == .verticalPull
        let rest: [Slot] = answers.dayType.isLower ? [.lowerAssist, .core] : [mainIsPull ? .push : .pull, .accessory]
        return [main(for: answers.dayType)] + rest.prefix(max(answers.count - 1, 0)) + (answers.cardio ? [.cardio] : [])
    }
}

// MARK: - 第三步：候選動作

nonisolated struct PlanCandidate: Identifiable, Equatable, Sendable {
    var exercise: PlanExercise
    var daysSince: Int?
    var id: UUID { exercise.id }
    /// 未練過的動作標示「新」
    var isNew: Bool { daysSince == nil }
}

nonisolated struct RankedCandidates: Equatable, Sendable {
    var items: [PlanCandidate]
    /// 第一個（建議）的原因
    var reason: String?
}

nonisolated enum PlanRanking {
    /// 建立菜單每格最多顯示幾個候選
    static let visibleCount = 5

    /// 某個日型主項格的第一個建議：「下一次」卡的建議主項、建立菜單主項格預設選的、「訓練狀態」的下次主項都用這個
    static func suggestedMain(for dayType: DayType, exercises: [PlanExercise], history: PlanHistory, now: Date = .now) -> PlanExercise? {
        candidates(for: Slot.main(for: dayType), dayType: dayType, exercises: exercises.filter { !$0.isArchived },
                   history: history, now: now).items.first?.exercise
    }

    /// 某一格的候選：已經選在其他格的動作（excluding）不列入；main 是這次選的主項（下肢輔助依它排序）
    static func candidates(for slot: Slot, dayType: DayType?, exercises: [PlanExercise], history: PlanHistory,
                           excluding: Set<UUID> = [], main: PlanExercise? = nil, now: Date = .now) -> RankedCandidates {
        let pool = exercises.filter { !$0.isArchived && !excluding.contains($0.id) }
        func ranked(_ list: [PlanExercise], reason: (PlanExercise) -> String?) -> RankedCandidates {
            let items = list.map { PlanCandidate(exercise: $0, daysSince: Recency.daysSince($0.lastDate, now: now)) }
            guard let first = items.first else { return RankedCandidates(items: [], reason: nil) }
            return RankedCandidates(items: items, reason: reason(first.exercise) ?? stalenessReason(first))
        }

        switch slot {
        case .maxEffort, .dynamicEffort:
            guard let dayType else { return ranked(sortedByStaleness(pool.filter { $0.has(.main) })) { _ in nil } }
            let rotation = Rotation(slot: slot, dayType: dayType, exercises: pool, history: history)
            return ranked(rotation.order) { _ in rotation.reason }

        case .lowerAssist:
            let list = pool.filter { $0.category.isLower && !$0.has(.main) && !$0.has(.explosive) }
            let mainCategory = main.map(\.category).flatMap { $0.isLower ? $0 : nil }
            let sorted = sortedByStaleness(list) { e in
                [mainCategory == nil || e.category != mainCategory ? 0 : 1, e.has(.unilateral) ? 0 : 1]
            }
            return ranked(sorted) { first in
                var parts: [String] = []
                if let mainCategory, first.category != mainCategory {
                    parts.append("主項是\(mainCategory.subtitle ?? mainCategory.title)，換\(first.category.subtitle ?? first.category.title)")
                }
                if first.has(.unilateral) { parts.append("單邊") }
                return parts.isEmpty ? nil : parts.joined(separator: "・")
            }

        case .pull:
            let list = pool.filter { ($0.category == .horizontalPull || $0.category == .verticalPull) && !$0.has(.explosive) }
            let last = lastPullDirection(history)
            let preferred: ExerciseCategory = last == .horizontalPull ? .verticalPull : .horizontalPull
            let sorted = sortedByStaleness(list) { [$0.category == preferred ? 0 : 1] }
            return ranked(sorted) { first in
                guard first.category == preferred else { return nil }
                guard let last else { return "還沒有拉的紀錄，先做水平拉" }
                return "上次是\(direction(last))拉，這次換\(direction(preferred))"
            }

        case .push:
            let list = pool.filter {
                ($0.category == .horizontalPush || $0.category == .verticalPush) && !$0.has(.main) && !$0.has(.explosive)
            }
            return ranked(sortedByStaleness(list)) { _ in nil }

        case .core:
            return ranked(sortedByStaleness(pool.filter { $0.category == .core })) { _ in nil }

        case .accessory:
            return ranked(sortedByStaleness(pool.filter { $0.category == .accessory })) { _ in nil }

        case .cardio:
            // 固定是跑步機
            let list = pool.filter { $0.category == .cardio }.sorted { ($0.name == "跑步機" ? 0 : 1) < ($1.name == "跑步機" ? 0 : 1) }
            return ranked(list) { _ in "固定是跑步機" }
        }
    }

    /// 依優先條件排序，條件相同時最久沒做的在前（沒練過算最久），再依名稱
    static func sortedByStaleness(_ list: [PlanExercise], keys: (PlanExercise) -> [Int] = { _ in [] }) -> [PlanExercise] {
        list.sorted { a, b in
            let (ka, kb) = (keys(a), keys(b))
            if ka != kb { return ka.lexicographicallyPrecedes(kb) }
            switch (a.lastDate, b.lastDate) {
            case (nil, nil): break
            case (nil, _): return true
            case (_, nil): return false
            case let (da?, db?) where da != db: return da < db
            default: break
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    private static func stalenessReason(_ candidate: PlanCandidate) -> String {
        guard let days = candidate.daysSince else { return "還沒練過" }
        return "最久沒做（\(RelativeDay.text(days))）"
    }

    /// 上次拉的方向：最近一筆角色為「拉」的紀錄的動作分類
    static func lastPullDirection(_ history: PlanHistory) -> ExerciseCategory? {
        for session in history.sessions {
            if let pull = session.items.last(where: { $0.role == .pull }) { return pull.category }
        }
        return nil
    }

    /// 「上肢水平拉」→「水平」
    private static func direction(_ category: ExerciseCategory) -> String {
        category == .verticalPull || category == .verticalPush ? "垂直" : "水平"
    }

    // MARK: 整份菜單

    struct SlotState: Equatable, Sendable {
        var slot: Slot
        var candidates: RankedCandidates
        /// 目前選的動作；沒有候選時為 nil（這一格略過）
        var selected: PlanExercise?
    }

    /// 先決定主項，再依主項決定其他格子（主項是拉的動作時「拉」改成「推」）。
    /// 使用者選過的照用，沒選過的用第一個建議；已經在其他格選了的動作會排除
    static func resolve(answers: PlanAnswers, picks: [Slot: UUID], exercises: [PlanExercise], history: PlanHistory,
                        now: Date = .now) -> [SlotState] {
        let mainSlot = Slot.main(for: answers.dayType)
        var states: [SlotState] = []
        let mainRanked = candidates(for: mainSlot, dayType: answers.dayType, exercises: exercises, history: history,
                                    excluding: Set(picks.filter { $0.key != mainSlot }.values), now: now)
        let main = pick(picks[mainSlot], from: mainRanked)
        states.append(SlotState(slot: mainSlot, candidates: mainRanked, selected: main))

        let slots = Slot.slots(for: answers, mainCategory: main?.category)
        var taken = Set(slots.compactMap { picks[$0] })
        if let main { taken.insert(main.id) }
        for slot in slots.dropFirst() {
            let excluded = taken.subtracting([picks[slot]].compactMap { $0 })
            let ranked = candidates(for: slot, dayType: answers.dayType, exercises: exercises, history: history,
                                    excluding: excluded, main: main, now: now)
            let selected = pick(picks[slot], from: ranked)
            if let selected { taken.insert(selected.id) }
            states.append(SlotState(slot: slot, candidates: ranked, selected: selected))
        }
        return states
    }

    private static func pick(_ id: UUID?, from ranked: RankedCandidates) -> PlanExercise? {
        id.flatMap { id in ranked.items.first { $0.id == id }?.exercise } ?? ranked.items.first?.exercise
    }
}

// MARK: - 主項輪替

/// 每個日型各自的主項輪替：從上次主項的下一個開始照順序排，上次用的排最後；沒有紀錄時從 1 開始
nonisolated struct Rotation {
    /// 輪替表，依順序
    let table: [PlanExercise]
    /// 同日型最近一次訓練的主項（不在輪替表裡時為 nil）
    let last: PlanExercise?

    init(slot: Slot, dayType: DayType, exercises: [PlanExercise], history: PlanHistory) {
        let order: (PlanExercise) -> Int? = { slot == .maxEffort ? $0.meRotation : $0.deRotation }
        table = exercises
            .filter { order($0) != nil && (dayType.isLower ? $0.category.isLower : !$0.category.isLower) }
            .sorted { order($0)! < order($1)! }
        let lastID = Self.lastMainID(dayType: dayType, history: history)
        last = table.first { $0.id == lastID }
    }

    /// 上次主項：同日型最近一次有主項的訓練中，角色為 ME 主項或 DE 主項的動作
    static func lastMainID(dayType: DayType, history: PlanHistory) -> UUID? {
        for session in history.sessions where session.dayType == dayType {
            if let main = session.items.first(where: { $0.role == .maxEffort || $0.role == .dynamicEffort }) {
                return main.exerciseID
            }
        }
        return nil
    }

    var order: [PlanExercise] {
        guard let last, let index = table.firstIndex(of: last) else { return table }
        return Array(table[(index + 1)...] + table[...index])
    }

    var reason: String {
        guard let last else { return "輪替從第 1 個開始" }
        return "輪替的下一個（上次：\(last.name)）"
    }
}

// MARK: - 建議重量

/// 某一格選定動作的建議：重量、參數、提示（建立菜單第三步和訓練中畫面共用）
nonisolated struct SlotAdvice: Equatable, Sendable {
    var prescription: Prescription
    /// 「建議 32.5 kg（60%）」「上次 60 kg」「用能做得很快的重量」
    var weightText: String?
    /// DE 速度主項的建議重量（kg）；沒有可以計算的紀錄時為 nil
    var speedWeightKg: Double?

    /// DE 速度主項的建議重量是強度換算表的 60% 那一列（CHANGE_10 §0-5）：基準是換算表預設的「估算 1RM」，
    /// 用這個動作所有角色的紀錄（以前只看 ME 紀錄，角色是 CHANGE_06 才有的，舊紀錄的主項沒有 ME 紀錄）；
    /// 進位用設定頁的值。step 為 nil 時讀設定
    static func make(role: Role, exercise: PlanExercise, logs: [ExerciseLog], unit: WeightUnit,
                     step: Double? = nil, now: Date = .now) -> SlotAdvice {
        let prescription = Prescription.of(role: role, name: exercise.name, tags: exercise.tags)
        if Prescription.isSpeed(role: role, tags: exercise.tags) {
            let sessions = logs.map { SessionSets(sessionID: UUID(), date: $0.date, sets: $0.sets) }
            let step = step ?? RoundingSteps.step(equipment: exercise.equipment, unit: unit)
            guard let base = IntensityTable.estimatedBase1RMKg(sessions, now: now),
                  let weight = IntensityTable.weightKg(percent: 60, base1RMKg: base, unit: unit, step: step) else {
                return SlotAdvice(prescription: prescription, weightText: "用能做得很快的重量")
            }
            return SlotAdvice(prescription: prescription, weightText: "建議 \(unit.formatWithUnit(kg: weight))（60%）",
                              speedWeightKg: weight)
        }
        guard let last = logs.first(where: { $0.sets.contains(where: \.isCompleted) }) else {
            return SlotAdvice(prescription: prescription)
        }
        let done = last.sets.filter { $0.isCompleted && $0.kind != .warmup }
        if exercise.logType == .cardio {
            return SlotAdvice(prescription: prescription, weightText: done.last.map { "上次 \(SetFormat.cardio($0))" })
        }
        guard let heaviest = done.compactMap(\.weightKg).max() else { return SlotAdvice(prescription: prescription) }
        return SlotAdvice(prescription: prescription, weightText: "上次 \(unit.formatWithUnit(kg: heaviest))")
    }
}

// MARK: - 從資料庫建立快照

nonisolated extension PlanHistory {
    init(sessions: [WorkoutSession]) {
        self.init(sessions.filter { !$0.isActive }.map { s in
            Session(id: s.id, date: s.startedAt, title: s.title.isEmpty ? "訓練" : s.title, region: s.region, dayType: s.dayType,
                    items: s.orderedItems.compactMap { item in
                guard let exercise = item.exercise else { return nil }
                return Item(exerciseID: exercise.id, category: exercise.category, tags: exercise.tags, role: item.role,
                            sets: item.completedSets.map(\.values))
            })
        })
    }
}

nonisolated extension PlanExercise {
    init(_ exercise: Exercise) {
        self.init(snapshotOf: exercise)
        lastDate = exercise.lastCompletedDate
    }

    /// 不算最後日期（StatsCache 自己從訓練紀錄算，比逐一攤平每個動作的組快）
    init(snapshotOf exercise: Exercise) {
        self.init(id: exercise.id, name: exercise.name, category: exercise.category, tags: exercise.tags,
                  isArchived: exercise.isArchived, lastDate: nil,
                  meRotation: exercise.meRotation, deRotation: exercise.deRotation, logType: exercise.logType,
                  equipment: exercise.equipment)
    }
}
