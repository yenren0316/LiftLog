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

    // MARK: 「本週」卡的點點日曆（CHANGE_14 §1）

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!)
    }

    @Test func calendarColumnsFollowTheWidthAndAreAtLeastTwelveWeeks() {
        // iPhone 17 Pro 的卡片裡 338 pt：14 pt 的格子放得下 20 週，12 pt 放得下 22 週
        #expect(WeekCard.Grid.layout(width: 338, cell: 14) == (20, 14))
        #expect(WeekCard.Grid.layout(width: 338, cell: 12) == (22, 12))
        // 剛好 20 週：20 × 14 + 19 × 3 = 337
        #expect(WeekCard.Grid.layout(width: 337, cell: 14).weeks == 20)
        #expect(WeekCard.Grid.layout(width: 336, cell: 14).weeks == 19)
        // 格子限制在 12～14 pt
        #expect(WeekCard.Grid.layout(width: 338, cell: 20) == (20, 14))
        #expect(WeekCard.Grid.layout(width: 338, cell: 8) == (22, 12))
        // 放不下 12 週：格子縮小塞滿 12 週，最小 12 pt
        let narrow = WeekCard.Grid.layout(width: 200, cell: 14)
        #expect(narrow.weeks == 12 && abs(narrow.cell - (200 - 33) / 12) < 0.001)
        #expect(WeekCard.Grid.layout(width: 150, cell: 14) == (12, 12))
        #expect(WeekCard.Grid.height(cell: 14) == 116 && WeekCard.Grid.height(cell: 12) == 102)
    }

    @Test func lastColumnIsThisWeekMondayToSunday() {
        let now = date(10, 28, 9)   // 週三
        let weeks = WeekCard.weeks(regions: [:], now: now, count: 20, calendar: calendar)
        #expect(weeks.count == 20)
        // 最右邊一欄是本週：週一到週日（地區設定的一週從週日開始也一樣）
        #expect(weeks.last?.monday == day(10, 26))
        #expect(weeks.last?.days.map(\.date) == (26...31).map { day(10, $0) } + [day(11, 1)])
        // 每一欄是連續的一週，由上到下週一到週日；第一欄是 19 週前
        #expect(weeks.first?.monday == day(2026, 6, 15))
        for (index, week) in weeks.enumerated() {
            #expect(week.days.count == 7)
            #expect(week.days.map(\.date) == (0..<7).map { calendar.date(byAdding: .day, value: $0, to: week.monday)! })
            #expect(calendar.component(.weekday, from: week.monday) == 2)
            if index > 0 { #expect(calendar.date(byAdding: .day, value: 7, to: weeks[index - 1].monday) == week.monday) }
        }
    }

    @Test func todayIsMarkedAndTheRestOfThisWeekIsOutlined() {
        let now = date(10, 28, 9)
        // 今天之後的日子即使有資料也不上色（只畫外框）
        let regions: [Date: DayRegion] = [day(10, 26): .lower, day(10, 28): .upper, day(10, 30): .full, day(10, 21): .cardio]
        let weeks = WeekCard.weeks(regions: regions, now: now, count: 12, calendar: calendar)
        let all = weeks.flatMap(\.days)
        #expect(all.filter(\.isToday).map(\.date) == [day(10, 28)])
        #expect(all.filter(\.isFuture).map(\.date) == [29, 30, 31].map { day(10, $0) } + [day(11, 1)])
        #expect(all.filter(\.isFuture).allSatisfy { $0.region == nil })
        // 今天有練：照部位上色，外框另外畫
        #expect(all.first { $0.isToday }?.region == .upper)
        // 前面的週沒有「之後」的日子
        #expect(weeks.dropLast().allSatisfy { $0.days.allSatisfy { !$0.isFuture && !$0.isToday } })
        // 週一 0 點：本週只有今天，後面 6 天都是之後；週日晚上：沒有之後的日子
        let monday = WeekCard.weeks(regions: regions, now: date(10, 26, 0), count: 12, calendar: calendar).last!
        #expect(monday.days.first?.isToday == true && monday.days.dropFirst().allSatisfy(\.isFuture))
        let sunday = WeekCard.weeks(regions: regions, now: date(11, 1, 23), count: 12, calendar: calendar).last!
        #expect(sunday.monday == day(10, 26) && sunday.days.last?.isToday == true && sunday.days.allSatisfy { !$0.isFuture })
        // 下一個週一是新的一欄
        #expect(WeekCard.weeks(regions: regions, now: date(11, 2, 0), count: 12, calendar: calendar).last?.monday == day(11, 2))
    }

    @Test func monthsAreLabeledOnTheFirstMondayColumn() {
        let weeks = WeekCard.weeks(regions: [:], now: date(10, 28, 9), count: 20, calendar: calendar)
        let labeled = weeks.filter { $0.month != nil }
        // 每個月第一個週一：7/6、8/3、9/7、10/5（6/15 那欄不是 6 月的第一個週一）
        #expect(labeled.map(\.monday) == [day(7, 6), day(8, 3), day(9, 7), day(10, 5)])
        #expect(labeled.map(\.month) == ["7月", "8月", "9月", "10月"])
        // 月初不是週一：那個月第一個週一（1～7 號）才標
        #expect(WeekCard.monthLabel(monday: day(2026, 6, 1), calendar: calendar) == "6月")
        #expect(WeekCard.monthLabel(monday: day(2026, 6, 8), calendar: calendar) == nil)
        #expect(WeekCard.monthLabel(monday: day(2026, 9, 7), calendar: calendar) == "9月")
        #expect(WeekCard.monthLabel(monday: day(2026, 8, 31), calendar: calendar) == nil)
    }

    @Test func calendarCrossesMonthsAndTheYear() {
        // 2027/1/6（週三）：本週從 2027/1/4（週一）開始，那天也是 1 月的第一個週一
        let now = calendar.date(from: DateComponents(year: 2027, month: 1, day: 6, hour: 9))!
        let regions: [Date: DayRegion] = [day(2026, 12, 31): .lower, day(2027, 1, 1): .upper, day(2027, 1, 4): .full]
        let weeks = WeekCard.weeks(regions: regions, now: now, count: 12, calendar: calendar)
        #expect(weeks.last?.monday == day(2027, 1, 4) && weeks.last?.month == "1月")
        // 跨年的那一週：12/28（週一）到 1/3（週日）在同一欄，不標月份
        let newYear = weeks[weeks.count - 2]
        #expect(newYear.monday == day(2026, 12, 28) && newYear.month == nil)
        #expect(newYear.days.map(\.date) == [28, 29, 30, 31].map { day(2026, 12, $0) } + [1, 2, 3].map { day(2027, 1, $0) })
        #expect(newYear.days.map(\.region) == [nil, nil, nil, .lower, .upper, nil, nil])
        #expect(weeks.last?.days.first?.region == .full)
        // 跨月：11/30 那週有 12/1～12/6，標在 12/7（12 月第一個週一）
        #expect(weeks.first { $0.monday == day(2026, 11, 30) }?.month == nil)
        #expect(weeks.first { $0.monday == day(2026, 12, 7) }?.month == "12月")
        #expect(weeks.first { $0.monday == day(2026, 11, 2) }?.month == "11月")
    }

    /// 日曆每一格的部位就是統計快照的 dayRegions（DayRegion.of／merged，和訓練頻率同一套）
    @Test func cellsMatchTheSnapshotDayRegions() {
        let now = date(10, 28, 9)
        let squat = PlanHistory.Item(exerciseID: UUID(), category: .kneeDominant, role: .lowerAssist, sets: [set(60, 5)])
        let bench = PlanHistory.Item(exerciseID: UUID(), category: .horizontalPush, role: .push, sets: [set(40, 8)])
        let run = PlanHistory.Item(exerciseID: UUID(), category: .cardio, role: .cardio, sets: [SetValues(minutes: 30, isCompleted: true)])
        // 沒打勾：PlanHistory(sessions:) 只帶完成的組，所以這個動作沒有組（SwiftData 的版本在 TrainingRegionTests）
        let unchecked = PlanHistory.Item(exerciseID: UUID(), category: .kneeDominant, role: .lowerAssist, sets: [])
        let history = PlanHistory([
            // 同一天下肢、上肢分兩次練：全身
            PlanHistory.Session(date: date(10, 27, 8), items: [squat]),
            PlanHistory.Session(date: date(10, 27, 19), items: [bench]),
            // 只有有氧：中性灰
            PlanHistory.Session(date: date(10, 26), items: [run]),
            // 有氧不影響有重訓的日子
            PlanHistory.Session(date: date(10, 20), items: [bench, run]),
            // 沒打勾的那天沒有顏色
            PlanHistory.Session(date: date(10, 19), items: [unchecked]),
            // 很久以前（日曆的第一欄）也有
            PlanHistory.Session(date: date(8, 4), items: [squat]),
        ])
        let snapshot = StatsSnapshot.make(history: history, exercises: [], now: now, calendar: calendar)
        let cells = WeekCard.weeks(regions: snapshot.dayRegions, now: now, count: 13, calendar: calendar).flatMap(\.days)
        for cell in cells where !cell.isFuture {
            #expect(cell.region == snapshot.dayRegions[cell.date], "\(cell.date)")
        }
        let byDay = Dictionary(uniqueKeysWithValues: cells.map { ($0.date, $0.region) })
        #expect(byDay[day(10, 27)] == .full)
        #expect(byDay[day(10, 26)] == .cardio)
        #expect(byDay[day(10, 20)] == .upper)
        #expect(byDay[day(10, 19)] == .some(nil))
        #expect(byDay[day(8, 4)] == .lower)
        #expect(cells.first?.date == day(8, 3))
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
