import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_09 §2：全 App 唯一的訓練次數規則、週一開始的週（CHANGE_10 §2 拿掉了連續達標）
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
    }
}
