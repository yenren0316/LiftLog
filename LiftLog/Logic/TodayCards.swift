import Foundation

// 「今天」的兩張卡（CHANGE_13 §2）：「下一次」卡和「本週」卡要顯示的內容。
// 純邏輯；數字都來自統計快照和建立菜單的共用函式，畫面只排版

/// 「下一次」卡：沒有進行中的訓練時是建立菜單的預設答案，有的話改成顯示這次的訓練
nonisolated enum NextCard {
    /// 進行中的訓練
    struct Active: Equatable, Sendable {
        var dayType: DayType?
        var title: String
        var startedAt: Date
    }

    /// 主項一行：「主項：臥推（速度）・建議 32.5 kg」「主項：深蹲・做到 3RM」「主項：—」
    struct MainLine: Equatable, Sendable {
        /// 主項的名稱，DE 速度主項加「（速度）」；沒有候選時為 nil
        var name: String?
        /// 「建議 32.5 kg」「做到 3RM」
        var detail: String?
        /// detail 是建議重量（強調色，CHANGE_13 §3）；「做到 3RM」不是
        var detailIsSuggestion = false

        var text: String {
            "主項：\(name ?? "—")" + (detail.map { "・\($0)" } ?? "")
        }
    }

    enum Content: Equatable, Sendable {
        /// 下一次：日型、主項一行、「3 個動作・跑步機 30 分鐘」
        case next(dayType: DayType, main: MainLine, volume: String)
        /// 進行中：不顯示下一次的建議
        case active(Active)
    }

    /// main：主項格的第一個建議（PlanRanking.suggestedMain）；mainLogs：它的歷次紀錄（建議重量用）。
    /// step 為 nil 時讀設定頁的進位（和建立菜單同一個 SlotAdvice）
    static func content(active: Active?, answers: PlanAnswers, main: PlanExercise?, mainLogs: [ExerciseLog],
                        unit: WeightUnit, step: Double? = nil, now: Date) -> Content {
        if let active { return .active(active) }
        return .next(dayType: answers.dayType,
                     main: mainLine(dayType: answers.dayType, main: main, logs: mainLogs, unit: unit, step: step, now: now),
                     volume: volumeLine(answers))
    }

    /// DE 速度主項的建議重量和建立菜單同一個函式（SlotAdvice，強度換算表 60%）；沒有可以計算的紀錄時只寫名稱。
    /// ME 寫「做到 3RM」（早安式 5RM）；DE（爆）只寫名稱
    static func mainLine(dayType: DayType, main: PlanExercise?, logs: [ExerciseLog], unit: WeightUnit,
                         step: Double? = nil, now: Date) -> MainLine {
        guard let main else { return MainLine() }
        if dayType.isMaxEffort {
            return MainLine(name: main.name, detail: "做到 \(Prescription.maxEffortRM(main.name))RM")
        }
        guard Prescription.isSpeed(role: .dynamicEffort, tags: main.tags) else { return MainLine(name: main.name) }
        let advice = SlotAdvice.make(role: .dynamicEffort, exercise: main, logs: logs, unit: unit, step: step, now: now)
        return MainLine(name: "\(main.name)（速度）",
                        detail: advice.speedWeightKg.map { "建議 \(unit.formatWithUnit(kg: $0))" },
                        detailIsSuggestion: advice.speedWeightKg != nil)
    }

    /// 「3 個動作・跑步機 30 分鐘」；不加跑步機時「3 個動作」（建立菜單的預設答案和有氧的預設分鐘）
    static func volumeLine(_ answers: PlanAnswers) -> String {
        "\(answers.count) 個動作" + (answers.cardio ? "・跑步機 \(Prescription.cardioMinutes) 分鐘" : "")
    }
}

/// 「本週」卡：週一到週日 7 個圓點、輪替的四個膠囊、很久沒練的分類提醒
nonisolated enum WeekCard {
    struct Day: Equatable, Sendable, Identifiable {
        /// 那天 0 點
        var date: Date
        /// 「一」…「日」
        var label: String
        /// 有完成組的已結束訓練的部位（同一天多次訓練合併）；沒練或今天之後為 nil
        var region: DayRegion?
        var isToday: Bool
        var isFuture: Bool

        var id: Date { date }
    }

    static let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    /// 這一週（週一開始，TrainingCount.weekCalendar）的 7 天。regions：每天 0 點 → 部位（StatsSnapshot.days）
    static func days(regions: [Date: DayRegion], now: Date, calendar: Calendar = .current) -> [Day] {
        let weekCalendar = TrainingCount.weekCalendar(calendar)
        let today = calendar.startOfDay(for: now)
        guard let monday = TrainingCount.weekStart(of: now, calendar: weekCalendar) else { return [] }
        return weekdayLabels.enumerated().compactMap { index, label in
            guard let day = calendar.date(byAdding: .day, value: index, to: monday) else { return nil }
            let isFuture = day > today
            return Day(date: day, label: label, region: isFuture ? nil : regions[day], isToday: day == today, isFuture: isFuture)
        }
    }

    /// 輪替膠囊的標記：排在「下一次」前面的是這一輪練過的（勾勾），後面的不加標記
    enum RotationMark: Equatable, Sendable {
        case done, next, upcoming
    }

    /// 依輪替順序（ME 下肢、ME 上肢、DE 下肢、DE 上肢）。next：「下一次」卡的日型（PlanDefaults.answers）
    static func rotation(next: DayType) -> [(dayType: DayType, mark: RotationMark)] {
        let order = DayType.allCases
        let nextIndex = order.firstIndex(of: next) ?? 0
        return order.enumerated().map { index, dayType in
            (dayType, index < nextIndex ? .done : index == nextIndex ? .next : .upcoming)
        }
    }

    /// 「下肢拉已經 18 天沒練」
    struct Reminder: Equatable, Sendable {
        var category: ExerciseCategory
        var days: Int

        var text: String { "\(category.title)已經 \(days) 天沒練" }
    }

    /// 提醒的分類：下肢推、下肢拉和四個上肢分類（核心、補強、有氧不列入）
    static let reminderCategories: [ExerciseCategory] = ExerciseCategory.allCases.filter { $0.isLower || $0.isUpper }

    /// lastDates：每個分類最近一次完成組的日期（任何動作）；從來沒練過的分類沒有值、不列入。
    /// 超過 14 天（和「訓練狀態」的警示同一個門檻）才提醒；好幾個分類都超過時取天數最多的（一樣多時依分類順序）
    static func reminder(lastDates: [ExerciseCategory: Date], now: Date, calendar: Calendar = .current) -> Reminder? {
        let stale = reminderCategories.compactMap { category -> Reminder? in
            guard let days = Recency.daysSince(lastDates[category], now: now, calendar: calendar),
                  TrainingStatus.isStale(daysAgo: days) else { return nil }
            return Reminder(category: category, days: days)
        }
        return stale.max { $0.days < $1.days || ($0.days == $1.days && isLater($0.category, than: $1.category)) }
    }

    /// 一樣多天時，分類順序在前面的勝出
    private static func isLater(_ a: ExerciseCategory, than b: ExerciseCategory) -> Bool {
        let order = ExerciseCategory.allCases
        return order.firstIndex(of: a)! > order.firstIndex(of: b)!
    }
}
