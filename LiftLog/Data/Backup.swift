import Foundation
import SwiftData

/// 備份檔格式（version 3：訓練 → 動作 → 組）。匯入時也能讀 version 2（seed.json 也是 v2）。
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
        var restSeconds: Int?
    }

    struct SetRecordData: Codable {
        var id: UUID
        var order: Int
        var kind: String
        var weightKg: Double?
        var reps: Int?
        var incline: Double?
        var speed: Double?
        var minutes: Double?
        var isCompleted: Bool
        var completedAt: Date?
        var healthWorkoutID: UUID?
    }

    struct ItemRecord: Codable {
        var id: UUID
        var exerciseId: UUID
        var order: Int
        var note: String
        var sets: [SetRecordData]
    }

    struct SessionRecord: Codable {
        var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var title: String
        var note: String
        var hasTime: Bool
        var items: [ItemRecord]
    }

    struct BodyWeightRecord: Codable {
        var date: Date
        var kg: Double
    }

    static let currentVersion = 3

    var version: Int
    var exercises: [ExerciseRecord]
    var sessions: [SessionRecord]
    var bodyWeights: [BodyWeightRecord]

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let version = try decoder.decode(VersionProbe.self, from: data).version
        switch version {
        case 3:
            return try decoder.decode(BackupFile.self, from: data)
        case 2:
            return try decoder.decode(V2.self, from: data).upgraded()
        default:
            throw BackupError.unsupportedVersion(version)
        }
    }

    func encode() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    private struct VersionProbe: Decodable {
        var version: Int
    }

    /// CHANGE_01 的格式：一筆紀錄 = 一個動作在某天的數字
    private struct V2: Decodable {
        struct Entry: Decodable {
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
            var healthWorkoutID: UUID?
        }

        var exercises: [ExerciseRecord]
        var entries: [Entry]
        var bodyWeights: [BodyWeightRecord]

        func upgraded() -> BackupFile {
            let legacy = entries.map {
                SessionMigration.LegacyEntry(
                    date: $0.date, exerciseID: $0.exerciseId, weightKg: $0.weightKg, sets: $0.sets, reps: $0.reps,
                    isMax: $0.isMax, incline: $0.incline, speed: $0.speed, minutes: $0.minutes, note: $0.note,
                    healthWorkoutID: $0.healthWorkoutID
                )
            }
            let names = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
            let sessions = SessionMigration.plan(legacy).map { plan in
                SessionRecord(
                    id: UUID(), startedAt: plan.startedAt, endedAt: plan.startedAt,
                    title: SessionTitle.automatic(plan.items.compactMap { names[$0.exerciseID] }),
                    note: "", hasTime: false,
                    items: plan.items.enumerated().map { index, item in
                        ItemRecord(id: UUID(), exerciseId: item.exerciseID, order: index, note: item.note,
                                   sets: item.sets.enumerated().map { order, s in
                                       SetRecordData(id: UUID(), order: order, kind: s.values.kind.rawValue,
                                                     weightKg: s.values.weightKg, reps: s.values.reps,
                                                     incline: s.values.incline, speed: s.values.speed,
                                                     minutes: s.values.minutes, isCompleted: s.values.isCompleted,
                                                     completedAt: s.values.completedAt, healthWorkoutID: s.healthWorkoutID)
                                   })
                    }
                )
            }
            return BackupFile(version: BackupFile.currentVersion, exercises: exercises, sessions: sessions,
                              bodyWeights: bodyWeights)
        }
    }
}

enum BackupError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v): "不支援的備份格式（version \(v)）"
        }
    }
}

enum BackupService {
    static func makeBackup(from context: ModelContext) throws -> BackupFile {
        let exercises = try context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startedAt)]))
        let bodyWeights = try context.fetch(FetchDescriptor<BodyWeight>(sortBy: [SortDescriptor(\.date)]))
        return BackupFile(
            version: BackupFile.currentVersion,
            exercises: exercises.map {
                .init(id: $0.id, name: $0.name, category: $0.categoryRaw, tags: $0.tagsRaw, aliases: $0.aliases,
                      englishName: $0.englishName, equipment: $0.equipmentRaw, logType: $0.logTypeRaw,
                      note: $0.note, isArchived: $0.isArchived, restSeconds: $0.restSeconds)
            },
            sessions: sessions.map { s in
                .init(id: s.id, startedAt: s.startedAt, endedAt: s.endedAt, title: s.title, note: s.note, hasTime: s.hasTime,
                      items: s.orderedItems.compactMap { item in
                          guard let exerciseId = item.exercise?.id else { return nil }
                          return .init(id: item.id, exerciseId: exerciseId, order: item.order, note: item.note,
                                       sets: item.orderedSets.map { r in
                                           .init(id: r.id, order: r.order, kind: r.kindRaw, weightKg: r.weightKg, reps: r.reps,
                                                 incline: r.incline, speed: r.speed, minutes: r.minutes,
                                                 isCompleted: r.isCompleted, completedAt: r.completedAt,
                                                 healthWorkoutID: r.healthWorkoutID)
                                       })
                      })
            },
            bodyWeights: bodyWeights.map { .init(date: $0.date, kg: $0.kg) }
        )
    }

    /// 清空現有資料後寫入備份內容
    static func restore(_ file: BackupFile, into context: ModelContext) throws {
        // 逐筆刪除：批次刪除只作用在已存檔的資料，尚未存檔的新物件會殘留
        for session in try context.fetch(FetchDescriptor<WorkoutSession>()) { context.delete(session) }
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
                isArchived: r.isArchived,
                restSeconds: r.restSeconds
            )
            context.insert(exercise)
            byID[r.id] = exercise
        }
        for s in file.sessions {
            let session = WorkoutSession(id: s.id, startedAt: s.startedAt, endedAt: s.endedAt, title: s.title,
                                         note: s.note, hasTime: s.hasTime)
            context.insert(session)
            for i in s.items {
                guard let exercise = byID[i.exerciseId] else { continue }
                let item = SessionExercise(id: i.id, session: session, exercise: exercise, order: i.order, note: i.note)
                context.insert(item)
                for r in i.sets {
                    context.insert(SetRecord(
                        id: r.id, sessionExercise: item, order: r.order, kind: SetKind(rawValue: r.kind) ?? .normal,
                        weightKg: r.weightKg, reps: r.reps, incline: r.incline, speed: r.speed, minutes: r.minutes,
                        isCompleted: r.isCompleted, completedAt: r.completedAt, healthWorkoutID: r.healthWorkoutID
                    ))
                }
            }
        }
        for r in file.bodyWeights {
            context.insert(BodyWeight(date: r.date, kg: r.kg))
        }
        try context.save()
    }
}

enum SeedImporter {
    /// 資料庫沒有任何動作時，匯入 bundle 裡的 seed.json（v2 格式，匯入時轉成訓練）
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
