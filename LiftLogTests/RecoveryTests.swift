import Foundation
import Testing
@testable import LiftLog

/// CHANGE_18 §2：主項的 48 小時規則。輪到的動作在 48 小時內有完成組就跳過、改用輪替表的下一個；
/// 看的是同一個動作（不分角色、日型，自由選動作也算）；其他格子把 48 小時內練過的排到最後
struct RecoveryTests {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }()

    /// 週二 19:00
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 19))! }
    private func hoursAgo(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

    private struct Lift {
        var name: String
        var category: ExerciseCategory
        var tags: [ExerciseTag] = []
        var me: Int?
        var de: Int?
    }

    private static let lifts: [Lift] = [
        Lift(name: "深蹲", category: .kneeDominant, tags: [.main], me: 1, de: 1),
        Lift(name: "傳統硬舉", category: .hipDominant, tags: [.main], me: 2, de: 4),
        Lift(name: "前蹲舉", category: .kneeDominant, tags: [.main], me: 3),
        Lift(name: "壺鈴擺盪", category: .hipDominant, tags: [.explosive], de: 2),
        Lift(name: "臥推", category: .horizontalPush, tags: [.main], me: 1, de: 1),
        Lift(name: "肩推", category: .verticalPush, tags: [.main], me: 2),
        Lift(name: "地板臥推", category: .horizontalPush, tags: [.main], me: 3),
        Lift(name: "窄握臥推", category: .horizontalPush, tags: [.main], me: 4),
        Lift(name: "借力推舉", category: .verticalPush, tags: [.explosive], de: 2),
        Lift(name: "爆發划船", category: .horizontalPull, tags: [.explosive], de: 3),
        Lift(name: "後腳抬高蹲", category: .kneeDominant, tags: [.unilateral]),
        Lift(name: "單腳 RDL", category: .hipDominant, tags: [.unilateral]),
        Lift(name: "臀推", category: .hipDominant),
        Lift(name: "坐姿 Cable 划船", category: .horizontalPull),
        Lift(name: "單手啞鈴划船", category: .horizontalPull, tags: [.unilateral]),
        Lift(name: "滑輪下拉", category: .verticalPull),
        Lift(name: "輔助引體向上", category: .verticalPull),
        Lift(name: "腹前推", category: .core),
        Lift(name: "棒式划船", category: .core),
        Lift(name: "地雷管抗旋轉", category: .core),
    ]
    private static let ids = Dictionary(uniqueKeysWithValues: lifts.map { ($0.name, UUID()) })
    private static func id(_ name: String) -> UUID { ids[name]! }

    private var exercises: [PlanExercise] {
        Self.lifts.map { PlanExercise(id: Self.id($0.name), name: $0.name, category: $0.category, tags: $0.tags,
                                      meRotation: $0.me, deRotation: $0.de, equipment: .barbell) }
    }

    /// 一次已結束的訓練：每個動作一組，完成時間是開始後 10 分鐘
    private func session(_ start: Date, _ dayType: DayType?, _ items: [(String, Role)]) -> PlanHistory.Session {
        PlanHistory.Session(date: start, dayType: dayType, items: items.map { name, role in
            let lift = Self.lifts.first { $0.name == name }!
            return PlanHistory.Item(exerciseID: Self.id(name), category: lift.category, tags: lift.tags, role: role,
                                    sets: [SetValues(weightKg: 60, reps: 3, isCompleted: true,
                                                     completedAt: start.addingTimeInterval(600))])
        })
    }

    private func candidates(_ slot: Slot, _ dayType: DayType, _ history: PlanHistory, main: String? = nil) -> RankedCandidates {
        let all = history.withLastDates(exercises)
        return PlanRanking.candidates(for: slot, dayType: dayType, exercises: all, history: history,
                                      excluding: main.map { [Self.id($0)] } ?? [],
                                      main: main.flatMap { m in all.first { $0.name == m } }, now: now)
    }

    private func names(_ ranked: RankedCandidates) -> [String] { ranked.items.map(\.exercise.name) }

    private func suggestedMain(_ dayType: DayType, _ history: PlanHistory) -> String? {
        PlanRanking.suggestedMain(for: dayType, exercises: history.withLastDates(exercises), history: history, now: now)?.name
    }

    // MARK: 判斷

    @Test func fortyEightHoursIsRealTimeNotCalendarDays() {
        // 完成組的時間（開始後 10 分鐘）往前推：47 小時前算、49 小時前不算、剛好 48 小時不算
        #expect(Recovery.isRecent(hoursAgo(47), now: now))
        #expect(!Recovery.isRecent(hoursAgo(49), now: now))
        #expect(!Recovery.isRecent(hoursAgo(48), now: now))
        #expect(Recovery.isRecent(hoursAgo(47.99), now: now))
        #expect(!Recovery.isRecent(nil, now: now))
        // 日曆上是兩天前的晚上，但還不到 48 小時：算
        let twoDaysAgoLate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 23))!
        #expect(Recovery.isRecent(twoDaysAgoLate, now: now))
    }

    @Test func whenTextUsesTodayYesterdayOrHours() {
        #expect(Recovery.whenText(hoursAgo(3), now: now, calendar: calendar) == "今天")
        #expect(Recovery.whenText(hoursAgo(20), now: now, calendar: calendar) == "昨天")
        // 前天的晚上 20:00（還在 48 小時內）：寫小時
        #expect(Recovery.whenText(hoursAgo(47), now: now, calendar: calendar) == "47 小時前")
    }

    // MARK: 主項

    /// 規格第 1 節的情境：DE 上肢上次是爆發划船，輪到臥推（速度），但臥推在 48 小時內練過 → 借力推舉
    @Test func skipsTheNextMainDoneWithin48Hours() {
        let last = session(hoursAgo(24 * 6), .deUpper, [("爆發划船", .dynamicEffort)])
        // 47 小時前做過臥推（完成組在開始後 10 分鐘，所以開始時間再往前 10 分鐘）：跳過
        let recent = PlanHistory([last, session(hoursAgo(47 + 1.0 / 6), .meUpper, [("臥推", .maxEffort)])])
        let ranked = candidates(.dynamicEffort, .deUpper, recent)
        #expect(names(ranked) == ["借力推舉", "爆發划船", "臥推"])
        #expect(ranked.reason == "臥推（速度）47 小時前練過，換下一個")
        // 49 小時前：不跳過，原因照舊
        let old = PlanHistory([last, session(hoursAgo(49 + 1.0 / 6), .meUpper, [("臥推", .maxEffort)])])
        let normal = candidates(.dynamicEffort, .deUpper, old)
        #expect(names(normal) == ["臥推", "借力推舉", "爆發划船"])
        #expect(normal.reason == "輪替的下一個（上次：爆發划船）")
    }

    @Test func reasonSaysYesterdayOrToday() {
        let last = session(hoursAgo(24 * 6), .deUpper, [("爆發划船", .dynamicEffort)])
        let yesterday = PlanHistory([last, session(hoursAgo(24), nil, [("臥推", .push)])])
        #expect(candidates(.dynamicEffort, .deUpper, yesterday).reason == "臥推（速度）昨天練過，換下一個")
        // ME 的主項沒有「（速度）」
        let me = PlanHistory([session(hoursAgo(24 * 5), .meUpper, [("窄握臥推", .maxEffort)]),
                              session(hoursAgo(24), nil, [("臥推", .push)])])
        let suggestion = Rotation(slot: .maxEffort, dayType: .meUpper, exercises: me.withLastDates(exercises), history: me)
            .suggestion(now: now, calendar: calendar)
        #expect(suggestion.order.first?.name == "肩推")
        #expect(suggestion.reason == "臥推昨天練過，換下一個")
        let today = PlanHistory([session(hoursAgo(24 * 5), .meUpper, [("窄握臥推", .maxEffort)]),
                                 session(hoursAgo(3), nil, [("臥推", .push)])])
        #expect(Rotation(slot: .maxEffort, dayType: .meUpper, exercises: today.withLastDates(exercises), history: today)
            .suggestion(now: now, calendar: calendar).reason == "臥推今天練過，換下一個")
    }

    @Test func twoInARowWithin48HoursGoesFurtherDown() {
        // ME 上肢上次窄握臥推 → 輪到臥推（昨天做過）→ 肩推（今天做過）→ 地板臥推
        let history = PlanHistory([
            session(hoursAgo(24 * 4), .meUpper, [("窄握臥推", .maxEffort)]),
            session(hoursAgo(24), .deUpper, [("臥推", .dynamicEffort)]),
            session(hoursAgo(5), nil, [("肩推", .push)]),
        ])
        let suggestion = Rotation(slot: .maxEffort, dayType: .meUpper, exercises: history.withLastDates(exercises), history: history)
            .suggestion(now: now, calendar: calendar)
        #expect(suggestion.order.map(\.name) == ["地板臥推", "窄握臥推", "臥推", "肩推"])
        #expect(suggestion.reason == "臥推昨天練過、肩推今天練過，換下一個")
        #expect(suggestedMain(.meUpper, history) == "地板臥推")
    }

    @Test func wholePoolWithin48HoursPicksTheOldest() {
        // DE 上肢三個都在 48 小時內：最近一次完成組離現在最久的是借力推舉
        let history = PlanHistory([
            session(hoursAgo(30), .deUpper, [("爆發划船", .dynamicEffort)]),
            session(hoursAgo(10), .meUpper, [("臥推", .maxEffort)]),
            session(hoursAgo(40), nil, [("借力推舉", .push)]),
        ])
        let ranked = candidates(.dynamicEffort, .deUpper, history)
        #expect(names(ranked) == ["借力推舉", "爆發划船", "臥推"])
        #expect(ranked.reason == "都在 48 小時內練過，選最久沒練的")
    }

    /// 同一個動作：速度版和一般版一起算；不同日型、不同角色、自由選動作做過的都算
    @Test func sameExerciseAcrossRolesDayTypesAndFreeWorkouts() {
        let last = session(hoursAgo(24 * 6), .deUpper, [("爆發划船", .dynamicEffort)])
        let cases: [(String, PlanHistory.Session)] = [
            ("DE 主項（速度版）", session(hoursAgo(30), .deUpper, [("臥推", .dynamicEffort)])),
            ("ME 主項（一般版、不同日型）", session(hoursAgo(30), .meUpper, [("臥推", .maxEffort)])),
            ("推（不同角色）", session(hoursAgo(30), .meLower, [("深蹲", .maxEffort), ("臥推", .push)])),
            ("自由選動作", session(hoursAgo(30), nil, [("臥推", .push)])),
        ]
        for (label, recent) in cases {
            let history = PlanHistory([last, recent])
            #expect(suggestedMain(.deUpper, history) == "借力推舉", "\(label)")
        }
        // 「臥推（速度）」和「臥推」是同一個動作：DE 上肢做過速度臥推，ME 上肢的臥推也跳過
        let speed = PlanHistory([session(hoursAgo(24 * 5), .meUpper, [("窄握臥推", .maxEffort)]),
                                 session(hoursAgo(20), .deUpper, [("臥推", .dynamicEffort)])])
        #expect(suggestedMain(.meUpper, speed) == "肩推")
    }

    /// 跳過之後，下一次從實際用的主項往下接；被跳過的只是延後一輪
    @Test func afterSkippingTheRotationContinuesFromWhatWasUsed() {
        var sessions = [session(hoursAgo(24 * 6), .deUpper, [("爆發划船", .dynamicEffort)]),
                        session(hoursAgo(20), .meUpper, [("臥推", .maxEffort)])]
        #expect(suggestedMain(.deUpper, PlanHistory(sessions)) == "借力推舉")
        // 照建議做了借力推舉；三天後（臥推已經超過 48 小時）輪到爆發划船，不是補回臥推
        sessions.append(session(hoursAgo(2), .deUpper, [("借力推舉", .dynamicEffort)]))
        let later = now.addingTimeInterval(3 * 86_400)
        let history = PlanHistory(sessions)
        let main = PlanRanking.suggestedMain(for: .deUpper, exercises: history.withLastDates(exercises), history: history, now: later)
        #expect(main?.name == "爆發划船")
        // 再下一次才回到臥推
        sessions.append(session(later, .deUpper, [("爆發划船", .dynamicEffort)]))
        let after = PlanHistory(sessions)
        #expect(PlanRanking.suggestedMain(for: .deUpper, exercises: after.withLastDates(exercises), history: after,
                                          now: later.addingTimeInterval(4 * 86_400))?.name == "臥推")
    }

    // MARK: 其他格子

    @Test func otherSlotsPutRecentExercisesLast() {
        // 上次拉是垂直（滑輪下拉）→ 這次先水平；兩個水平拉都在 48 小時內 → 排到最後，垂直的輔助引體向上變成建議
        let history = PlanHistory([
            session(hoursAgo(20), nil, [("滑輪下拉", .pull)]),
            session(hoursAgo(30), nil, [("坐姿 Cable 划船", .pull)]),
            session(hoursAgo(40), nil, [("單手啞鈴划船", .pull)]),
        ])
        #expect(PlanRanking.lastPullDirection(history) == .verticalPull)
        let pull = candidates(.pull, .meUpper, history)
        // 排除後照原本的排序（方向、最久沒做）；排到最後的三個也照原本的順序
        #expect(names(pull) == ["輔助引體向上", "單手啞鈴划船", "坐姿 Cable 划船", "滑輪下拉"])
        #expect(pull.reason == "還沒練過")

        // 下肢輔助：主項是膝主導 → 先髖主導、單邊；單腳 RDL 昨天練過 → 換臀推，單腳 RDL 排最後
        let assist = PlanHistory([session(hoursAgo(24), nil, [("單腳 RDL", .lowerAssist)])])
        let lower = candidates(.lowerAssist, .meLower, assist, main: "深蹲")
        #expect(names(lower) == ["臀推", "後腳抬高蹲", "單腳 RDL"])
        #expect(lower.reason == "主項是膝主導，換髖主導")
    }

    @Test func otherSlotsKeepTheOriginalOrderWhenEveryCandidateIsRecent() {
        // 核心三個都在 48 小時內：不排除，照原本的最久沒練優先
        let history = PlanHistory([
            session(hoursAgo(10), nil, [("腹前推", .core)]),
            session(hoursAgo(40), nil, [("棒式划船", .core)]),
            session(hoursAgo(25), nil, [("地雷管抗旋轉", .core)]),
        ])
        let core = candidates(.core, .meLower, history)
        #expect(names(core) == ["棒式划船", "地雷管抗旋轉", "腹前推"])
        #expect(core.reason == "最久沒做（昨天）" || core.reason == "最久沒做（2 天前）")
        // deferringRecent：全部都在 48 小時內時就是原本的順序
        let list = history.withLastDates(exercises).filter { $0.category == .core }
        #expect(Recovery.deferringRecent(list, now: now) == list)
    }

    // MARK: 資料來源（S2）

    @Test func lastCompletedDateIsTheLatestCompletedSet() {
        let start = hoursAgo(30)
        let history = PlanHistory([PlanHistory.Session(date: start, dayType: nil, items: [
            PlanHistory.Item(exerciseID: Self.id("臥推"), category: .horizontalPush, role: .push, sets: [
                SetValues(weightKg: 60, reps: 5, isCompleted: true, completedAt: start.addingTimeInterval(300)),
                SetValues(weightKg: 60, reps: 5, isCompleted: true, completedAt: start.addingTimeInterval(1200)),
                SetValues(weightKg: 60, reps: 5, isCompleted: false, completedAt: start.addingTimeInterval(9000)),
            ]),
            // 舊資料沒有完成時間：用那次訓練的時間
            PlanHistory.Item(exerciseID: Self.id("深蹲"), category: .kneeDominant, role: .lowerAssist,
                             sets: [SetValues(weightKg: 60, reps: 5, isCompleted: true)]),
            // 沒有完成組：沒有時間
            PlanHistory.Item(exerciseID: Self.id("肩推"), category: .verticalPush, role: .push, sets: []),
        ])])
        #expect(history.lastCompletedDates[Self.id("臥推")] == start.addingTimeInterval(1200))
        #expect(history.lastCompletedDates[Self.id("深蹲")] == start)
        #expect(history.lastCompletedDates[Self.id("肩推")] == nil)
        // 候選的 lastDate（48 小時規則和「最久沒做」）都是它
        let filled = history.withLastDates(exercises)
        #expect(filled.first { $0.name == "臥推" }?.lastDate == start.addingTimeInterval(1200))
        // 統計快照的「最近一次」也是同一個值
        let snapshot = StatsSnapshot.make(history: history, exercises: exercises, now: now, calendar: calendar)
        #expect(snapshot.exercises[Self.id("臥推")]?.lastDate == start.addingTimeInterval(1200))
    }

    /// 「下一次」卡（統計快照）在某個動作滿 48 小時的時間重算，主項才會和建立菜單一樣
    @Test func snapshotRecomputesWhenA48HourWindowEnds() {
        let history = PlanHistory([
            session(hoursAgo(24 * 6), .deUpper, [("爆發划船", .dynamicEffort)]),
            session(hoursAgo(20), nil, [("臥推", .push)]),
            session(hoursAgo(24 * 3), .deLower, [("深蹲", .dynamicEffort)]),
        ])
        let snapshot = StatsSnapshot.make(history: history, exercises: exercises, now: now, calendar: calendar)
        #expect(snapshot.nextPlan.dayType == .deUpper)
        #expect(snapshot.suggestedMain?.name == "借力推舉")
        #expect(snapshot.trainingStatus.rotation.first { $0.dayType == .deUpper }?.nextMain == "借力推舉")
        // 臥推的完成組在 20 小時前（開始後 10 分鐘）：滿 48 小時是 28 小時後
        let boundary = hoursAgo(20).addingTimeInterval(600 + 48 * 3600)
        #expect(snapshot.recoveryBoundary == boundary)
        // 同一天回到前景：還沒到不重算、到了就重算（沒有 validUntil 時同一天不會重算）
        let computed = boundary.addingTimeInterval(-2 * 3600)
        #expect(calendar.isDate(computed, inSameDayAs: boundary))
        #expect(!StatsRefresh.needsRecompute(.foreground, computedAt: computed, validUntil: boundary,
                                             now: boundary.addingTimeInterval(-60), calendar: calendar))
        #expect(StatsRefresh.needsRecompute(.foreground, computedAt: computed, validUntil: boundary, now: boundary, calendar: calendar))
        #expect(!StatsRefresh.needsRecompute(.foreground, computedAt: computed, now: boundary, calendar: calendar))
        // 過了之後重算：輪到臥推（速度）
        let later = StatsSnapshot.make(history: history, exercises: exercises, now: boundary, calendar: calendar)
        #expect(later.suggestedMain?.name == "臥推")
    }
}
