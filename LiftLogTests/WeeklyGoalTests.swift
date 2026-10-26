import Foundation
import Testing
@testable import LiftLog

/// CHANGE_09 §1：每週目標的預設值和設定
@MainActor
struct WeeklyGoalTests {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return TrainingCount.weekCalendar(c)
    }()

    private func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    /// 2026/10/28（週三）；本週從 10/26 開始
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12))! }

    /// counts：由新到舊，第一個是本週
    private func weeks(_ counts: [Int]) -> [Date: Int] {
        var weeks: [Date: Int] = [:]
        for (back, count) in counts.enumerated() where count > 0 {
            weeks[calendar.date(byAdding: .day, value: -7 * back, to: day(10, 26))!] = count
        }
        return weeks
    }

    @Test func automaticGoalFromTheLastTwelveFinishedWeeks() {
        // 本週 7 天不算；之前 12 週共 40 天 → 3.33 → 3
        let forty = [7] + [4, 4, 4, 4, 3, 3, 3, 3, 3, 3, 3, 3]
        #expect(WeeklyGoal.automatic(weeks: weeks(forty), now: now, calendar: calendar) == 3)
        // 共 42 天 → 3.5 → 四捨五入 4；第 13 週以前的不算
        let fortyTwo = [0] + [4, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3, 3] + [7, 7]
        #expect(WeeklyGoal.automatic(weeks: weeks(fortyTwo), now: now, calendar: calendar) == 4)
        // 很少練：限制在 1 以上
        #expect(WeeklyGoal.automatic(weeks: weeks([0, 0, 0, 2]), now: now, calendar: calendar) == 1)
        // 天天練：7
        #expect(WeeklyGoal.automatic(weeks: weeks([0] + Array(repeating: 7, count: 12)), now: now, calendar: calendar) == 7)
    }

    @Test func automaticGoalWithoutRecordsIsThree() {
        #expect(WeeklyGoal.automatic(weeks: [:], now: now, calendar: calendar) == 3)
        // 只有本週，或只有 12 週以前的紀錄：近 12 個過完的週沒有紀錄，也是 3
        #expect(WeeklyGoal.automatic(weeks: weeks([2]), now: now, calendar: calendar) == 3)
        #expect(WeeklyGoal.automatic(weeks: weeks(Array(repeating: 0, count: 13) + [5]), now: now, calendar: calendar) == 3)
    }

    @Test func snapshotAutomaticGoalMatchesTheFrequencyAverage() {
        // 預設值和訓練頻率卡「近 12 週平均」是同一個數字（四捨五入）
        let sessions = (1...30).map { back -> PlanHistory.Session in
            PlanHistory.Session(date: calendar.date(byAdding: .day, value: -back * 3, to: now)!, items: [
                PlanHistory.Item(exerciseID: UUID(), category: .kneeDominant, role: .lowerAssist,
                                 sets: [SetValues(weightKg: 60, reps: 5, isCompleted: true)]),
            ])
        }
        let snapshot = StatsSnapshot.make(history: PlanHistory(sessions), exercises: [], now: now, calendar: calendar)
        #expect(snapshot.automaticWeeklyGoal == Int(snapshot.frequencyWeeks.average.rounded()))
        #expect(snapshot.automaticWeeklyGoal == 2)   // 每 3 天一次：12 週 28 天，平均 2.33
    }

    @Test func storedGoalStopsTheAutomaticValue() throws {
        let defaults = try #require(UserDefaults(suiteName: "WeeklyGoalTests.\(UUID().uuidString)"))
        // 從來沒設定過：跟著預設值變
        #expect(WeeklyGoal.goal(automatic: 4, defaults: defaults) == 4)
        #expect(WeeklyGoal.goal(automatic: 2, defaults: defaults) == 2)
        // 改過之後就以設定的為準，預設值怎麼變都不影響
        defaults.set(5, forKey: WeeklyGoal.goalKey)
        #expect(WeeklyGoal.goal(automatic: 2, defaults: defaults) == 5)
        #expect(WeeklyGoal.goal(automatic: 7, defaults: defaults) == 5)
        // 設成和預設值一樣也算設定過
        defaults.set(3, forKey: WeeklyGoal.goalKey)
        #expect(WeeklyGoal.goal(automatic: 6, defaults: defaults) == 3)
    }

    @Test func cardioSettingIsOffByDefault() throws {
        let defaults = try #require(UserDefaults(suiteName: "WeeklyGoalTests.\(UUID().uuidString)"))
        #expect(defaults.bool(forKey: WeeklyGoal.cardioOnlyCountsKey) == false)
        #expect(defaults.integer(forKey: WeeklyGoal.goalKey) == 0)
    }
}
