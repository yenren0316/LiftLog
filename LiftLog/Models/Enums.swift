import Foundation

/// 怪獸訓練的動作分類，依此順序顯示
nonisolated enum ExerciseCategory: String, Codable, CaseIterable, Identifiable {
    case kneeDominant, hipDominant
    case horizontalPush, horizontalPull, verticalPush, verticalPull
    case core, accessory, cardio

    var id: String { rawValue }

    /// 讀資料庫或舊備份用：CHANGE_04 前的轉體、負重行走、違常姿勢都併入核心
    init?(stored raw: String) {
        switch raw {
        case "rotation", "loadedCarry", "unusualPosture": self = .core
        default: self.init(rawValue: raw)
        }
    }

    var isLower: Bool { self == .kneeDominant || self == .hipDominant }
    var isUpper: Bool { [.horizontalPush, .horizontalPull, .verticalPush, .verticalPull].contains(self) }

    var title: String {
        switch self {
        case .kneeDominant: "下肢推"
        case .hipDominant: "下肢拉"
        case .horizontalPush: "上肢水平推"
        case .horizontalPull: "上肢水平拉"
        case .verticalPush: "上肢垂直推"
        case .verticalPull: "上肢垂直拉"
        case .core: "核心"
        case .accessory: "補強"
        case .cardio: "有氧"
        }
    }

    var subtitle: String? {
        switch self {
        case .kneeDominant: "膝主導"
        case .hipDominant: "髖主導"
        default: nil
        }
    }

    /// 選單用的完整名稱：下肢推（膝主導）
    var fullTitle: String {
        subtitle.map { "\(title)（\($0)）" } ?? title
    }
}

nonisolated enum ExerciseTag: String, Codable, CaseIterable, Identifiable {
    case unilateral, explosive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unilateral: "單邊"
        case .explosive: "爆發"
        }
    }
}

nonisolated enum Equipment: String, Codable, CaseIterable, Identifiable {
    case barbell, dumbbell, kettlebell, machine, cable, bodyweight, box, ball, bar, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .barbell: "槓鈴"
        case .dumbbell: "啞鈴"
        case .kettlebell: "壺鈴"
        case .machine: "機械"
        case .cable: "Cable"
        case .bodyweight: "自重"
        case .box: "跳箱"
        case .ball: "抗力球"
        case .bar: "單槓"
        case .other: "其他"
        }
    }

    /// 重量欄位旁的提示，提醒記錄時的慣例
    var weightHint: String? {
        switch self {
        case .dumbbell, .kettlebell: "單手"
        case .machine: "單邊"
        default: nil
        }
    }
}

nonisolated enum LogType: String, Codable, CaseIterable, Identifiable {
    case weight, assisted, bodyweight, timed, cardio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "重量 × 次 × 組"
        case .assisted: "輔助重量"
        case .bodyweight: "自重次數（負重選填）"
        case .timed: "計時（秒）"
        case .cardio: "有氧"
        }
    }
}

nonisolated enum SetKind: String, Codable, CaseIterable, Identifiable {
    case normal, warmup, max

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal: "正式"
        case .warmup: "熱身"
        case .max: "MAX"
        }
    }

    /// 組號欄的顯示：正式組顯示序號，熱身 W，MAX M
    func badge(number: Int) -> String {
        switch self {
        case .normal: String(number)
        case .warmup: "W"
        case .max: "M"
        }
    }
}
