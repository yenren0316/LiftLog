import Foundation
import SwiftData

/// 備份檔與 seed.json 共用的格式
nonisolated struct BackupFile: Codable {
    struct ExerciseRecord: Codable {
        var name: String
        var primaryGroup: String
        var secondaryGroups: [String]
        var equipment: String
        var logType: String
        var note: String
        var isArchived: Bool
    }

    struct EntryRecord: Codable {
        var date: Date
        var exercise: String
        var weightKg: Double?
        var sets: Int?
        var reps: Int?
        var isMax: Bool
        var incline: Double?
        var speed: Double?
        var minutes: Double?
        var note: String
    }

    struct BodyWeightRecord: Codable {
        var date: Date
        var kg: Double
    }

    var version: Int
    var exercises: [ExerciseRecord]
    var entries: [EntryRecord]
    var bodyWeights: [BodyWeightRecord]

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupFile.self, from: data)
    }

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

enum BackupService {
    static func makeBackup(from context: ModelContext) throws -> BackupFile {
        let exercises = try context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        let entries = try context.fetch(FetchDescriptor<WorkoutEntry>(sortBy: [SortDescriptor(\.date)]))
        let bodyWeights = try context.fetch(FetchDescriptor<BodyWeight>(sortBy: [SortDescriptor(\.date)]))
        return BackupFile(
            version: 1,
            exercises: exercises.map {
                .init(name: $0.name, primaryGroup: $0.primaryGroupRaw, secondaryGroups: $0.secondaryGroupsRaw,
                      equipment: $0.equipmentRaw, logType: $0.logTypeRaw, note: $0.note, isArchived: $0.isArchived)
            },
            entries: entries.compactMap { e in
                guard let name = e.exercise?.name else { return nil }
                return .init(date: e.date, exercise: name, weightKg: e.weightKg, sets: e.sets, reps: e.reps,
                             isMax: e.isMax, incline: e.incline, speed: e.speed, minutes: e.minutes, note: e.note)
            },
            bodyWeights: bodyWeights.map { .init(date: $0.date, kg: $0.kg) }
        )
    }

    /// 清空現有資料後寫入備份內容
    static func restore(_ file: BackupFile, into context: ModelContext) throws {
        try context.delete(model: WorkoutEntry.self)
        try context.delete(model: Exercise.self)
        try context.delete(model: BodyWeight.self)

        var byName: [String: Exercise] = [:]
        for r in file.exercises {
            let exercise = Exercise(
                name: r.name,
                primaryGroup: MuscleGroup(rawValue: r.primaryGroup) ?? .core,
                secondaryGroups: r.secondaryGroups.compactMap(MuscleGroup.init(rawValue:)),
                equipment: Equipment(rawValue: r.equipment) ?? .other,
                logType: LogType(rawValue: r.logType) ?? .weight,
                note: r.note,
                isArchived: r.isArchived
            )
            context.insert(exercise)
            byName[r.name] = exercise
        }
        for r in file.entries {
            guard let exercise = byName[r.exercise] else { continue }
            context.insert(WorkoutEntry(
                date: r.date, exercise: exercise, weightKg: r.weightKg, sets: r.sets, reps: r.reps,
                isMax: r.isMax, incline: r.incline, speed: r.speed, minutes: r.minutes, note: r.note
            ))
        }
        for r in file.bodyWeights {
            context.insert(BodyWeight(date: r.date, kg: r.kg))
        }
        try context.save()
    }
}

enum SeedImporter {
    /// 資料庫沒有任何動作時，匯入 bundle 裡的 seed.json
    static func importIfNeeded(into context: ModelContext) {
        do {
            guard try context.fetchCount(FetchDescriptor<Exercise>()) == 0,
                  let url = Bundle.main.url(forResource: "seed", withExtension: "json")
            else { return }
            try BackupService.restore(BackupFile.decode(Data(contentsOf: url)), into: context)
        } catch {
            print("Seed import failed: \(error)")
        }
    }
}
