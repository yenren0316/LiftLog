import Foundation
import Testing
@testable import LiftLog

/// CHANGE_13 §2：「今天」的「下一次」卡和「本週」卡
struct TodayCardsTests {
    /// 地區設定的一週從週日開始，圓點還是從週一開始
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        c.firstWeekday = 1
        return c
    }()

    private func date(_ month: Int, _ day: Int, _ hour: Int = 19) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func day(_ month: Int, _ day: Int) -> Date {
        calendar.startOfDay(for: date(month, day))
    }

    private let bench = PlanExercise(id: UUID(), name: "臥推", category: .horizontalPush, tags: [.main], meRotation: 1, deRotation: 1,
                                     equipment: .barbell)
    private let squat = PlanExercise(id: UUID(), name: "深蹲", category: .kneeDominant, tags: [.main], meRotation: 1, deRotation: 1,
                                     equipment: .barbell)
    private let goodMorning = PlanExercise(id: UUID(), name: "槓鈴早安式", category: .hipDominant, tags: [.main], meRotation: 4,
                                           equipment: .barbell)
    private let swing = PlanExercise(id: UUID(), name: "壺鈴擺盪", category: .hipDominant, tags: [.explosive], deRotation: 2,
                                     equipment: .kettlebell)

    private func set(_ kg: Double, _ reps: Int) -> SetValues { SetValues(weightKg: kg, reps: reps, isCompleted: true) }

    // MARK: 「下一次」卡

    @Test func nextCardWithoutAWorkoutShowsThePlanDefaults() {
        let now = date(10, 26, 9)
        let history = PlanHistory([
            PlanHistory.Session(date: date(10, 20), dayType: .deLower, items: [
                PlanHistory.Item(exerciseID: bench.id, category: .horizontalPush, role: .push, sets: [set(90, 2)]),
                PlanHistory.Item(exerciseID: UUID(), category: .cardio, role: .cardio, sets: [SetValues(minutes: 30, isCompleted: true)]),
            ]),
        ])
        let answers = PlanDefaults.answers(history)
        #expect(answers.dayType == .deUpper)
        let content = NextCard.content(active: nil, answers: answers, main: bench, mainLogs: history.logs(for: bench.id),
                                       unit: .kg, step: 2.5, now: now)
        guard case let .next(dayType, main, volume) = content else {
            Issue.record("沒有進行中的訓練時是下一次的建議")
            return
        }
        #expect(dayType == .deUpper)
        // DE 速度主項：建議重量和建立菜單同一個函式（強度換算表 60%）
        let advice = SlotAdvice.make(role: .dynamicEffort, exercise: bench, logs: history.logs(for: bench.id), unit: .kg, step: 2.5, now: now)
        #expect(advice.speedWeightKg == 57.5)
        #expect(main.text == "主項：臥推（速度）・建議 57.5 kg")
        #expect(main.detailIsSuggestion)
        // 上次加了跑步機：「・跑步機 30 分鐘」（有氧的預設分鐘）
        #expect(volume == "1 個動作・跑步機 30 分鐘")
    }

    @Test func nextCardWithAnActiveWorkoutShowsThatWorkout() {
        let active = NextCard.Active(dayType: .meLower, title: "下肢最大肌力・深蹲", startedAt: date(10, 26, 8))
        let content = NextCard.content(active: active, answers: PlanAnswers(dayType: .meUpper, count: 3, cardio: false),
                                       main: bench, mainLogs: [], unit: .kg, step: 2.5, now: date(10, 26, 9))
        // 不顯示下一次的建議
        #expect(content == .active(active))
    }

    @Test func mainLineForMaxEffortDynamicEffortAndNoCandidate() {
        let now = date(10, 26, 9)
        // ME：做到 3RM；早安式 5RM
        #expect(NextCard.mainLine(dayType: .meLower, main: squat, logs: [], unit: .kg, now: now).text == "主項：深蹲・做到 3RM")
        let morning = NextCard.mainLine(dayType: .meLower, main: goodMorning, logs: [], unit: .kg, now: now)
        #expect(morning.text == "主項：槓鈴早安式・做到 5RM" && !morning.detailIsSuggestion)
        // DE 速度主項沒有可以計算的紀錄：只有名稱
        #expect(NextCard.mainLine(dayType: .deLower, main: squat, logs: [], unit: .kg, step: 2.5, now: now).text == "主項：深蹲（速度）")
        // DE（爆）：只有名稱
        #expect(NextCard.mainLine(dayType: .deLower, main: swing, logs: [], unit: .kg, now: now).text == "主項：壺鈴擺盪")
        // 沒有主項的候選
        let none = NextCard.mainLine(dayType: .meUpper, main: nil, logs: [], unit: .kg, now: now)
        #expect(none.text == "主項：—" && none.name == nil)
        // 動作數：沒有加跑步機時只寫動作數
        #expect(NextCard.volumeLine(PlanAnswers(dayType: .meLower, count: 2, cardio: false)) == "2 個動作")
    }

    /// 「下一次」卡的主項就是建立菜單主項格預設選的那一個，建議重量用它的紀錄
    @Test func snapshotKeepsTheSuggestedMainAndItsLogs() {
        let now = date(10, 26, 9)
        let history = PlanHistory([
            PlanHistory.Session(date: date(10, 20), dayType: .deLower, items: [
                PlanHistory.Item(exerciseID: squat.id, category: .kneeDominant, role: .dynamicEffort, sets: [set(100, 2)]),
            ]),
            PlanHistory.Session(date: date(10, 10), dayType: .meUpper, items: [
                PlanHistory.Item(exerciseID: bench.id, category: .horizontalPush, role: .maxEffort, sets: [set(90, 3)]),
            ]),
        ])
        let exercises = [bench, squat, swing]
        let snapshot = StatsSnapshot.make(history: history, exercises: exercises, now: now, calendar: calendar)
        let states = PlanRanking.resolve(answers: snapshot.nextPlan, picks: [:], exercises: exercises.map { e in
            var e = e
            e.lastDate = snapshot.exercises[e.id]?.lastDate
            return e
        }, history: history, now: now)
        #expect(snapshot.nextPlan.dayType == .deUpper)
        #expect(snapshot.suggestedMain?.id == states.first?.selected?.id && snapshot.suggestedMain?.id == bench.id)
        #expect(snapshot.suggestedMainLogs.count == 1)
    }

    // MARK: 「本週」卡的圓點

    @Test func dotsAreColoredByRegionAndTodayIsMarked() {
        let now = date(10, 28, 9)   // 週三
        let regions: [Date: DayRegion] = [day(10, 26): .lower, day(10, 27): .cardio, day(10, 28): .full, day(10, 25): .upper]
        let dots = WeekCard.days(regions: regions, now: now, calendar: calendar)
        #expect(dots.map(\.label) == ["一", "二", "三", "四", "五", "六", "日"])
        #expect(dots.map(\.date) == (26...31).map { day(10, $0) } + [day(11, 1)])
        // 依部位；只有有氧的日子是有氧與其他（中性灰）；上週日的訓練不在這週
        #expect(dots.map(\.region) == [.lower, .cardio, .full, nil, nil, nil, nil])
        #expect(dots.map(\.isToday) == [false, false, true, false, false, false, false])
        #expect(dots.map(\.isFuture) == [false, false, false, true, true, true, true])
        // 顏色：下肢、上肢各自的部位色，全身兩色，有氧與其他中性灰
        #expect(DayRegion.lower.swatch == .solid(.lower) && DayRegion.upper.swatch == .solid(.upper))
        #expect(DayRegion.full.swatch == .split(.lower, .upper) && DayRegion.cardio.swatch == .neutral)
        // 「不以顏色區分」時圓點裡的字
        #expect(DayRegion.allCases.map(\.letter) == ["下", "上", "全", nil])
    }

    @Test func mondayAndSundayBoundaries() {
        let regions: [Date: DayRegion] = [day(10, 25): .upper, day(10, 26): .lower, day(11, 1): .full, day(11, 2): .lower]
        // 週一早上：第一個是今天，後面 6 天都是之後的日子；前一天（週日）屬於上一週
        let monday = WeekCard.days(regions: regions, now: date(10, 26, 0), calendar: calendar)
        #expect(monday.first?.date == day(10, 26) && monday.first?.isToday == true)
        #expect(monday.first?.region == .lower)
        #expect(monday.dropFirst().allSatisfy { $0.isFuture && $0.region == nil })
        // 週日晚上：最後一個是今天，沒有之後的日子；下一個週一不在這週
        let sunday = WeekCard.days(regions: regions, now: date(11, 1, 23), calendar: calendar)
        #expect(sunday.first?.date == day(10, 26) && sunday.last?.date == day(11, 1))
        #expect(sunday.last?.isToday == true && sunday.last?.region == .full)
        #expect(sunday.allSatisfy { !$0.isFuture })
        #expect(sunday.filter(\.isToday).count == 1)
    }

    // MARK: 輪替膠囊

    @Test func rotationMarksForEachNextDayType() {
        func marks(_ next: DayType) -> [WeekCard.RotationMark] { WeekCard.rotation(next: next).map(\.mark) }
        #expect(WeekCard.rotation(next: .meLower).map(\.dayType) == [.meLower, .meUpper, .deLower, .deUpper])
        // 下一次是 ME 下肢：新的一輪，四個都沒有勾勾
        #expect(marks(.meLower) == [.next, .upcoming, .upcoming, .upcoming])
        #expect(marks(.meUpper) == [.done, .next, .upcoming, .upcoming])
        #expect(marks(.deLower) == [.done, .done, .next, .upcoming])
        #expect(marks(.deUpper) == [.done, .done, .done, .next])
    }

    // MARK: 提醒

    @Test func reminderAfterFourteenDays() {
        let now = date(10, 29, 9)
        // 14 天：不顯示；15 天：顯示
        #expect(WeekCard.reminder(lastDates: [.hipDominant: date(10, 15, 20)], now: now, calendar: calendar) == nil)
        let reminder = WeekCard.reminder(lastDates: [.hipDominant: date(10, 14, 20)], now: now, calendar: calendar)
        #expect(reminder == WeekCard.Reminder(category: .hipDominant, days: 15))
        #expect(reminder?.text == "下肢拉已經 15 天沒練")
    }

    @Test func reminderPicksTheLongestAndSkipsCoreAccessoryCardioAndNeverTrained() {
        let now = date(10, 29, 9)
        let lastDates: [ExerciseCategory: Date] = [
            .kneeDominant: date(10, 28),        // 1 天
            .horizontalPull: date(10, 11),      // 18 天
            .verticalPush: date(10, 1),         // 28 天：最多
            .horizontalPush: date(10, 10),      // 19 天
            .core: date(8, 1), .accessory: date(7, 1), .cardio: date(6, 1),   // 不列入
            // 上肢垂直拉、下肢拉從來沒練過：不列入
        ]
        #expect(WeekCard.reminder(lastDates: lastDates, now: now, calendar: calendar) == WeekCard.Reminder(category: .verticalPush, days: 28))
        // 只有核心、補強、有氧很久沒練：不提醒
        #expect(WeekCard.reminder(lastDates: [.core: date(8, 1), .accessory: date(7, 1), .cardio: date(6, 1)],
                                  now: now, calendar: calendar) == nil)
        // 一樣多天：分類順序在前面的
        #expect(WeekCard.reminder(lastDates: [.verticalPull: date(10, 1), .hipDominant: date(10, 1)], now: now, calendar: calendar)?
            .category == .hipDominant)
        // 都沒練過：不提醒
        #expect(WeekCard.reminder(lastDates: [:], now: now, calendar: calendar) == nil)
    }

    /// 統計快照：每個分類最近一次完成組（任何動作，包括封存的），用快照的「現在」
    @Test func snapshotReminderUsesTheLatestSetOfTheCategory() {
        let now = date(10, 29, 9)
        let rdl = PlanExercise(id: UUID(), name: "羅馬尼亞式硬舉", category: .hipDominant, tags: [])
        let archived = PlanExercise(id: UUID(), name: "臥姿腿彎舉機", category: .hipDominant, tags: [], isArchived: true)
        func session(_ when: Date, _ exercise: PlanExercise) -> PlanHistory.Session {
            PlanHistory.Session(date: when, items: [PlanHistory.Item(exerciseID: exercise.id, category: exercise.category,
                                                                     role: .lowerAssist, sets: [set(40, 10)])])
        }
        let history = PlanHistory([session(date(10, 5), rdl), session(date(10, 11), archived),
                                   session(date(10, 28), squat), session(date(10, 27), bench)])
        let snapshot = StatsSnapshot.make(history: history, exercises: [rdl, archived, squat, bench], now: now, calendar: calendar)
        #expect(snapshot.categoryLastDates[.hipDominant] == date(10, 11))
        #expect(snapshot.weekReminder == WeekCard.Reminder(category: .hipDominant, days: 18))
        // 本週卡的天數和組數就是訓練狀態的本週（同一份數字）
        #expect(snapshot.trainingStatus.thisWeek.days == 2 && snapshot.trainingStatus.thisWeek.sets == 2)
    }
}
