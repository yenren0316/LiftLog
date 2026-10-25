import Foundation
import SwiftData

/// 備份檔與 seed.json 共用的格式（version 2：紀錄以 exercise id 對應）
nonisolated struct BackupFile: Codable {
    struct ExerciseRecord: Codable {
        var id: UUID
        var name: String
        var category: String
        var tags: [String]
        var aliases: [String]
        var englishName: String
        var equipment: String
        var logType: String
        var note: String
        var isArchived: Bool
    }

    struct EntryRecord: Codable {
        var date: Date
        var exerciseId: UUID
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
            version: 2,
            exercises: exercises.map {
                .init(id: $0.id, name: $0.name, category: $0.categoryRaw, tags: $0.tagsRaw, aliases: $0.aliases,
                      englishName: $0.englishName, equipment: $0.equipmentRaw, logType: $0.logTypeRaw,
                      note: $0.note, isArchived: $0.isArchived)
            },
            entries: entries.compactMap { e in
                guard let id = e.exercise?.id else { return nil }
                return .init(date: e.date, exerciseId: id, weightKg: e.weightKg, sets: e.sets, reps: e.reps,
                             isMax: e.isMax, incline: e.incline, speed: e.speed, minutes: e.minutes, note: e.note)
            },
            bodyWeights: bodyWeights.map { .init(date: $0.date, kg: $0.kg) }
        )
    }

    /// 清空現有資料後寫入備份內容
    static func restore(_ file: BackupFile, into context: ModelContext) throws {
        // 逐筆刪除：批次刪除只作用在已存檔的資料，尚未存檔的新物件會殘留
        for entry in try context.fetch(FetchDescriptor<WorkoutEntry>()) { context.delete(entry) }
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) { context.delete(exercise) }
        for bodyWeight in try context.fetch(FetchDescriptor<BodyWeight>()) { context.delete(bodyWeight) }
        try context.save()

        var byID: [UUID: Exercise] = [:]
        for r in file.exercises {
            let exercise = Exercise(
                id: r.id,
                name: r.name,
                category: ExerciseCategory(rawValue: r.category) ?? .accessory,
                tags: r.tags.compactMap(ExerciseTag.init(rawValue:)),
                aliases: r.aliases,
                englishName: r.englishName,
                equipment: Equipment(rawValue: r.equipment) ?? .other,
                logType: LogType(rawValue: r.logType) ?? .weight,
                note: r.note,
                isArchived: r.isArchived
            )
            context.insert(exercise)
            byID[r.id] = exercise
        }
        for r in file.entries {
            guard let exercise = byID[r.exerciseId] else { continue }
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
