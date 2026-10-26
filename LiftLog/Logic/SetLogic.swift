import Foundation

/// 一組的數值（不依賴 SwiftData，方便測試）
nonisolated struct SetValues: Equatable, Sendable {
    var kind: SetKind = .normal
    var weightKg: Double?
    var reps: Int?
    var incline: Double?
    var speed: Double?
    var minutes: Double?
    var seconds: Double?
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

    /// 目前的組：依動作順序，第一個還沒打勾的組（第幾個動作、第幾組）；全部打勾時為 nil
    static func currentSet(_ completed: [[Bool]]) -> (item: Int, set: Int)? {
        for (item, sets) in completed.enumerated() {
            if let set = sets.firstIndex(of: false) { return (item, set) }
        }
        return nil
    }

    /// 打勾時採用的值：有輸入用輸入，沒輸入用預填
    static func resolved(entered: SetValues, placeholder: SetValues?) -> SetValues {
        var v = entered
        v.weightKg = entered.weightKg ?? placeholder?.weightKg
        v.reps = entered.reps ?? placeholder?.reps
        v.incline = entered.incline ?? placeholder?.incline
        v.speed = entered.speed ?? placeholder?.speed
        v.minutes = entered.minutes ?? placeholder?.minutes
        v.seconds = entered.seconds ?? placeholder?.seconds
        return v
    }

    /// 自重器材的重量型動作可以記負重（輔助引體向上：輔助 20 kg 記 −20 kg）
    static func allowsNegativeLoad(logType: LogType, equipment: Equipment) -> Bool {
        logType == .weight && equipment == .bodyweight
    }

    /// timed 型的負重是否必填（農夫走路這類負重行走）
    static func timedRequiresLoad(_ equipment: Equipment) -> Bool {
        [.dumbbell, .kettlebell, .barbell].contains(equipment)
    }

    /// 打勾需要的欄位是否齊全；不齊全時該列晃動、不標記完成
    static func canComplete(_ v: SetValues, logType: LogType, equipment: Equipment) -> Bool {
        switch logType {
        case .cardio:
            return v.minutes != nil
        case .assisted:
            return v.weightKg != nil && v.reps != nil
        case .weight:
            // 自重器材的動作不一定有重量
            return v.reps != nil && (v.weightKg != nil || equipment == .bodyweight)
        case .bodyweight:
            return v.reps != nil
        case .timed:
            return v.seconds != nil && (v.weightKg != nil || !timedRequiresLoad(equipment))
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

    // MARK: 新紀錄與趨勢

    /// 一組的成績（越大越好，assisted 例外）：
    /// weight／assisted 用重量；bodyweight 用次數；timed 有負重用負重、沒有用秒數
    static func metric(_ s: SetValues, logType: LogType, loaded: Bool) -> Double? {
        switch logType {
        case .weight, .assisted: s.weightKg
        case .bodyweight: s.reps.map(Double.init)
        case .timed: loaded ? s.weightKg : s.seconds
        case .cardio: nil
        }
    }

    /// 計算紀錄用的組：已完成的正式組或 MAX 組，不含熱身
    static func countsForRecord(_ s: SetValues) -> Bool {
        s.isCompleted && s.kind != .warmup
    }

    static func lowerIsBetter(_ logType: LogType) -> Bool {
        logType == .assisted
    }

    /// 最佳值：weight 取最重，assisted 取輔助最少，bodyweight 取最多次，timed 取最重負重或最長秒數
    static func best(_ sets: [SetValues], logType: LogType) -> Double? {
        let counted = sets.filter(countsForRecord)
        let loaded = counted.contains { $0.weightKg != nil }
        let values = counted.compactMap { metric($0, logType: logType, loaded: loaded) }
        return lowerIsBetter(logType) ? values.min() : values.max()
    }

    /// 新紀錄：這次的最佳值超越以往所有紀錄。沒有歷史紀錄時不算新紀錄。
    static func isNewRecord(session: [SetValues], history: [SetValues], logType: LogType) -> Bool {
        guard logType != .cardio,
              let now = best(session, logType: logType),
              let before = best(history, logType: logType)
        else { return false }
        return lowerIsBetter(logType) ? now < before : now > before
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
    static func compact(_ sets: [SetValues], logType: LogType, unit: WeightUnit = .kg) -> String {
        let working = sets.filter { $0.kind != .warmup }
        guard !working.isEmpty else { return "—" }

        if logType == .cardio {
            return working.map(cardio).joined(separator: "、")
        }

        let first = working[0]
        let allSame = working.allSatisfy {
            $0.weightKg == first.weightKg && $0.reps == first.reps && $0.seconds == first.seconds && $0.kind == first.kind
        }
        if allSame {
            var parts: [String] = []
            if let w = first.weightKg { parts.append(weightText(w, logType: logType, unit: unit)) }
            if logType == .timed {
                if let s = first.seconds { parts.append("\(Units.number(s)) 秒") }
            } else if let r = first.reps {
                parts.append("\(r) 下")
            }
            if working.count > 1 { parts.append("\(working.count) 組") }
            var text = parts.isEmpty ? "\(working.count) 組" : parts.joined(separator: " × ")
            if first.kind == .max { text += " (MAX)" }
            return text
        }

        let prefix = logType == .assisted ? "輔助 " : ""
        return prefix + working.map { s in
            let amount: String = logType == .timed
                ? (s.seconds.map { "\(Units.number($0)) 秒" } ?? "—")
                : (s.reps.map(String.init) ?? "—")
            let text = s.weightKg.map { "\(unit.format(kg: $0))×\(amount)" } ?? amount
            return text + (s.kind == .max ? " (MAX)" : "")
        }.joined(separator: "、")
    }

    static func cardio(_ s: SetValues) -> String {
        var parts: [String] = []
        if let incline = s.incline { parts.append("坡度 \(Units.number(incline))%") }
        if let speed = s.speed { parts.append("\(speed.formatted(.number.precision(.fractionLength(1)))) km/h") }
        if let minutes = s.minutes { parts.append("\(Units.number(minutes)) 分") }
        return parts.isEmpty ? "—" : parts.joined(separator: "・")
    }

    /// 「上一次」欄的短格式：60 × 5、12 (+10)、45″ (+20)
    static func short(_ s: SetValues, logType: LogType, unit: WeightUnit = .kg) -> String {
        let w = s.weightKg.map { unit.format(kg: $0) }
        switch logType {
        case .cardio:
            // 欄位窄，只放數字：12%·4.0·30′
            var parts: [String] = []
            if let incline = s.incline { parts.append("\(Units.number(incline))%") }
            if let speed = s.speed { parts.append(speed.formatted(.number.precision(.fractionLength(1)))) }
            if let minutes = s.minutes { parts.append("\(Units.number(minutes))′") }
            return parts.isEmpty ? "—" : parts.joined(separator: "·")
        case .bodyweight:
            guard let r = s.reps else { return "—" }
            return w.map { "\(r) (+\($0))" } ?? String(r)
        case .timed:
            guard let sec = s.seconds else { return "—" }
            return "\(Units.number(sec))″" + (w.map { " (+\($0))" } ?? "")
        case .weight, .assisted:
            let r = s.reps.map(String.init)
            switch (w, r) {
            case let (w?, r?): return "\(w) × \(r)"
            case let (w?, nil): return w
            case let (nil, r?): return "\(r) 下"
            default: return "—"
            }
        }
    }

    private static func weightText(_ w: Double, logType: LogType, unit: WeightUnit) -> String {
        switch logType {
        case .assisted: w == 0 ? "自重" : "輔助 \(unit.formatWithUnit(kg: w))"
        case .bodyweight, .timed: "+\(unit.formatWithUnit(kg: w))"
        default: unit.formatWithUnit(kg: w)
        }
    }
}

/// 訓練名稱（CHANGE_07 C-5）：自動產生的名稱是訓練目的
nonisolated enum SessionTitle {
    /// 有日型：「下肢最大肌力・深蹲」（主項是角色為 ME／DE 主項的第一個動作，沒有就不加）。
    /// 沒有日型：依上肢和下肢分類的動作推算「下肢訓練／上肢訓練／全身訓練」（忽略核心、補強、有氧）；
    /// 只有有氧「有氧」；沒有任何動作或推算不出來「訓練」
    static func purpose(dayType: DayType?, mainName: String?, categories: [ExerciseCategory]) -> String {
        if let dayType {
            let base = switch dayType {
            case .meLower: "下肢最大肌力"
            case .meUpper: "上肢最大肌力"
            case .deLower: "下肢速度與爆發"
            case .deUpper: "上肢速度與爆發"
            }
            return mainName.map { "\(base)・\($0)" } ?? base
        }
        if !categories.isEmpty, categories.allSatisfy({ $0 == .cardio }) { return "有氧" }
        switch Region.infer(categories) {
        case .lower: return "下肢訓練"
        case .upper: return "上肢訓練"
        case .full: return "全身訓練"
        case .unspecified: return "訓練"
        }
    }

    /// CHANGE_07 之前的自動名稱：動作名稱以「＋」連接；超過 3 個時顯示前兩個加「等 N 項」（舊備份匯入時產生）
    static func legacyAutomatic(_ names: [String]) -> String {
        if names.count > 3 {
            return names.prefix(2).joined(separator: "＋") + " 等 \(names.count) 項"
        }
        return names.joined(separator: "＋")
    }

    /// 名稱符合舊的自動格式：空白、動作名稱（或別名）用「＋」串起來、或「A＋B 等 N 項」
    static func isLegacyAutomatic(_ title: String, exerciseNames: Set<String>) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        var head = trimmed
        if let range = trimmed.range(of: #" 等 \d+ 項$"#, options: .regularExpression) {
            head = String(trimmed[..<range.lowerBound])
        }
        let parts = head.split(separator: "＋").map { $0.trimmingCharacters(in: .whitespaces) }
        return !parts.isEmpty && parts.allSatisfy(exerciseNames.contains)
    }
}
