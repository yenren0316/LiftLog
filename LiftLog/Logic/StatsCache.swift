import Foundation
import SwiftData

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
        /// 那天有完成組的訓練的名稱，依開始時間（日曆的標籤，CHANGE_08 §4）
        var titles: [String] = []
        /// 合併後的部位（日曆格子的顏色）；那天沒有完成任何組時為 nil
        var region: DayRegion?
        /// 各次訓練的部位，算 region 用
        var regions: [DayRegion] = []
    }

    /// 主項的估算 1RM 趨勢
    struct MainLiftTrend: Sendable, Equatable {
        /// 最近 90 天的估算 1RM（最大值）
        var current: Double?
        /// 4 週前那天往前 90 天的估算 1RM，用來比較
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

    var exercises: [UUID: ExerciseStat] = [:]
    /// 近 30 天各分類完成的組數（不含熱身）
    var recentSets: [ExerciseCategory: Int] = [:]
    var days: [Date: DayStat] = [:]
    var nextPlan = PlanAnswers(dayType: .meLower, count: PlanDefaults.countWithoutHistory, cardio: false)
    var suggestedMain: String?
    var mainLifts: [UUID: MainLiftTrend] = [:]
    var balance = Balance()
    /// 近 12 週每週跑步機的分鐘數，由舊到新
    var weeklyCardioMinutes: [Double] = []
    /// 近 12 週每週的訓練次數，由舊到新（最後一個是本週）；只算有完成組的訓練
    var weeklySessions: [Int] = []
    /// 訓練頻率卡：近 12 週、近 12 個月，依部位分開（CHANGE_08 §3）；平均只算過完的週或月（CHANGE_09 §0-2）
    var frequencyWeeks = TrainingFrequency.Series()
    var frequencyMonths = TrainingFrequency.Series()

    static let empty = StatsSnapshot()

    static let trendWeeks = 12

    /// exercises：全部動作（含封存）；lastDate 不需要先算好
    static func make(history: PlanHistory, exercises: [PlanExercise], now: Date = .now,
                     calendar: Calendar = .current) -> StatsSnapshot {
        var snapshot = StatsSnapshot()
        let today = calendar.startOfDay(for: now)

        // 每個動作：最後日期、次數、上一次的組（history 由新到舊）
        var regional: [(date: Date, region: DayRegion)] = []
        for session in history.sessions {
            let day = calendar.startOfDay(for: session.date)
            var dayStat = snapshot.days[day] ?? DayStat()
            dayStat.sessionIDs.insert(session.id, at: 0)
            if let region = DayRegion.of(session) {
                regional.append((session.date, region))
                dayStat.regions.insert(region, at: 0)
                dayStat.titles.insert(session.title, at: 0)
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
        snapshot.suggestedMain = PlanRanking.candidates(
            for: Slot.main(for: snapshot.nextPlan.dayType), dayType: snapshot.nextPlan.dayType,
            exercises: planExercises.filter { !$0.isArchived }, history: history, now: now
        ).items.first?.exercise.name

        // 每週：近 12 週（含本週）
        let weeks = (0..<trendWeeks).reversed().compactMap { back -> DateInterval? in
            guard let day = calendar.date(byAdding: .weekOfYear, value: -back, to: today) else { return nil }
            return calendar.dateInterval(of: .weekOfYear, for: day)
        }
        snapshot.frequencyWeeks = TrainingFrequency.series(regional, period: .week, now: now, calendar: calendar)
        snapshot.frequencyMonths = TrainingFrequency.series(regional, period: .month, now: now, calendar: calendar)
        snapshot.weeklySessions = snapshot.frequencyWeeks.buckets.map(\.total)
        snapshot.weeklyCardioMinutes = weeks.map { week -> Double in
            let items: [PlanHistory.Item] = history.sessions.filter { week.contains($0.date) }.flatMap(\.items)
            let sets: [SetValues] = items.filter { $0.category == .cardio }.flatMap(\.sets)
            return sets.filter(\.isCompleted).compactMap(\.minutes).reduce(0, +)
        }

        // 主項：最近 90 天的估算 1RM、4 週前的、近 12 週每週最好的
        for exercise in exercises where exercise.has(.main) && !exercise.isArchived {
            let points = history.logs(for: exercise.id).flatMap { log in
                log.sets.filter(PersonalRecords.countsForEstimate).map {
                    (date: log.date, value: PersonalRecords.epley(weight: $0.weightKg!, reps: $0.reps!))
                }
            }
            func best(from start: Date, to end: Date) -> Double? {
                points.filter { $0.date >= start && $0.date < end }.map(\.value).filter { $0 > 0 }.max()
            }
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
            let fourWeeks = calendar.date(byAdding: .day, value: -28, to: tomorrow) ?? now
            func ninetyDaysBefore(_ end: Date) -> Date { calendar.date(byAdding: .day, value: -90, to: end) ?? end }
            snapshot.mainLifts[exercise.id] = MainLiftTrend(
                current: best(from: ninetyDaysBefore(tomorrow), to: tomorrow),
                fourWeeksAgo: best(from: ninetyDaysBefore(fourWeeks), to: fourWeeks),
                weekly: weeks.map { best(from: $0.start, to: $0.end) }
            )
        }
        return snapshot
    }
}

/// 統計快取：App 啟動時和每次存檔後（合併成一次）重新計算，畫面只讀 snapshot
@Observable
final class StatsCache {
    static let shared = StatsCache()

    private(set) var snapshot = StatsSnapshot.empty
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var pending: Task<Void, Never>?

    func start(context: ModelContext) {
        self.context = context
        recompute()
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { StatsCache.shared.scheduleRecompute() }
        }
    }

    func scheduleRecompute() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            recompute()
        }
    }

    func recompute() {
        guard let context else { return }
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        snapshot = StatsSnapshot.make(history: PlanHistory(sessions: sessions),
                                      exercises: exercises.map { PlanExercise(snapshotOf: $0) })
    }
}
