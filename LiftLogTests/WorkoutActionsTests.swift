import Foundation
import SwiftData
import Testing
@testable import LiftLog

@MainActor
struct WorkoutActionsTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer(for: LiftLogStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    /// 一次已結束的歷史訓練，給「上一次」用
    private func history(_ exercise: Exercise, sets: [(Double, Int)], daysAgo: Double, in context: ModelContext) {
        let date = Date.now.addingTimeInterval(-daysAgo * 86_400)
        let session = WorkoutSession(startedAt: date, endedAt: date)
        context.insert(session)
        let item = SessionExercise(session: session, exercise: exercise, order: 0)
        context.insert(item)
        for (i, s) in sets.enumerated() {
            context.insert(SetRecord(sessionExercise: item, order: i, weightKg: s.0, reps: s.1, isCompleted: true, completedAt: date))
        }
    }

    @Test func startCopiesSetCountFromLastSessionAndTitles() throws {
        let context = try makeContext()
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        let row = Exercise(name: "爆發划船", category: .horizontalPull, equipment: .barbell)
        context.insert(bench)
        context.insert(row)
        history(bench, sets: [(40, 5), (42.6, 5), (42.6, 5)], daysAgo: 10, in: context)
        history(bench, sets: [(60, 1)], daysAgo: 30, in: context)

        let session = WorkoutActions.start(with: [bench, row], in: context)
        #expect(session.title == "臥推＋爆發划船")
        #expect(session.orderedItems[0].sets.count == 3)   // 照最近一次
        #expect(session.orderedItems[1].sets.count == 5)   // 沒有歷史 → 依角色（拉 5 組）
        #expect(bench.lastSets(excluding: session).map(\.weightKg) == [40, 42.6, 42.6])

        // 重複加入同一個動作：回傳既有卡片
        let again = WorkoutActions.add(bench, to: session, in: context)
        #expect(again === session.orderedItems[0])
        #expect(session.items.count == 2)
    }

    @Test func finishDeletingIncompleteRemovesEmptyExercises() throws {
        let context = try makeContext()
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        let row = Exercise(name: "爆發划船", category: .horizontalPull, equipment: .barbell)
        context.insert(bench)
        context.insert(row)
        let session = WorkoutActions.start(with: [bench, row], in: context)
        WorkoutActions.addSet(to: session.orderedItems[0], in: context)
        let first = session.orderedItems[0].orderedSets[0]
        first.weightKg = 42.6; first.reps = 5; first.isCompleted = true; first.completedAt = .now

        #expect(WorkoutActions.finish(session, choice: .deleteIncomplete, in: context))
        #expect(session.endedAt != nil)
        #expect(session.orderedItems.map { $0.exercise?.name } == ["臥推"])
        #expect(session.orderedItems[0].sets.count == 1)
        // 「幾天前」只計算已完成的組：沒完成的划船不算
        #expect(bench.lastCompletedDate != nil)
        #expect(row.lastCompletedDate == nil)
    }

    @Test func finishCompletingAllKeepsEverything() throws {
        let context = try makeContext()
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        context.insert(bench)
        let session = WorkoutActions.start(with: [bench], in: context)
        WorkoutActions.addSet(to: session.orderedItems[0], in: context)
        #expect(WorkoutActions.finish(session, choice: .completeAll, in: context))
        #expect(session.orderedItems[0].sets.count == 6)   // 推 5 組＋新增 1 組
        #expect(session.orderedItems[0].sets.allSatisfy { $0.isCompleted && $0.completedAt != nil })
    }

    @Test func finishWithNothingCompletedDeletesSession() throws {
        let context = try makeContext()
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        context.insert(bench)
        let session = WorkoutActions.start(with: [bench], in: context)
        #expect(!WorkoutActions.finish(session, choice: .deleteIncomplete, in: context))
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SetRecord>()) == 0)
    }

    @Test func customTitleIsKeptWhenExercisesChange() throws {
        let context = try makeContext()
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        let row = Exercise(name: "爆發划船", category: .horizontalPull, equipment: .barbell)
        context.insert(bench)
        context.insert(row)
        let session = WorkoutActions.start(with: [bench], in: context)
        _ = WorkoutActions.add(row, to: session, in: context)
        #expect(session.title == "臥推＋爆發划船")
        session.title = "推日"
        WorkoutActions.remove(session.orderedItems[1], in: context)
        #expect(session.title == "推日")
    }

    @Test func rolesAndRegionFromPlanAreKept() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        context.insert(squat)
        context.insert(bench)
        let session = WorkoutActions.start(with: [squat, bench], roles: [.main, .push], region: .full,
                                           modeID: "full2", in: context)
        #expect(session.orderedItems.map(\.role) == [.main, .push])
        let item = session.orderedItems[1]
        WorkoutActions.remove(item, in: context)
        session.orderedItems[0].sets.forEach { $0.isCompleted = true }
        #expect(WorkoutActions.finish(session, choice: .deleteIncomplete, in: context))
        // 從流程建立的訓練，部位以使用者選的為準
        #expect(session.region == .full && session.modeID == "full2")
    }

    @Test func freeSessionsInferRegionWhenFinished() throws {
        let context = try makeContext()
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        let curl = Exercise(name: "二頭彎舉", category: .accessory, equipment: .dumbbell)
        context.insert(bench)
        context.insert(curl)
        let session = WorkoutActions.start(with: [bench, curl], in: context)
        #expect(session.region == .unspecified)
        #expect(session.orderedItems.map(\.role) == [.push, .accessory])
        #expect(WorkoutActions.finish(session, choice: .completeAll, in: context))
        #expect(session.region == .upper)
    }

    @Test func defaultSetsByRoleWhenNoHistory() throws {
        let context = try makeContext()
        let cases: [(Exercise, Int)] = [
            (Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell), 5),
            (Exercise(name: "壺鈴擺盪", category: .hipDominant, tags: [.explosive], equipment: .kettlebell), 5),
            (Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell), 5),
            (Exercise(name: "滑輪下拉", category: .verticalPull, equipment: .cable), 5),
            (Exercise(name: "側蹲", category: .kneeDominant, tags: [.unilateral], equipment: .dumbbell), 3),
            (Exercise(name: "腹前推", category: .core, equipment: .cable), 3),
            (Exercise(name: "面拉", category: .accessory, equipment: .cable), 3),
            (Exercise(name: "跑步機", category: .cardio, equipment: .other, logType: .cardio), 1),
        ]
        cases.forEach { context.insert($0.0) }
        let session = WorkoutActions.start(with: cases.map(\.0), in: context)
        #expect(session.orderedItems.map(\.sets.count) == cases.map(\.1))
        // 有上一次紀錄就照上次的組數，不看角色
        let lunge = cases[4].0
        history(lunge, sets: [(10, 8), (10, 8), (10, 8), (10, 8)], daysAgo: 3, in: context)
        WorkoutActions.discard(session, in: context)
        let next = WorkoutActions.start(with: [lunge], in: context)
        #expect(next.orderedItems[0].sets.count == 4)
    }

    @Test func restSecondsByRoleUnlessExerciseOverrides() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        let lunge = Exercise(name: "側蹲", category: .kneeDominant, tags: [.unilateral], equipment: .dumbbell)
        let core = Exercise(name: "腹前推", category: .core, equipment: .cable)
        let curl = Exercise(name: "二頭彎舉", category: .accessory, equipment: .dumbbell)
        let custom = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell, restSeconds: 120)
        [squat, lunge, core, curl, custom].forEach(context.insert)
        let session = WorkoutActions.start(with: [squat, lunge, core, curl, custom], in: context)
        #expect(session.orderedItems.map(\.restSeconds) == [180, 90, 90, 60, 120])
        // 同一個動作放在不同角色的位置，休息跟著角色
        let item = session.orderedItems[0]
        item.role = .accessory
        #expect(item.restSeconds == 60)
    }

    @Test func replaceKeepsRoleOrTakesPushOrPull() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        let row = Exercise(name: "坐姿 Cable 划船", category: .horizontalPull, equipment: .cable)
        let front = Exercise(name: "前蹲舉", category: .kneeDominant, equipment: .barbell)
        [squat, bench, row, front].forEach(context.insert)
        let session = WorkoutActions.start(with: [squat, bench], roles: [.main, .push], region: .full,
                                           modeID: "full2", in: context)
        let pushItem = session.orderedItems[1]
        #expect(Slot(role: pushItem.role, modeID: session.modeID) == .pushOrPull)
        #expect(Slot(role: .push, modeID: "upper2") == .push)
        #expect(Slot(role: .main, modeID: nil) == .main)
        WorkoutActions.replace(pushItem, with: row, role: .pull, in: context)
        #expect(pushItem.role == .pull && session.title == "深蹲＋坐姿 Cable 划船")
        WorkoutActions.replace(session.orderedItems[0], with: front, in: context)
        #expect(session.orderedItems[0].role == .main)
    }

    @Test func repeatCarriesRolesRegionAndMode() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        let curl = Exercise(name: "二頭彎舉", category: .accessory, equipment: .dumbbell)
        [squat, curl].forEach(context.insert)
        // 把補強動作放在核心的位置，再做一次時照原本的位置
        let session = WorkoutActions.start(with: [curl, squat], roles: [.core, .main], region: .lower,
                                           modeID: "lower3B", in: context)
        let request = StartRequest(exercises: session.orderedItems.compactMap(\.exercise),
                                   roles: session.orderedItems.map(\.role), region: session.region, modeID: session.modeID)
        WorkoutActions.discard(session, in: context)
        let again = WorkoutActions.start(with: request.exercises, roles: request.roles, region: request.region,
                                         modeID: request.modeID, in: context)
        #expect(again.orderedItems.map { $0.exercise?.name } == ["二頭彎舉", "深蹲"])
        #expect(again.orderedItems.map(\.role) == [.core, .main])
        #expect(again.region == .lower && again.modeID == "lower3B")
    }
}
