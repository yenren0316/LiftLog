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
        // 「本週」卡的圓點：那天的部位（上肢推＋上肢拉 = 上肢）；只有有氧的日子是有氧與其他
        #expect(snapshot.dayRegions[calendar.startOfDay(for: date(10, 25))] == .upper)
        #expect(snapshot.dayRegions[calendar.startOfDay(for: date(10, 20))] == .cardio)
        // 有氧每週分鐘數：最後一週（本週）有 30 分鐘以前的那週
        #expect(snapshot.weeklyCardioMinutes.reduce(0, +) == 30)
        #expect(snapshot.weeklyCardioMinutes.count == StatsSnapshot.trendWeeks)
        #expect(snapshot.frequencyWeeks.buckets.count == StatsSnapshot.trendWeeks)
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

    /// CHANGE_11 §3：全 App 只有一種 1RM。主項進步卡、強度換算表的基準、DE 建議重量都是 PersonalRecords.estimated1RM
    /// （1～10 下的正式組和 MAX 組、不分角色、近 90 天最好的一次，沒有就取全期）
    @Test func oneEstimated1RMEverywhere() throws {
        let now = date(10, 26, 9)
        let deadlift = UUID()
        func set(_ kg: Double, _ reps: Int, _ kind: SetKind = .normal) -> SetValues {
            SetValues(kind: kind, weightKg: kg, reps: reps, isCompleted: true)
        }
        func item(_ id: UUID, _ role: Role, _ sets: [SetValues]) -> PlanHistory.Item {
            PlanHistory.Item(exerciseID: id, category: id == bench ? .horizontalPush : .hipDominant, role: role, sets: sets)
        }
        let history = PlanHistory([
            // 熱身和 12 下的組不算；MAX 組算；角色不影響
            PlanHistory.Session(date: date(10, 20), items: [item(bench, .push, [set(120, 3, .warmup), set(95, 12), set(90, 2, .max)])]),
            PlanHistory.Session(date: date(9, 1), items: [item(bench, .maxEffort, [set(85, 3)])]),
            // 硬舉只有 90 天以前的紀錄
            PlanHistory.Session(date: date(5, 1), items: [item(deadlift, .main, [set(140, 3)])]),
        ])
        let exercises = [PlanExercise(id: bench, name: "臥推", category: .horizontalPush, tags: [.main], meRotation: 1, equipment: .barbell),
                         PlanExercise(id: deadlift, name: "傳統硬舉", category: .hipDominant, tags: [.main], meRotation: 2, equipment: .barbell)]
        let snapshot = StatsSnapshot.make(history: history, exercises: exercises, now: now, calendar: calendar)
        func sessions(_ id: UUID) -> [SessionSets] {
            history.logs(for: id).map { SessionSets(sessionID: UUID(), date: $0.date, sets: $0.sets) }
        }

        // 臥推：90 × (1 + 2/30) = 96
        let benchMax = try #require(PersonalRecords.estimated1RM(sessions(bench), now: now, calendar: calendar))
        #expect(abs(benchMax.record.value - 96) < 0.001 && !benchMax.isAllTime)
        #expect(snapshot.mainLifts[bench]?.current == benchMax.record.value)
        #expect(IntensityTable.estimatedBase1RMKg(sessions(bench), now: now) == benchMax.record.value)
        let advice = SlotAdvice.make(role: .dynamicEffort, exercise: exercises[0], logs: history.logs(for: bench),
                                     unit: .kg, step: 2.5, now: now)
        #expect(advice.speedWeightKg == IntensityTable.weightKg(percent: 60, base1RMKg: 96, unit: .kg, step: 2.5))
        #expect(advice.speedWeightKg == 57.5)

        // 硬舉：90 天內沒有 → 估算 1RM 取全期（換算表、DE 建議照樣有），主項進步卡不列
        let deadliftMax = try #require(PersonalRecords.estimated1RM(sessions(deadlift), now: now, calendar: calendar))
        #expect(deadliftMax.isAllTime && abs(deadliftMax.record.value - 154) < 0.001)
        #expect(snapshot.mainLifts[deadlift]?.current == nil)
        #expect(IntensityTable.estimatedBase1RMKg(sessions(deadlift), now: now) == deadliftMax.record.value)
    }
}
