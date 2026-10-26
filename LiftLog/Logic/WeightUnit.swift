import Foundation

/// 全域重量單位。資料一律存 kg，只在顯示與輸入時換算。
nonisolated enum WeightUnit: String, CaseIterable, Identifiable, Sendable {
    case kg, lbs

    static let storageKey = "weightUnit"

    /// 設定頁選的單位（不在畫面裡、拿不到 AppStorage 時用）
    static var current: WeightUnit {
        WeightUnit(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .kg
    }

    var id: String { rawValue }
    var symbol: String { rawValue }

    func fromKg(_ kg: Double) -> Double {
        self == .kg ? kg : Units.kgToLbs(kg)
    }

    func toKg(_ value: Double) -> Double {
        self == .kg ? value : Units.lbsToKg(value)
    }

    /// 顯示精度：kg 到小數一位，lbs 到 0.5
    func displayRounded(_ value: Double) -> Double {
        switch self {
        case .kg: (value * 10).rounded() / 10
        case .lbs: (value * 2).rounded() / 2
        }
    }

    /// 把 kg 轉成目前單位的顯示文字（不含單位）：42.6、94、93.5
    func format(kg: Double) -> String {
        Units.number(displayRounded(fromKg(kg)))
    }

    /// 「42.6 kg」
    func formatWithUnit(kg: Double) -> String {
        "\(format(kg: kg)) \(symbol)"
    }

    /// 欄位標題：kg、lbs，啞鈴／壺鈴加「（單顆）」
    func columnTitle(equipment: Equipment) -> String {
        switch equipment {
        case .dumbbell, .kettlebell: "\(symbol)（單顆）"
        default: symbol
        }
    }
}
