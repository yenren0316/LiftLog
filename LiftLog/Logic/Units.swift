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

extension WorkoutEntry {
    /// 例如「58.54 kg · 5×5 · MAX」、「輔助 12 kg · 5×5」、「坡度 12%・4.0 km/h・30 分」
    var summary: String {
        var parts: [String] = []
        switch exercise?.logType ?? .weight {
        case .cardio:
            var cardio: [String] = []
            if let incline { cardio.append("坡度 \(Units.number(incline))%") }
            if let speed { cardio.append("\(speed.formatted(.number.precision(.fractionLength(1)))) km/h") }
            if let minutes { cardio.append("\(Units.number(minutes)) 分") }
            return cardio.isEmpty ? "—" : cardio.joined(separator: "・")
        case .assisted:
            if let weightKg { parts.append(weightKg == 0 ? "自重" : "輔助 \(Units.number(weightKg)) kg") }
        case .weight:
            if let weightKg { parts.append("\(Units.number(weightKg)) kg") }
        }
        if exercise?.logType != .cardio {
            switch (reps, sets) {
            case let (r?, s?): parts.append("\(r)×\(s)")
            case let (r?, nil): parts.append("\(r) 下")
            case let (nil, s?): parts.append("\(s) 組")
            default: break
            }
        }
        if isMax { parts.append("MAX") }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}
