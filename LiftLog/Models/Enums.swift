import Foundation

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, shoulders, back, arms, quads, posterior, core, power, cardio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: "胸"
        case .shoulders: "肩"
        case .back: "背"
        case .arms: "手臂"
        case .quads: "腿前側"
        case .posterior: "臀腿後側"
        case .core: "核心"
        case .power: "爆發／全身"
        case .cardio: "有氧"
        }
    }

    var subtitle: String? {
        switch self {
        case .quads: "膝主導"
        case .posterior: "髖主導"
        default: nil
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
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

enum LogType: String, Codable, CaseIterable, Identifiable {
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
