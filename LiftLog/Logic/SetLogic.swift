import Foundation

/// 一組的數值（不依賴 SwiftData，方便測試）
nonisolated struct SetValues: Equatable, Sendable {
    var kind: SetKind = .normal
    var weightKg: Double?
    var reps: Int?
    var incline: Double?
    var speed: Double?
    var minutes: Double?
    var isCompleted = false
    var completedAt: Date?
}

nonisolated enum SetLogic {
    // MARK: 上一次與預填

    /// 「上一次」依組的順序對應上次紀錄的同一組；沒有對應的組為 nil
    static func previous(at index: Int, lastSets: [SetValues]) -> SetValues? {
        lastSets.indices.contains(index) ? lastSets[index] : nil
    }

    /// 灰字預填值：有「上一次」就用它，沒有就用本次前一組（已輸入或已預填的值）
    static func placeholder(previous: SetValues?, priorInSession: SetValues?) -> SetValues? {
        previous ?? priorInSession
    }

    /// 打勾時採用的值：有輸入用輸入，沒輸入用預填
    static func resolved(entered: SetValues, placeholder: SetValues?) -> SetValues {
        var v = entered
        v.weightKg = entered.weightKg ?? placeholder?.weightKg
        v.reps = entered.reps ?? placeholder?.reps
        v.incline = entered.incline ?? placeholder?.incline
        v.speed = entered.speed ?? placeholder?.speed
        v.minutes = entered.minutes ?? placeholder?.minutes
        return v
    }

    /// 打勾需要的欄位是否齊全；不齊全時該列晃動、不標記完成
    static func canComplete(_ v: SetValues, logType: LogType, equipment: Equipment) -> Bool {
        switch logType {
        case .cardio:
            return v.minutes != nil
        case .assisted:
            return v.weightKg != nil && v.reps != nil
        case .weight:
            // 自重動作（反式划船等）不一定有重量
            return v.reps != nil && (v.weightKg != nil || equipment == .bodyweight)
        }
    }

    // MARK: 完成訓練

    enum IncompleteChoice {
        case deleteIncomplete
        case completeAll
    }

    /// 完成訓練時處理未打勾的組。回傳每個動作保留下來的組；沒有任何已完成組的動作回傳空陣列（之後移除）
    static func finish(_ items: [[SetValues]], choice: IncompleteChoice, now: Date) -> [[SetValues]] {
        items.map { sets in
            switch choice {
            case .deleteIncomplete:
                return sets.filter(\.isCompleted)
            case .completeAll:
                return sets.map { s in
                    var s = s
                    if !s.isCompleted {
                        s.isCompleted = true
                        s.completedAt = now
                    }
                    return s
                }
            }
        }
    }

    // MARK: 新紀錄

    /// 計算新紀錄用的組：已完成的正式組或 MAX 組，不含熱身
    static func countsForRecord(_ s: SetValues) -> Bool {
        s.isCompleted && s.kind != .warmup && s.weightKg != nil
    }

    /// 這次訓練的最佳值（weight 型取最重，assisted 型取輔助最少）
    static func best(_ sets: [SetValues], logType: LogType) -> Double? {
        let weights = sets.filter(countsForRecord).compactMap(\.weightKg)
        switch logType {
        case .weight: return weights.max()
        case .assisted: return weights.min()
        case .cardio: return nil
        }
    }

    /// 新紀錄：這次的最佳值超越以往所有紀錄。沒有歷史紀錄時不算新紀錄。
    static func isNewRecord(session: [SetValues], history: [SetValues], logType: LogType) -> Bool {
        guard let now = best(session, logType: logType),
              let before = best(history, logType: logType)
        else { return false }
        switch logType {
        case .weight: return now > before
        case .assisted: return now < before
        case .cardio: return false
        }
    }

    // MARK: 幾天前

    /// 只計算已完成的組
    static func lastCompletedDate(_ sets: [SetValues]) -> Date? {
        sets.filter(\.isCompleted).compactMap(\.completedAt).max()
    }
}

nonisolated enum SetFormat {
    /// 精簡格式：
    /// - 每組相同：「42.6 kg × 5 下 × 5 組」（只有一組時省略組數）
    /// - 每組不同：「60×5、65×3、70×1 (MAX)」
    /// - 跑步機：「坡度 12%・4.0 km/h・30 分」
    /// 熱身組不列入
    static func compact(_ sets: [SetValues], logType: LogType) -> String {
        let working = sets.filter { $0.kind != .warmup }
        guard !working.isEmpty else { return "—" }

        if logType == .cardio {
            return working.map(cardio).joined(separator: "、")
        }

        let first = working[0]
        let allSame = working.allSatisfy { $0.weightKg == first.weightKg && $0.reps == first.reps && $0.kind == first.kind }
        if allSame {
            var parts: [String] = []
            if let w = first.weightKg { parts.append(weightText(w, logType: logType)) }
            if let r = first.reps { parts.append("\(r) 下") }
            if working.count > 1 { parts.append("\(working.count) 組") }
            var text = parts.isEmpty ? "\(working.count) 組" : parts.joined(separator: " × ")
            if first.kind == .max { text += " (MAX)" }
            return text
        }

        let prefix = logType == .assisted ? "輔助 " : ""
        return prefix + working.map { s in
            let w = s.weightKg.map(Units.number) ?? "—"
            let r = s.reps.map(String.init) ?? "—"
            return "\(w)×\(r)" + (s.kind == .max ? " (MAX)" : "")
        }.joined(separator: "、")
    }

    static func cardio(_ s: SetValues) -> String {
        var parts: [String] = []
        if let incline = s.incline { parts.append("坡度 \(Units.number(incline))%") }
        if let speed = s.speed { parts.append("\(speed.formatted(.number.precision(.fractionLength(1)))) km/h") }
        if let minutes = s.minutes { parts.append("\(Units.number(minutes)) 分") }
        return parts.isEmpty ? "—" : parts.joined(separator: "・")
    }

    /// 「上一次」欄的短格式：60 × 5、輔助 12 × 5
    static func short(_ s: SetValues, logType: LogType) -> String {
        if logType == .cardio {
            // 欄位窄，只放數字：12%·4.0·30′
            var parts: [String] = []
            if let incline = s.incline { parts.append("\(Units.number(incline))%") }
            if let speed = s.speed { parts.append(speed.formatted(.number.precision(.fractionLength(1)))) }
            if let minutes = s.minutes { parts.append("\(Units.number(minutes))′") }
            return parts.isEmpty ? "—" : parts.joined(separator: "·")
        }
        let w = s.weightKg.map(Units.number)
        let r = s.reps.map(String.init)
        switch (w, r) {
        case let (w?, r?): return "\(w) × \(r)"
        case let (w?, nil): return w
        case let (nil, r?): return "\(r) 下"
        default: return "—"
        }
    }

    private static func weightText(_ w: Double, logType: LogType) -> String {
        if logType == .assisted {
            return w == 0 ? "自重" : "輔助 \(Units.number(w)) kg"
        }
        return "\(Units.number(w)) kg"
    }
}

nonisolated enum SessionTitle {
    /// 動作名稱以「＋」連接；超過 3 個時顯示前兩個加「等 N 項」
    static func automatic(_ names: [String]) -> String {
        if names.count > 3 {
            return names.prefix(2).joined(separator: "＋") + " 等 \(names.count) 項"
        }
        return names.joined(separator: "＋")
    }
}
