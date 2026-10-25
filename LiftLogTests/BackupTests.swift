import Foundation
import SwiftData
import Testing
@testable import LiftLog

@MainActor
struct BackupTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: LiftLogStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func exportThenImportKeepsEverything() throws {
        let source = try makeContext()
        let pullUp = Exercise(name: "輔助引體向上", category: .verticalPull, tags: [.unilateral],
                              aliases: ["引體向上"], englishName: "Assisted Pull-up",
                              equipment: .bodyweight, logType: .assisted, note: "握距中等")
        let walk = Exercise(name: "跑步機", category: .cardio, equipment: .other,
                            logType: .cardio, isArchived: true)
        source.insert(pullUp)
        source.insert(walk)
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        source.insert(WorkoutEntry(date: date, exercise: pullUp, weightKg: 13.75, sets: 5, reps: 5,
                                   isMax: true, note: "一邊"))
        source.insert(WorkoutEntry(date: date, exercise: walk, incline: 14.5, speed: 4.2, minutes: 30))
        source.insert(BodyWeight(date: date, kg: 70.8))
        try source.save()

        let data = try BackupService.makeBackup(from: source).encode()
        let target = try makeContext()
        target.insert(Exercise(name: "會被取代", category: .accessory, equipment: .barbell))
        try BackupService.restore(BackupFile.decode(data), into: target)

        let exercises = try target.fetch(FetchDescriptor<Exercise>())
        #expect(Set(exercises.map(\.name)) == ["跑步機", "輔助引體向上"])

        let restoredPullUp = try #require(exercises.first { $0.name == "輔助引體向上" })
        #expect(restoredPullUp.id == pullUp.id)
        #expect(restoredPullUp.logType == .assisted)
        #expect(restoredPullUp.category == .verticalPull)
        #expect(restoredPullUp.tags == [.unilateral])
        #expect(restoredPullUp.aliases == ["引體向上"])
        #expect(restoredPullUp.englishName == "Assisted Pull-up")
        #expect(restoredPullUp.note == "握距中等")
        let entry = try #require(restoredPullUp.entries.first)
        #expect(entry.weightKg == 13.75 && entry.sets == 5 && entry.reps == 5)
        #expect(entry.isMax && entry.note == "一邊")
        #expect(entry.date == date)

        let restoredWalk = try #require(exercises.first { $0.name == "跑步機" })
        #expect(restoredWalk.isArchived)
        #expect(restoredWalk.entries.first?.incline == 14.5)

        #expect(try target.fetch(FetchDescriptor<BodyWeight>()).map(\.kg) == [70.8])
    }

    @Test func bundledSeedDecodes() throws {
        let url = try #require(Bundle.main.url(forResource: "seed", withExtension: "json"))
        let file = try BackupFile.decode(Data(contentsOf: url))
        let ids = Set(file.exercises.map(\.id))
        #expect(file.version == 2)
        #expect(file.exercises.count == ids.count)
        #expect(Set(file.exercises.map(\.name)).count == ids.count)
        #expect(file.entries.allSatisfy { ids.contains($0.exerciseId) })
        #expect(file.entries.count > 500)
        #expect(file.exercises.allSatisfy { ExerciseCategory(rawValue: $0.category) != nil })
        #expect(file.exercises.allSatisfy { $0.tags.allSatisfy { ExerciseTag(rawValue: $0) != nil } })
    }

    @Test func seedTreadmillEntriesHaveAllThreeFields() throws {
        let url = try #require(Bundle.main.url(forResource: "seed", withExtension: "json"))
        let file = try BackupFile.decode(Data(contentsOf: url))
        let treadmill = try #require(file.exercises.first { $0.name == "跑步機" })
        #expect(treadmill.logType == "cardio")
        #expect(treadmill.aliases == ["室內步行", "跑步"])
        let entries = file.entries.filter { $0.exerciseId == treadmill.id }
        #expect(entries.count > 50)
        #expect(entries.allSatisfy { $0.incline != nil && $0.speed != nil && $0.minutes != nil && $0.weightKg == nil })
        // 原文「坡度13速度4 30min」（2026/7/1，沒有空格）
        #expect(entries.contains { $0.incline == 13 && $0.speed == 4 && $0.minutes == 30 })
        #expect(entries.filter { $0.note == "跑步" }.count == 1)
    }
}
