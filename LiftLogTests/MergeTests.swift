import Foundation
import SwiftData
import Testing
@testable import LiftLog

@MainActor
struct MergeTests {
    @Test func mergeMovesEntriesAndAliases() throws {
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
        for day in 1...3 {
            context.insert(WorkoutEntry(date: .now.addingTimeInterval(Double(-day) * 86_400), exercise: source, weightKg: 20))
        }
        context.insert(WorkoutEntry(date: .now, exercise: target, weightKg: 22))
        try context.save()

        try ExerciseMerge.merge(source, into: target, context: context)

        #expect(target.entries.count == 4)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutEntry>()) == 4)
        #expect(target.aliases == ["保加利亞分腿蹲", "保加利亞蹲（舊）", "BSS"])
        let remaining = try context.fetch(FetchDescriptor<Exercise>())
        #expect(remaining.map(\.name) == ["後腳抬高蹲"])
    }

    @Test func mergedAliasesDropTargetNameAndDuplicates() {
        let result = ExerciseMerge.mergedAliases(
            target: "臥推", targetAliases: ["槓鈴臥推"],
            source: "槓鈴臥推", sourceAliases: ["臥推", "Bench"]
        )
        #expect(result == ["槓鈴臥推", "Bench"])
    }
}
