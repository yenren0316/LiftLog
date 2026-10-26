import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_09 §2：全 App 唯一的訓練次數規則、週一開始的週、連續達標
@MainActor
struct TrainingCountTests {
    /// 地區設定的一週從週日開始（像 en_US）：規則還是要從週一開始
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        c.firstWeekday = 1
        return c
    }()

    private var weekCalendar: Calendar { TrainingCount.weekCalendar(calendar) }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 19, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func day(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        calendar.startOfDay(for: date(month, day, year: year))
    }

    /// 一次訓練：每個分類一個動作；completed 為 false 的動作沒有完成的組
    private func session(_ date: Date, _ items: [(ExerciseCategory, Bool)]) -> PlanHistory.Session {
        PlanHistory.Session(date: date, items: items.map { category, completed in
            PlanHistory.Item(exerciseID: UUID(), category: category, role: .push,
                             sets: completed ? [SetValues(weightKg: 40, reps: 8, minutes: category == .cardio ? 20 : nil, isCompleted: true)] : [])
        })
    }

    // MARK: 規則

    @Test func countsDaysNotSessions() {
        let sessions = [
            session(date(10, 26, 7), [(.kneeDominant, true)]),
            session(date(10, 26, 18), [(.horizontalPush, true)]),
            session(date(10, 24), [(.hipDominant, true)]),
        ]
        let days = TrainingCount.days(sessions, cardioOnlyCounts: false, calendar: calendar)
        // 10/26 練兩次只算 1 天，部位合併成全身
        #expect(days.count == 2)
        #expect(days[day(10, 26)] == .full)
        #expect(days[day(10, 24)] == .lower)
        let weeks = TrainingCount.weeks(days, calendar: weekCalendar)
        #expect(weeks[day(10, 26)] == 1)     // 10/26 是週一，自己一週
        #expect(weeks[day(10, 19)] == 1)     // 10/24（週六）在 10/19 那週
    }

    @Test func onlyEndedSessionsWithCompletedSetsCount() throws {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        let row = Exercise(name: "划船", category: .horizontalPull, equipment: .cable)
        [squat, row].forEach(context.insert)
        func add(_ start: Date, ended: Bool, _ entries: [(Exercise, Bool)]) {
            let s = WorkoutSession(startedAt: start, endedAt: ended ? start.addingTimeInterval(3600) : nil)
            context.insert(s)
            for (i, (exercise, completed)) in entries.enumerated() {
                let item = SessionExercise(session: s, exercise: exercise, order: i)
                context.insert(item)
                context.insert(SetRecord(sessionExercise: item, order: 0, weightKg: 60, reps: 5, isCompleted: completed))
            }
        }
        add(date(10, 20), ended: true, [(squat, true), (row, false)])   // 算：有一個動作有完成組
        add(date(10, 21), ended: true, [(squat, false)])                // 不算：沒有完成組
        add(date(10, 22), ended: false, [(row, true)])                  // 不算：還沒結束
        let history = PlanHistory(sessions: try context.fetch(FetchDescriptor<WorkoutSession>()))
        let days = TrainingCount.days(history.sessions, cardioOnlyCounts: true, calendar: calendar)
        #expect(Array(days.keys) == [day(10, 20)])
        // 沒有完成組的動作不影響部位
        #expect(days[day(10, 20)] == .lower)
    }

    @Test func cardioOnlyDaysFollowTheSetting() {
        let sessions = [
            session(date(10, 20), [(.cardio, true)]),                              // 只有跑步機
            session(date(10, 21, 7), [(.cardio, true)]),                           // 同一天另一次有重訓
            session(date(10, 21, 19), [(.kneeDominant, true)]),
            session(date(10, 22), [(.core, true)]),                                // 只有核心：不是有氧，算
            session(date(10, 23), [(.cardio, true), (.horizontalPush, false)]),    // 重訓動作沒有完成組：只有有氧
            session(date(10, 24), [(.cardio, true), (.horizontalPush, true)]),     // 有氧加重訓
        ]
        let off = TrainingCount.days(sessions, cardioOnlyCounts: false, calendar: calendar)
        #expect(Set(off.keys) == [day(10, 21), day(10, 22), day(10, 24)])
        #expect(off[day(10, 21)] == .lower)
        #expect(off[day(10, 22)] == .cardio)
        #expect(off[day(10, 24)] == .upper)
        let on = TrainingCount.days(sessions, cardioOnlyCounts: true, calendar: calendar)
        #expect(Set(on.keys) == [day(10, 20), day(10, 21), day(10, 22), day(10, 23), day(10, 24)])
        #expect(on[day(10, 20)] == .cardio)
        #expect(on[day(10, 21)] == .lower)
    }

    // MARK: 週

    @Test func weeksStartOnMonday() {
        // 週日 10/25 屬於 10/19 那週，週一 10/26 是新的一週（地區設定是週日開始也一樣）
        #expect(TrainingCount.weekStart(of: date(10, 25, 23), calendar: weekCalendar) == day(10, 19))
        #expect(TrainingCount.weekStart(of: date(10, 26, 0), calendar: weekCalendar) == day(10, 26))
        // 今天的日曆的欄位：最上面一格是週一
        let columns = ActivityCalendar.weeks(endingAt: date(10, 28), count: 2, calendar: weekCalendar)
        #expect(columns.last?.first == day(10, 26))
        #expect(columns.first?.last == day(10, 25))
        let days = TrainingCount.days([session(date(10, 25), [(.kneeDominant, true)]),
                                       session(date(10, 26), [(.horizontalPush, true)])],
                                      cardioOnlyCounts: false, calendar: calendar)
        #expect(TrainingCount.weeks(days, calendar: weekCalendar) == [day(10, 19): 1, day(10, 26): 1])
    }

    @Test func weekSpanningTheNewYear() {
        // 2025/12/29（週一）到 2026/1/4（週日）是同一週
        let sessions = [
            session(date(12, 30, year: 2025), [(.kneeDominant, true)]),
            session(date(1, 2), [(.horizontalPush, true)]),
            session(date(1, 4, 10), [(.hipDominant, true)]),
            session(date(1, 5), [(.horizontalPull, true)]),
            session(date(12, 23, year: 2025), [(.kneeDominant, true)]),
        ]
        let days = TrainingCount.days(sessions, cardioOnlyCounts: false, calendar: calendar)
        let weeks = TrainingCount.weeks(days, calendar: weekCalendar)
        #expect(weeks == [day(12, 22, year: 2025): 1, day(12, 29, year: 2025): 3, day(1, 5): 1])
        // 本週（1/5 那週）1 天；跨年那週 3 天達標，前一週 1 天沒達標
        let progress = WeeklyGoal.progress(weeks: weeks, goal: 3, now: date(1, 7), calendar: weekCalendar)
        #expect(progress == WeeklyGoal.Progress(count: 1, goal: 3, streak: 1))
        #expect(progress.text == "本週 1/3・連續 1 週達標")
    }

    // MARK: 連續達標

    /// counts：由新到舊，第一個是本週（now 是 2026/10/28 週三，本週從 10/26 開始）
    private func weeks(_ counts: [Int]) -> [Date: Int] {
        var weeks: [Date: Int] = [:]
        for (back, count) in counts.enumerated() where count > 0 {
            weeks[weekCalendar.date(byAdding: .day, value: -7 * back, to: day(10, 26))!] = count
        }
        return weeks
    }

    private let now = Calendar(identifier: .gregorian).date(from: DateComponents(
        timeZone: TimeZone(identifier: "Asia/Taipei"), year: 2026, month: 10, day: 28, hour: 12))!

    @Test func streakIncludesThisWeekOnceMet() {
        let progress = WeeklyGoal.progress(weeks: weeks([3, 3, 4, 3, 1]), goal: 3, now: now, calendar: weekCalendar)
        #expect(progress.isMet)
        #expect(progress.streak == 4)
        #expect(progress.text == "本週 3/3 ✓・連續 4 週達標")
    }

    @Test func thisWeekNotMetYetDoesNotBreakTheStreak() {
        let progress = WeeklyGoal.progress(weeks: weeks([2, 3, 3, 5, 3, 3]), goal: 3, now: now, calendar: weekCalendar)
        #expect(!progress.isMet)
        #expect(progress.streak == 5)
        #expect(progress.text == "本週 2/3・連續 5 週達標")
    }

    @Test func aMissedWeekBreaksTheStreak() {
        let progress = WeeklyGoal.progress(weeks: weeks([0, 3, 4, 2, 3, 3, 3]), goal: 3, now: now, calendar: weekCalendar)
        #expect(progress.streak == 2)
        // 上週沒達標：連續 0 週，只寫本週
        let broken = WeeklyGoal.progress(weeks: weeks([1, 2, 3, 3]), goal: 3, now: now, calendar: weekCalendar)
        #expect(broken.streak == 0)
        #expect(broken.text == "本週 1/3")
    }

    @Test func noRecordsAtAll() {
        let progress = WeeklyGoal.progress(weeks: [:], goal: 3, now: now, calendar: weekCalendar)
        #expect(progress == WeeklyGoal.Progress(count: 0, goal: 3, streak: 0))
        #expect(progress.text == "本週 0/3")
    }

    @Test func changingTheGoalReevaluatesPastWeeks() {
        let history = weeks([0, 2, 3, 2, 1])
        let lastWeek = day(10, 19), twoWeeksAgo = day(10, 12)
        #expect(!WeeklyGoal.isMet(week: lastWeek, weeks: history, goal: 3))
        #expect(WeeklyGoal.isMet(week: twoWeeksAgo, weeks: history, goal: 3))
        #expect(WeeklyGoal.progress(weeks: history, goal: 3, now: now, calendar: weekCalendar).streak == 0)
        // 目標改成 2：上週也算達標，連續 3 週
        #expect(WeeklyGoal.isMet(week: lastWeek, weeks: history, goal: 2))
        #expect(WeeklyGoal.progress(weeks: history, goal: 2, now: now, calendar: weekCalendar).streak == 3)
        // 改成 4：每一週都沒達標
        #expect(!WeeklyGoal.isMet(week: twoWeeksAgo, weeks: history, goal: 4))
        #expect(WeeklyGoal.progress(weeks: history, goal: 4, now: now, calendar: weekCalendar).streak == 0)
    }
}
