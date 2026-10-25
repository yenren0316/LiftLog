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
    /// 自訂休息秒數；nil 代表依這次訓練的角色決定
    var restSeconds: Int?

    // 說明分頁（第一次啟動從 ExerciseGuides.json 匯入，之後可編輯）
    var guideCore: String = ""
    var guideCues: [String] = []
    var guideMistakes: [String] = []
    var guideRegression: String = ""
    var guideProgression: String = ""
    var myNotes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.exercise)
    var sessionItems: [SessionExercise] = []

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
        isArchived: Bool = false,
        restSeconds: Int? = nil
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
        self.restSeconds = restSeconds
    }

    var category: ExerciseCategory {
        get { ExerciseCategory(stored: categoryRaw) ?? .accessory }
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
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    /// 進行中為 nil
    var endedAt: Date?
    var title: String
    var note: String
    /// 從舊紀錄匯入的訓練沒有時間資訊，不顯示時長
    var hasTime: Bool
    /// 上半身／下半身／全身／未指定（Region）
    var regionRaw: String = "unspecified"
    /// 建立菜單時選的組合模式，例如 lower3A；不是從流程建立的為 nil
    var modeID: String?

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var items: [SessionExercise] = []

    init(id: UUID = UUID(), startedAt: Date, endedAt: Date? = nil, title: String = "", note: String = "", hasTime: Bool = true,
         region: Region = .unspecified, modeID: String? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.title = title
        self.note = note
        self.hasTime = hasTime
        self.regionRaw = region.rawValue
        self.modeID = modeID
    }

    var isActive: Bool { endedAt == nil }

    var orderedItems: [SessionExercise] {
        items.sorted { $0.order < $1.order }
    }
}

@Model
final class SessionExercise {
    @Attribute(.unique) var id: UUID
    var session: WorkoutSession?
    var exercise: Exercise?
    var order: Int
    var note: String
    /// 這次訓練裡的角色（Role）；空字串代表依動作推算
    var roleRaw: String = ""

    @Relationship(deleteRule: .cascade, inverse: \SetRecord.sessionExercise)
    var sets: [SetRecord] = []

    init(id: UUID = UUID(), session: WorkoutSession?, exercise: Exercise?, order: Int, note: String = "", role: Role? = nil) {
        self.id = id
        self.session = session
        self.exercise = exercise
        self.order = order
        self.note = note
        self.roleRaw = (role ?? exercise?.defaultRole)?.rawValue ?? ""
    }

    var orderedSets: [SetRecord] {
        sets.sorted { $0.order < $1.order }
    }

    var completedSets: [SetRecord] {
        orderedSets.filter(\.isCompleted)
    }
}

@Model
final class SetRecord {
    @Attribute(.unique) var id: UUID
    var sessionExercise: SessionExercise?
    var order: Int
    var kindRaw: String
    /// weight 型存負重，assisted 型存輔助重量
    var weightKg: Double?
    var reps: Int?
    var incline: Double?
    var speed: Double?
    var minutes: Double?
    /// timed 型的秒數
    var seconds: Double?
    var isCompleted: Bool
    var completedAt: Date?
    /// 從 Apple Watch 帶入時記下的 HKWorkout uuid，避免重複帶入
    var healthWorkoutID: UUID?

    init(
        id: UUID = UUID(),
        sessionExercise: SessionExercise?,
        order: Int,
        kind: SetKind = .normal,
        weightKg: Double? = nil,
        reps: Int? = nil,
        incline: Double? = nil,
        speed: Double? = nil,
        minutes: Double? = nil,
        seconds: Double? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        healthWorkoutID: UUID? = nil
    ) {
        self.id = id
        self.sessionExercise = sessionExercise
        self.order = order
        self.kindRaw = kind.rawValue
        self.weightKg = weightKg
        self.reps = reps
        self.incline = incline
        self.speed = speed
        self.minutes = minutes
        self.seconds = seconds
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.healthWorkoutID = healthWorkoutID
    }

    var kind: SetKind {
        get { SetKind(rawValue: kindRaw) ?? .normal }
        set { kindRaw = newValue.rawValue }
    }

    var values: SetValues {
        SetValues(kind: kind, weightKg: weightKg, reps: reps, incline: incline, speed: speed, minutes: minutes,
                  seconds: seconds, isCompleted: isCompleted, completedAt: completedAt)
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
    static let schema = Schema([Exercise.self, WorkoutSession.self, SessionExercise.self, SetRecord.self, BodyWeight.self])

    /// CHANGE_04 動作庫重整，改用新的檔名重新匯入（手機上還沒有資料），舊的資料庫直接忽略。
    /// groupContainer 固定為 .none：App 有 App Group 權限後，預設（.automatic）會改用群組容器裡的新資料庫，
    /// 資料庫要留在 App 自己的位置（小工具只讀 App Group 裡的快照）
    static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration("LiftLog4", schema: schema, groupContainer: .none))
        } catch {
            fatalError("無法開啟資料庫：\(error)")
        }
    }
}
