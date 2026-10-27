import Foundation

/// 「訓練狀態」浮窗（CHANGE_10 §3）的內容：本週、上週同期、輪替狀態。存檔時和其他統計一起算（StatsSnapshot），
/// 每個數字都來自共用的函式：天數是 TrainingCount.days（每週目標同一套）、組數是 PlanHistory.setCount（首頁近 30 天同一套）、
/// 有氧分鐘是 PlanHistory.cardioMinutes（歷程的有氧卡同一套）、下次主項和「下一次」是建立菜單和「下一次」卡的同一個函式
nonisolated struct TrainingStatus: Sendable, Equatable {
    /// 一段期間的訓練量
    struct Period: Sendable, Equatable {
        /// 算進次數的天數（TrainingCount）
        var days = 0
        /// 正式組和 MAX 組（不含熱身、不含有氧）
        var sets = 0
        /// 下肢推＋下肢拉
        var lower = 0
        /// 四個上肢分類
        var upper = 0
        /// 核心＋補強
        var other = 0
        /// 跑步機的分鐘
        var cardioMinutes: Double = 0
    }

    /// 輪替的一列（ME 下肢、ME 上肢、DE 下肢、DE 上肢）
    struct Rotation: Sendable, Equatable, Identifiable {
        var dayType: DayType
        /// 上次：這個日型、有完成組的已結束訓練裡最近的一次；沒有為 nil
        var lastDate: Date?
        var lastSessionID: UUID?
        /// 上次的主項（那次 ME 主項或 DE 主項的動作）
        var lastMain: String?
        /// 下次的主項：建立菜單主項格的第一個建議
        var nextMain: String?
        /// 「下一次」卡推薦的日型
        var isNext = false

        var id: DayType { dayType }
    }

    var thisWeek = Period()
    var lastWeek = Period()
    var rotation: [Rotation] = []

    /// 上次距今超過這個天數用 warning 色
    static let staleDays = 14

    static func isStale(daysAgo: Int) -> Bool { daysAgo > staleDays }

    /// 本週：週一 0 點到明天 0 點（含今天）
    static func thisWeekRange(now: Date, calendar: Calendar) -> Range<Date> {
        let today = calendar.startOfDay(for: now)
        let start = TrainingCount.weekStart(of: now, calendar: calendar) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        return start..<end
    }

    /// 上週同期：上週一 0 點到上週的同一個星期幾（含當天）
    static func lastWeekRange(now: Date, calendar: Calendar) -> Range<Date> {
        let this = thisWeekRange(now: now, calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -7, to: this.lowerBound) ?? this.lowerBound
        let end = calendar.date(byAdding: .day, value: -7, to: this.upperBound) ?? this.upperBound
        return start..<end
    }

    /// 幾天前（以日曆日算）
    static func daysAgo(_ date: Date, now: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
    }
}

nonisolated extension TrainingStatus {
    /// countedDays：TrainingCount.days 的結果；exercises：全部動作（含上次日期）；nextDayType：「下一次」卡的日型
    static func make(history: PlanHistory, exercises: [PlanExercise], countedDays: [Date: DayRegion],
                     nextDayType: DayType, now: Date = .now, calendar: Calendar = .current) -> TrainingStatus {
        let weekCalendar = TrainingCount.weekCalendar(calendar)
        func period(_ range: Range<Date>) -> Period {
            func sets(_ categories: Set<ExerciseCategory>) -> Int {
                history.setCount(in: range) { categories.contains($0.category) }
            }
            let lower = sets([.kneeDominant, .hipDominant])
            let upper = sets([.horizontalPush, .horizontalPull, .verticalPush, .verticalPull])
            let other = sets([.core, .accessory])
            return Period(days: TrainingCount.count(in: range, days: countedDays), sets: lower + upper + other,
                          lower: lower, upper: upper, other: other, cardioMinutes: history.cardioMinutes(in: range))
        }
        let names = Dictionary(exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let rotation = DayType.allCases.map { dayType -> Rotation in
            // history 由新到舊；只算有完成組的訓練
            let last = history.sessions.first { $0.dayType == dayType && $0.items.contains { !$0.sets.isEmpty } }
            let lastMain = last?.items.first { ($0.role == .maxEffort || $0.role == .dynamicEffort) && !$0.sets.isEmpty }
            return Rotation(dayType: dayType, lastDate: last?.date, lastSessionID: last?.id,
                            lastMain: lastMain.flatMap { names[$0.exerciseID] },
                            nextMain: PlanRanking.suggestedMain(for: dayType, exercises: exercises, history: history, now: now)?.name,
                            isNext: dayType == nextDayType)
        }
        return TrainingStatus(thisWeek: period(thisWeekRange(now: now, calendar: weekCalendar)),
                              lastWeek: period(lastWeekRange(now: now, calendar: weekCalendar)),
                              rotation: rotation)
    }
}
