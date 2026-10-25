import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var name: String
    var primaryGroupRaw: String
    var secondaryGroupsRaw: [String]
    var equipmentRaw: String
    var logTypeRaw: String
    var note: String
    var isArchived: Bool

    @Relationship(deleteRule: .cascade, inverse: \WorkoutEntry.exercise)
    var entries: [WorkoutEntry] = []

    init(
        name: String,
        primaryGroup: MuscleGroup,
        secondaryGroups: [MuscleGroup] = [],
        equipment: Equipment,
        logType: LogType = .weight,
        note: String = "",
        isArchived: Bool = false
    ) {
        self.name = name
        self.primaryGroupRaw = primaryGroup.rawValue
        self.secondaryGroupsRaw = secondaryGroups.map(\.rawValue)
        self.equipmentRaw = equipment.rawValue
        self.logTypeRaw = logType.rawValue
        self.note = note
        self.isArchived = isArchived
    }

    var primaryGroup: MuscleGroup {
        get { MuscleGroup(rawValue: primaryGroupRaw) ?? .core }
        set { primaryGroupRaw = newValue.rawValue }
    }

    var secondaryGroups: [MuscleGroup] {
        get { secondaryGroupsRaw.compactMap(MuscleGroup.init(rawValue:)) }
        set { secondaryGroupsRaw = newValue.map(\.rawValue) }
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
        note: String = ""
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
