import Foundation
import Testing
@testable import LiftLog

struct PlanTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func day(_ daysAgo: Double) -> Date { now.addingTimeInterval(-daysAgo * 86_400) }

    private func ex(_ name: String, _ category: ExerciseCategory, _ tags: [ExerciseTag] = [], last: Double? = nil,
                    archived: Bool = false) -> PlanExercise {
        PlanExercise(id: UUID(), name: name, category: category, tags: tags, isArchived: archived,
                     lastDate: last.map(day))
    }

    private func session(_ daysAgo: Double, _ region: Region, _ items: [PlanExercise], roles: [Role]? = nil) -> PlanHistory.Session {
        PlanHistory.Session(date: day(daysAgo), region: region, items: items.enumerated().map { i, e in
            PlanHistory.Item(exerciseID: e.id, category: e.category, role: roles?[i] ?? e.role)
        })
    }

    private let squat = PlanExercise(id: UUID(), name: "深蹲", category: .kneeDominant, tags: [])
    private let deadlift = PlanExercise(id: UUID(), name: "傳統硬舉", category: .hipDominant, tags: [])
    private let bench = PlanExercise(id: UUID(), name: "臥推", category: .horizontalPush, tags: [])
    private let row = PlanExercise(id: UUID(), name: "坐姿 Cable 划船", category: .horizontalPull, tags: [])
    private let treadmill = PlanExercise(id: UUID(), name: "跑步機", category: .cardio, tags: [])
    private let curl = PlanExercise(id: UUID(), name: "二頭彎舉", category: .accessory, tags: [])
    private let plank = PlanExercise(id: UUID(), name: "腹前推", category: .core, tags: [])
    private let swing = PlanExercise(id: UUID(), name: "壺鈴擺盪", category: .hipDominant, tags: [.explosive])

    // MARK: 三個問題的預設值

    @Test func regionAlternatesUpperAndLower() {
        let afterUpper = PlanHistory([session(2, .upper, [bench, row]), session(5, .lower, [squat])])
        #expect(PlanDefaults.answers(afterUpper).region == .lower)
        let afterLower = PlanHistory([session(2, .lower, [squat]), session(5, .upper, [bench])])
        #expect(PlanDefaults.answers(afterLower).region == .upper)
        // 「未指定」的訓練（例如只有跑步機）不算
        let cardioOnly = PlanHistory([session(1, .unspecified, [treadmill]), session(3, .upper, [bench])])
        #expect(PlanDefaults.answers(cardioOnly).region == .lower)
    }

    @Test func afterFullBodyPicksTheLongerNeglectedHalf() {
        let upperOlder = PlanHistory([session(1, .full, [squat, bench]), session(4, .lower, [squat]), session(9, .upper, [bench])])
        #expect(PlanDefaults.answers(upperOlder).region == .upper)
        let lowerOlder = PlanHistory([session(1, .full, [squat, bench]), session(4, .upper, [bench]), session(9, .lower, [squat])])
        #expect(PlanDefaults.answers(lowerOlder).region == .lower)
        let neverUpper = PlanHistory([session(1, .full, [squat, bench]), session(4, .lower, [squat])])
        #expect(PlanDefaults.answers(neverUpper).region == .upper)
    }

    @Test func noHistoryDefaults() {
        let answers = PlanDefaults.answers(PlanHistory([]))
        #expect(answers == PlanAnswers(region: .lower, count: PlanDefaults.countWithoutHistory, cardio: false))
    }

    @Test func countAndCardioFromLastSession() {
        let history = PlanHistory([session(1, .upper, [bench, row, curl, treadmill]), session(4, .lower, [squat])])
        let answers = PlanDefaults.answers(history)
        #expect(answers.count == 3)          // 不計有氧
        #expect(answers.cardio)
        let single = PlanHistory([session(1, .lower, [squat])])
        #expect(PlanDefaults.answers(single).count == 1 && !PlanDefaults.answers(single).cardio)
    }

    @Test func fullBodyHasNoSingleExercise() {
        #expect(PlanAnswers.countOptions(for: .full) == [2, 3])
        #expect(PlanAnswers.countOptions(for: .upper) == [1, 2, 3])
        // 預設是 1 個動作時改選全身 → 2
        var answers = PlanAnswers(region: .lower, count: 1, cardio: false)
        answers.setRegion(.full)
        #expect(answers.count == 2)
        answers.count = 3
        answers.setRegion(.upper)
        #expect(answers.count == 3)
    }

    // MARK: 模式

    @Test func modesTable() {
        #expect(PlanModes.modes(region: .lower, count: 3).map(\.slots) == [[.explosive, .main, .unilateral], [.main, .unilateral, .core]])
        #expect(PlanModes.modes(region: .upper, count: 1).map(\.slots) == [[.pushOrPull]])
        #expect(PlanModes.modes(region: .full, count: 1).isEmpty)
        #expect(PlanModes.modes(region: .full, count: 3).map(\.id) == ["full3A", "full3B"])
    }

    @Test func recommendsModeWithLeastUsedRole() {
        let modes = PlanModes.modes(region: .lower, count: 3)   // A 有爆發，B 有核心
        let moreCore = PlanHistory([session(2, .lower, [squat, plank]), session(5, .lower, [squat, plank]),
                                    session(8, .lower, [swing, squat])])
        #expect(PlanModes.recommended(modes, history: moreCore, now: now)?.id == "lower3A")
        let moreExplosive = PlanHistory([session(2, .lower, [swing, squat]), session(5, .lower, [swing, plank])])
        #expect(PlanModes.recommended(modes, history: moreExplosive, now: now)?.id == "lower3B")
        // 超過 30 天的不算
        let old = PlanHistory([session(40, .lower, [swing, squat]), session(41, .lower, [swing, squat])])
        #expect(PlanModes.recommended(modes, history: old, now: now)?.id == "lower3A")
    }

    @Test func tieRecommendsA() {
        let modes = PlanModes.modes(region: .upper, count: 3)   // A 核心、B 補強
        let tie = PlanHistory([session(2, .upper, [bench, row, plank]), session(5, .upper, [bench, row, curl])])
        #expect(PlanModes.recommended(modes, history: tie, now: now)?.id == "upper3A")
        #expect(PlanModes.recommended(modes, history: PlanHistory([]), now: now)?.id == "upper3A")
    }

    // MARK: 候選排序

    @Test func mainAlternatesFromLastMain() {
        let squat = ex("深蹲", .kneeDominant, last: 3), front = ex("前蹲舉", .kneeDominant)
        let deadlift = ex("傳統硬舉", .hipDominant, last: 10), hex = ex("六角槓硬舉", .hipDominant, last: 30)
        let history = PlanHistory([session(3, .lower, [squat])])
        let ranked = PlanRanking.candidates(for: .main, exercises: [squat, front, deadlift, hex], history: history, now: now)
        #expect(ranked.items.map(\.exercise.name) == ["六角槓硬舉", "傳統硬舉", "前蹲舉", "深蹲"])
        #expect(ranked.reason == "交替：上次是膝主導")
    }

    @Test func mainWithoutHistoryPrefersOlderCategory() {
        let squat = ex("深蹲", .kneeDominant), deadlift = ex("傳統硬舉", .hipDominant)
        // 兩類都沒練過：沒有優先的一類
        let ranked = PlanRanking.candidates(for: .main, exercises: [squat, deadlift], history: PlanHistory([]), now: now)
        #expect(ranked.items.count == 2 && ranked.reason == "新動作：還沒練過")
        // 只有單邊的紀錄（不是主項）：膝主導練過，髖主導比較久沒練
        let lunge = ex("側蹲", .kneeDominant, [.unilateral], last: 2)
        let history = PlanHistory([session(2, .lower, [lunge])])
        let next = PlanRanking.candidates(for: .main, exercises: [squat, deadlift, lunge], history: history, now: now)
        #expect(next.items.map(\.exercise.name) == ["傳統硬舉", "深蹲"])
        #expect(next.reason == "髖主導比較久沒練")
    }

    @Test func pushPrefersLessUsedDirection() {
        let bench = ex("臥推", .horizontalPush, last: 2), dbBench = ex("啞鈴臥推", .horizontalPush, last: 20)
        let press = ex("肩推", .verticalPush, last: 6), dip = ex("雙槓撐", .verticalPush, last: 15)
        let history = PlanHistory([session(2, .upper, [bench]), session(6, .upper, [press]), session(20, .upper, [dbBench])])
        // 近 30 天：水平推 2 次、垂直推 1 次 → 垂直優先
        let ranked = PlanRanking.candidates(for: .push, exercises: [bench, dbBench, press, dip], history: history, now: now)
        #expect(ranked.items.map(\.exercise.name) == ["雙槓撐", "肩推", "啞鈴臥推", "臥推"])
        #expect(ranked.reason == "輪替：近 30 天垂直推比較少")
        // 次數相同：最後練習日期比較舊的方向優先
        let tie = PlanHistory([session(2, .upper, [press]), session(6, .upper, [bench])])
        let tied = PlanRanking.candidates(for: .push, exercises: [bench, press], history: tie, now: now)
        #expect(tied.items.map(\.exercise.name) == ["臥推", "肩推"])
        #expect(tied.reason == "輪替：水平推比較久沒做")
    }

    @Test func pushOrPullComparesSidesThenDirections() {
        let bench = ex("臥推", .horizontalPush, last: 2), press = ex("肩推", .verticalPush, last: 9)
        let row = ex("坐姿 Cable 划船", .horizontalPull, last: 12), pulldown = ex("滑輪下拉", .verticalPull, last: 4)
        let history = PlanHistory([session(2, .upper, [bench, pulldown]), session(9, .upper, [press]),
                                   session(12, .upper, [row])])
        let more = PlanHistory(history.sessions + [session(20, .upper, [bench])])
        let ranked = PlanRanking.candidates(for: .pushOrPull, exercises: [bench, press, row, pulldown], history: more, now: now)
        // 拉比較少 → 拉先；拉裡面水平 1 次、垂直 1 次 → 水平比較久沒做
        #expect(ranked.items.map(\.exercise.name) == ["坐姿 Cable 划船", "滑輪下拉", "肩推", "臥推"])
        #expect(ranked.reason == "推拉平衡：近 30 天拉比較少")
    }

    @Test func unilateralPrefersOtherCategoryThanMain() {
        let bss = ex("後腳抬高蹲", .kneeDominant, [.unilateral], last: 50)
        let sl = ex("單腳 RDL", .hipDominant, [.unilateral], last: 5)
        let kneeMain = PlanRanking.candidates(for: .unilateral, exercises: [bss, sl], history: PlanHistory([]),
                                              mainCategory: .kneeDominant, now: now)
        #expect(kneeMain.items.map(\.exercise.name) == ["單腳 RDL", "後腳抬高蹲"])
        #expect(kneeMain.reason == "和主項不同：髖主導")
        let hipMain = PlanRanking.candidates(for: .unilateral, exercises: [bss, sl], history: PlanHistory([]),
                                             mainCategory: .hipDominant, now: now)
        #expect(hipMain.items.map(\.exercise.name) == ["後腳抬高蹲", "單腳 RDL"])
    }

    @Test func unilateralFollowsMainSelection() {
        let squat = ex("深蹲", .kneeDominant, last: 20), deadlift = ex("傳統硬舉", .hipDominant, last: 3)
        let bss = ex("後腳抬高蹲", .kneeDominant, [.unilateral], last: 50)
        let sl = ex("單腳 RDL", .hipDominant, [.unilateral], last: 5)
        let all = [squat, deadlift, bss, sl]
        let history = PlanHistory([session(3, .lower, [deadlift])])
        // 預設主項交替成膝主導（深蹲）→ 單邊優先髖主導
        let auto = PlanRanking.resolve(slots: [.main, .unilateral], picks: [:], exercises: all, history: history, now: now)
        #expect(auto.map { $0.selected?.name } == ["深蹲", "單腳 RDL"])
        // 改選傳統硬舉 → 單邊改成膝主導優先
        let changed = PlanRanking.resolve(slots: [.main, .unilateral], picks: [0: deadlift.id], exercises: all,
                                          history: history, now: now)
        #expect(changed.map { $0.selected?.name } == ["傳統硬舉", "後腳抬高蹲"])
    }

    @Test func untrainedFirstWithNewLabelAndArchivedExcluded() {
        let face = ex("面拉", .accessory, last: 87), ytw = ex("YTW", .accessory)
        let curl = ex("二頭彎舉", .accessory, last: 100), old = ex("垂直舉肩訓練機", .accessory, last: 400, archived: true)
        let ranked = PlanRanking.candidates(for: .accessory, exercises: [face, ytw, curl, old], history: PlanHistory([]), now: now)
        #expect(ranked.items.map(\.exercise.name) == ["YTW", "二頭彎舉", "面拉"])
        #expect(ranked.items.map(\.isNew) == [true, false, false])
        #expect(ranked.reason == "新動作：還沒練過")
        let trained = PlanRanking.candidates(for: .accessory, exercises: [face, curl], history: PlanHistory([]), now: now)
        #expect(trained.reason == "最久沒做：100 天")
    }

    @Test func selectedElsewhereIsExcluded() {
        let bench = ex("臥推", .horizontalPush), row = ex("坐姿 Cable 划船", .horizontalPull)
        let ranked = PlanRanking.candidates(for: .pushOrPull, exercises: [bench, row], history: PlanHistory([]),
                                            excluding: [bench.id], now: now)
        #expect(ranked.items.map(\.exercise.name) == ["坐姿 Cable 划船"])
        // 整份菜單：使用者在後面的位置選了某個動作，前面的位置就不會再選它
        let states = PlanRanking.resolve(slots: [.pushOrPull, .pushOrPull], picks: [1: bench.id],
                                         exercises: [bench, row], history: PlanHistory([]), now: now)
        #expect(states.map { $0.selected?.name } == ["坐姿 Cable 划船", "臥推"])
        let none = PlanRanking.candidates(for: .core, exercises: [bench], history: PlanHistory([]), now: now)
        #expect(none.items.isEmpty && none.reason == nil)
    }
}
