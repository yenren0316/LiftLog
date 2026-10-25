import Foundation
import SwiftData
import Testing
@testable import LiftLog

@MainActor
struct BackupTests {
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Exercise.self, WorkoutEntry.self, BodyWeight.self, configurations: config
        )
        return ModelContext(container)
    }

    @Test func exportThenImportKeepsEverything() throws {
        let source = try makeContext()
        let pullUp = Exercise(name: "引體向上", primaryGroup: .back, secondaryGroups: [.arms],
                              equipment: .bodyweight, logType: .assisted, note: "握距中等")
        let walk = Exercise(name: "室內步行", primaryGroup: .cardio, equipment: .other,
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
        target.insert(Exercise(name: "會被取代", primaryGroup: .chest, equipment: .barbell))
        try BackupService.restore(BackupFile.decode(data), into: target)

        let exercises = try target.fetch(FetchDescriptor<Exercise>())
        #expect(Set(exercises.map(\.name)) == ["室內步行", "引體向上"])

        let restoredPullUp = try #require(exercises.first { $0.name == "引體向上" })
        #expect(restoredPullUp.logType == .assisted)
        #expect(restoredPullUp.secondaryGroups == [.arms])
        #expect(restoredPullUp.note == "握距中等")
        let entry = try #require(restoredPullUp.entries.first)
        #expect(entry.weightKg == 13.75 && entry.sets == 5 && entry.reps == 5)
        #expect(entry.isMax && entry.note == "一邊")
        #expect(entry.date == date)

        let restoredWalk = try #require(exercises.first { $0.name == "室內步行" })
        #expect(restoredWalk.isArchived)
        #expect(restoredWalk.entries.first?.incline == 14.5)

        #expect(try target.fetch(FetchDescriptor<BodyWeight>()).map(\.kg) == [70.8])
    }

    @Test func bundledSeedDecodes() throws {
        let url = try #require(Bundle.main.url(forResource: "seed", withExtension: "json"))
        let file = try BackupFile.decode(Data(contentsOf: url))
        let names = Set(file.exercises.map(\.name))
        #expect(file.exercises.count == names.count)
        #expect(file.entries.allSatisfy { names.contains($0.exercise) })
        #expect(file.entries.count > 500)
    }
}
