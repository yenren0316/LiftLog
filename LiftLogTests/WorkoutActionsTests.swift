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
        #expect(session.orderedItems[1].sets.count == 3)   // 沒有歷史 → 依角色（拉 3 組）
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
        #expect(session.orderedItems[0].sets.count == 4)   // 推 3 組＋新增 1 組
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

    @Test func rolesAndDayTypeFromPlanAreKept() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, tags: [.main], equipment: .barbell)
        let rdl = Exercise(name: "單腳 RDL", category: .hipDominant, tags: [.unilateral], equipment: .dumbbell)
        context.insert(squat)
        context.insert(rdl)
        let session = WorkoutActions.start(with: [squat, rdl], roles: [.maxEffort, .lowerAssist], dayType: .meLower, in: context)
        #expect(session.orderedItems.map(\.role) == [.maxEffort, .lowerAssist])
        #expect(session.dayType == .meLower && session.modeID == nil)
        session.items.flatMap(\.sets).forEach { $0.isCompleted = true }
        #expect(WorkoutActions.finish(session, choice: .deleteIncomplete, in: context))
        // 日型照建立菜單選的，部位依動作推算
        #expect(session.dayType == .meLower && session.region == .lower)
    }

    @Test func cardioOnlySessionsHaveNoDayType() throws {
        let context = try makeContext()
        let bench = Exercise(name: "臥推", category: .horizontalPush, tags: [.main], equipment: .barbell)
        let treadmill = Exercise(name: "跑步機", category: .cardio, equipment: .other, logType: .cardio)
        [bench, treadmill].forEach(context.insert)
        let session = WorkoutActions.start(with: [bench, treadmill], roles: [.maxEffort, .cardio], dayType: .meUpper, in: context)
        // 只完成跑步機：主項被移除，這次不算日型
        session.orderedItems[1].sets.forEach { $0.minutes = 30; $0.isCompleted = true }
        #expect(WorkoutActions.finish(session, choice: .deleteIncomplete, in: context))
        #expect(session.orderedItems.count == 1 && session.dayType == nil)
    }

    @Test func freeSessionsInferRegionWhenFinished() throws {
        let context = try makeContext()
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        let curl = Exercise(name: "二頭彎舉", category: .accessory, equipment: .dumbbell)
        context.insert(bench)
        context.insert(curl)
        let session = WorkoutActions.start(with: [bench, curl], in: context)
        #expect(session.region == .unspecified && session.dayType == nil)
        #expect(session.orderedItems.map(\.role) == [.push, .accessory])
        #expect(WorkoutActions.finish(session, choice: .completeAll, in: context))
        #expect(session.region == .upper)
    }

    @Test func defaultSetsByRoleWhenNoHistory() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, tags: [.main], equipment: .barbell)
        let deadlift = Exercise(name: "傳統硬舉", category: .hipDominant, tags: [.main], equipment: .barbell)
        let bench = Exercise(name: "臥推", category: .horizontalPush, tags: [.main], equipment: .barbell)
        let swing = Exercise(name: "壺鈴擺盪", category: .hipDominant, tags: [.explosive], equipment: .kettlebell)
        let lunge = Exercise(name: "側蹲", category: .kneeDominant, tags: [.unilateral], equipment: .dumbbell)
        let core = Exercise(name: "腹前推", category: .core, equipment: .cable)
        let treadmill = Exercise(name: "跑步機", category: .cardio, equipment: .other, logType: .cardio)
        [squat, deadlift, bench, swing, lunge, core, treadmill].forEach(context.insert)
        // ME 5 組；DE 速度深蹲 8、硬舉 6、臥推 8；DE（爆）6；輔助、核心 3；有氧 1
        let cases: [(Exercise, Role, Int)] = [
            (squat, .maxEffort, 5), (deadlift, .dynamicEffort, 6), (bench, .dynamicEffort, 8), (swing, .dynamicEffort, 6),
            (lunge, .lowerAssist, 3), (core, .core, 3), (treadmill, .cardio, 1),
        ]
        let session = WorkoutActions.start(with: cases.map(\.0), roles: cases.map(\.1), in: context)
        #expect(session.orderedItems.map(\.sets.count) == cases.map(\.2))
        // 不是從建立菜單加入的動作依分類：下肢輔助 3 組
        WorkoutActions.discard(session, in: context)
        #expect(WorkoutActions.start(with: [squat], in: context).orderedItems[0].sets.count == 3)
    }

    @Test func setCountFollowsLastSessionExceptSpeedLifts() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, tags: [.main], equipment: .barbell)
        let lunge = Exercise(name: "側蹲", category: .kneeDominant, tags: [.unilateral], equipment: .dumbbell)
        [squat, lunge].forEach(context.insert)
        history(lunge, sets: [(10, 8), (10, 8), (10, 8), (10, 8)], daysAgo: 3, in: context)
        history(squat, sets: [(60, 5), (80, 3), (100, 3)], daysAgo: 5, in: context)
        // 有上一次紀錄就照上次的組數；DE 速度主項固定 8 組，不看上一次
        let session = WorkoutActions.start(with: [lunge, squat], roles: [.lowerAssist, .dynamicEffort], in: context)
        #expect(session.orderedItems.map(\.sets.count) == [4, 8])
    }

    @Test func restSecondsByRoleUnlessExerciseOverrides() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, tags: [.main], equipment: .barbell)
        let lunge = Exercise(name: "側蹲", category: .kneeDominant, tags: [.unilateral], equipment: .dumbbell)
        let core = Exercise(name: "腹前推", category: .core, equipment: .cable)
        let curl = Exercise(name: "二頭彎舉", category: .accessory, equipment: .dumbbell)
        let custom = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell, restSeconds: 120)
        [squat, lunge, core, curl, custom].forEach(context.insert)
        let session = WorkoutActions.start(with: [squat, lunge, core, curl, custom],
                                           roles: [.maxEffort, .lowerAssist, .core, .accessory, .push], in: context)
        #expect(session.orderedItems.map(\.restSeconds) == [180, 90, 60, 60, 120])
        // 同一個動作放在不同角色，休息跟著角色：DE 速度 60 秒
        let item = session.orderedItems[0]
        item.role = .dynamicEffort
        #expect(item.restSeconds == 60)
    }

    @Test func replaceKeepsRoleAndSlotFollowsRole() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, tags: [.main], equipment: .barbell)
        let front = Exercise(name: "前蹲舉", category: .kneeDominant, tags: [.main], equipment: .barbell)
        let row = Exercise(name: "坐姿 Cable 划船", category: .horizontalPull, equipment: .cable)
        let pulldown = Exercise(name: "滑輪下拉", category: .verticalPull, equipment: .cable)
        [squat, front, row, pulldown].forEach(context.insert)
        let session = WorkoutActions.start(with: [squat, row], roles: [.maxEffort, .pull], dayType: .meUpper, in: context)
        #expect(session.orderedItems.map { Slot(role: $0.role) } == [.maxEffort, .pull])
        // 舊角色換動作時當作下肢輔助
        #expect([Role.main, .explosive, .unilateral].map(Slot.init(role:)) == [.lowerAssist, .lowerAssist, .lowerAssist])
        WorkoutActions.replace(session.orderedItems[1], with: pulldown, role: .pull, in: context)
        #expect(session.orderedItems[1].role == .pull && session.title == "深蹲＋滑輪下拉")
        WorkoutActions.replace(session.orderedItems[0], with: front, in: context)
        #expect(session.orderedItems[0].role == .maxEffort)
    }

    @Test func repeatCarriesRolesAndDayType() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, tags: [.main], equipment: .barbell)
        let curl = Exercise(name: "二頭彎舉", category: .accessory, equipment: .dumbbell)
        [squat, curl].forEach(context.insert)
        // 把補強動作放在核心的位置，再做一次時照原本的角色
        let session = WorkoutActions.start(with: [squat, curl], roles: [.dynamicEffort, .core], dayType: .deLower, in: context)
        let request = StartRequest(exercises: session.orderedItems.compactMap(\.exercise),
                                   roles: session.orderedItems.map(\.role), dayType: session.dayType)
        WorkoutActions.discard(session, in: context)
        let again = WorkoutActions.start(with: request.exercises, roles: request.roles, dayType: request.dayType, in: context)
        #expect(again.orderedItems.map { $0.exercise?.name } == ["深蹲", "二頭彎舉"])
        #expect(again.orderedItems.map(\.role) == [.dynamicEffort, .core])
        #expect(again.dayType == .deLower)
    }

    @Test func previousSetsDependOnMainRole() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, tags: [.main], equipment: .barbell)
        context.insert(squat)
        func record(_ role: Role, _ sets: [(Double, Int)], daysAgo: Double) {
            let date = Date.now.addingTimeInterval(-daysAgo * 86_400)
            let session = WorkoutSession(startedAt: date, endedAt: date)
            context.insert(session)
            let item = SessionExercise(session: session, exercise: squat, order: 0, role: role)
            context.insert(item)
            for (i, s) in sets.enumerated() {
                context.insert(SetRecord(sessionExercise: item, order: i, weightKg: s.0, reps: s.1, isCompleted: true, completedAt: date))
            }
        }
        record(.maxEffort, [(100, 3)], daysAgo: 10)
        record(.lowerAssist, [(60, 10)], daysAgo: 6)
        // DE 主項沒有上次 DE 紀錄：上一次是空的，預填建議重量（ME 100 × 3 → 估算 1RM 110 × 60% = 65）和固定次數
        let de = WorkoutActions.start(with: [squat], roles: [.dynamicEffort], in: context)
        let hints = de.orderedItems[0].setHints()
        #expect(hints.count == 8 && hints.allSatisfy { $0.previous == nil })
        let expected = MaxEffortRecords.speedWeightKg(estimated1RM: 110, unit: .current)  // kg 單位時是 65
        #expect(hints.allSatisfy { $0.placeholder?.weightKg == expected && $0.placeholder?.reps == 2 })
        // ME 主項先看上次 ME；其他角色看最近一次
        #expect(squat.lastSets(role: .maxEffort).map(\.weightKg) == [100])
        #expect(squat.lastSets(role: .lowerAssist).map(\.weightKg) == [60])
        WorkoutActions.discard(de, in: context)
        record(.dynamicEffort, [(60, 2), (60, 2)], daysAgo: 3)
        #expect(squat.lastSets(role: .dynamicEffort).map(\.weightKg) == [60, 60])
        #expect(squat.lastSets(role: .maxEffort).map(\.weightKg) == [100])
        #expect(squat.lastSets().map(\.weightKg) == [60, 60])
    }
}
