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
        #expect(session.title == "上肢訓練")
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

    @Test func finishCompletingAllUsesPrefillAndDropsEmptySets() throws {
        let context = try makeContext()
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        let row = Exercise(name: "坐姿 Cable 划船", category: .horizontalPull, equipment: .cable)
        [bench, row].forEach(context.insert)
        history(bench, sets: [(40, 5), (42.6, 5)], daysAgo: 3, in: context)
        let session = WorkoutActions.start(with: [bench, row], in: context)
        let benchItem = session.orderedItems[0]
        WorkoutActions.addSet(to: benchItem, in: context)
        // 第一組只改了重量，次數沿用預填；第三組沒有上一次，沿用本次前一組
        benchItem.orderedSets[0].weightKg = 45
        #expect(WorkoutActions.finish(session, choice: .completeAll, in: context))
        let sets = benchItem.orderedSets
        #expect(sets.map(\.weightKg) == [45, 42.6, 42.6] && sets.map(\.reps) == [5, 5, 5])
        #expect(sets.allSatisfy { $0.isCompleted && $0.completedAt != nil })
        // 划船沒做過也沒填：連預填都沒有，組被刪掉，動作也一起移除（不會留下沒有數字的完成組）
        #expect(session.orderedItems.map { $0.exercise?.name } == ["臥推"])
        #expect(try context.fetch(FetchDescriptor<SetRecord>()).allSatisfy { $0.weightKg != nil && $0.reps != nil })
    }

    @Test func finishCompletingAllWithNothingToFillDeletesSession() throws {
        let context = try makeContext()
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        context.insert(bench)
        let session = WorkoutActions.start(with: [bench], in: context)
        #expect(!WorkoutActions.finish(session, choice: .completeAll, in: context))
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSession>()) == 0)
    }

    @Test func checkingASetInAPastSessionUsesThatSessionsDate() throws {
        let context = try makeContext()
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        context.insert(bench)
        history(bench, sets: [(40, 5), (42.6, 5)], daysAgo: 10, in: context)
        let past = try #require(bench.completedItems.first?.session)
        let set = try #require(past.orderedItems.first?.orderedSets.last)
        // 在歷史訓練裡取消打勾再打勾：完成時間是那次訓練，「幾天前」不會變成今天
        set.isCompleted = false
        set.completedAt = nil
        #expect(WorkoutActions.complete(set, placeholder: nil, in: context))
        #expect(set.completedAt == past.endedAt)
        #expect(Recency.daysSince(bench.lastCompletedDate) == 10)
        // 進行中的訓練是現在
        let now = Date.now
        #expect(WorkoutActions.completionDate(in: past, now: now) == past.endedAt)
        let active = WorkoutActions.start(with: [bench], in: context)
        #expect(WorkoutActions.completionDate(in: active, now: now) == now)
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
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        context.insert(squat)
        let session = WorkoutActions.start(with: [bench], in: context)
        _ = WorkoutActions.add(row, to: session, in: context)
        #expect(session.title == "上肢訓練")
        // 沒有自訂時跟著動作更新
        _ = WorkoutActions.add(squat, to: session, in: context)
        #expect(session.title == "全身訓練")
        // 手動改過就不再覆蓋；「恢復自動名稱」再交回自動
        session.setTitle(fromUserInput: "推日")
        #expect(session.isTitleCustom)
        WorkoutActions.remove(session.orderedItems[2], in: context)
        #expect(session.title == "推日")
        session.restoreAutomaticTitle()
        #expect(!session.isTitleCustom && session.title == "上肢訓練")
        // 欄位清空等於恢復自動名稱
        session.setTitle(fromUserInput: "  ")
        #expect(!session.isTitleCustom && session.title == "上肢訓練")
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
        for set in session.items.flatMap(\.sets) { set.weightKg = 20; set.reps = 10 }
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
        #expect(session.orderedItems[1].role == .pull && session.title == "上肢最大肌力・深蹲")
        WorkoutActions.replace(session.orderedItems[0], with: front, in: context)
        #expect(session.orderedItems[0].role == .maxEffort)
    }

    @Test func previousSetsInAPastSessionComeOnlyFromEarlierSessions() throws {
        // T3：編輯過去的訓練時，「上一次」和灰字預填只取那次訓練開始之前最新的紀錄
        let context = try makeContext()
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        context.insert(bench)
        history(bench, sets: [(40, 5)], daysAgo: 20, in: context)
        history(bench, sets: [(50, 5), (50, 5)], daysAgo: 10, in: context)
        history(bench, sets: [(60, 3)], daysAgo: 2, in: context)
        let middle = try #require(bench.completedItems.first { $0.completedSets.count == 2 })
        let session = try #require(middle.session)
        #expect(bench.lastSets(excluding: session).map(\.weightKg) == [40])
        #expect(middle.setHints().map(\.previous?.weightKg) == [40, nil])
        // 建議重量用的紀錄也一樣
        #expect(bench.logs(excluding: session).map { $0.sets.compactMap(\.weightKg) } == [[40]])
        // 最早的那次沒有之前的紀錄
        let first = try #require(bench.completedItems.last?.session)
        #expect(bench.lastSets(excluding: first).isEmpty)
        // 進行中的訓練照常取最近一次
        let active = WorkoutActions.start(with: [bench], in: context)
        #expect(bench.lastSets(excluding: active).map(\.weightKg) == [60])
    }

    /// CHANGE_08 T1：編輯已結束的訓練（補登）按「完成」時，沒打勾但已經填了數字的組可以一次標為完成，
    /// 完成時間是那次訓練的結束時間；沒填數字的組、已經打勾的組不處理
    @Test func finishingAnEndedSessionCompletesFilledSets() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        let row = Exercise(name: "反式划船", category: .horizontalPull, equipment: .bodyweight, logType: .bodyweight)
        [squat, row].forEach(context.insert)
        let start = Date.now.addingTimeInterval(-3 * 86_400)
        let end = start.addingTimeInterval(3600)
        let session = WorkoutSession(startedAt: start, endedAt: end)
        context.insert(session)
        let squatItem = SessionExercise(session: session, exercise: squat, order: 0)
        let rowItem = SessionExercise(session: session, exercise: row, order: 1)
        [squatItem, rowItem].forEach(context.insert)
        let done = SetRecord(sessionExercise: squatItem, order: 0, weightKg: 60, reps: 5, isCompleted: true,
                             completedAt: start.addingTimeInterval(600))
        let filled = SetRecord(sessionExercise: squatItem, order: 1, weightKg: 80, reps: 5)
        // 只填了重量：次數沿用前一組（和直接按 ✓ 一樣）
        let weightOnly = SetRecord(sessionExercise: squatItem, order: 2, weightKg: 85)
        let empty = SetRecord(sessionExercise: squatItem, order: 3)
        let rowFilled = SetRecord(sessionExercise: rowItem, order: 0, reps: 12)
        let rowEmpty = SetRecord(sessionExercise: rowItem, order: 1)
        [done, filled, weightOnly, empty, rowFilled, rowEmpty].forEach(context.insert)

        let pending = WorkoutActions.filledIncompleteSets(in: session)
        #expect(pending.map(\.set.id) == [filled.id, weightOnly.id, rowFilled.id])
        #expect(WorkoutActions.completeFilledSets(in: session, context: context) == 3)

        #expect(filled.isCompleted && filled.completedAt == end)
        #expect(weightOnly.isCompleted && weightOnly.weightKg == 85 && weightOnly.reps == 5 && weightOnly.completedAt == end)
        #expect(rowFilled.isCompleted && rowFilled.completedAt == end)
        // 已經打勾的不動，完全沒填數字的維持原樣
        #expect(done.completedAt == start.addingTimeInterval(600))
        #expect(!empty.isCompleted && empty.weightKg == nil && empty.reps == nil)
        #expect(!rowEmpty.isCompleted)
        #expect(WorkoutActions.filledIncompleteSets(in: session).isEmpty)
        // 上次日期跟著算進來
        #expect(squat.lastCompletedDate == end)
    }

    /// CHANGE_09 §0-1：「繼續編輯」不改任何資料、不關閉編輯畫面；另外兩個選項的行為不變
    @Test func continueEditingChangesNothing() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        context.insert(squat)
        let start = Date.now.addingTimeInterval(-2 * 86_400)
        let session = WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(3600))
        context.insert(session)
        let item = SessionExercise(session: session, exercise: squat, order: 0)
        context.insert(item)
        let filled = SetRecord(sessionExercise: item, order: 0, weightKg: 80, reps: 5)
        let weightOnly = SetRecord(sessionExercise: item, order: 1, weightKg: 85)
        [filled, weightOnly].forEach(context.insert)
        try context.save()
        let before = [filled, weightOnly].map { ($0.values, $0.isCompleted, $0.completedAt) }

        #expect(WorkoutActions.resolveFilledSets(.continueEditing, in: session, context: context) == false)
        #expect(!context.hasChanges)
        for (set, old) in zip([filled, weightOnly], before) {
            #expect(set.values == old.0 && set.isCompleted == old.1 && set.completedAt == old.2)
        }
        #expect(WorkoutActions.filledIncompleteSets(in: session).count == 2)
        #expect(squat.lastCompletedDate == nil)

        // 「保持未完成」：一樣不改資料，但關閉
        #expect(WorkoutActions.resolveFilledSets(.keepIncomplete, in: session, context: context))
        #expect(!context.hasChanges && !filled.isCompleted)
        // 「標為完成」：標完成並關閉
        #expect(WorkoutActions.resolveFilledSets(.complete, in: session, context: context))
        #expect(filled.isCompleted && weightOnly.isCompleted && weightOnly.reps == 5)
    }

    /// 進行中的訓練不走這裡（由「完成訓練」處理）
    @Test func filledSetsPromptIsOnlyForEndedSessions() throws {
        let context = try makeContext()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        context.insert(squat)
        let active = WorkoutActions.start(with: [squat], in: context)
        let set = try #require(active.orderedItems.first?.orderedSets.first)
        set.weightKg = 80
        set.reps = 5
        #expect(WorkoutActions.filledIncompleteSets(in: active).isEmpty)
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
