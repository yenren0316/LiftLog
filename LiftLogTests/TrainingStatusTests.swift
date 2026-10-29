import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_10 §3：「訓練狀態」浮窗的本週、上週同期和輪替狀態
@MainActor
struct TrainingStatusTests {
    /// 地區設定的一週從週日開始，規則還是週一
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

    // MARK: 本週和上週同期的日期範圍

    @Test func lastWeekSamePeriodOnAMonday() {
        let now = date(10, 26, 9)   // 週一
        #expect(TrainingStatus.thisWeekRange(now: now, calendar: weekCalendar) == day(10, 26)..<day(10, 27))
        #expect(TrainingStatus.lastWeekRange(now: now, calendar: weekCalendar) == day(10, 19)..<day(10, 20))
    }

    @Test func lastWeekSamePeriodOnASunday() {
        let now = date(11, 1, 22)   // 週日：整週
        #expect(TrainingStatus.thisWeekRange(now: now, calendar: weekCalendar) == day(10, 26)..<day(11, 2))
        #expect(TrainingStatus.lastWeekRange(now: now, calendar: weekCalendar) == day(10, 19)..<day(10, 26))
    }

    @Test func lastWeekSamePeriodAcrossTheNewYear() {
        let now = date(1, 1, 12)    // 2026/1/1 週四；本週從 2025/12/29 開始
        #expect(TrainingStatus.thisWeekRange(now: now, calendar: weekCalendar) == day(12, 29, year: 2025)..<day(1, 2))
        #expect(TrainingStatus.lastWeekRange(now: now, calendar: weekCalendar) == day(12, 22, year: 2025)..<day(12, 26, year: 2025))
    }

    // MARK: 本週的組數

    @Test func weekSetsCountWorkingAndMaxSetsOfEndedSessions() throws {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        let plank = Exercise(name: "棒式", category: .core, equipment: .bodyweight, logType: .timed)
        let treadmill = Exercise(name: "跑步機", category: .cardio, equipment: .machine, logType: .cardio)
        [squat, bench, plank, treadmill].forEach(context.insert)
        func add(_ start: Date, ended: Bool = true, _ entries: [(Exercise, [(SetKind, Bool)])], minutes: Double? = nil) {
            let s = WorkoutSession(startedAt: start, endedAt: ended ? start.addingTimeInterval(3600) : nil)
            context.insert(s)
            for (i, (exercise, sets)) in entries.enumerated() {
                let item = SessionExercise(session: s, exercise: exercise, order: i)
                context.insert(item)
                for (j, (kind, done)) in sets.enumerated() {
                    let set = exercise.logType == .cardio
                        ? SetRecord(sessionExercise: item, order: j, incline: 8, speed: 6, minutes: minutes, isCompleted: done)
                        : SetRecord(sessionExercise: item, order: j, kind: kind, weightKg: 60, reps: 5, isCompleted: done)
                    context.insert(set)
                }
            }
        }
        // 本週（10/26 週一 – 10/28 週三）
        add(date(10, 26, 7), [(squat, [(.warmup, true), (.normal, true), (.normal, true), (.max, true), (.normal, false)]),
                              (bench, [(.normal, true), (.normal, true)])])
        add(date(10, 27), [(plank, [(.normal, true), (.normal, true)])])
        add(date(10, 27, 20), [(treadmill, [(.normal, true)])], minutes: 20)
        add(date(10, 28, 7), [(treadmill, [(.normal, true)])], minutes: 15)
        add(date(10, 28, 9), ended: false, [(bench, [(.normal, true), (.normal, true), (.normal, true)])])   // 進行中：不算
        // 上週同期（10/19 – 10/21）和上週其他天（10/24 不算）
        add(date(10, 20), [(squat, [(.normal, true), (.normal, true)])])
        add(date(10, 24), [(bench, [(.normal, true), (.normal, true), (.normal, true)])])

        let now = date(10, 28, 12)
        let history = PlanHistory(sessions: try context.fetch(FetchDescriptor<WorkoutSession>()))
        let snapshot = StatsSnapshot.make(history: history, exercises: [], now: now, calendar: calendar)
        let week = snapshot.trainingStatus.thisWeek
        // 熱身和沒打勾的不算；MAX 組算；有氧不算組數，改算分鐘
        #expect(week.lower == 3 && week.upper == 2 && week.other == 2)
        #expect(week.sets == 7)
        #expect(week.cardioMinutes == 35)
        // 天數：每週目標同一套（只有有氧的那天預設不算）
        #expect(week.days == 2)
        #expect(week.days == TrainingCount.count(in: TrainingStatus.thisWeekRange(now: now, calendar: weekCalendar),
                                                 days: snapshot.countedDays))
        // 組數和歷程平衡卡的近 30 天是同一個函式
        let range = TrainingStatus.thisWeekRange(now: now, calendar: weekCalendar)
        #expect(week.sets == history.setCount(in: range) { $0.category != .cardio })
        let last = snapshot.trainingStatus.lastWeek
        #expect(last.days == 1 && last.sets == 2 && last.lower == 2)
    }

    // MARK: 輪替狀態

    private static let squatID = UUID(), deadliftID = UUID(), benchID = UUID(), inclineID = UUID(), rowID = UUID()

    private var library: [PlanExercise] {
        [PlanExercise(id: Self.squatID, name: "深蹲", category: .kneeDominant, tags: [.main], meRotation: 1, deRotation: 1),
         PlanExercise(id: Self.deadliftID, name: "傳統硬舉", category: .hipDominant, tags: [.main], meRotation: 2, deRotation: 2),
         PlanExercise(id: Self.benchID, name: "臥推", category: .horizontalPush, tags: [.main], meRotation: 1, deRotation: 1),
         PlanExercise(id: Self.inclineID, name: "上斜臥推", category: .horizontalPush, tags: [.main], meRotation: 2),
         PlanExercise(id: Self.rowID, name: "坐姿 Cable 划船", category: .horizontalPull, tags: [])]
    }

    private func session(_ date: Date, _ dayType: DayType, main id: UUID, role: Role, category: ExerciseCategory) -> PlanHistory.Session {
        PlanHistory.Session(date: date, dayType: dayType, items: [
            PlanHistory.Item(exerciseID: id, category: category, tags: [.main], role: role,
                             sets: [SetValues(weightKg: 100, reps: 3, isCompleted: true)]),
        ])
    }

    @Test func rotationMatchesThePlanBuilderAndTheNextCard() {
        let now = date(10, 28, 12)
        let history = PlanHistory([
            session(date(10, 18), .meLower, main: Self.squatID, role: .maxEffort, category: .kneeDominant),
            session(date(10, 8), .meUpper, main: Self.benchID, role: .maxEffort, category: .horizontalPush),
            session(date(10, 23), .deLower, main: Self.squatID, role: .dynamicEffort, category: .kneeDominant),
        ])
        let snapshot = StatsSnapshot.make(history: history, exercises: library, now: now, calendar: calendar)
        let rotation = snapshot.trainingStatus.rotation
        #expect(rotation.map(\.dayType) == [.meLower, .meUpper, .deLower, .deUpper])

        // 上次：日期、主項；沒有紀錄的日型沒有上次
        #expect(rotation[0].lastDate == date(10, 18) && rotation[0].lastMain == "深蹲")
        #expect(TrainingStatus.daysAgo(rotation[0].lastDate!, now: now, calendar: calendar) == 10)
        #expect(TrainingStatus.daysAgo(rotation[1].lastDate!, now: now, calendar: calendar) == 20)
        #expect(rotation[3].lastDate == nil && rotation[3].lastMain == nil && rotation[3].lastSessionID == nil)

        // 下次主項：和建立菜單主項格預設選的一樣
        for row in rotation {
            let states = PlanRanking.resolve(answers: PlanAnswers(dayType: row.dayType, count: 3, cardio: false),
                                             picks: [:], exercises: library, history: history, now: now)
            let main = states.first { $0.slot == Slot.main(for: row.dayType) }?.selected?.name
            #expect(row.nextMain == main, "\(row.dayType)")
        }
        // 「下一次」：和「下一次」卡（建立菜單的預設答案）同一個日型，只有一列
        #expect(rotation.filter(\.isNext).map(\.dayType) == [PlanDefaults.answers(history).dayType])
        #expect(rotation.first(where: \.isNext)?.nextMain == snapshot.suggestedMain?.name)
    }

    @Test func overFourteenDaysIsStale() {
        #expect(!TrainingStatus.isStale(daysAgo: 0))
        #expect(!TrainingStatus.isStale(daysAgo: 14))
        #expect(TrainingStatus.isStale(daysAgo: 15))
        // 以日曆日算：昨天晚上到今天早上是 1 天
        #expect(TrainingStatus.daysAgo(date(10, 27, 23), now: date(10, 28, 1), calendar: calendar) == 1)
        #expect(TrainingStatus.daysAgo(date(10, 13, 23), now: date(10, 28, 1), calendar: calendar) == 15)
    }
}
