import Foundation

// 建立菜單（CHANGE_04 第 3 節）：三個問題的預設值、組合模式、候選動作排序。
// 全部是純邏輯，輸入是訓練紀錄的快照，方便測試。

// MARK: - 輸入

/// 已結束訓練的快照
nonisolated struct PlanHistory: Sendable {
    struct Item: Sendable {
        var exerciseID: UUID
        var category: ExerciseCategory
        var role: Role
    }

    struct Session: Sendable {
        var date: Date
        var region: Region
        var items: [Item]
    }

    /// 由新到舊
    let sessions: [Session]

    init(_ sessions: [Session]) {
        self.sessions = sessions.sorted { $0.date > $1.date }
    }

    static func windowStart(now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now)) ?? now
    }

    /// 近 30 天有幾次訓練符合條件
    func sessionCount(within now: Date, where match: (Item) -> Bool) -> Int {
        let start = Self.windowStart(now: now)
        return sessions.filter { $0.date >= start && $0.items.contains(where: match) }.count
    }

    /// 最近一次有符合條件的訓練日期
    func lastDate(where match: (Item) -> Bool) -> Date? {
        sessions.first { $0.items.contains(where: match) }?.date
    }
}

/// 候選動作的快照
nonisolated struct PlanExercise: Sendable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var category: ExerciseCategory
    var tags: [ExerciseTag]
    var isArchived = false
    var lastDate: Date?

    var role: Role { Role.of(category: category, tags: tags) }
}

// MARK: - 第一步：三個問題

nonisolated struct PlanAnswers: Equatable, Sendable {
    var region: Region
    var count: Int
    var cardio: Bool

    /// 全身沒有 1 個動作
    static func countOptions(for region: Region) -> [Int] {
        region == .full ? [2, 3] : [1, 2, 3]
    }

    /// 換部位時，把動作數調整到可選的範圍
    mutating func setRegion(_ region: Region) {
        self.region = region
        if !Self.countOptions(for: region).contains(count) { count = 2 }
    }
}

nonisolated enum PlanDefaults {
    /// 沒有任何紀錄時的動作數
    static let countWithoutHistory = 3

    /// 上一次部位不是「未指定」的訓練
    static func lastRegionSession(_ history: PlanHistory) -> PlanHistory.Session? {
        history.sessions.first { $0.region != .unspecified }
    }

    static func answers(_ history: PlanHistory) -> PlanAnswers {
        var answers = PlanAnswers(region: region(history), count: countWithoutHistory, cardio: false)
        // 動作數：上次的動作數，不計有氧，限制在 1–3
        if let last = history.sessions.first(where: { $0.items.contains { $0.role != .cardio } }) {
            answers.count = min(max(last.items.filter { $0.role != .cardio }.count, 1), 3)
        }
        if answers.region == .full && answers.count == 1 { answers.count = 2 }
        answers.cardio = history.sessions.first?.items.contains { $0.role == .cardio } ?? false
        return answers
    }

    /// 和上一次相反；上次全身就選上半身、下半身中比較久沒練的；沒有紀錄時下半身
    static func region(_ history: PlanHistory) -> Region {
        switch lastRegionSession(history)?.region {
        case .upper: return .lower
        case .lower: return .upper
        case .full:
            let upper = history.sessions.first { $0.region == .upper }?.date
            let lower = history.sessions.first { $0.region == .lower }?.date
            switch (upper, lower) {
            case (nil, .some): return .upper
            case let (.some(u), .some(l)) where u < l: return .upper
            default: return .lower
            }
        default:
            return .lower
        }
    }
}

// MARK: - 第二步：組合模式

/// 菜單裡的一個位置
nonisolated enum Slot: String, Hashable, Sendable {
    case explosive, main, unilateral, push, pull, pushOrPull, core, accessory, cardio

    var title: String {
        switch self {
        case .pushOrPull: "推或拉"
        default: role.title
        }
    }

    /// 寫入 SessionExercise 的角色；「推或拉」依選到的動作決定
    var role: Role {
        switch self {
        case .explosive: .explosive
        case .main: .main
        case .unilateral: .unilateral
        case .push, .pushOrPull: .push
        case .pull: .pull
        case .core: .core
        case .accessory: .accessory
        case .cardio: .cardio
        }
    }

    func role(for exercise: PlanExercise) -> Role {
        self == .pushOrPull ? exercise.role : role
    }

    func accepts(_ role: Role) -> Bool {
        self == .pushOrPull ? (role == .push || role == .pull) : role == self.role
    }
}

nonisolated struct PlanMode: Identifiable, Equatable, Sendable {
    var id: String
    /// "A"、"B"；只有一個模式時為 nil
    var variant: String?
    var slots: [Slot]
}

nonisolated enum PlanModes {
    static func modes(region: Region, count: Int) -> [PlanMode] {
        switch (region, count) {
        case (.lower, 1): [PlanMode(id: "lower1", slots: [.main])]
        case (.lower, 2): [PlanMode(id: "lower2", slots: [.main, .unilateral])]
        case (.lower, 3): [PlanMode(id: "lower3A", variant: "A", slots: [.explosive, .main, .unilateral]),
                           PlanMode(id: "lower3B", variant: "B", slots: [.main, .unilateral, .core])]
        case (.upper, 1): [PlanMode(id: "upper1", slots: [.pushOrPull])]
        case (.upper, 2): [PlanMode(id: "upper2", slots: [.push, .pull])]
        case (.upper, 3): [PlanMode(id: "upper3A", variant: "A", slots: [.push, .pull, .core]),
                           PlanMode(id: "upper3B", variant: "B", slots: [.push, .pull, .accessory])]
        case (.full, 2): [PlanMode(id: "full2", slots: [.main, .pushOrPull])]
        case (.full, 3): [PlanMode(id: "full3A", variant: "A", slots: [.main, .pushOrPull, .core]),
                          PlanMode(id: "full3B", variant: "B", slots: [.explosive, .main, .pushOrPull])]
        default: []
        }
    }

    /// A、B 中不同的角色，近 30 天出現在比較少次訓練的那個模式；次數相同時 A
    static func recommended(_ modes: [PlanMode], history: PlanHistory, now: Date = .now) -> PlanMode? {
        guard modes.count == 2 else { return modes.first }
        let (a, b) = (modes[0], modes[1])
        let onlyA = Set(a.slots.map(\.role)).subtracting(b.slots.map(\.role))
        let onlyB = Set(b.slots.map(\.role)).subtracting(a.slots.map(\.role))
        func fewest(_ roles: Set<Role>) -> Int {
            roles.map { role in history.sessionCount(within: now) { $0.role == role } }.min() ?? .max
        }
        return fewest(onlyB) < fewest(onlyA) ? b : a
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
    /// 排序的優先群組：rank 越小越前面；reason 是排第一的原因
    private struct Preference {
        var rank: (PlanExercise) -> Int
        var reason: String?
    }

    static func candidates(for slot: Slot, exercises: [PlanExercise], history: PlanHistory,
                           excluding: Set<UUID> = [], mainCategory: ExerciseCategory? = nil,
                           now: Date = .now) -> RankedCandidates {
        let pool = exercises.filter { !$0.isArchived && slot.accepts($0.role) && !excluding.contains($0.id) }
        let preference = preference(for: slot, history: history, mainCategory: mainCategory, now: now)
        let sorted = pool.sorted { a, b in
            let (ra, rb) = (preference.rank(a), preference.rank(b))
            if ra != rb { return ra < rb }
            // 同條件下最久沒做的在前；未練過的視為最久沒做
            switch (a.lastDate, b.lastDate) {
            case (nil, nil): break
            case (nil, _): return true
            case (_, nil): return false
            case let (da?, db?) where da != db: return da < db
            default: break
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        let items = sorted.map { PlanCandidate(exercise: $0, daysSince: Recency.daysSince($0.lastDate, now: now)) }
        guard let first = items.first else { return RankedCandidates(items: [], reason: nil) }
        let reason: String
        if preference.rank(first.exercise) == 0, let preferred = preference.reason {
            reason = preferred
        } else if let days = first.daysSince {
            reason = "最久沒做：\(days) 天"
        } else {
            reason = "新動作：還沒練過"
        }
        return RankedCandidates(items: items, reason: reason)
    }

    private static func preference(for slot: Slot, history: PlanHistory, mainCategory: ExerciseCategory?,
                                   now: Date) -> Preference {
        switch slot {
        case .main:
            return alternation(history)
        case .push:
            return direction([.horizontalPush, .verticalPush], history: history, now: now)
        case .pull:
            return direction([.horizontalPull, .verticalPull], history: history, now: now)
        case .pushOrPull:
            let push = direction([.horizontalPush, .verticalPush], history: history, now: now)
            let pull = direction([.horizontalPull, .verticalPull], history: history, now: now)
            let pushFirst = sideOrder(history: history, now: now)
            let first = pushFirst.push ? push : pull
            return Preference(
                rank: { exercise in
                    let isPush = exercise.role == .push
                    let side = isPush == pushFirst.push ? 0 : 2
                    return side + (isPush ? push : pull).rank(exercise)
                },
                reason: pushFirst.reason ?? first.reason
            )
        case .unilateral:
            guard let mainCategory, mainCategory.isLower else { return Preference(rank: { _ in 0 }) }
            let other: ExerciseCategory = mainCategory == .kneeDominant ? .hipDominant : .kneeDominant
            return Preference(rank: { $0.category == mainCategory ? 1 : 0 },
                              reason: "和主項不同：\(other.subtitle ?? other.title)")
        case .cardio:
            // 固定是跑步機
            return Preference(rank: { $0.name == "跑步機" ? 0 : 1 })
        case .explosive, .core, .accessory:
            return Preference(rank: { _ in 0 })
        }
    }

    /// 主項：和最近一次主項的方向（膝／髖主導）相反；沒有紀錄時最後練習日期比較舊的那一類
    private static func alternation(_ history: PlanHistory) -> Preference {
        let lastMain = history.sessions.lazy.compactMap { s in
            s.items.first { $0.role == .main && $0.category.isLower }
        }.first
        if let last = lastMain?.category {
            let other: ExerciseCategory = last == .kneeDominant ? .hipDominant : .kneeDominant
            return Preference(rank: { $0.category == other ? 0 : 1 }, reason: "交替：上次是\(last.subtitle ?? last.title)")
        }
        let knee = history.lastDate { $0.category == .kneeDominant }
        let hip = history.lastDate { $0.category == .hipDominant }
        guard let older = older(knee, .kneeDominant, hip, .hipDominant) else { return Preference(rank: { _ in 0 }) }
        return Preference(rank: { $0.category == older ? 0 : 1 }, reason: "\(older.subtitle ?? older.title)比較久沒練")
    }

    /// 推、拉：水平和垂直比較近 30 天出現在幾次訓練，少的優先；相同時最後練習日期比較舊的優先
    private static func direction(_ pair: [ExerciseCategory], history: PlanHistory, now: Date) -> Preference {
        let (a, b) = (pair[0], pair[1])
        let countA = history.sessionCount(within: now) { $0.category == a }
        let countB = history.sessionCount(within: now) { $0.category == b }
        let preferred: ExerciseCategory?
        let reason: String?
        if countA != countB {
            preferred = countA < countB ? a : b
            reason = "輪替：近 30 天\(directionTitle(preferred!))比較少"
        } else {
            preferred = older(history.lastDate { $0.category == a }, a, history.lastDate { $0.category == b }, b)
            reason = preferred.map { "輪替：\(directionTitle($0))比較久沒做" }
        }
        guard let preferred else { return Preference(rank: { _ in 0 }) }
        return Preference(rank: { $0.category == preferred ? 0 : 1 }, reason: reason)
    }

    /// 「上肢水平推」→「水平推」
    private static func directionTitle(_ category: ExerciseCategory) -> String {
        category.title.replacingOccurrences(of: "上肢", with: "")
    }

    /// 推或拉：先比較推和拉近 30 天出現在幾次訓練，少的那一邊優先；相同時最後練習日期比較舊的那一邊
    private static func sideOrder(history: PlanHistory, now: Date) -> (push: Bool, reason: String?) {
        let isPush: (PlanHistory.Item) -> Bool = { [.horizontalPush, .verticalPush].contains($0.category) }
        let isPull: (PlanHistory.Item) -> Bool = { [.horizontalPull, .verticalPull].contains($0.category) }
        let pushCount = history.sessionCount(within: now, where: isPush)
        let pullCount = history.sessionCount(within: now, where: isPull)
        if pushCount != pullCount {
            let push = pushCount < pullCount
            return (push, "推拉平衡：近 30 天\(push ? "推" : "拉")比較少")
        }
        let pushDate = history.lastDate(where: isPush)
        let pullDate = history.lastDate(where: isPull)
        switch (pushDate, pullDate) {
        case (nil, nil): return (true, nil)
        case (nil, _): return (true, "推拉平衡：推比較久沒做")
        case (_, nil): return (false, "推拉平衡：拉比較久沒做")
        case let (p?, q?):
            if p == q { return (true, nil) }
            return (p < q, "推拉平衡：\(p < q ? "推" : "拉")比較久沒做")
        }
    }

    /// 兩類中最後練習日期比較舊的（沒練過算最舊）；一樣時回傳 nil
    private static func older(_ dateA: Date?, _ a: ExerciseCategory, _ dateB: Date?, _ b: ExerciseCategory) -> ExerciseCategory? {
        switch (dateA, dateB) {
        case (nil, nil): return nil
        case (nil, _): return a
        case (_, nil): return b
        case let (x?, y?): return x == y ? nil : (x < y ? a : b)
        }
    }

    // MARK: 整份菜單

    struct SlotState: Equatable, Sendable {
        var slot: Slot
        var candidates: RankedCandidates
        /// 目前選的動作；沒有候選時為 nil（這個位置略過）
        var selected: PlanExercise?
    }

    /// 依位置順序決定每個位置的候選與選擇：使用者選過的照用，沒選過的用第一個建議。
    /// 已經在其他位置選了的動作會排除；單邊依這次主項的分類排序
    static func resolve(slots: [Slot], picks: [Int: UUID], exercises: [PlanExercise], history: PlanHistory,
                        now: Date = .now) -> [SlotState] {
        var states: [SlotState] = []
        var taken = Set(picks.values)
        for (index, slot) in slots.enumerated() {
            let excluded = taken.subtracting([picks[index]].compactMap { $0 })
            let mainCategory = zip(slots, states).first { $0.0 == .main }?.1.selected?.category
            let ranked = candidates(for: slot, exercises: exercises, history: history, excluding: excluded,
                                    mainCategory: mainCategory, now: now)
            let selected = picks[index].flatMap { id in ranked.items.first { $0.id == id }?.exercise }
                ?? ranked.items.first?.exercise
            if let selected { taken.insert(selected.id) }
            states.append(SlotState(slot: slot, candidates: ranked, selected: selected))
        }
        return states
    }
}

// MARK: - 從資料庫建立快照

extension PlanHistory {
    init(sessions: [WorkoutSession]) {
        self.init(sessions.filter { !$0.isActive }.map { s in
            Session(date: s.startedAt, region: s.region, items: s.orderedItems.compactMap { item in
                guard let exercise = item.exercise else { return nil }
                return Item(exerciseID: exercise.id, category: exercise.category, role: item.role)
            })
        })
    }
}

extension PlanExercise {
    init(_ exercise: Exercise) {
        self.init(id: exercise.id, name: exercise.name, category: exercise.category, tags: exercise.tags,
                  isArchived: exercise.isArchived, lastDate: exercise.lastCompletedDate)
    }
}
