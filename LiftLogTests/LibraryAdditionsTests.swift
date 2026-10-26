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

    @Test func conjugateLibraryUpdatesTagsAndRotationButNoRecords() throws {
        let context = try makeContext()
        let (seed, guides) = try bundled()
        try BackupService.restore(seed, into: context)
        try LibraryAdditions.apply(ConjugateLibrary.additions, from: seed.exercises, guides: guides, into: context)
        let pullUp = try #require(try context.fetch(FetchDescriptor<Exercise>()).first { $0.name == "輔助引體向上" })
        let assistBefore = pullUp.sessionItems.flatMap(\.sets).compactMap(\.weightKg).sorted()
        let setCount = try context.fetchCount(FetchDescriptor<SetRecord>())
        let roles = try context.fetch(FetchDescriptor<SessionExercise>()).map(\.roleRaw).sorted()

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        ConjugateLibrary.apply(to: exercises)
        let byName = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0) })

        // 51 個動作＋跑步機都在，而且沒有封存
        for entry in ConjugateLibrary.entries {
            let exercise = try #require(byName[entry.name], "\(entry.name)")
            #expect(!exercise.isArchived, "\(entry.name)")
            #expect(exercise.tags == entry.tags, "\(entry.name)")
            #expect(exercise.meRotation == entry.me && exercise.deRotation == entry.de, "\(entry.name)")
        }
        #expect(byName["深蹲"]?.tags == [.main] && byName["單手壺鈴擺盪"]?.tags == [.unilateral, .explosive])
        #expect(byName["窄跪姿單手啞鈴肩推"]?.tags == [.unilateral])
        #expect(exercises.filter { $0.tags.contains(.main) }.count == 12)
        // 不在清單裡的動作（封存的機械）不在輪替表
        #expect(byName["腿推機"]?.meRotation == nil && byName["腿推機"]?.isArchived == true)
        // 輔助引體向上改記負重，舊紀錄的數字不轉換
        #expect(pullUp.logType == .weight && pullUp.note == ConjugateLibrary.negativeLoadNote)
        #expect(pullUp.sessionItems.flatMap(\.sets).compactMap(\.weightKg).sorted() == assistBefore)
        #expect(try context.fetchCount(FetchDescriptor<SetRecord>()) == setCount)
        #expect(try context.fetch(FetchDescriptor<SessionExercise>()).map(\.roleRaw).sorted() == roles)
        // 新動作都有說明（全新安裝時由 GuideImporter 填入）
        GuideImporter.apply(guides, to: exercises)
        #expect(ConjugateLibrary.additions.allSatisfy { !(byName[$0]?.guideCues.isEmpty ?? true) })
    }

    @Test func conjugateLibraryRunsOnlyOnce() throws {
        let context = try makeContext()
        let defaults = try #require(UserDefaults(suiteName: "ConjugateLibraryTests.\(UUID().uuidString)"))
        let squat = Exercise(name: "深蹲", category: .kneeDominant, equipment: .barbell)
        context.insert(squat)
        ConjugateLibrary.applyIfNeeded(into: context, defaults: defaults)
        #expect(squat.tags == [.main] && squat.meRotation == 1)
        // 之後使用者自己改的標籤不會被蓋掉
        squat.tags = []
        ConjugateLibrary.applyIfNeeded(into: context, defaults: defaults)
        #expect(squat.tags.isEmpty)
    }
}
