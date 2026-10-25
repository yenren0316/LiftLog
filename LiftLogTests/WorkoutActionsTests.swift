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
        #expect(session.orderedItems[1].sets.count == 1)   // 沒有歷史 → 一組
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
        #expect(session.orderedItems[0].sets.count == 2)
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
}
