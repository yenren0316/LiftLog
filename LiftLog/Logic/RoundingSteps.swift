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
}
