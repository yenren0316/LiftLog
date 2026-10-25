import Foundation

/// 動作在一次訓練裡的角色（CHANGE_04）
nonisolated enum Role: String, Codable, CaseIterable, Identifiable {
    case explosive, main, unilateral, push, pull, core, accessory, cardio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explosive: "爆發"
        case .main: "主項"
        case .unilateral: "單邊"
        case .push: "推"
        case .pull: "拉"
        case .core: "核心"
        case .accessory: "補強"
        case .cardio: "有氧"
        }
    }

    /// 完整說明；第一句是簡短說明
    var guide: String {
        switch self {
        case .main: "雙邊、能承受大重量，是最大肌力的主要來源。以漸進加重為目標，做 5×5，或逐組加重到當天的 MAX。"
        case .unilateral: "重點是平衡、控制和左右差異，不追求重量。用中等重量，每邊 7–10 下 × 3 組。"
        case .explosive: "重點是速度。用 60–70% 的重量，每組 3–5 下，組間休息充足；動作變慢就停，不要做到力竭。放在訓練最前面。"
        case .push, .pull: "上肢主項，以漸進加重為目標。有推就有拉，水平和垂直輪流。"
        case .core: "以穩定為目的，動作品質優先於重量。"
        case .accessory: "小肌群，10–12 下 × 3 組。"
        case .cardio: "放在最後，延續上次的坡度、速度和時間。"
        }
    }

    var shortGuide: String {
        guard let end = guide.firstIndex(of: "。") else { return guide }
        return String(guide[...end])
    }

    /// 沒有上一次紀錄時的預設組數
    var defaultSets: Int {
        switch self {
        case .main, .explosive, .push, .pull: 5
        case .unilateral, .core, .accessory: 3
        case .cardio: 1
        }
    }

    /// 休息計時的預設秒數（動作有個別設定時以個別設定為準）
    var restSeconds: Int {
        switch self {
        case .main, .explosive, .push, .pull: 180
        case .unilateral, .core: 90
        case .accessory, .cardio: 60
        }
    }

    /// 依分類與標籤判定角色，符合第一條就停止
    static func of(category: ExerciseCategory, tags: [ExerciseTag]) -> Role {
        switch category {
        case .cardio: return .cardio
        case .accessory: return .accessory
        case .core: return .core
        case .horizontalPush, .verticalPush: return .push
        case .horizontalPull, .verticalPull: return .pull
        case .kneeDominant, .hipDominant:
            if tags.contains(.explosive) { return .explosive }
            if tags.contains(.unilateral) { return .unilateral }
            return .main
        }
    }
}

/// 一次訓練練的部位
nonisolated enum Region: String, Codable, CaseIterable, Identifiable {
    case upper, lower, full, unspecified

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upper: "上半身"
        case .lower: "下半身"
        case .full: "全身"
        case .unspecified: "未指定"
        }
    }

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
    var defaultRole: Role { Role.of(category: category, tags: tags) }
}

extension SessionExercise {
    /// 舊資料沒有 role 時依動作推算
    var role: Role {
        get { Role(rawValue: roleRaw) ?? exercise?.defaultRole ?? .accessory }
        set { roleRaw = newValue.rawValue }
    }

    /// 休息秒數：動作有個別設定時以個別設定為準，否則依角色
    var restSeconds: Int {
        exercise?.restSeconds ?? role.restSeconds
    }
}

extension WorkoutSession {
    var region: Region {
        get { Region(rawValue: regionRaw) ?? .unspecified }
        set { regionRaw = newValue.rawValue }
    }

    /// 依目前的動作推算部位
    var inferredRegion: Region {
        Region.infer(items.compactMap { $0.exercise?.category })
    }
}
