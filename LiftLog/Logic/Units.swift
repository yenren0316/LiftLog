import Foundation

nonisolated enum Units {
    static let kgPerLb = 0.45359237

    static func lbsToKg(_ lbs: Double) -> Double { lbs * kgPerLb }
    static func kgToLbs(_ kg: Double) -> Double { kg / kgPerLb }

    /// 最多兩位小數，去掉多餘的 0：60.8、58.54、100
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
