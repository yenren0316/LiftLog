import Foundation
import SwiftData

/// 動作在一次訓練裡的角色。共軛訓練用前八個；主項、爆發、單邊是 CHANGE_04 的角色，只出現在舊紀錄
nonisolated enum Role: String, Codable, CaseIterable, Identifiable {
    case maxEffort, dynamicEffort, lowerAssist, push, pull, core, accessory, cardio
    case main, explosive, unilateral

    var id: String { rawValue }

    /// CHANGE_04 的角色，共軛訓練不再指定
    var isLegacy: Bool { self == .main || self == .explosive || self == .unilateral }

    var title: String {
        switch self {
        case .maxEffort: "ME 主項"
        case .dynamicEffort: "DE 主項"
        case .lowerAssist: "下肢輔助"
        case .push: "推"
        case .pull: "拉"
        case .core: "核心"
        case .accessory: "補強"
        case .cardio: "有氧"
        case .main: "主項"
        case .explosive: "爆發"
        case .unilateral: "單邊"
        }
    }

    /// 「上一次」欄的小字（「40×3・ME」）：主項用 ME／DE，其他和名稱一樣
    var shortTitle: String {
        switch self {
        case .maxEffort: "ME"
        case .dynamicEffort: "DE"
        default: title
        }
    }

    /// 完整說明；第一句是簡短說明
    var guide: String {
        switch self {
        case .maxEffort: "最大肌力：逐步加重到當天的 3RM（早安式做到 5RM），組間充分休息。一定要設好安全槓。"
        case .dynamicEffort: "速度：槓鈴動作用約 1RM 的 60%，每下都盡量快；爆發動作做到速度掉了就停，不要做到力竭。"
        case .lowerAssist: "補主項沒練到的方向，單邊優先。3–4 組 × 8–12 下，休息 60–90 秒。"
        case .push: "上肢輔助的推。3–4 組 × 8–12 下，休息 60–90 秒。"
        case .pull: "上肢輔助的拉，水平和垂直輪流。3–4 組 × 8–12 下，休息 60–90 秒。"
        case .core: "以穩定為目的，動作品質優先於重量。2–3 組 × 10–15 下或 30–45 秒，休息 45–60 秒。"
        case .accessory: "小肌群。2–3 組 × 10–15 下，休息 45–60 秒。"
        case .cardio: "放在最後。30 分鐘，坡度和速度沿用上次。"
        case .main: "雙邊、能承受大重量，是最大肌力的主要來源。以漸進加重為目標，做 5×5，或逐組加重到當天的 MAX。"
        case .unilateral: "重點是平衡、控制和左右差異，不追求重量。用中等重量，每邊 7–10 下 × 3 組。"
        case .explosive: "重點是速度。用 60–70% 的重量，每組 3–5 下，組間休息充足；動作變慢就停，不要做到力竭。放在訓練最前面。"
        }
    }

    /// 動態島左側的圖示（SF Symbols）
    var symbol: String {
        switch self {
        case .maxEffort, .main: "dumbbell.fill"
        case .dynamicEffort, .explosive: "bolt.fill"
        case .lowerAssist, .unilateral: "figure.strengthtraining.functional"
        case .push: "arrow.up.circle.fill"
        case .pull: "arrow.down.circle.fill"
        case .core: "figure.core.training"
        case .accessory: "plus.circle.fill"
        case .cardio: "figure.run"
        }
    }

    var shortGuide: String {
        guard let end = guide.firstIndex(of: "。") else { return guide }
        return String(guide[...end])
    }

    /// 不是從建立菜單加入的動作（空白訓練、訓練中新增）依分類決定角色；ME、DE 只由建立菜單指定
    static func of(category: ExerciseCategory) -> Role {
        switch category {
        case .cardio: .cardio
        case .accessory: .accessory
        case .core: .core
        case .horizontalPush, .verticalPush: .push
        case .horizontalPull, .verticalPull: .pull
        case .kneeDominant, .hipDominant: .lowerAssist
        }
    }
}

/// 依角色和動作決定的預設參數（共軛訓練第 5 節）
nonisolated struct Prescription: Equatable, Sendable {
    /// 「8 組 × 2 下」
    var volume: String
    /// 「休息 45–60 秒」「充分休息」；有氧為 nil
    var rest: String?
    /// 「設好安全槓」「速度掉了就停」
    var tip: String?
    /// 新增到訓練時的組數
    var setCount: Int
    var restSeconds: Int
    /// DE 速度主項固定的組數和次數：上一次紀錄的組數不適用，預填的次數用這個
    var fixedReps: Int?

    /// DE 主項沒有「爆」標籤的就是速度主項（同一個槓鈴動作用速度做）
    static func isSpeed(role: Role, tags: [ExerciseTag]) -> Bool {
        role == .dynamicEffort && !tags.contains(.explosive)
    }

    static func of(role: Role, name: String, tags: [ExerciseTag]) -> Prescription {
        switch role {
        case .maxEffort:
            return Prescription(volume: "逐步加重到當天 \(maxEffortRM(name))RM", rest: "充分休息", tip: "設好安全槓", setCount: 5,
                                restSeconds: 180)
        case .dynamicEffort where isSpeed(role: role, tags: tags):
            let (sets, reps) = speedVolume(name)
            return Prescription(volume: "\(sets) 組 × \(reps) 下", rest: "休息 45–60 秒", setCount: sets, restSeconds: 60,
                                fixedReps: reps)
        case .dynamicEffort:
            let reps = name.contains("壺鈴擺盪") ? "8–10" : "3–5"
            return Prescription(volume: "6–8 組 × \(reps) 下", rest: "休息 60–90 秒", tip: "速度掉了就停", setCount: 6, restSeconds: 90)
        case .lowerAssist, .push, .pull:
            return Prescription(volume: "3–4 組 × 8–12 下", rest: "休息 60–90 秒", setCount: 3, restSeconds: 90)
        case .core, .accessory:
            return Prescription(volume: "2–3 組 × 10–15 下，或 30–45 秒", rest: "休息 45–60 秒", setCount: 3, restSeconds: 60)
        case .cardio:
            return Prescription(volume: "\(cardioMinutes) 分鐘，坡度和速度沿用上次", setCount: 1, restSeconds: 60)
        case .main, .explosive:
            return Prescription(volume: "5 組", rest: "休息 180 秒", setCount: 5, restSeconds: 180)
        case .unilateral:
            return Prescription(volume: "3 組 × 每邊 7–10 下", rest: "休息 90 秒", setCount: 3, restSeconds: 90)
        }
    }

    /// ME 主項做到當天幾 RM：早安式 5RM，其他 3RM（「下一次」卡的「做到 3RM」也用它）
    static func maxEffortRM(_ name: String) -> Int {
        name.contains("早安") ? 5 : 3
    }

    /// 有氧（跑步機）的預設分鐘數
    static let cardioMinutes = 30

    /// DE 速度主項：深蹲 8 × 2、硬舉 6 × 1、臥推 8 × 3；其他槓鈴動作 6 × 2
    private static func speedVolume(_ name: String) -> (sets: Int, reps: Int) {
        if name.contains("硬舉") { return (6, 1) }
        if name.contains("臥推") { return (8, 3) }
        if name.contains("蹲") { return (8, 2) }
        return (6, 2)
    }

    /// 「8 組 × 2 下・休息 45–60 秒」「逐步加重到當天 3RM・充分休息」
    var summary: String {
        [volume, rest].compactMap { $0 }.joined(separator: "・")
    }
}

nonisolated extension Region {
    /// 只看上肢和下肢分類的動作，不看核心、補強、有氧
    static func infer(_ categories: [ExerciseCategory]) -> Region {
        let lower = categories.contains(where: \.isLower)
        let upper = categories.contains(where: \.isUpper)
        switch (upper, lower) {
        case (true, true): return .full
        case (true, false): return .upper
        case (false, true): return .lower
        case (false, false): return .unspecified
        }
    }
}

extension Exercise {
    var defaultRole: Role { Role.of(category: category) }
}

extension SessionExercise {
    /// 舊資料沒有 role 時依動作推算
    var role: Role {
        get { Role(rawValue: roleRaw) ?? exercise?.defaultRole ?? .accessory }
        set { roleRaw = newValue.rawValue }
    }

    var prescription: Prescription {
        Prescription.of(role: role, name: exercise?.name ?? "", tags: exercise?.tags ?? [])
    }

    /// 休息秒數：動作有個別設定時以個別設定為準，否則依角色
    var restSeconds: Int {
        exercise?.restSeconds ?? prescription.restSeconds
    }
}

extension WorkoutSession {
    var region: Region {
        get { Region(rawValue: regionRaw) ?? .unspecified }
        set { regionRaw = newValue.rawValue }
    }

    var dayType: DayType? {
        get { dayTypeRaw.flatMap(DayType.init(rawValue:)) }
        set { dayTypeRaw = newValue?.rawValue }
    }

    /// 自動產生的名稱（訓練目的，CHANGE_07 C-5）；excluding 是正在刪除的動作
    func automaticTitle(excluding: SessionExercise? = nil) -> String {
        let items = orderedItems.filter { $0 !== excluding && !$0.isDeleted }
        let main = items.first { $0.role == .maxEffort || $0.role == .dynamicEffort }?.exercise?.name
        return SessionTitle.purpose(dayType: dayType, mainName: main, categories: items.compactMap { $0.exercise?.category })
    }

    /// 沒有自訂名稱時，名稱跟著動作和日型更新
    func refreshAutomaticTitle(excluding: SessionExercise? = nil) {
        guard !isTitleCustom else { return }
        title = automaticTitle(excluding: excluding)
    }

    /// 使用者在名稱欄位輸入：有字就是自訂名稱，留空就恢復自動名稱
    func setTitle(fromUserInput text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isTitleCustom = !trimmed.isEmpty
        title = trimmed.isEmpty ? automaticTitle() : text
    }

    /// 「恢復自動名稱」
    func restoreAutomaticTitle() {
        isTitleCustom = false
        title = automaticTitle()
    }
}
