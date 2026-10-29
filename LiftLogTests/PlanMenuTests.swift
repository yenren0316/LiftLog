import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_15 §2：建立菜單合成一個畫面（PlanMenu）。照建議直接開始時，建立的訓練和舊流程（CHANGE_14 的兩步）完全相同；
/// 改日型時全部重算，改動作數、跑步機時保留手動換過的格子
@MainActor
struct PlanMenuTests {
    struct Fixture {
        var context: ModelContext
        var exercises: [Exercise]
        var history: PlanHistory
        var now: Date
        func exercise(_ name: String) -> Exercise { exercises.first { $0.name == name }! }
        var snapshot: [PlanExercise] { exercises.map { PlanExercise($0) } }
    }

    /// seed（兩年多的舊紀錄，沒有日型）加上動作庫 v2 的輪替，再加四次有日型、有完成組的訓練：
    /// DE 上肢上次是借力推舉，所以這次的主項是爆發划船（「拉」變成「推」）；ME 下肢上次深蹲；最後一次加了跑步機
    private func makeFixture() throws -> Fixture {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let seed = try #require(try SeedImporter.bundled())
        let guides = try #require(GuideImporter.bundled())
        try BackupService.restore(seed, into: context)
        try LibraryAdditions.apply(ConjugateLibrary.additions, from: seed.exercises, guides: guides, into: context)
        let all = try context.fetch(FetchDescriptor<Exercise>())
        ConjugateLibrary.apply(to: all)
        func named(_ name: String) -> Exercise { all.first { $0.name == name }! }
        let now = Date.now
        func past(_ daysAgo: Double, _ dayType: DayType, _ items: [(String, Role)], weight: Double) {
            let start = now.addingTimeInterval(-daysAgo * 86_400)
            let session = WorkoutActions.start(with: items.map { named($0.0) }, roles: items.map(\.1), dayType: dayType,
                                               backfill: DateInterval(start: start, duration: 3600), in: context)
            for set in session.items.flatMap(\.sets) {
                set.weightKg = weight; set.reps = 3; set.isCompleted = true; set.completedAt = start
            }
            WorkoutActions.save(context)
        }
        past(8, .meLower, [("深蹲", .maxEffort), ("單腳 RDL", .lowerAssist), ("棒式划船", .core)], weight: 100)
        past(6, .meUpper, [("臥推", .maxEffort), ("滑輪下拉", .pull), ("面拉", .accessory)], weight: 70)
        past(4, .deLower, [("壺鈴擺盪", .dynamicEffort), ("後腳抬高蹲", .lowerAssist)], weight: 24)
        past(2, .deUpper, [("借力推舉", .dynamicEffort), ("坐姿 Cable 划船", .pull), ("跑步機", .cardio)], weight: 50)
        let ended = try context.fetch(FetchDescriptor<WorkoutSession>()).filter { !$0.isActive }
        return Fixture(context: context, exercises: try context.fetch(FetchDescriptor<Exercise>()),
                       history: PlanHistory(sessions: ended), now: now)
    }

    /// 舊流程（CHANGE_14 的 PlanFlowView）照建議開始：第一步選好三個答案、按「下一步」（picks 清空），
    /// 第二步不換任何一格就按「開始訓練」——每一格都是第一個建議，依格子的順序、角色是格子的角色
    private func oldFlowSelection(_ answers: PlanAnswers, _ f: Fixture) -> [(exerciseID: UUID, role: Role)] {
        PlanRanking.resolve(answers: answers, picks: [:], exercises: f.snapshot, history: f.history, now: f.now)
            .compactMap { state in state.selected.map { ($0.id, state.slot.role) } }
    }

    /// 建立出來的訓練：日型、每個動作的格子（角色）、動作、處方（組數、組的種類、預設參數、建議重量）
    private struct Built: Equatable {
        var dayType: DayType?
        var items: [Item]
        struct Item: Equatable {
            var exerciseID: UUID
            var role: Role
            var setKinds: [SetKind]
            var prescription: Prescription
            var advice: SlotAdvice
        }
    }

    private func build(_ selection: [(exerciseID: UUID, role: Role)], dayType: DayType, _ f: Fixture) throws -> Built {
        let request = try #require(WorkoutLauncher.Request.plan(selection, exercises: f.exercises, dayType: dayType, backfill: nil))
        let session = WorkoutActions.start(with: request.exercises, roles: request.roles, dayType: request.dayType, in: f.context)
        defer { WorkoutActions.discard(session, in: f.context) }
        return Built(dayType: session.dayType, items: session.orderedItems.map { item in
            let exercise = PlanExercise(item.exercise!)
            return Built.Item(exerciseID: exercise.id, role: item.role, setKinds: item.orderedSets.map(\.kind),
                              prescription: item.prescription,
                              advice: SlotAdvice.make(role: item.role, exercise: exercise, logs: f.history.logs(for: exercise.id),
                                                      unit: .kg, step: 2.5, now: f.now))
        })
    }

    @Test func startingAsSuggestedBuildsTheSameWorkoutAsTheOldFlow() throws {
        let f = try makeFixture()
        var slotsSeen = Set<Slot>()
        for dayType in DayType.allCases {
            for count in PlanAnswers.countOptions {
                for cardio in [false, true] {
                    let answers = PlanAnswers(dayType: dayType, count: count, cardio: cardio)
                    // 新的畫面：打開時是預設答案，用日型的 Menu、動作數的分段、跑步機的開關改成這一組，不換任何一格
                    var menu = PlanMenu(exercises: f.snapshot, history: f.history, now: f.now)
                    menu.setDayType(dayType)
                    menu.setCount(count)
                    menu.setCardio(cardio)
                    #expect(menu.answers == answers)
                    let old = oldFlowSelection(answers, f)
                    #expect(menu.selection.map(\.exerciseID) == old.map(\.exerciseID), "\(answers)")
                    #expect(menu.selection.map(\.role) == old.map(\.role), "\(answers)")
                    let built = try build(menu.selection, dayType: dayType, f)
                    #expect(built == (try build(old, dayType: dayType, f)), "\(answers)")
                    #expect(built.dayType == dayType && built.items.count == count + (cardio ? 1 : 0), "\(answers)")
                    slotsSeen.formUnion(menu.states.map(\.slot))
                }
            }
        }
        // 涵蓋每一種格子，包括主項是爆發划船時的「推」和跑步機
        #expect(slotsSeen == Set(Slot.allCases))

        // 不改任何答案：打開就是預設答案（和「下一次」卡相同），直接開始也一樣
        let menu = PlanMenu(exercises: f.snapshot, history: f.history, now: f.now)
        let defaults = PlanDefaults.answers(f.history)
        #expect(menu.answers == defaults && defaults == PlanAnswers(dayType: .meLower, count: 2, cardio: true))
        #expect(try build(menu.selection, dayType: defaults.dayType, f) == (try build(oldFlowSelection(defaults, f), dayType: defaults.dayType, f)))
    }

    @Test func dayTypeRecomputesEverySlotWhileCountAndCardioKeepManualPicks() throws {
        let f = try makeFixture()
        var menu = PlanMenu(answers: PlanAnswers(dayType: .meLower, count: 3, cardio: false), exercises: f.snapshot,
                            history: f.history, now: f.now)
        let suggested = menu.states.map { $0.selected?.id }
        // 手動換下肢輔助和核心（各換成第 2 個候選）
        let assist = menu.states[1].candidates.items[1].id, core = menu.states[2].candidates.items[1].id
        menu.pick(assist, for: .lowerAssist)
        menu.pick(core, for: .core)
        #expect(menu.states.map { $0.selected?.id } == [suggested[0], assist, core])

        // 加跑步機：換過的兩格保留，多一格有氧
        menu.setCardio(true)
        #expect(menu.states.map(\.slot) == [.maxEffort, .lowerAssist, .core, .cardio])
        #expect(menu.states.prefix(3).map { $0.selected?.id } == [suggested[0], assist, core])
        // 動作數改成 2：核心那一格不在了，丟掉；下肢輔助還在，保留
        menu.setCount(2)
        #expect(menu.picks == [.lowerAssist: assist])
        #expect(menu.states.map { $0.selected?.id }.prefix(2) == [suggested[0], assist])
        // 改回 3：核心重新計算（回到建議），不是剛才換的
        menu.setCount(3)
        #expect(menu.states[2].selected?.id == suggested[2] && menu.states[1].selected?.id == assist)

        // 改日型：全部重新計算，換過的都不留
        menu.setDayType(.meUpper)
        #expect(menu.picks.isEmpty)
        let upper = PlanRanking.resolve(answers: menu.answers, picks: [:], exercises: f.snapshot, history: f.history, now: f.now)
        #expect(menu.states == upper)
        menu.setDayType(.meLower)
        #expect(menu.states.map { $0.selected?.id } == suggested + [menu.states[3].selected?.id])
    }

    @Test func swappingTheMainRebuildsThePullOrPushSlot() throws {
        let f = try makeFixture()
        var menu = PlanMenu(answers: PlanAnswers(dayType: .deUpper, count: 3, cardio: false), exercises: f.snapshot,
                            history: f.history, now: f.now)
        // 上次借力推舉 → 這次的建議是爆發划船，「拉」變成「推」
        #expect(menu.states[0].selected?.name == "爆發划船")
        #expect(menu.states.map(\.slot) == [.dynamicEffort, .push, .accessory])
        let accessory = menu.states[2].candidates.items[1].id
        menu.pick(accessory, for: .accessory)
        let push = menu.states[1].candidates.items[1].id
        menu.pick(push, for: .push)
        // 主項換成臥推：「推」那一格不在了（換過的丟掉），換成「拉」重新計算；補強還在，保留
        menu.pick(f.exercise("臥推").id, for: .dynamicEffort)
        #expect(menu.states.map(\.slot) == [.dynamicEffort, .pull, .accessory])
        #expect(menu.picks[.push] == nil && menu.states[2].selected?.id == accessory)
        #expect(menu.states[1].selected?.id == menu.states[1].candidates.items.first?.id)
    }

    @Test func candidateNotes() {
        let squat = PlanExercise(id: UUID(), name: "深蹲", category: .kneeDominant, tags: [.main])
        let seen = PlanCandidate(exercise: squat, daysSince: 12), fresh = PlanCandidate(exercise: squat, daysSince: nil)
        #expect(PlanMenu.note(for: seen, isSuggestion: true, reason: "輪替的下一個（上次：傳統硬舉）") == "建議・輪替的下一個（上次：傳統硬舉）")
        #expect(PlanMenu.note(for: seen, isSuggestion: false, reason: "輪替的下一個（上次：傳統硬舉）") == "12 天前")
        #expect(PlanMenu.note(for: fresh, isSuggestion: false, reason: nil) == "還沒練過")
        #expect(PlanMenu.note(for: PlanCandidate(exercise: squat, daysSince: 0), isSuggestion: false, reason: nil) == "今天")
        // 處方一行
        let advice = SlotAdvice(prescription: Prescription.of(role: .dynamicEffort, name: "臥推", tags: [.main]),
                                weightText: "建議 32.5 kg（60%）", speedWeightKg: 32.5)
        #expect(advice.line == "8 組 × 3 下・建議 32.5 kg（60%）")
    }
}
