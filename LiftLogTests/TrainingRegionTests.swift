import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_08 T3：訓練頻率的週和月統計、依部位分段、平均值，只算已結束而且有完成組的訓練；
/// T4 的部位判定（包括全身和同一天多次訓練）
@MainActor
struct TrainingRegionTests {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }()

    private func date(_ month: Int, _ day: Int, _ hour: Int = 19, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // MARK: 部位

    @Test func regionFromCompletedExercises() {
        #expect(DayRegion.of(categories: [.kneeDominant, .core]) == .lower)
        #expect(DayRegion.of(categories: [.horizontalPush, .cardio]) == .upper)
        #expect(DayRegion.of(categories: [.hipDominant, .verticalPull]) == .full)
        #expect(DayRegion.of(categories: [.cardio]) == .cardio)
        // 只有核心或補強：沒有上下肢，歸在有氧那一類
        #expect(DayRegion.of(categories: [.core, .accessory]) == .cardio)
        #expect(DayRegion.of(categories: []) == nil)
        // 沒有完成組的動作不算
        let session = PlanHistory.Session(date: date(10, 1), items: [
            PlanHistory.Item(exerciseID: UUID(), category: .kneeDominant, role: .lowerAssist, sets: []),
            PlanHistory.Item(exerciseID: UUID(), category: .horizontalPush, role: .push,
                             sets: [SetValues(weightKg: 40, reps: 8, isCompleted: true)]),
        ])
        #expect(DayRegion.of(session) == .upper)
    }

    @Test func sameDayRegionsMerge() {
        #expect(DayRegion.merged([.lower, .upper]) == .full)
        #expect(DayRegion.merged([.lower, .cardio]) == .lower)
        #expect(DayRegion.merged([.cardio, .upper]) == .upper)
        #expect(DayRegion.merged([.full, .lower]) == .full)
        #expect(DayRegion.merged([.cardio, .cardio]) == .cardio)
        #expect(DayRegion.merged([]) == nil)
    }

    // MARK: 訓練頻率

    /// 2026-10-26 是週一；這個 calendar 的一週從週日開始，本週是 10/25–10/31
    private var sessions: [(date: Date, region: DayRegion)] {
        [(date(10, 25), .lower), (date(10, 26, 8), .upper), (date(10, 26, 18), .cardio),
         (date(10, 20), .full), (date(10, 12), .lower), (date(8, 1), .lower), (date(11, 3, year: 2025), .upper)]
    }

    @Test func weeklyBucketsStackByRegion() {
        let now = date(10, 26, 9)
        let weeks = TrainingFrequency.buckets(sessions, period: .week, now: now, calendar: calendar)
        #expect(weeks.count == 12)
        #expect(weeks.first?.start == calendar.date(from: DateComponents(year: 2026, month: 8, day: 9)))
        #expect(weeks.last?.start == calendar.date(from: DateComponents(year: 2026, month: 10, day: 25)))
        #expect(weeks.last?.counts == [.lower: 1, .upper: 1, .cardio: 1])
        #expect(weeks.last?.total == 3)
        #expect(weeks[10].counts == [.full: 1])
        #expect(weeks[9].counts == [.lower: 1])
        // 8/1 在 12 週以外
        #expect(weeks.map(\.total).reduce(0, +) == 5)
        #expect(abs(TrainingFrequency.average(weeks) - 5.0 / 12) < 0.0001)
    }

    @Test func monthlyBucketsStackByRegion() {
        let now = date(10, 26, 9)
        let months = TrainingFrequency.buckets(sessions, period: .month, now: now, calendar: calendar)
        #expect(months.count == 12)
        #expect(months.first?.start == calendar.date(from: DateComponents(year: 2025, month: 11, day: 1)))
        #expect(months.last?.counts == [.lower: 2, .upper: 1, .cardio: 1, .full: 1])
        #expect(months[9].counts == [.lower: 1])          // 8 月
        #expect(months.first?.counts == [.upper: 1])      // 2025 年 11 月
        #expect(abs(TrainingFrequency.average(months) - 7.0 / 12) < 0.0001)
        // 一段的結束是下一段的開始（不重複計算邊界上的訓練）
        #expect(zip(months, months.dropFirst()).allSatisfy { $0.end == $1.start })
    }

    /// CHANGE_09 §0-2：平均只算近 12 個已經過完的週或月，不含本週或本月；本週或本月的長條照樣畫
    @Test func averageExcludesTheCurrentWeekAndMonth() {
        let now = date(10, 26, 9)
        // 本週（10/25–10/31）3 次；之前 12 週（8/2–10/24）共 6 次，其中 8/2 那週不在畫出來的 12 條裡
        let list: [(date: Date, region: DayRegion)] = [
            (date(10, 25), .lower), (date(10, 26, 7), .upper), (date(10, 26, 18), .lower),
            (date(10, 20), .lower), (date(10, 14), .upper), (date(9, 30), .lower), (date(9, 2), .lower),
            (date(8, 12), .upper), (date(8, 3), .lower),
            (date(7, 29), .lower),   // 13 週前：不算
        ]
        let weeks = TrainingFrequency.series(list, period: .week, now: now, calendar: calendar)
        #expect(weeks.buckets.count == 12)
        #expect(weeks.buckets.last?.total == 3)
        #expect(weeks.buckets.first?.start == calendar.date(from: DateComponents(year: 2026, month: 8, day: 9)))
        #expect(abs(weeks.average - 6.0 / 12) < 0.0001)
        // 月：本月（10 月）5 次不算；之前 12 個月（2025/10–2026/9）共 5 次（7/29、8/3、8/12、9/2、9/30）
        let months = TrainingFrequency.series(list, period: .month, now: now, calendar: calendar)
        #expect(months.buckets.count == 12)
        #expect(months.buckets.last?.total == 5)
        #expect(abs(months.average - 5.0 / 12) < 0.0001)
    }

    @Test func snapshotCountsOnlyEndedSessionsWithCompletedSets() throws {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        [squat, bench].forEach(context.insert)
        func session(_ start: Date, ended: Bool, _ entries: [(Exercise, Bool)], title: String) {
            let s = WorkoutSession(startedAt: start, endedAt: ended ? start.addingTimeInterval(3600) : nil, title: title)
            context.insert(s)
            for (i, (exercise, completed)) in entries.enumerated() {
                let item = SessionExercise(session: s, exercise: exercise, order: i)
                context.insert(item)
                context.insert(SetRecord(sessionExercise: item, order: 0, weightKg: 60, reps: 5, isCompleted: completed))
            }
        }
        let now = date(10, 26, 21)
        session(date(10, 26, 7), ended: true, [(squat, true)], title: "下肢訓練")
        session(date(10, 26, 18), ended: true, [(bench, true)], title: "上肢訓練")
        session(date(10, 24), ended: true, [(squat, false)], title: "沒打勾")      // 沒有完成組：不算
        session(date(10, 26, 20), ended: false, [(bench, true)], title: "進行中")   // 進行中：不算
        let snapshot = StatsSnapshot.make(history: PlanHistory(sessions: try context.fetch(FetchDescriptor<WorkoutSession>())),
                                          exercises: [squat, bench].map { PlanExercise($0) }, now: now, calendar: calendar)
        // CHANGE_09：以天為單位，同一天的下肢＋上肢合併成 1 天全身
        #expect(snapshot.frequencyWeeks.buckets.last?.counts == [.full: 1])
        #expect(snapshot.frequencyMonths.buckets.last?.total == 1)
        #expect(snapshot.countedDays == [calendar.startOfDay(for: now): .full])
        #expect(snapshot.weekCounts == [calendar.startOfDay(for: now): 1])   // 10/26 是週一
        // 同一天下肢＋上肢：日曆是全身，標籤列出兩次的名稱（依開始時間）
        let today = try #require(snapshot.days[calendar.startOfDay(for: now)])
        #expect(today.region == .full)
        #expect(today.titles == ["下肢訓練", "上肢訓練"])
        // 只有沒打勾的組的那天：沒有顏色
        #expect(snapshot.days[calendar.startOfDay(for: date(10, 24))]?.region == nil)
    }
}
