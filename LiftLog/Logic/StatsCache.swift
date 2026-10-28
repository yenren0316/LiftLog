import Foundation
import SwiftData
import UIKit

/// 「近 30 天」的口徑（CHANGE_07 B-1）：今天往前推 30 個日曆日（含今天），只算已結束的訓練。全 App 共用
nonisolated enum RecentWindow {
    static let days = 30

    static func start(now: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now
    }

    static func contains(_ date: Date, now: Date, calendar: Calendar = .current) -> Bool {
        guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return false }
        return date >= start(now: now, calendar: calendar) && date < end
    }
}

/// 畫面要用的統計，存檔時算一次（StatsCache），畫面只讀（CHANGE_07 B-1）
nonisolated struct StatsSnapshot: Sendable {
    struct ExerciseStat: Sendable, Equatable {
        /// 最後一次（已結束的訓練）的日期
        var lastDate: Date?
        /// 有完成組的訓練次數
        var sessionCount = 0
        /// 上一次的已完成組（精簡紀錄用）
        var lastSets: [SetValues] = []
    }

    struct DayStat: Sendable, Equatable {
        /// 那天做了幾個動作（日曆亮度）
        var exerciseCount = 0
        /// 那天的訓練，依開始時間
        var sessionIDs: [UUID] = []
        /// 合併後的部位（日曆格子的顏色）；那天沒有完成任何組時為 nil
        var region: DayRegion?
        /// 各次訓練的部位，算 region 用
        var regions: [DayRegion] = []
    }

    /// 主項的估算 1RM 趨勢
    struct MainLiftTrend: Sendable, Equatable {
        /// 估算 1RM（近 90 天最好的一次）；90 天內沒有紀錄為 nil（卡片不列）
        var current: Double?
        /// 4 週前那時候的估算 1RM（同一個函式，90 天內沒有就取全期），用來比較
        var fourWeeksAgo: Double?
        /// 近 12 週每週最好的估算 1RM，由舊到新；那週沒練為 nil
        var weekly: [Double?] = []

        var change: Double? {
            guard let current, let fourWeeksAgo else { return nil }
            return current - fourWeeksAgo
        }
    }

    struct Balance: Sendable, Equatable {
        var push = 0
        var pull = 0
        var unilateralSessions = 0
        var explosiveSessions = 0
    }

    /// 計算時的「現在」：畫面的「N 天前」「今天」都用它，和快照裡的本週、近 30 天同一個時間點（CHANGE_11 §2）
    var now = Date.now
    var exercises: [UUID: ExerciseStat] = [:]
    /// 動作庫各分類「最久沒練」的天數：未封存、練過的動作裡最久沒練的那個距今幾天；都沒練過的分類沒有值
    var neglectedDays: [ExerciseCategory: Int] = [:]
    /// 近 30 天各分類完成的組數（不含熱身）
    var recentSets: [ExerciseCategory: Int] = [:]
    var days: [Date: DayStat] = [:]
    var nextPlan = PlanAnswers(dayType: .meLower, count: PlanDefaults.countWithoutHistory, cardio: false)
    var suggestedMain: String?
    var mainLifts: [UUID: MainLiftTrend] = [:]
    var balance = Balance()
    /// 近 12 週每週跑步機的分鐘數，由舊到新
    var weeklyCardioMinutes: [Double] = []
    /// 算進次數的日子和那天的部位（TrainingCount.days，CHANGE_09 §2）
    var countedDays: [Date: DayRegion] = [:]
    /// 每週（週一）算進次數的天數：每週目標、日曆達標的小點
    var weekCounts: [Date: Int] = [:]
    /// 每週目標的預設值（使用者沒設定過時用，CHANGE_09 §1）
    var automaticWeeklyGoal = WeeklyGoal.fallback
    /// 「訓練狀態」浮窗：本週、上週同期、輪替狀態（CHANGE_10 §3）
    var trainingStatus = TrainingStatus()
    /// 訓練頻率卡：近 12 週、近 12 個月，依部位分開（CHANGE_08 §3）；以天為單位（CHANGE_09 §4），平均只算過完的週或月（§0-2）
    var frequencyWeeks = TrainingFrequency.Series()
    var frequencyMonths = TrainingFrequency.Series()

    static let empty = StatsSnapshot()

    static let trendWeeks = 12

    /// exercises：全部動作（含封存）；lastDate 不需要先算好。cardioOnlyCounts：「只有有氧的訓練也算」（每週目標的設定）
    static func make(history: PlanHistory, exercises: [PlanExercise], now: Date = .now,
                     calendar: Calendar = .current, cardioOnlyCounts: Bool = false) -> StatsSnapshot {
        var snapshot = StatsSnapshot()
        snapshot.now = now
        let today = calendar.startOfDay(for: now)
        // 週一開始的週（和今天的日曆、每週目標一致）
        let weekCalendar = TrainingCount.weekCalendar(calendar)

        // 每個動作：最後日期、次數、上一次的組（history 由新到舊）
        for session in history.sessions {
            let day = calendar.startOfDay(for: session.date)
            var dayStat = snapshot.days[day] ?? DayStat()
            dayStat.sessionIDs.insert(session.id, at: 0)
            if let region = DayRegion.of(session) {
                dayStat.regions.insert(region, at: 0)
                dayStat.region = DayRegion.merged(dayStat.regions)
            }
            for item in session.items where item.sets.contains(where: \.isCompleted) {
                var stat = snapshot.exercises[item.exerciseID] ?? ExerciseStat()
                if stat.lastDate == nil {
                    stat.lastDate = session.date
                    stat.lastSets = item.sets
                }
                stat.sessionCount += 1
                snapshot.exercises[item.exerciseID] = stat
                dayStat.exerciseCount += 1
            }
            snapshot.days[day] = dayStat
        }

        // 動作庫的分類列：最久沒練
        for category in ExerciseCategory.allCases {
            let dates = exercises.filter { $0.category == category && !$0.isArchived }.compactMap { snapshot.exercises[$0.id]?.lastDate }
            if let oldest = dates.min() { snapshot.neglectedDays[category] = Recency.daysSince(oldest, now: now, calendar: calendar) }
        }

        // 近 30 天
        let recent = PlanHistory(history.sessions.filter { RecentWindow.contains($0.date, now: now, calendar: calendar) })
        for category in ExerciseCategory.allCases {
            snapshot.recentSets[category] = recent.setCount(within: now) { $0.category == category }
        }
        let pushCategories: Set<ExerciseCategory> = [.horizontalPush, .verticalPush]
        let pullCategories: Set<ExerciseCategory> = [.horizontalPull, .verticalPull]
        snapshot.balance = Balance(
            push: recent.setCount(within: now) { pushCategories.contains($0.category) },
            pull: recent.setCount(within: now) { pullCategories.contains($0.category) },
            unilateralSessions: recent.sessionCount(within: now) { $0.tags.contains(.unilateral) },
            explosiveSessions: recent.sessionCount(within: now) { $0.tags.contains(.explosive) }
        )

        // 下一次：建立菜單的預設答案和主項格的第一個建議
        let planExercises = exercises.map { e in
            var e = e
            e.lastDate = snapshot.exercises[e.id]?.lastDate
            return e
        }
        snapshot.nextPlan = PlanDefaults.answers(history)
        snapshot.suggestedMain = PlanRanking.suggestedMain(for: snapshot.nextPlan.dayType, exercises: planExercises,
                                                           history: history, now: now)?.name

        // 訓練次數：全 App 同一套規則（以天為單位、只有有氧的處理），頻率卡的長條、每週目標都從這裡算
        snapshot.countedDays = TrainingCount.days(history.sessions, cardioOnlyCounts: cardioOnlyCounts, calendar: calendar)
        snapshot.weekCounts = TrainingCount.weeks(snapshot.countedDays, calendar: weekCalendar)
        snapshot.automaticWeeklyGoal = WeeklyGoal.automatic(weeks: snapshot.weekCounts, now: now, calendar: weekCalendar)
        let counted = snapshot.countedDays.map { (date: $0.key, region: $0.value) }
        snapshot.frequencyWeeks = TrainingFrequency.series(counted, period: .week, now: now, calendar: weekCalendar)
        snapshot.frequencyMonths = TrainingFrequency.series(counted, period: .month, now: now, calendar: weekCalendar)

        // 每週：近 12 週（含本週）
        let weeks = (0..<trendWeeks).reversed().compactMap { back -> DateInterval? in
            guard let day = weekCalendar.date(byAdding: .weekOfYear, value: -back, to: today) else { return nil }
            return weekCalendar.dateInterval(of: .weekOfYear, for: day)
        }
        snapshot.weeklyCardioMinutes = weeks.map { history.cardioMinutes(in: $0.start..<$0.end) }

        // 訓練狀態：天數、組數、有氧分鐘、下次主項都用上面同一套函式
        snapshot.trainingStatus = TrainingStatus.make(history: history, exercises: planExercises, countedDays: snapshot.countedDays,
                                                      nextDayType: snapshot.nextPlan.dayType, now: now, calendar: calendar)

        // 主項：估算 1RM（全 App 只有這一種，CHANGE_11 §3：PersonalRecords.estimated1RM，強度換算表和 DE 建議重量同一個）、
        // 4 週前那時候的估算 1RM、近 12 週每週最好的
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: now) ?? now
        for exercise in exercises where exercise.has(.main) && !exercise.isArchived {
            let logs = history.logs(for: exercise.id)
            let sessions = logs.map { SessionSets(sessionID: UUID(), date: $0.date, sets: $0.sets) }
            let current = PersonalRecords.estimated1RM(sessions.filter { $0.date <= now }, now: now, calendar: calendar)
            let before = PersonalRecords.estimated1RM(sessions.filter { $0.date < fourWeeksAgo }, now: fourWeeksAgo, calendar: calendar)
            let points = logs.flatMap { log in
                log.sets.filter(PersonalRecords.countsForEstimate).map {
                    (date: log.date, value: PersonalRecords.epley(weight: $0.weightKg!, reps: $0.reps!))
                }
            }
            func best(from start: Date, to end: Date) -> Double? {
                points.filter { $0.date >= start && $0.date < end }.map(\.value).filter { $0 > 0 }.max()
            }
            snapshot.mainLifts[exercise.id] = MainLiftTrend(
                // 卡片只列 90 天內有紀錄的主項：90 天內沒有時（估算 1RM 取全期）不列
                current: current.flatMap { $0.isAllTime ? nil : $0.record.value },
                fourWeeksAgo: before?.record.value,
                weekly: weeks.map { best(from: $0.start, to: $0.end) }
            )
        }
        return snapshot
    }
}

/// 統計快取：App 啟動時和每次存檔後（合併成一次）重新計算，畫面只讀 snapshot。
/// 日期改變時也重算（CHANGE_11 §2）：回到前景而且日期不同、App 開著時跨過午夜、時區或系統時間改變
@Observable
final class StatsCache {
    static let shared = StatsCache()

    private(set) var snapshot = StatsSnapshot.empty
    /// 上次計算的時間；nil 表示還沒算過
    @ObservationIgnored private(set) var computedAt: Date?
    /// 測試用：固定日曆（時區）；平常每次取 Calendar.current，時區改變後馬上用新的
    @ObservationIgnored var fixedCalendar: Calendar?
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var pending: Task<Void, Never>?

    private var calendar: Calendar { fixedCalendar ?? .current }

    func start(context: ModelContext, now: Date = AppClock.now) {
        self.context = context
        recompute(now: now)
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleRecompute() }
        })
        let timeChanges: [(Notification.Name, StatsRefresh.Trigger)] = [
            (.NSCalendarDayChanged, .dayChanged),
            (UIApplication.significantTimeChangeNotification, .timeChanged),
            (.NSSystemTimeZoneDidChange, .timeChanged),
            (.NSSystemClockDidChange, .timeChanged),
        ]
        for (name, trigger) in timeChanges {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh(trigger) }
            })
        }
    }

    /// 日期可能改變時呼叫：依 StatsRefresh 的規則決定要不要重算
    func refresh(_ trigger: StatsRefresh.Trigger, now: Date = AppClock.now) {
        guard context != nil,
              StatsRefresh.needsRecompute(trigger, computedAt: computedAt, now: now, calendar: calendar) else { return }
        recompute(now: now)
    }

    func scheduleRecompute() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            recompute()
        }
    }

    func recompute(now: Date = AppClock.now) {
        guard let context else { return }
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        computedAt = now
        snapshot = StatsSnapshot.make(history: PlanHistory(sessions: sessions),
                                      exercises: exercises.map { PlanExercise(snapshotOf: $0) },
                                      now: now, calendar: calendar,
                                      cardioOnlyCounts: UserDefaults.standard.bool(forKey: WeeklyGoal.cardioOnlyCountsKey))
    }
}
