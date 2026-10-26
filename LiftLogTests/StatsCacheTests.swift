import Foundation
import Testing
@testable import LiftLog

/// CHANGE_07 B-1：統計快取與「近 30 天」的口徑
struct StatsCacheTests {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }()

    private func date(_ month: Int, _ day: Int, _ hour: Int = 19) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private let bench = UUID(), row = UUID(), treadmill = UUID()

    private func session(_ day: Date, _ items: [(UUID, ExerciseCategory, Int)]) -> PlanHistory.Session {
        PlanHistory.Session(date: day, items: items.map { id, category, sets in
            PlanHistory.Item(exerciseID: id, category: category, role: .push,
                             sets: (0..<sets).map { _ in SetValues(weightKg: 40, reps: 8, minutes: category == .cardio ? 30 : nil, isCompleted: true) })
        })
    }

    @Test func recentWindowIsThirtyCalendarDaysIncludingToday() {
        // T4：今天往前推 30 個日曆日（含今天）
        let now = date(10, 26, 9)
        #expect(RecentWindow.start(now: now, calendar: calendar) == calendar.date(from: DateComponents(year: 2026, month: 9, day: 27)))
        #expect(RecentWindow.contains(date(9, 27, 0), now: now, calendar: calendar))
        #expect(!RecentWindow.contains(date(9, 26, 23), now: now, calendar: calendar))
        #expect(RecentWindow.contains(date(10, 26, 23), now: now, calendar: calendar))
        #expect(PlanHistory.windowStart(now: now, calendar: calendar) == RecentWindow.start(now: now, calendar: calendar))
    }

    @Test func snapshotCountsOnlySessionsInTheWindow() {
        let now = date(10, 26, 9)
        let history = PlanHistory([
            session(date(10, 25), [(bench, .horizontalPush, 3), (row, .horizontalPull, 2)]),
            session(date(9, 27, 8), [(bench, .horizontalPush, 4)]),        // 第 30 天：算
            session(date(9, 26, 20), [(row, .horizontalPull, 5)]),         // 第 31 天：不算
            session(date(10, 20), [(treadmill, .cardio, 1)]),
        ])
        let exercises = [PlanExercise(id: bench, name: "臥推", category: .horizontalPush, tags: [.main], meRotation: 1),
                         PlanExercise(id: row, name: "坐姿 Cable 划船", category: .horizontalPull, tags: []),
                         PlanExercise(id: treadmill, name: "跑步機", category: .cardio, tags: [], logType: .cardio)]
        let snapshot = StatsSnapshot.make(history: history, exercises: exercises, now: now, calendar: calendar)
        #expect(snapshot.recentSets[.horizontalPush] == 7)
        #expect(snapshot.recentSets[.horizontalPull] == 2)
        #expect(snapshot.recentSets[.cardio] == 1)
        #expect(snapshot.balance.push == 7 && snapshot.balance.pull == 2)
        // 每個動作的最後日期和次數（含 30 天以外）
        #expect(snapshot.exercises[row]?.lastDate == date(10, 25) && snapshot.exercises[row]?.sessionCount == 2)
        #expect(snapshot.exercises[bench]?.lastSets.count == 3)
        // 日曆：那天的訓練和動作數
        let day = calendar.startOfDay(for: date(10, 25))
        #expect(snapshot.days[day]?.exerciseCount == 2 && snapshot.days[day]?.sessionIDs.count == 1)
        // 有氧每週分鐘數：最後一週（本週）有 30 分鐘以前的那週
        #expect(snapshot.weeklyCardioMinutes.reduce(0, +) == 30)
        #expect(snapshot.weeklySessions.count == StatsSnapshot.trendWeeks)
    }

    @Test func mainLiftTrend() {
        let now = date(10, 26, 9)
        func set(_ kg: Double, _ reps: Int) -> SetValues { SetValues(weightKg: kg, reps: reps, isCompleted: true) }
        let history = PlanHistory([
            PlanHistory.Session(date: date(10, 24), items: [PlanHistory.Item(exerciseID: bench, category: .horizontalPush, role: .maxEffort, sets: [set(100, 3)])]),
            PlanHistory.Session(date: date(9, 10), items: [PlanHistory.Item(exerciseID: bench, category: .horizontalPush, role: .maxEffort, sets: [set(90, 3)])]),
        ])
        let exercises = [PlanExercise(id: bench, name: "臥推", category: .horizontalPush, tags: [.main], meRotation: 1)]
        let trend = StatsSnapshot.make(history: history, exercises: exercises, now: now, calendar: calendar).mainLifts[bench]
        #expect(abs((trend?.current ?? 0) - 110) < 0.01)          // 100 × (1 + 3/30)
        #expect(abs((trend?.fourWeeksAgo ?? 0) - 99) < 0.01)      // 4 週前只有 90 × 3
        #expect(abs((trend?.change ?? 0) - 11) < 0.01)
        // 近 12 週每週最好的：兩次訓練在不同週，其他週沒練
        let weekly = trend?.weekly ?? []
        #expect(weekly.count == 12 && weekly.compactMap { $0 }.map { $0.rounded() } == [99, 110])
    }
}
