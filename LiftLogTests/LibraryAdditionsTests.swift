import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// 已經有資料的 App 啟動時，從 seed.json 補進之後才加的預設動作
@MainActor
struct LibraryAdditionsTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: LiftLogStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func bundled() throws -> (BackupFile, [String: GuideImporter.Guide]) {
        (try #require(try SeedImporter.bundled()), try #require(GuideImporter.bundled()))
    }

    @Test func everyAdditionIsInTheSeedWithAGuide() throws {
        let (seed, guides) = try bundled()
        for name in LibraryAdditions.names {
            #expect(seed.exercises.contains { $0.name == name && !$0.isArchived }, "\(name)")
            #expect(guides[name] != nil, "\(name)")
        }
    }

    @Test func addsMissingExerciseWithItsGuide() throws {
        let context = try makeContext()
        let (seed, guides) = try bundled()
        context.insert(Exercise(name: "啞鈴臥推", category: .horizontalPush, equipment: .dumbbell))
        let added = try LibraryAdditions.apply(["啞鈴上斜臥推"], from: seed.exercises, guides: guides, into: context)
        let exercise = try #require(added.first)
        #expect(added.count == 1)
        #expect(exercise.category == .horizontalPush && exercise.equipment == .dumbbell && !exercise.isArchived)
        #expect(exercise.aliases.contains("上斜啞鈴臥推"))
        #expect(exercise.guideCore == "抗伸展" && !exercise.guideCues.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 2)

        // 再跑一次不會重複
        let again = try LibraryAdditions.apply(["啞鈴上斜臥推"], from: seed.exercises, guides: guides, into: context)
        #expect(again.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 2)
    }

    @Test func skipsWhenTheNameIsAlreadyUsed() throws {
        let context = try makeContext()
        let (seed, guides) = try bundled()
        // 使用者自己建過，名稱用的是別名
        context.insert(Exercise(name: "上斜啞鈴臥推", category: .horizontalPush, equipment: .dumbbell))
        let added = try LibraryAdditions.apply(["啞鈴上斜臥推"], from: seed.exercises, guides: guides, into: context)
        #expect(added.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 1)
    }

    @Test func runsOnlyOnce() throws {
        let context = try makeContext()
        let defaults = try #require(UserDefaults(suiteName: "LibraryAdditionsTests.\(UUID().uuidString)"))
        LibraryAdditions.applyIfNeeded(into: context, defaults: defaults)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == LibraryAdditions.names.count)
        // 使用者刪掉之後，下次啟動不會再補回來
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) { context.delete(exercise) }
        try context.save()
        LibraryAdditions.applyIfNeeded(into: context, defaults: defaults)
        #expect(try context.fetchCount(FetchDescriptor<Exercise>()) == 0)
    }
}
