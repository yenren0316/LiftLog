import Foundation
import Testing
@testable import LiftLog

/// 共軛訓練的建立菜單：日型預設、格子、候選排序、主項輪替、建議重量（含規格的 8 個驗收情境）
struct PlanTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func day(_ daysAgo: Double) -> Date { now.addingTimeInterval(-daysAgo * 86_400) }

    /// 動作庫 v2 的分類；標籤和輪替順序取自 ConjugateLibrary.entries
    private static let categories: [String: ExerciseCategory] = {
        var map: [String: ExerciseCategory] = [:]
        let groups: [(ExerciseCategory, [String])] = [
            (.kneeDominant, ["深蹲", "前蹲舉", "後腳抬高蹲", "高背槓分腿蹲", "側蹲", "負重原地起跳"]),
            (.hipDominant, ["傳統硬舉", "六角槓硬舉", "相撲硬舉", "槓鈴早安式", "羅馬尼亞式硬舉", "單腳 RDL", "臀推", "壺鈴擺盪", "單手抓舉"]),
            (.horizontalPush, ["臥推", "上斜臥推", "地板臥推", "窄握臥推", "啞鈴臥推", "啞鈴上斜臥推", "地板啞鈴臥推"]),
            (.horizontalPull, ["爆發划船", "反式划船", "坐姿 Cable 划船", "槓鈴俯身划船", "單手啞鈴划船", "胸靠上斜椅啞鈴划船"]),
            (.verticalPush, ["肩推", "坐姿槓鈴肩推", "坐姿啞鈴肩推", "雙槓撐", "借力推舉"]),
            (.verticalPull, ["輔助引體向上", "滑輪下拉"]),
            (.core, ["腹前推", "地雷管抗旋轉", "坐姿分腿壺鈴三點搬移", "六角槓原地踏步", "仰臥拉舉", "單手啞鈴臥推",
                     "棒式划船", "窄跪姿單手啞鈴肩推", "單手壺鈴擺盪", "行李箱原地踏步"]),
            (.accessory, ["三頭肌滑輪下拉", "二頭彎舉", "面拉", "YTW", "仰臥啞鈴三頭伸展", "JM 推"]),
            (.cardio, ["跑步機"]),
        ]
        for (category, names) in groups { for name in names { map[name] = category } }
        return map
    }()

    /// 全部動作；lastDates 指定幾天前做過（沒指定就是沒練過）
    private func library(_ lastDates: [String: Double] = [:]) -> [PlanExercise] {
        ConjugateLibrary.entries.map { entry in
            PlanExercise(id: Self.id(entry.name), name: entry.name, category: Self.categories[entry.name]!, tags: entry.tags,
                         lastDate: lastDates[entry.name].map(day), meRotation: entry.me, deRotation: entry.de,
                         logType: entry.name == "跑步機" ? .cardio : .weight)
        }
    }

    private static let ids = Dictionary(uniqueKeysWithValues: categories.keys.map { ($0, UUID()) })
    private static func id(_ name: String) -> UUID { ids[name]! }

    private func item(_ name: String, _ role: Role, sets: [SetValues] = []) -> PlanHistory.Item {
        PlanHistory.Item(exerciseID: Self.id(name), category: Self.categories[name]!, tags: [], role: role, sets: sets)
    }

    private func session(_ daysAgo: Double, _ dayType: DayType?, _ items: [PlanHistory.Item]) -> PlanHistory.Session {
        PlanHistory.Session(date: day(daysAgo), dayType: dayType, items: items)
    }

    private func names(_ ranked: RankedCandidates) -> [String] { ranked.items.map(\.exercise.name) }

    private func candidates(_ slot: Slot, _ dayType: DayType, history: PlanHistory = PlanHistory([]),
                            lastDates: [String: Double] = [:], main: String? = nil) -> RankedCandidates {
        let all = library(lastDates)
        return PlanRanking.candidates(for: slot, dayType: dayType, exercises: all, history: history,
                                      excluding: main.map { [Self.id($0)] } ?? [],
                                      main: main.flatMap { m in all.first { $0.name == m } }, now: now)
    }

    // MARK: 動作庫 v2

    @Test func libraryTablesFollowTheSpec() {
        let all = library()
        #expect(all.count == 52)  // 51 個重訓動作＋跑步機
        #expect(all.filter { $0.has(.main) }.count == 12)
        func table(_ slot: Slot, _ dayType: DayType) -> [String] {
            Rotation(slot: slot, dayType: dayType, exercises: all, history: PlanHistory([])).table.map(\.name)
        }
        #expect(table(.maxEffort, .meLower) == ["深蹲", "傳統硬舉", "前蹲舉", "槓鈴早安式", "六角槓硬舉", "相撲硬舉"])
        #expect(table(.maxEffort, .meUpper) == ["臥推", "肩推", "地板臥推", "窄握臥推", "坐姿槓鈴肩推", "上斜臥推"])
        #expect(table(.dynamicEffort, .deLower) == ["深蹲", "壺鈴擺盪", "負重原地起跳", "傳統硬舉", "單手抓舉"])
        #expect(table(.dynamicEffort, .deUpper) == ["臥推", "借力推舉", "爆發划船"])
        // ME 主項只從「主」裡選
        #expect(all.filter { $0.meRotation != nil }.allSatisfy { $0.has(.main) })
    }

    @Test func assistancePoolsExcludeMainAndExplosive() {
        #expect(Set(names(candidates(.lowerAssist, .meLower)))
                == ["後腳抬高蹲", "高背槓分腿蹲", "側蹲", "羅馬尼亞式硬舉", "單腳 RDL", "臀推"])
        #expect(Set(names(candidates(.pull, .meUpper)))
                == ["反式划船", "坐姿 Cable 划船", "槓鈴俯身划船", "單手啞鈴划船", "胸靠上斜椅啞鈴划船", "輔助引體向上", "滑輪下拉"])
        #expect(names(candidates(.core, .meLower)).count == 10)
        #expect(names(candidates(.accessory, .meUpper)).count == 6)
        #expect(names(candidates(.cardio, .meUpper)) == ["跑步機"])
    }

    // MARK: 驗收情境

    @Test func scenario1NoHistory() {
        let history = PlanHistory([])
        let answers = PlanDefaults.answers(history)
        #expect(answers == PlanAnswers(dayType: .meLower, count: PlanDefaults.countWithoutHistory, cardio: false))
        let main = candidates(.maxEffort, .meLower, history: history)
        #expect(names(main).first == "深蹲")
        #expect(main.reason == "輪替從第 1 個開始")
    }

    @Test func scenario2RotationContinuesAfterLastMain() {
        let history = PlanHistory([session(2, .meLower, [item("深蹲", .maxEffort), item("單腳 RDL", .lowerAssist)])])
        #expect(PlanDefaults.dayType(history) == .meUpper)
        let main = candidates(.maxEffort, .meLower, history: history)
        #expect(names(main) == ["傳統硬舉", "前蹲舉", "槓鈴早安式", "六角槓硬舉", "相撲硬舉", "深蹲"])
        #expect(main.reason == "輪替的下一個（上次：深蹲）")
        // 最多顯示 5 個，深蹲排第 6 不顯示
        #expect(!main.items.prefix(PlanRanking.visibleCount).contains { $0.exercise.name == "深蹲" })
    }

    @Test func scenario3CardioOnlyDoesNotAdvance() {
        let history = PlanHistory([
            session(1, nil, [item("跑步機", .cardio)]),
            session(3, .meLower, [item("深蹲", .maxEffort)]),
        ])
        #expect(PlanDefaults.dayType(history) == .meUpper)
    }

    @Test func scenario4DEUpperIsFollowedByMELower() {
        let history = PlanHistory([session(1, .deUpper, [item("臥推", .dynamicEffort)]),
                                   session(4, .meLower, [item("深蹲", .maxEffort)])])
        #expect(PlanDefaults.dayType(history) == .meLower)
        // 沒有日型的舊紀錄不算：只有舊紀錄時從 ME 下肢開始
        let legacy = PlanHistory([session(1, nil, [item("臥推", .main)])])
        #expect(PlanDefaults.dayType(legacy) == .meLower)
    }

    @Test func scenario5LowerAssistPrefersOtherPatternThenUnilateral() {
        let answers = PlanAnswers(dayType: .meLower, count: 2, cardio: false)
        let states = PlanRanking.resolve(answers: answers, picks: [:], exercises: library(), history: PlanHistory([]), now: now)
        #expect(states.map(\.slot) == [.maxEffort, .lowerAssist])
        #expect(states[0].selected?.name == "深蹲")
        let assist = states[1].candidates
        let shown = assist.items.prefix(PlanRanking.visibleCount).map(\.exercise)
        #expect(shown.prefix(3).allSatisfy { $0.category == .hipDominant })
        #expect(shown.first?.name == "單腳 RDL")
        #expect(shown.suffix(2).allSatisfy { $0.category == .kneeDominant && $0.has(.unilateral) })
        #expect(assist.reason == "主項是膝主導，換髖主導・單邊")
    }

    @Test func scenario6PullAlternatesDirection() {
        let history = PlanHistory([session(3, .meUpper, [item("臥推", .maxEffort), item("槓鈴俯身划船", .pull)])])
        let pull = candidates(.pull, .meUpper, history: history)
        #expect(names(pull).prefix(2).sorted() == ["滑輪下拉", "輔助引體向上"])
        #expect(pull.reason == "上次是水平拉，這次換垂直")
        // 沒有拉的紀錄：先水平
        let fresh = candidates(.pull, .meUpper)
        #expect(fresh.items.first?.exercise.category == .horizontalPull)
        #expect(fresh.reason == "還沒有拉的紀錄，先做水平拉")
    }

    @Test func scenario7PowerRowAsMainTurnsPullIntoPush() {
        let answers = PlanAnswers(dayType: .deUpper, count: 3, cardio: true)
        let all = library()
        let row = all.first { $0.name == "爆發划船" }!
        let states = PlanRanking.resolve(answers: answers, picks: [.dynamicEffort: row.id], exercises: all,
                                         history: PlanHistory([]), now: now)
        #expect(states.map(\.slot) == [.dynamicEffort, .push, .accessory, .cardio])
        #expect(Set(names(states[1].candidates)) == ["啞鈴臥推", "啞鈴上斜臥推", "地板啞鈴臥推", "坐姿啞鈴肩推", "雙槓撐"])
        // 改回臥推：即時變回「拉」
        let bench = PlanRanking.resolve(answers: answers, picks: [:], exercises: all, history: PlanHistory([]), now: now)
        #expect(bench[0].selected?.name == "臥推")
        #expect(bench.map(\.slot) == [.dynamicEffort, .pull, .accessory, .cardio])
    }

    @Test func scenario8SpeedSquatIsSixtyPercentOfEstimatedMax() {
        let squat = library().first { $0.name == "深蹲" }!
        let logs = [ExerciseLog(date: day(5), role: .maxEffort, sets: [
            SetValues(kind: .warmup, weightKg: 60, reps: 5, isCompleted: true),
            SetValues(weightKg: 90, reps: 3, isCompleted: true),
            SetValues(weightKg: 100, reps: 3, isCompleted: true),
            SetValues(weightKg: 105, reps: 1, isCompleted: false),
        ])]
        let advice = SlotAdvice.make(role: .dynamicEffort, exercise: squat, logs: logs, unit: .kg)
        #expect(advice.speedWeightKg == 65)
        #expect(advice.weightText == "建議 65 kg（估算 1RM 110 kg × 60%）")
        #expect(advice.prescription.summary == "8 組 × 2 下・休息 45–60 秒")
        // 沒有 ME 紀錄：不顯示重量
        let none = SlotAdvice.make(role: .dynamicEffort, exercise: squat,
                                   logs: [ExerciseLog(date: day(3), role: .lowerAssist, sets: [SetValues(weightKg: 80, reps: 8, isCompleted: true)])],
                                   unit: .kg)
        #expect(none.speedWeightKg == nil && none.weightText == "用能做得很快的重量")
    }

    // MARK: 其他規則

    @Test func manualMainContinuesFromWhatWasActuallyUsed() {
        // 建議硬舉卻做了前蹲舉：下一次從前蹲舉往下接
        let history = PlanHistory([
            session(3, .meLower, [item("前蹲舉", .maxEffort)]),
            session(10, .meLower, [item("深蹲", .maxEffort)]),
            session(6, .deLower, [item("壺鈴擺盪", .dynamicEffort)]),
        ])
        #expect(names(candidates(.maxEffort, .meLower, history: history)).first == "槓鈴早安式")
        // 每個日型各自記：DE 下肢從壺鈴擺盪往下
        #expect(names(candidates(.dynamicEffort, .deLower, history: history)).first == "負重原地起跳")
        // 排到最後再回到 1
        let wrap = PlanHistory([session(2, .deUpper, [item("爆發划船", .dynamicEffort)])])
        #expect(names(candidates(.dynamicEffort, .deUpper, history: wrap)) == ["臥推", "借力推舉", "爆發划船"])
    }

    @Test func slotsByDayTypeAndCount() {
        func slots(_ dayType: DayType, _ count: Int, cardio: Bool = false) -> [Slot] {
            Slot.slots(for: PlanAnswers(dayType: dayType, count: count, cardio: cardio), mainCategory: nil)
        }
        #expect(slots(.meLower, 1) == [.maxEffort])
        #expect(slots(.deLower, 2) == [.dynamicEffort, .lowerAssist])
        #expect(slots(.meLower, 3, cardio: true) == [.maxEffort, .lowerAssist, .core, .cardio])
        #expect(slots(.meUpper, 2) == [.maxEffort, .pull])
        #expect(slots(.deUpper, 3) == [.dynamicEffort, .pull, .accessory])
        #expect(Slot.slots(for: PlanAnswers(dayType: .deUpper, count: 2, cardio: false), mainCategory: .horizontalPull)
                == [.dynamicEffort, .push])
    }

    @Test func countAndCardioDefaultsFromLastSession() {
        let history = PlanHistory([
            session(1, .meUpper, [item("臥推", .maxEffort), item("滑輪下拉", .pull), item("面拉", .accessory), item("跑步機", .cardio)]),
            session(4, .meLower, [item("深蹲", .maxEffort)]),
        ])
        let answers = PlanDefaults.answers(history)
        #expect(answers == PlanAnswers(dayType: .deLower, count: 3, cardio: true))  // 有氧不算在動作數
        // 上次只做有氧：動作數看上一次重訓，跑步機看上一次訓練
        let cardioLast = PlanHistory([session(0, nil, [item("跑步機", .cardio)]), session(4, .meLower, [item("深蹲", .maxEffort)])])
        #expect(PlanDefaults.answers(cardioLast) == PlanAnswers(dayType: .meUpper, count: 1, cardio: true))
    }

    @Test func stalestFirstWithNewAndReasons() {
        let core = candidates(.core, .meLower, lastDates: Dictionary(uniqueKeysWithValues:
            ["腹前推", "地雷管抗旋轉", "坐姿分腿壺鈴三點搬移", "六角槓原地踏步", "仰臥拉舉", "單手啞鈴臥推",
             "棒式划船", "窄跪姿單手啞鈴肩推", "單手壺鈴擺盪"].enumerated().map { ($1, Double($0 + 3)) }))
        // 沒練過的視為最久沒做，標「新」
        #expect(core.items.first?.exercise.name == "行李箱原地踏步" && core.items.first?.isNew == true)
        #expect(core.reason == "還沒練過")
        #expect(core.items[1].exercise.name == "單手壺鈴擺盪")
        let accessory = candidates(.accessory, .meUpper, lastDates: ["三頭肌滑輪下拉": 9, "二頭彎舉": 2, "面拉": 4, "YTW": 5,
                                                                    "仰臥啞鈴三頭伸展": 1, "JM 推": 3])
        #expect(accessory.items.first?.exercise.name == "三頭肌滑輪下拉")
        #expect(accessory.reason == "最久沒做（9 天前）")
    }

    @Test func picksAreNotRepeatedAcrossSlots() {
        let all = library()
        let rdl = all.first { $0.name == "單腳 RDL" }!
        let answers = PlanAnswers(dayType: .meLower, count: 3, cardio: false)
        let states = PlanRanking.resolve(answers: answers, picks: [.lowerAssist: rdl.id], exercises: all,
                                         history: PlanHistory([]), now: now)
        #expect(states[1].selected?.name == "單腳 RDL")
        let chosen = states.compactMap(\.selected?.id)
        #expect(Set(chosen).count == chosen.count)
        #expect(!states[2].candidates.items.contains { $0.id == states[0].selected?.id })
    }

    @Test func lastPullDirectionReadsTheMostRecentPullRole() {
        let history = PlanHistory([
            session(1, .meLower, [item("深蹲", .maxEffort)]),
            session(3, nil, [item("滑輪下拉", .pull), item("坐姿 Cable 划船", .pull)]),
        ])
        #expect(PlanRanking.lastPullDirection(history) == .horizontalPull)
        #expect(PlanRanking.lastPullDirection(PlanHistory([])) == nil)
    }

    // MARK: ME 紀錄與首頁統計

    @Test func maxEffortRecordsUseOnlyMERoleAndHeaviestSuccessfulSet() {
        let logs = [
            ExerciseLog(date: day(1), role: .dynamicEffort, sets: [SetValues(weightKg: 65, reps: 2, isCompleted: true)]),
            ExerciseLog(date: day(8), role: .maxEffort, sets: [SetValues(weightKg: 100, reps: 3, isCompleted: true),
                                                              SetValues(weightKg: 100, reps: 2, isCompleted: true)]),
            ExerciseLog(date: day(20), role: .maxEffort, sets: [SetValues(weightKg: 95, reps: 3, isCompleted: true)]),
            ExerciseLog(date: day(30), role: .main, sets: [SetValues(weightKg: 120, reps: 1, isCompleted: true)]),
        ]
        let records = MaxEffortRecords.records(logs)
        #expect(records.map(\.weightKg) == [100, 95])
        #expect(records[0].reps == 3 && abs(records[0].estimated1RM - 110) < 0.001)
        let summary = MainLiftSummary(logs: logs)
        #expect(summary.latest == records[0])
        #expect(abs(summary.change! - (110 - 104.5)) < 0.001)
        #expect(MainLiftSummary(logs: []).latest == nil)
        #expect(MainLiftSummary(logs: Array(logs.prefix(2))).change == nil)
    }

    @Test func recentVolumeCountsSetsAndPushPull() {
        let done = SetValues(weightKg: 40, reps: 10, isCompleted: true)
        let warmup = SetValues(kind: .warmup, weightKg: 20, reps: 10, isCompleted: true)
        let history = PlanHistory([
            session(2, .meUpper, [item("臥推", .maxEffort, sets: [warmup, done, done, done]),
                                  item("肩推", .push, sets: [done, done]),
                                  item("滑輪下拉", .pull, sets: [done, done, done])]),
            session(40, .meUpper, [item("坐姿 Cable 划船", .pull, sets: [done, done, done, done, done])]),
        ])
        let volume = RecentVolume(history: history, now: now)
        #expect(volume[.horizontalPush] == 3 && volume[.verticalPush] == 2 && volume[.verticalPull] == 3)
        #expect(volume[.horizontalPull] == 0)  // 超過 30 天不算
        #expect(volume.push == 5 && volume.pull == 3 && volume.pullIsShort)
    }
}
