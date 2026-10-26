import Foundation
import SwiftData

/// 備份檔格式（version 5：訓練 → 動作 → 組，加上 role、region、modeID、日型與主項輪替順序）。
/// 匯入時也能讀 version 3、4（缺的欄位依動作推算或留空）與 version 2（seed.json 也是 v2）。
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
        var guideCore: String?
        var guideCues: [String]?
        var guideMistakes: [String]?
        var guideRegression: String?
        var guideProgression: String?
        var myNotes: String?
        /// v5 新增
        var meRotation: Int?
        var deRotation: Int?
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
        var seconds: Double?
        var isCompleted: Bool
        var completedAt: Date?
        var healthWorkoutID: UUID?
    }

    struct ItemRecord: Codable {
        var id: UUID
        var exerciseId: UUID
        var order: Int
        var note: String
        /// v4 新增；舊版本為 nil，匯入時依動作推算
        var role: String?
        var sets: [SetRecordData]
    }

    struct SessionRecord: Codable {
        var id: UUID
        var startedAt: Date
        var endedAt: Date?
        var title: String
        var note: String
        var hasTime: Bool
        /// v4 新增；舊版本為 nil，匯入時依動作推算
        var region: String?
        var modeID: String?
        /// v5 新增；舊版本和沒有日型的訓練為 nil
        var dayType: String?
        var items: [ItemRecord]
    }

    struct BodyWeightRecord: Codable {
        var date: Date
        var kg: Double
    }

    static let currentVersion = 5

    var version: Int
    var exercises: [ExerciseRecord]
    var sessions: [SessionRecord]
    var bodyWeights: [BodyWeightRecord]

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let version = try decoder.decode(VersionProbe.self, from: data).version
        switch version {
        case 3, 4, 5:
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
                    note: "", hasTime: false, region: nil, modeID: nil, dayType: nil,
                    items: plan.items.enumerated().map { index, item in
                        ItemRecord(id: UUID(), exerciseId: item.exerciseID, order: index, note: item.note, role: nil,
                                   sets: item.sets.enumerated().map { order, s in
                                       SetRecordData(id: UUID(), order: order, kind: s.values.kind.rawValue,
                                                     weightKg: s.values.weightKg, reps: s.values.reps,
                                                     incline: s.values.incline, speed: s.values.speed,
                                                     minutes: s.values.minutes, seconds: nil, isCompleted: s.values.isCompleted,
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
                      note: $0.note, isArchived: $0.isArchived, restSeconds: $0.restSeconds,
                      guideCore: $0.guideCore, guideCues: $0.guideCues, guideMistakes: $0.guideMistakes,
                      guideRegression: $0.guideRegression, guideProgression: $0.guideProgression, myNotes: $0.myNotes,
                      meRotation: $0.meRotation, deRotation: $0.deRotation)
            },
            sessions: sessions.map { s in
                .init(id: s.id, startedAt: s.startedAt, endedAt: s.endedAt, title: s.title, note: s.note, hasTime: s.hasTime,
                      region: s.regionRaw, modeID: s.modeID, dayType: s.dayTypeRaw,
                      items: s.orderedItems.compactMap { item in
                          guard let exerciseId = item.exercise?.id else { return nil }
                          return .init(id: item.id, exerciseId: exerciseId, order: item.order, note: item.note,
                                       role: item.role.rawValue,
                                       sets: item.orderedSets.map { r in
                                           .init(id: r.id, order: r.order, kind: r.kindRaw, weightKg: r.weightKg, reps: r.reps,
                                                 incline: r.incline, speed: r.speed, minutes: r.minutes, seconds: r.seconds,
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
            let exercise = makeExercise(r)
            context.insert(exercise)
            byID[r.id] = exercise
        }
        for s in file.sessions {
            let exercises = s.items.compactMap { byID[$0.exerciseId] }
            let region = s.region.flatMap(Region.init(rawValue:)) ?? Region.infer(exercises.map(\.category))
            let session = WorkoutSession(id: s.id, startedAt: s.startedAt, endedAt: s.endedAt, title: s.title,
                                         note: s.note, hasTime: s.hasTime, region: region, modeID: s.modeID,
                                         dayType: s.dayType.flatMap(DayType.init(rawValue:)))
            context.insert(session)
            for i in s.items {
                guard let exercise = byID[i.exerciseId] else { continue }
                let item = SessionExercise(id: i.id, session: session, exercise: exercise, order: i.order, note: i.note,
                                           role: i.role.flatMap(Role.init(rawValue:)) ?? exercise.defaultRole)
                context.insert(item)
                for r in i.sets {
                    context.insert(SetRecord(
                        id: r.id, sessionExercise: item, order: r.order, kind: SetKind(rawValue: r.kind) ?? .normal,
                        weightKg: r.weightKg, reps: r.reps, incline: r.incline, speed: r.speed, minutes: r.minutes,
                        seconds: r.seconds, isCompleted: r.isCompleted, completedAt: r.completedAt, healthWorkoutID: r.healthWorkoutID
                    ))
                }
            }
        }
        for r in file.bodyWeights {
            context.insert(BodyWeight(date: r.date, kg: r.kg))
        }
        try context.save()
    }

    static func makeExercise(_ r: BackupFile.ExerciseRecord) -> Exercise {
        let exercise = Exercise(
            id: r.id,
            name: r.name,
            category: ExerciseCategory(stored: r.category) ?? .accessory,
            tags: r.tags.compactMap(ExerciseTag.init(rawValue:)),
            aliases: r.aliases,
            englishName: r.englishName,
            equipment: Equipment(rawValue: r.equipment) ?? .other,
            logType: LogType(rawValue: r.logType) ?? .weight,
            note: r.note,
            isArchived: r.isArchived,
            restSeconds: r.restSeconds,
            meRotation: r.meRotation,
            deRotation: r.deRotation
        )
        exercise.guideCore = r.guideCore ?? ""
        exercise.guideCues = r.guideCues ?? []
        exercise.guideMistakes = r.guideMistakes ?? []
        exercise.guideRegression = r.guideRegression ?? ""
        exercise.guideProgression = r.guideProgression ?? ""
        exercise.myNotes = r.myNotes ?? ""
        return exercise
    }
}

enum SeedImporter {
    /// 資料庫沒有任何動作時，匯入 bundle 裡的 seed.json（v2 格式，匯入時轉成訓練）
    static func importIfNeeded(into context: ModelContext) {
        do {
            guard try context.fetchCount(FetchDescriptor<Exercise>()) == 0, let seed = try bundled() else { return }
            try BackupService.restore(seed, into: context)
        } catch {
            print("Seed import failed: \(error)")
        }
    }

    static func bundled() throws -> BackupFile? {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json") else { return nil }
        return try BackupFile.decode(Data(contentsOf: url))
    }
}

/// 之後才加進動作庫的預設動作。已經有資料的 App 不會再匯入 seed，所以啟動時從 seed.json 補進來。
/// 名稱或別名已經存在就略過；每一批只補一次，使用者之後刪掉也不會再出現。
enum LibraryAdditions {
    static let batches: [(key: String, names: [String])] = [
        ("libraryAdditions.v1", ["啞鈴上斜臥推"]),
        // 共軛訓練的動作庫 v2
        ("libraryAdditions.v2", ConjugateLibrary.additions),
    ]

    static var names: [String] { batches.flatMap(\.names) }

    static func applyIfNeeded(into context: ModelContext, defaults: UserDefaults = .standard) {
        let pending = batches.filter { !defaults.bool(forKey: $0.key) }
        guard !pending.isEmpty,
              let seed = try? SeedImporter.bundled(),
              let guides = GuideImporter.bundled()
        else { return }
        for batch in pending {
            do {
                try apply(batch.names, from: seed.exercises, guides: guides, into: context)
                defaults.set(true, forKey: batch.key)
            } catch {
                print("Library additions failed: \(error)")
            }
        }
    }

    @discardableResult
    static func apply(_ names: [String], from records: [BackupFile.ExerciseRecord],
                      guides: [String: GuideImporter.Guide], into context: ModelContext) throws -> [Exercise] {
        let existing = try context.fetch(FetchDescriptor<Exercise>())
        let ids = Set(existing.map(\.id))
        let taken = Set(existing.flatMap { [$0.name] + $0.aliases })
        let added = records
            .filter { names.contains($0.name) && !ids.contains($0.id) }
            .filter { r in ([r.name] + r.aliases).allSatisfy { !taken.contains($0) } }
            .map(BackupService.makeExercise)
        for exercise in added { context.insert(exercise) }
        GuideImporter.apply(guides, to: added)
        try context.save()
        return added
    }
}

/// 共軛訓練的動作庫 v2：各動作的標籤（主、單、爆）與 ME／DE 主項輪替表。
/// 啟動時依名稱更新一次；只改動作的設定，不動任何訓練紀錄
enum ConjugateLibrary {
    nonisolated struct Entry: Sendable {
        var name: String
        var tags: [ExerciseTag]
        /// 輪替表的順序；下肢動作屬於下肢輪替表，上肢動作屬於上肢輪替表
        var me: Int?
        var de: Int?
    }

    nonisolated static let entries: [Entry] = [
        // 下肢推
        Entry(name: "深蹲", tags: [.main], me: 1, de: 1),
        Entry(name: "前蹲舉", tags: [.main], me: 3),
        Entry(name: "後腳抬高蹲", tags: [.unilateral]),
        Entry(name: "高背槓分腿蹲", tags: [.unilateral]),
        Entry(name: "側蹲", tags: [.unilateral]),
        Entry(name: "負重原地起跳", tags: [.explosive], de: 3),
        // 下肢拉
        Entry(name: "傳統硬舉", tags: [.main], me: 2, de: 4),
        Entry(name: "六角槓硬舉", tags: [.main], me: 5),
        Entry(name: "相撲硬舉", tags: [.main], me: 6),
        Entry(name: "槓鈴早安式", tags: [.main], me: 4),
        Entry(name: "羅馬尼亞式硬舉", tags: []),
        Entry(name: "單腳 RDL", tags: [.unilateral]),
        Entry(name: "臀推", tags: []),
        Entry(name: "壺鈴擺盪", tags: [.explosive], de: 2),
        Entry(name: "單手抓舉", tags: [.unilateral, .explosive], de: 5),
        // 上肢水平推
        Entry(name: "臥推", tags: [.main], me: 1, de: 1),
        Entry(name: "上斜臥推", tags: [.main], me: 6),
        Entry(name: "地板臥推", tags: [.main], me: 3),
        Entry(name: "窄握臥推", tags: [.main], me: 4),
        Entry(name: "啞鈴臥推", tags: []),
        Entry(name: "啞鈴上斜臥推", tags: []),
        Entry(name: "地板啞鈴臥推", tags: []),
        // 上肢水平拉
        Entry(name: "爆發划船", tags: [.explosive], de: 3),
        Entry(name: "反式划船", tags: []),
        Entry(name: "坐姿 Cable 划船", tags: []),
        Entry(name: "槓鈴俯身划船", tags: []),
        Entry(name: "單手啞鈴划船", tags: [.unilateral]),
        Entry(name: "胸靠上斜椅啞鈴划船", tags: []),
        // 上肢垂直推
        Entry(name: "肩推", tags: [.main], me: 2),
        Entry(name: "坐姿槓鈴肩推", tags: [.main], me: 5),
        Entry(name: "坐姿啞鈴肩推", tags: []),
        Entry(name: "雙槓撐", tags: []),
        Entry(name: "借力推舉", tags: [.explosive], de: 2),
        // 上肢垂直拉
        Entry(name: "輔助引體向上", tags: []),
        Entry(name: "滑輪下拉", tags: []),
        // 核心
        Entry(name: "腹前推", tags: []),
        Entry(name: "地雷管抗旋轉", tags: []),
        Entry(name: "坐姿分腿壺鈴三點搬移", tags: []),
        Entry(name: "六角槓原地踏步", tags: []),
        Entry(name: "仰臥拉舉", tags: []),
        Entry(name: "單手啞鈴臥推", tags: [.unilateral]),
        Entry(name: "棒式划船", tags: []),
        Entry(name: "窄跪姿單手啞鈴肩推", tags: [.unilateral]),
        Entry(name: "單手壺鈴擺盪", tags: [.unilateral, .explosive]),
        Entry(name: "行李箱原地踏步", tags: [.unilateral]),
        // 補強
        Entry(name: "三頭肌滑輪下拉", tags: []),
        Entry(name: "二頭彎舉", tags: []),
        Entry(name: "面拉", tags: []),
        Entry(name: "YTW", tags: []),
        Entry(name: "仰臥啞鈴三頭伸展", tags: []),
        Entry(name: "JM 推", tags: []),
        // 有氧
        Entry(name: "跑步機", tags: []),
    ]

    /// 新增的動作（從 seed.json 補進來）
    nonisolated static let additions = ["槓鈴早安式", "窄握臥推", "槓鈴俯身划船", "單手啞鈴划船", "胸靠上斜椅啞鈴划船",
                            "借力推舉", "行李箱原地踏步", "仰臥啞鈴三頭伸展", "JM 推"]

    /// 輔助引體向上的新紀錄把輔助量記成負重（輔助 20 kg 記 −20 kg）；舊紀錄不轉換
    static let negativeLoadExercise = "輔助引體向上"
    static let negativeLoadNote = "輔助量記成負重：輔助 20 kg 記 −20 kg（鍵盤列的 ± 切換正負）。2026/10/26 以前的紀錄是輔助量，沒有轉換。"
    /// CHANGE_07 把舊紀錄也轉成負數之後的備註
    static let negativeLoadNoteConverted = "輔助量記成負重：輔助 20 kg 記 −20 kg（鍵盤列的 ± 切換正負）。2026/10/26 以前的輔助量紀錄已轉成負數。"

    private static let appliedKey = "conjugateLibrary.v1"

    static func applyIfNeeded(into context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: appliedKey),
              let exercises = try? context.fetch(FetchDescriptor<Exercise>()),
              !exercises.isEmpty
        else { return }
        apply(to: exercises)
        try? context.save()
        defaults.set(true, forKey: appliedKey)
    }

    /// 清單裡的動作設成清單的標籤和輪替順序；其他動作不在輪替表裡
    static func apply(to exercises: [Exercise]) {
        let byName = Dictionary(entries.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        for exercise in exercises {
            guard let entry = byName[exercise.name] else {
                exercise.meRotation = nil
                exercise.deRotation = nil
                continue
            }
            exercise.tags = entry.tags
            exercise.meRotation = entry.me
            exercise.deRotation = entry.de
            if exercise.name == negativeLoadExercise, exercise.logType == .assisted {
                exercise.logType = .weight
                if exercise.note.isEmpty { exercise.note = negativeLoadNote }
            }
        }
    }
}

enum GuideImporter {
    nonisolated struct Guide: Decodable {
        var core: String
        var cues: [String]
        var mistakes: [String]
        var regression: String
        var progression: String
    }

    private static let importedKey = "guidesImported.v2"

    /// 第一次啟動時把 bundle 的 ExerciseGuides.json 填進還沒有說明的動作（依名稱或別名對應）。
    /// 之後的編輯存在資料庫，不會被覆蓋。
    static func importIfNeeded(into context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: importedKey),
              let guides = bundled(),
              let exercises = try? context.fetch(FetchDescriptor<Exercise>()),
              !exercises.isEmpty
        else { return }
        apply(guides, to: exercises)
        try? context.save()
        defaults.set(true, forKey: importedKey)
    }

    static func bundled() -> [String: Guide]? {
        guard let url = Bundle.main.url(forResource: "ExerciseGuides", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode([String: Guide].self, from: data)
    }

    static func apply(_ guides: [String: Guide], to exercises: [Exercise]) {
        for exercise in exercises where exercise.guideCore.isEmpty && exercise.guideCues.isEmpty {
            guard let guide = ([exercise.name] + exercise.aliases).lazy.compactMap({ guides[$0] }).first else { continue }
            exercise.guideCore = guide.core
            exercise.guideCues = guide.cues
            exercise.guideMistakes = guide.mistakes
            exercise.guideRegression = guide.regression
            exercise.guideProgression = guide.progression
        }
    }
}
