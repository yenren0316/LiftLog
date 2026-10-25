import Foundation
import SwiftData

@Model
final class Exercise {
    /// 不會變動的識別碼；改名不影響紀錄
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String
    var tagsRaw: [String]
    var aliases: [String]
    var englishName: String
    var equipmentRaw: String
    var logTypeRaw: String
    var note: String
    var isArchived: Bool

    @Relationship(deleteRule: .cascade, inverse: \WorkoutEntry.exercise)
    var entries: [WorkoutEntry] = []

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        tags: [ExerciseTag] = [],
        aliases: [String] = [],
        englishName: String = "",
        equipment: Equipment,
        logType: LogType = .weight,
        note: String = "",
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.tagsRaw = tags.map(\.rawValue)
        self.aliases = aliases
        self.englishName = englishName
        self.equipmentRaw = equipment.rawValue
        self.logTypeRaw = logType.rawValue
        self.note = note
        self.isArchived = isArchived
    }

    var category: ExerciseCategory {
        get { ExerciseCategory(rawValue: categoryRaw) ?? .accessory }
        set { categoryRaw = newValue.rawValue }
    }

    var tags: [ExerciseTag] {
        get { tagsRaw.compactMap(ExerciseTag.init(rawValue:)) }
        set { tagsRaw = ExerciseTag.allCases.filter(newValue.contains).map(\.rawValue) }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .other }
        set { equipmentRaw = newValue.rawValue }
    }

    var logType: LogType {
        get { LogType(rawValue: logTypeRaw) ?? .weight }
        set { logTypeRaw = newValue.rawValue }
    }

    /// 依日期由新到舊
    var sortedEntries: [WorkoutEntry] {
        entries.sorted { $0.date > $1.date }
    }

    var lastEntry: WorkoutEntry? {
        entries.max { $0.date < $1.date }
    }
}

@Model
final class WorkoutEntry {
    var date: Date
    var exercise: Exercise?
    var weightKg: Double?
    var sets: Int?
    var reps: Int?
    var isMax: Bool
    var incline: Double?
    var speed: Double?
    var minutes: Double?
    var note: String
    /// 從「健康」帶入時記下的 HKWorkout uuid，避免同一次運動重複帶入
    var healthWorkoutID: UUID?

    init(
        date: Date,
        exercise: Exercise?,
        weightKg: Double? = nil,
        sets: Int? = nil,
        reps: Int? = nil,
        isMax: Bool = false,
        incline: Double? = nil,
        speed: Double? = nil,
        minutes: Double? = nil,
        note: String = "",
        healthWorkoutID: UUID? = nil
    ) {
        self.date = date
        self.exercise = exercise
        self.weightKg = weightKg
        self.sets = sets
        self.reps = reps
        self.isMax = isMax
        self.incline = incline
        self.speed = speed
        self.minutes = minutes
        self.note = note
        self.healthWorkoutID = healthWorkoutID
    }
}

@Model
final class BodyWeight {
    var date: Date
    var kg: Double

    init(date: Date, kg: Double) {
        self.date = date
        self.kg = kg
    }
}

enum LiftLogStore {
    static let schema = Schema([Exercise.self, WorkoutEntry.self, BodyWeight.self])

    /// 第二版改用新的檔名，第一版的資料庫直接忽略，不做遷移
    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration("LiftLog2", schema: schema))
        } catch {
            fatalError("無法開啟資料庫：\(error)")
        }
    }
}
