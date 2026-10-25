import Foundation
import SwiftData
import Testing
@testable import LiftLog

@MainActor
struct MergeTests {
    @Test func mergeMovesSessionsAndAliases() throws {
        let container = try ModelContainer(
            for: LiftLogStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let target = Exercise(name: "後腳抬高蹲", category: .kneeDominant, tags: [.unilateral],
                              aliases: ["保加利亞分腿蹲"], equipment: .dumbbell)
        let source = Exercise(name: "保加利亞蹲（舊）", category: .kneeDominant,
                              aliases: ["保加利亞分腿蹲", "BSS"], equipment: .barbell)
        context.insert(target)
        context.insert(source)

        // 三次只有來源的訓練，各 2 組
        for day in 1...3 {
            let session = WorkoutSession(startedAt: .now.addingTimeInterval(Double(-day) * 86_400), endedAt: .now)
            context.insert(session)
            let item = SessionExercise(session: session, exercise: source, order: 0)
            context.insert(item)
            for i in 0..<2 {
                context.insert(SetRecord(sessionExercise: item, order: i, weightKg: 20, reps: 7, isCompleted: true, completedAt: .now))
            }
        }
        // 一次兩個動作都有的訓練：合併後只剩一張卡片，組接在後面
        let both = WorkoutSession(startedAt: .now, endedAt: .now)
        context.insert(both)
        let targetItem = SessionExercise(session: both, exercise: target, order: 0)
        let sourceItem = SessionExercise(session: both, exercise: source, order: 1, note: "槓鈴")
        context.insert(targetItem)
        context.insert(sourceItem)
        context.insert(SetRecord(sessionExercise: targetItem, order: 0, weightKg: 22, reps: 7, isCompleted: true, completedAt: .now))
        context.insert(SetRecord(sessionExercise: sourceItem, order: 0, weightKg: 30, reps: 7, isCompleted: true, completedAt: .now))
        try context.save()

        try ExerciseMerge.merge(source, into: target, context: context)

        #expect(target.sessionItems.count == 4)
        #expect(try context.fetchCount(FetchDescriptor<SetRecord>()) == 8)
        #expect(targetItem.orderedSets.map(\.weightKg) == [22, 30])
        #expect(targetItem.note == "槓鈴")
        #expect(both.items.count == 1)
        #expect(target.aliases == ["保加利亞分腿蹲", "保加利亞蹲（舊）", "BSS"])
        #expect(try context.fetch(FetchDescriptor<Exercise>()).map(\.name) == ["後腳抬高蹲"])
    }

    @Test func mergedAliasesDropTargetNameAndDuplicates() {
        let result = ExerciseMerge.mergedAliases(
            target: "臥推", targetAliases: ["槓鈴臥推"],
            source: "槓鈴臥推", sourceAliases: ["臥推", "Bench"]
        )
        #expect(result == ["槓鈴臥推", "Bench"])
    }
}
