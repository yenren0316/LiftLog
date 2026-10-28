import Foundation

/// 訓練中鍵盤上緣的候選列（CHANGE_11 §4-2，取代 -2.5／+2.5／+5、下一格、完成的鍵盤列）：
/// 像輸入法的選字列，5 個數字，點一下填入這一格並跳到下一格
nonisolated enum SetCandidates {
    static let count = 5

    struct Candidate: Equatable, Sendable {
        /// 顯示單位（kg 或 lbs）的數字；次數欄是整數
        var value: Double
        /// 建議重量（DE 速度主項），用強調色並在下方加「建議」
        var isSuggested = false
    }

    /// kg 欄：以這一格目前的值為中心，空的時候用灰字預填的值，兩個都沒有時不顯示（空陣列）。
    /// 有建議重量時一定包含它；其餘依進位從「−1 步、目前值、+1 步、+2 步、+3 步」依序補滿 5 個，去掉重複，由小到大。
    /// 不能記負數的動作不列負數，往後多補一步。數字都是顯示單位（lbs 模式時是 lb，step 也是 lb）
    static func weight(current: Double?, placeholder: Double?, suggested: Double?, step: Double,
                       allowsNegative: Bool = false) -> [Candidate] {
        guard let center = current ?? placeholder, step > 0 else { return [] }
        var result: [Candidate] = []
        func contains(_ value: Double) -> Bool { result.contains { same($0.value, value) } }
        if let suggested { result.append(Candidate(value: rounded(suggested), isSuggested: true)) }
        var offset = -1
        // 不能記負數時最多往後多找幾步（目前值是 0 時 −1 步不列）
        while result.count < count, offset <= count + 1 {
            let value = rounded(center + Double(offset) * step)
            offset += 1
            guard allowsNegative || value >= 0, !contains(value) else { continue }
            result.append(Candidate(value: value))
        }
        return result.sorted { $0.value < $1.value }
    }

    /// 次數欄：以這一格的處方次數為中心的 5 個連續整數，最小是 1。處方是範圍時以中間為中心（8～12 下 → 8～12）；
    /// 沒有處方次數（有氧、舊角色的「主項」）時不顯示
    static func reps(prescribed: ClosedRange<Int>?) -> [Candidate] {
        guard let prescribed else { return [] }
        let center = (prescribed.lowerBound + prescribed.upperBound) / 2
        let start = max(1, center - count / 2)
        return (start..<start + count).map { Candidate(value: Double($0)) }
    }

    /// 浮點數的加減會有誤差（42.5 − 2.5 × 3），比較和顯示前先取到 0.001
    private static func rounded(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000
    }

    private static func same(_ a: Double, _ b: Double) -> Bool {
        abs(a - b) < 0.0005
    }
}
