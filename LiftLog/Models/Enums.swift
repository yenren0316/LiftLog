import Foundation

/// 怪獸訓練的動作分類，依此順序顯示
nonisolated enum ExerciseCategory: String, Codable, CaseIterable, Identifiable {
    case kneeDominant, hipDominant
    case horizontalPush, horizontalPull, verticalPush, verticalPull
    case rotation, loadedCarry, unusualPosture, accessory, cardio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kneeDominant: "下肢推"
        case .hipDominant: "下肢拉"
        case .horizontalPush: "上肢水平推"
        case .horizontalPull: "上肢水平拉"
        case .verticalPush: "上肢垂直推"
        case .verticalPull: "上肢垂直拉"
        case .rotation: "轉體"
        case .loadedCarry: "負重行走"
        case .unusualPosture: "違常姿勢"
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
    case barbell, dumbbell, kettlebell, machine, cable, bodyweight, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .barbell: "槓鈴"
        case .dumbbell: "啞鈴"
        case .kettlebell: "壺鈴"
        case .machine: "機械"
        case .cable: "Cable"
        case .bodyweight: "自重"
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
    case weight, assisted, cardio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "重量 × 次 × 組"
        case .assisted: "輔助重量"
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

nonisolated enum RestDefaults {
    /// 上下肢推拉六類 180 秒，其他 90 秒
    static func seconds(for category: ExerciseCategory) -> Int {
        switch category {
        case .kneeDominant, .hipDominant, .horizontalPush, .horizontalPull, .verticalPush, .verticalPull: 180
        default: 90
        }
    }
}
