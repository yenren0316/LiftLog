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
                              equipment: .bodyweight, logType: .assisted, note: "握距中等", restSeconds: 120)
        let treadmill = Exercise(name: "跑步機", category: .cardio, equipment: .other, logType: .cardio, isArchived: true)
        source.insert(pullUp)
        source.insert(treadmill)
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let session = WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(3600), title: "拉＋有氧", note: "累",
                                     region: .upper, modeID: "upper1")
        source.insert(session)
        let pullItem = SessionExercise(session: session, exercise: pullUp, order: 0, note: "一邊")
        let runItem = SessionExercise(session: session, exercise: treadmill, order: 1, role: .accessory)
        source.insert(pullItem)
        source.insert(runItem)
        source.insert(SetRecord(sessionExercise: pullItem, order: 0, kind: .warmup, weightKg: 20, reps: 5, isCompleted: true, completedAt: start))
        source.insert(SetRecord(sessionExercise: pullItem, order: 1, kind: .max, weightKg: 13.75, reps: 5, isCompleted: true, completedAt: start))
        let watch = UUID()
        source.insert(SetRecord(sessionExercise: runItem, order: 0, incline: 14.5, speed: 4.2, minutes: 30,
                                isCompleted: true, completedAt: start, healthWorkoutID: watch))
        source.insert(BodyWeight(date: start, kg: 70.8))
        try source.save()

        let data = try BackupService.makeBackup(from: source).encode()
        let target = try makeContext()
        target.insert(Exercise(name: "會被取代", category: .accessory, equipment: .barbell))
        try BackupService.restore(BackupFile.decode(data), into: target)

        let exercises = try target.fetch(FetchDescriptor<Exercise>())
        #expect(Set(exercises.map(\.name)) == ["跑步機", "輔助引體向上"])
        let restoredPullUp = try #require(exercises.first { $0.name == "輔助引體向上" })
        #expect(restoredPullUp.id == pullUp.id)
        #expect(restoredPullUp.restSeconds == 120)
        #expect(restoredPullUp.tags == [.unilateral] && restoredPullUp.aliases == ["引體向上"])

        let restoredSession = try #require(try target.fetch(FetchDescriptor<WorkoutSession>()).first)
        #expect(restoredSession.title == "拉＋有氧" && restoredSession.note == "累")
        #expect(restoredSession.endedAt == start.addingTimeInterval(3600) && restoredSession.hasTime)
        #expect(restoredSession.orderedItems.map { $0.exercise?.name } == ["輔助引體向上", "跑步機"])
        let pullSets = restoredSession.orderedItems[0].orderedSets
        #expect(pullSets.map(\.kind) == [.warmup, .max])
        #expect(pullSets[1].weightKg == 13.75 && pullSets[1].reps == 5)
        #expect(restoredSession.orderedItems[0].note == "一邊")
        #expect(restoredSession.region == .upper && restoredSession.modeID == "upper1")
        #expect(restoredSession.orderedItems.map(\.roleRaw) == ["pull", "accessory"])
        #expect(restoredSession.orderedItems[1].orderedSets[0].healthWorkoutID == watch)
        #expect(try target.fetch(FetchDescriptor<BodyWeight>()).map(\.kg) == [70.8])
    }

    @Test func readsVersion2Backups() throws {
        let id = UUID()
        let json = """
        {"version":2,
         "exercises":[{"id":"\(id.uuidString)","name":"臥推","category":"horizontalPush","tags":[],"aliases":["槓鈴臥推"],
                       "englishName":"","equipment":"barbell","logType":"weight","note":"","isArchived":false}],
         "entries":[{"date":"2026-06-24T12:00:00+08:00","exerciseId":"\(id.uuidString)","weightKg":42.6,"sets":5,"reps":5,
                     "isMax":false,"note":""},
                    {"date":"2026-07-24T12:00:00+08:00","exerciseId":"\(id.uuidString)","weightKg":58.4,
                     "isMax":true,"note":""}],
         "bodyWeights":[]}
        """
        let file = try BackupFile.decode(Data(json.utf8))
        #expect(file.version == BackupFile.currentVersion)
        #expect(file.sessions.count == 2)
        #expect(file.sessions.allSatisfy { !$0.hasTime && $0.endedAt == $0.startedAt })
        #expect(file.sessions[0].title == "臥推")
        #expect(file.sessions[0].items[0].sets.count == 5)
        #expect(file.sessions[1].items[0].sets.map(\.kind) == ["max"])
    }

    @Test func version3BackupsInferRoleAndRegion() throws {
        let squat = UUID(), lunge = UUID(), row = UUID(), plank = UUID()
        func ex(_ id: UUID, _ name: String, _ category: String, _ tags: String = "") -> String {
            """
            {"id":"\(id.uuidString)","name":"\(name)","category":"\(category)","tags":[\(tags)],"aliases":[],
             "englishName":"","equipment":"barbell","logType":"weight","note":"","isArchived":false}
            """
        }
        func item(_ id: UUID, _ order: Int) -> String {
            """
            {"id":"\(UUID().uuidString)","exerciseId":"\(id.uuidString)","order":\(order),"note":"","sets":[]}
            """
        }
        func session(_ items: String) -> String {
            """
            {"id":"\(UUID().uuidString)","startedAt":"2026-06-24T12:00:00+08:00","endedAt":"2026-06-24T12:00:00+08:00",
             "title":"","note":"","hasTime":false,"items":[\(items)]}
            """
        }
        let json = """
        {"version":3,
         "exercises":[\(ex(squat, "深蹲", "kneeDominant")),\(ex(lunge, "側蹲", "kneeDominant", "\"unilateral\"")),
                      \(ex(row, "坐姿 Cable 划船", "horizontalPull")),\(ex(plank, "六角槓原地踏步", "loadedCarry"))],
         "sessions":[\(session(item(squat, 0) + "," + item(lunge, 1) + "," + item(plank, 2))),
                     \(session(item(squat, 0) + "," + item(row, 1))),
                     \(session(item(plank, 0)))],
         "bodyWeights":[]}
        """
        let context = try makeContext()
        try BackupService.restore(BackupFile.decode(Data(json.utf8)), into: context)
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>()).sorted { $0.items.count > $1.items.count }
        #expect(sessions.map(\.region) == [.lower, .full, .unspecified])
        // 沒有 role 時依分類判定（CHANGE_06：下肢一律下肢輔助）
        #expect(sessions[0].orderedItems.map(\.roleRaw) == ["lowerAssist", "lowerAssist", "core"])
        #expect(sessions[1].orderedItems.map(\.roleRaw) == ["lowerAssist", "pull"])
        #expect(sessions.allSatisfy { $0.modeID == nil && $0.dayType == nil })
    }

    @Test func bundledSeedConvertsToSessions() throws {
        let url = try #require(Bundle.main.url(forResource: "seed", withExtension: "json"))
        let file = try BackupFile.decode(Data(contentsOf: url))
        let ids = Set(file.exercises.map(\.id))
        #expect(file.exercises.count == 68)
        #expect(file.exercises.filter(\.isArchived).count == 16)
        #expect(file.sessions.count > 200)
        #expect(file.sessions.allSatisfy { s in s.items.allSatisfy { ids.contains($0.exerciseId) && !$0.sets.isEmpty } })
        #expect(file.sessions.allSatisfy { s in s.items.allSatisfy { $0.sets.allSatisfy(\.isCompleted) } })
        // 同一次訓練同一個動作只出現一次
        #expect(file.sessions.allSatisfy { s in Set(s.items.map(\.exerciseId)).count == s.items.count })
    }

    @Test func seedTreadmillSetsHaveAllThreeFields() throws {
        let url = try #require(Bundle.main.url(forResource: "seed", withExtension: "json"))
        let file = try BackupFile.decode(Data(contentsOf: url))
        let treadmill = try #require(file.exercises.first { $0.name == "跑步機" })
        let sets = file.sessions.flatMap { $0.items.filter { $0.exerciseId == treadmill.id }.flatMap(\.sets) }
        #expect(sets.count > 50)
        #expect(sets.allSatisfy { $0.incline != nil && $0.speed != nil && $0.minutes != nil && $0.weightKg == nil })
        #expect(sets.contains { $0.incline == 13 && $0.speed == 4 && $0.minutes == 30 })
    }

    // MARK: 設定（CHANGE_11 §8）

    private func makeDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "BackupTests.\(UUID().uuidString)"))
    }

    private func makeFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "BackupTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 備份包含所有設定值；還原時一併還原
    @Test func settingsRoundTrip() throws {
        let source = try makeDefaults()
        source.set(4, forKey: WeeklyGoal.goalKey)
        source.set(true, forKey: WeeklyGoal.cardioOnlyCountsKey)
        source.set(WeightUnit.lbs.rawValue, forKey: WeightUnit.storageKey)
        source.set(5.0, forKey: RoundingSteps.barbellKgKey)
        source.set(2.0, forKey: RoundingSteps.otherKgKey)
        source.set(10.0, forKey: RoundingSteps.barbellLbsKey)
        source.set(5.0, forKey: RoundingSteps.otherLbsKey)
        source.set(false, forKey: WorkoutService.autoRestKey)
        source.set(false, forKey: LiveActivityController.enabledKey)
        source.set(AppTheme.graphiteBlue.rawValue, forKey: AppTheme.storageKey)
        let context = try makeContext()
        let data = try BackupService.makeBackup(from: context, migrations: DataMigrations.all.map(\.id),
                                                settings: .read(from: source)).encode()
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["version"] as? Int == 7)
        #expect((json["settings"] as? [String: Any])?["weeklyGoal"] as? Int == 4)

        // 還原到另一份設定（全部是預設值）
        let target = try makeDefaults()
        try DataMigrations.restore(BackupFile.decode(data), into: makeContext(), defaults: target, backupFolder: makeFolder())
        #expect(SettingsSnapshot.read(from: target) == SettingsSnapshot.read(from: source))
        #expect(target.integer(forKey: WeeklyGoal.goalKey) == 4)
        #expect(target.bool(forKey: WeeklyGoal.cardioOnlyCountsKey))
        #expect(target.string(forKey: WeightUnit.storageKey) == "lbs")
        #expect(target.double(forKey: RoundingSteps.barbellKgKey) == 5)
        #expect(target.object(forKey: WorkoutService.autoRestKey) as? Bool == false)
        #expect(target.object(forKey: LiveActivityController.enabledKey) as? Bool == false)
        #expect(target.string(forKey: AppTheme.storageKey) == AppTheme.graphiteBlue.rawValue)
    }

    /// 沒設定過每週目標（用自動的值）：備份裡是 nil，還原時拿掉目前的設定，回到自動
    @Test func automaticWeeklyGoalRoundTrips() throws {
        let source = try makeDefaults()
        let data = try BackupService.makeBackup(from: makeContext(), migrations: DataMigrations.all.map(\.id),
                                                settings: .read(from: source)).encode()
        let target = try makeDefaults()
        target.set(6, forKey: WeeklyGoal.goalKey)
        try DataMigrations.restore(BackupFile.decode(data), into: makeContext(), defaults: target, backupFolder: makeFolder())
        #expect(target.object(forKey: WeeklyGoal.goalKey) == nil)
    }

    /// 舊格式（version 6，沒有 settings）照樣能匯入，設定維持目前的值
    @Test func oldBackupWithoutSettingsKeepsCurrentSettings() throws {
        let json = """
        {"version":6,"migrations":["assistToNegative","autoTitles"],
         "exercises":[{"id":"\(UUID().uuidString)","name":"深蹲","category":"kneeDominant","tags":["main"],"aliases":[],
                       "englishName":"","equipment":"barbell","logType":"weight","note":"","isArchived":false}],
         "sessions":[],"bodyWeights":[]}
        """
        let file = try BackupFile.decode(Data(json.utf8))
        #expect(file.settings == nil)
        let target = try makeDefaults()
        target.set(5, forKey: WeeklyGoal.goalKey)
        target.set(WeightUnit.lbs.rawValue, forKey: WeightUnit.storageKey)
        target.set(AppTheme.graphitePink.rawValue, forKey: AppTheme.storageKey)
        let before = SettingsSnapshot.read(from: target)
        let context = try makeContext()
        try DataMigrations.restore(file, into: context, defaults: target, backupFolder: makeFolder())
        #expect(SettingsSnapshot.read(from: target) == before)
        #expect(try context.fetch(FetchDescriptor<Exercise>()).map(\.name) == ["深蹲"])
    }
}
