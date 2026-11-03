import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_18 §5：「下一次」卡、建立菜單、訓練狀態浮窗、訓練畫面四處的主項、處方和動作數一致——都呼叫同一套函式
/// （PlanDefaults.answers、PlanRanking.suggestedMain／resolve、Rotation.suggestion、SlotAdvice.make、Prescription.isFamiliarization）。
/// 四個日型各一個情境：DE 上肢的主項被 48 小時規則跳過、ME 下肢的主項是熟悉日、ME 上肢和 DE 下肢照常
@MainActor
struct PlanSyncTests {
    private let now = Date.now

    /// seed（兩年多的舊紀錄）加上動作庫 v2 的輪替；sessions：（幾小時前, 日型, 動作和角色），每組在開始後 10 分鐘完成
    private func makeContext(_ sessions: [(Double, DayType?, [(String, Role)])]) throws -> ModelContext {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let seed = try #require(try SeedImporter.bundled())
        let guides = try #require(GuideImporter.bundled())
        try BackupService.restore(seed, into: context)
        try LibraryAdditions.apply(ConjugateLibrary.additions, from: seed.exercises, guides: guides, into: context)
        let all = try context.fetch(FetchDescriptor<Exercise>())
        ConjugateLibrary.apply(to: all)
        for (hoursAgo, dayType, items) in sessions {
            let start = now.addingTimeInterval(-hoursAgo * 3600)
            let session = WorkoutActions.start(with: items.map { name in all.first { $0.name == name.0 }! }, roles: items.map(\.1),
                                               dayType: dayType, backfill: DateInterval(start: start, duration: 3600), in: context)
            for set in session.items.flatMap(\.sets) {
                set.weightKg = 50; set.reps = 3; set.isCompleted = true; set.completedAt = start.addingTimeInterval(600)
            }
            WorkoutActions.save(context)
        }
        return context
    }

    private struct Expected {
        var dayType: DayType
        var main: String
        var familiarization: Bool
        /// 建立菜單的原因（第一個建議）
        var reason: (String) -> Bool
    }

    private func checkFourPlaces(_ context: ModelContext, _ expected: Expected) throws {
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let label = "\(expected.dayType)"

        // 1.「下一次」卡：統計快照（StatsCache 的算法）
        let snapshot = StatsSnapshot.make(history: PlanHistory(sessions: sessions), exercises: exercises.map { PlanExercise($0) }, now: now)
        guard case let .next(cardDayType, line, volume) = NextCard.content(
            active: nil, answers: snapshot.nextPlan, main: snapshot.suggestedMain, mainLogs: snapshot.suggestedMainLogs,
            unit: .kg, step: 2.5, now: snapshot.now) else {
            Issue.record("沒有進行中的訓練時是下一次的建議")
            return
        }
        #expect(cardDayType == expected.dayType, "\(label)")

        // 2. 建立菜單：PlanSheet 打開時的做法（PlanHistory.withLastDates、PlanMenu），帶著「下一次」卡的答案
        let history = PlanHistory(sessions: sessions.filter { !$0.isActive })
        let menu = PlanMenu(answers: snapshot.nextPlan, exercises: history.withLastDates(exercises.map { PlanExercise($0) }),
                            history: history, now: now)
        #expect(menu.answers == PlanMenu(exercises: history.withLastDates(exercises.map { PlanExercise($0) }), history: history,
                                         now: now).answers, "\(label) 不帶答案打開也是同一組預設")
        let mainState = try #require(menu.states.first)
        let main = try #require(mainState.selected)
        #expect(main.name == expected.main, "\(label)：\(main.name)")
        #expect(expected.reason(mainState.candidates.reason ?? ""), "\(label)：\(mainState.candidates.reason ?? "")")
        let planAdvice = SlotAdvice.make(role: mainState.slot.role, exercise: main, logs: history.logs(for: main.id), unit: .kg,
                                         step: 2.5, now: now)

        // 「下一次」卡的主項、處方、動作數 = 建立菜單
        #expect(snapshot.suggestedMain?.id == main.id, "\(label)")
        #expect(line.name == Rotation.displayName(main, slot: mainState.slot), "\(label)：\(line.text)")
        #expect((line.detail == "熟悉日") == expected.familiarization, "\(label)：\(line.text)")
        #expect(planAdvice.prescription.isFamiliarization == expected.familiarization, "\(label)")
        if expected.familiarization {
            #expect(line.text == "主項：\(main.name)・熟悉日" && planAdvice.line == "熟悉日：逐步加到順手的 5 下，不衝極限", "\(label)")
        }
        #expect(menu.answers.count == PlanDefaults.count(for: expected.dayType), "\(label)")
        #expect(volume.hasPrefix("\(menu.answers.count) 個動作"), "\(label)：\(volume)")

        // 3. 訓練狀態浮窗：輪替列的下次主項
        let row = try #require(snapshot.trainingStatus.rotation.first { $0.dayType == expected.dayType })
        #expect(row.nextMain == main.name && row.isNext, "\(label)")

        // 4. 訓練畫面：照建議「開始訓練」，說明列的處方
        let request = try #require(WorkoutLauncher.Request.plan(menu.selection, exercises: exercises, dayType: menu.answers.dayType,
                                                                 backfill: nil))
        let session = WorkoutActions.start(with: request.exercises, roles: request.roles, dayType: request.dayType, in: context)
        defer { WorkoutActions.discard(session, in: context) }
        let card = try #require(session.orderedItems.first)
        #expect(card.exercise?.id == main.id && card.role == mainState.slot.role, "\(label)")
        let workoutAdvice = card.advice(unit: .kg)
        #expect(workoutAdvice.prescription == planAdvice.prescription, "\(label)：\(workoutAdvice.prescription.summary)")
        #expect(session.orderedItems.count == menu.answers.count + (menu.answers.cardio ? 1 : 0), "\(label)")
        #expect(session.orderedItems.map(\.role) == menu.states.map(\.slot.role), "\(label)")
    }

    /// 規格第 1 節：DE 上肢上次爆發划船，輪到臥推（速度），但臥推昨天在自由選的訓練做過 → 四處都是借力推舉
    @Test func deUpperSkippedByThe48HourRule() throws {
        let context = try makeContext([
            (24 * 8, .deUpper, [("爆發划船", .dynamicEffort)]),
            (24 * 3, .deLower, [("深蹲", .dynamicEffort), ("單腳 RDL", .lowerAssist)]),
            (20, nil, [("臥推", .push)]),
        ])
        try checkFourPlaces(context, Expected(dayType: .deUpper, main: "借力推舉", familiarization: false) {
            $0.hasPrefix("臥推（速度）") && $0.hasSuffix("練過，換下一個")
        })
    }

    /// 前蹲舉沒有任何完成組：ME 下肢的主項是熟悉日，四處一致
    @Test func meLowerFamiliarizationDay() throws {
        let context = try makeContext([
            (24 * 5, .meLower, [("傳統硬舉", .maxEffort)]),
            (24, .deUpper, [("爆發划船", .dynamicEffort)]),
        ])
        try checkFourPlaces(context, Expected(dayType: .meLower, main: "前蹲舉", familiarization: true) {
            $0 == "輪替的下一個（上次：傳統硬舉）"
        })
    }

    @Test func meUpperAsUsual() throws {
        let context = try makeContext([
            (24 * 6, .meUpper, [("臥推", .maxEffort)]),
            (24, .meLower, [("深蹲", .maxEffort)]),
        ])
        try checkFourPlaces(context, Expected(dayType: .meUpper, main: "肩推", familiarization: false) {
            $0 == "輪替的下一個（上次：臥推）"
        })
    }

    @Test func deLowerAsUsual() throws {
        let context = try makeContext([
            (24 * 5, .deLower, [("深蹲", .dynamicEffort)]),
            (24, .meUpper, [("臥推", .maxEffort)]),
        ])
        try checkFourPlaces(context, Expected(dayType: .deLower, main: "壺鈴擺盪", familiarization: false) {
            $0 == "輪替的下一個（上次：深蹲）"
        })
    }
}
