import Foundation

/// 建立菜單（CHANGE_15 §2：一個畫面）的狀態：三個答案和手動換過的格子。
/// 預設值、格子、建議和候選都是原本的函式（PlanDefaults、Slot.slots、PlanRanking.resolve），這裡只管什麼時候保留手動換過的格子：
/// - 改日型：全部格子重新計算
/// - 改動作數、跑步機，或換了某一格（主項換成拉的動作時「拉」會變成「推」）：手動換過、而且還在的格子保留，其他重新計算
nonisolated struct PlanMenu: Sendable {
    let exercises: [PlanExercise]
    let history: PlanHistory
    let now: Date
    private(set) var answers: PlanAnswers
    /// 手動換過的格子（格子 → 動作 id）
    private(set) var picks: [Slot: UUID] = [:]

    /// answers 為 nil 時用預設答案（和「下一次」卡相同）
    init(answers: PlanAnswers? = nil, exercises: [PlanExercise], history: PlanHistory, now: Date = .now) {
        self.exercises = exercises
        self.history = history
        self.now = now
        self.answers = answers ?? PlanDefaults.answers(history)
    }

    /// 每一格：候選、選定的動作（沒換過的是第一個建議）
    var states: [PlanRanking.SlotState] {
        PlanRanking.resolve(answers: answers, picks: picks, exercises: exercises, history: history, now: now)
    }

    mutating func setDayType(_ dayType: DayType) {
        guard dayType != answers.dayType else { return }
        answers.dayType = dayType
        picks = [:]
    }

    mutating func setCount(_ count: Int) {
        answers.count = count
        keepPicksInCurrentSlots()
    }

    mutating func setCardio(_ cardio: Bool) {
        answers.cardio = cardio
        keepPicksInCurrentSlots()
    }

    mutating func pick(_ exerciseID: UUID, for slot: Slot) {
        picks[slot] = exerciseID
        keepPicksInCurrentSlots()
    }

    /// 開始訓練：依格子的順序，選定的動作和格子的角色；沒有候選的格子略過
    var selection: [(exerciseID: UUID, role: Role)] {
        states.compactMap { state in state.selected.map { ($0.id, state.slot.role) } }
    }

    /// 不在現在格子裡的手動選擇丟掉（之後那一格回來時重新計算）
    private mutating func keepPicksInCurrentSlots() {
        let slots = Set(states.map(\.slot))
        picks = picks.filter { slots.contains($0.key) }
    }

    /// 候選的小字（Menu 裡每個候選的第二行）：第一個是建議和原因（RankedCandidates.reason）；
    /// 其他是上次做這個動作是幾天前（PlanCandidate.daysSince），沒練過「還沒練過」
    static func note(for candidate: PlanCandidate, isSuggestion: Bool, reason: String?) -> String {
        if isSuggestion { return ["建議", reason].compactMap { $0 }.joined(separator: "・") }
        return candidate.daysSince.map { RelativeDay.text($0) } ?? "還沒練過"
    }
}

nonisolated extension SlotAdvice {
    /// 處方一行：「8 組 × 3 下・建議 32.5 kg（60%）」「逐步加重到當天 3RM・上次 100 kg」
    var line: String {
        [prescription.volume, weightText].compactMap { $0 }.joined(separator: "・")
    }
}
