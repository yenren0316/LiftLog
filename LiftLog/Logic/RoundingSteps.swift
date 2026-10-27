import Foundation

/// 強度換算表的進位單位（設定頁可改）
nonisolated enum RoundingSteps {
    static let barbellKgKey = "round.barbell.kg"
    static let barbellLbsKey = "round.barbell.lbs"
    static let otherKgKey = "round.other.kg"
    static let otherLbsKey = "round.other.lbs"
    static let barbellKgDefault = 2.5
    static let barbellLbsDefault = 5.0
    static let otherKgDefault = 1.0
    static let otherLbsDefault = 2.5

    /// 強度換算表的進位單位（設定 → 單位與進位）：槓鈴或其他器材、kg 或 lbs。換算表和 DE 的建議重量共用
    static func step(equipment: Equipment, unit: WeightUnit, defaults: UserDefaults = .standard) -> Double {
        func value(_ key: String, _ fallback: Double) -> Double {
            defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
        }
        switch (equipment == .barbell, unit) {
        case (true, .kg): return value(barbellKgKey, barbellKgDefault)
        case (true, .lbs): return value(barbellLbsKey, barbellLbsDefault)
        case (false, .kg): return value(otherKgKey, otherKgDefault)
        case (false, .lbs): return value(otherLbsKey, otherLbsDefault)
        }
    }
}
