import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_07 A-1 與執行規則 6：輔助重量轉負數、遷移前自動備份
@MainActor
struct DataMigrationsTests {
    private func date(_ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: 19))!
    }

    private func tempFolder() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "AutoBackups-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    @Test func assistConversionFilter() {
        // T1：只轉負重制的動作、正數、而且在 CHANGE_06 上線那天之前的組
        let cutoff = AssistToNegative.cutoff
        let before = date(10, 20), after = date(10, 27)
        func convert(_ kg: Double?, _ day: Date, _ logType: LogType = .weight, _ equipment: Equipment = .bodyweight) -> Bool {
            AssistToNegative.shouldConvert(weightKg: kg, sessionDate: day, logType: logType, equipment: equipment, cutoff: cutoff)
        }
        #expect(convert(19, before))
        #expect(!convert(19, after))          // 之後的正數可能是真的加重
        #expect(!convert(-15, before))        // 已經是負數
        #expect(!convert(0, before))          // 0 = 自重
        #expect(!convert(nil, before))
        #expect(!convert(19, before, .assisted))           // 仍是輔助型（雙槓撐）不動
        #expect(!convert(60, before, .weight, .barbell))   // 一般的重量動作不動
        #expect(cutoff == Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 26)))
    }

    @Test func migrationBacksUpFirstThenConvertsOnce() throws {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let defaults = try #require(UserDefaults(suiteName: "DataMigrationsTests.\(UUID().uuidString)"))
        let folder = tempFolder()
        let pullUp = Exercise(name: "輔助引體向上", category: .verticalPull, equipment: .bodyweight, logType: .weight,
                              note: ConjugateLibrary.negativeLoadNote)
        let dips = Exercise(name: "雙槓撐", category: .verticalPush, equipment: .bodyweight, logType: .assisted)
        [pullUp, dips].forEach(context.insert)
        func record(_ exercise: Exercise, _ day: Date, _ weights: [Double]) {
            let session = WorkoutSession(startedAt: day, endedAt: day)
            context.insert(session)
            let item = SessionExercise(session: session, exercise: exercise, order: 0)
            context.insert(item)
            for (i, kg) in weights.enumerated() {
                context.insert(SetRecord(sessionExercise: item, order: i, weightKg: kg, reps: 5, isCompleted: true, completedAt: day))
            }
        }
        record(pullUp, date(9, 1), [19, 19, 16.25])
        record(pullUp, date(10, 27), [-15, 5])
        record(dips, date(9, 1), [12])
        try context.save()

        let assistOnly = DataMigrations.all.filter { $0.id == AssistToNegative.id }
        let ran = DataMigrations.runIfNeeded(context: context, migrations: assistOnly, defaults: defaults,
                                             backupFolder: folder, now: date(10, 28))
        #expect(ran == [AssistToNegative.id])
        // 遷移前的備份：檔名有日期和遷移名稱，內容還是轉換前的正數
        let backups = AutoBackup.list(folder: folder)
        #expect(backups.count == 1 && backups[0].migration == AssistToNegative.id)
        #expect(backups[0].url.lastPathComponent == "auto-2026-10-28-1900-assistToNegative.json")
        let saved = try BackupFile.decode(Data(contentsOf: backups[0].url))
        #expect(saved.sessions.flatMap { $0.items.flatMap { $0.sets.compactMap(\.weightKg) } }.sorted() == [-15, 5, 12, 16.25, 19, 19])
        // 轉換後
        let weights = { (e: Exercise) in e.sessionItems.flatMap(\.sets).compactMap(\.weightKg).sorted() }
        #expect(weights(pullUp) == [-19, -19, -16.25, -15, 5])
        #expect(weights(dips) == [12])
        #expect(pullUp.note == ConjugateLibrary.negativeLoadNoteConverted)
        // 只執行一次：再跑不會再備份、不會轉回正數
        #expect(DataMigrations.runIfNeeded(context: context, migrations: assistOnly, defaults: defaults, backupFolder: folder).isEmpty)
        #expect(AutoBackup.list(folder: folder).count == 1 && weights(pullUp) == [-19, -19, -16.25, -15, 5])
        // 名稱遷移也一樣先備份：兩個遷移各一份備份
        #expect(DataMigrations.runIfNeeded(context: context, defaults: defaults, backupFolder: folder, now: date(10, 29))
                == [AutoTitles.id])
        #expect(AutoBackup.list(folder: folder).map(\.migration) == [AutoTitles.id, AssistToNegative.id])
    }

    @Test func nothingToMigrateMeansNoBackup() throws {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let defaults = try #require(UserDefaults(suiteName: "DataMigrationsTests.\(UUID().uuidString)"))
        let folder = tempFolder()
        context.insert(Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell))
        #expect(DataMigrations.runIfNeeded(context: context, defaults: defaults, backupFolder: folder).isEmpty)
        #expect(AutoBackup.list(folder: folder).isEmpty)
        #expect(defaults.bool(forKey: DataMigrations.flagKey(AssistToNegative.id)))
    }

    /// 執行規則 7 的共用資料：輔助引體向上 9/1 一組 +19（遷移前的輔助量）、名稱是舊的自動格式
    private struct ImportFixture {
        var context: ModelContext
        var defaults: UserDefaults
        var folder: URL
        var session: WorkoutSession
    }

    private func makeImportFixture() throws -> ImportFixture {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let defaults = try #require(UserDefaults(suiteName: "DataMigrationsTests.\(UUID().uuidString)"))
        let pullUp = Exercise(name: "輔助引體向上", category: .verticalPull, equipment: .bodyweight, logType: .weight,
                              note: ConjugateLibrary.negativeLoadNote)
        context.insert(pullUp)
        let session = WorkoutSession(startedAt: date(9, 1), endedAt: date(9, 1), title: "輔助引體向上")
        context.insert(session)
        let item = SessionExercise(session: session, exercise: pullUp, order: 0, role: .pull)
        context.insert(item)
        context.insert(SetRecord(sessionExercise: item, order: 0, weightKg: 19, reps: 5, isCompleted: true, completedAt: date(9, 1)))
        try context.save()
        return ImportFixture(context: context, defaults: defaults, folder: tempFolder(), session: session)
    }

    private func weights(_ context: ModelContext) throws -> [Double] {
        try context.fetch(FetchDescriptor<SetRecord>()).compactMap(\.weightKg)
    }

    private func titles(_ context: ModelContext) throws -> [String] {
        try context.fetch(FetchDescriptor<WorkoutSession>()).map(\.title)
    }

    /// 規則 7：沒有 migrations 欄位的舊檔（CHANGE_07 之前匯出的）視為一個遷移都沒套用；
    /// 這台已經跑過遷移（旗標都是 true）也要對匯入的資料再轉換一次，而且一樣先自動備份
    @Test func importingABackupWithoutTheFieldAppliesEveryMigration() throws {
        let f = try makeImportFixture()
        DataMigrations.all.forEach { f.defaults.set(true, forKey: DataMigrations.flagKey($0.id)) }
        var file = try BackupService.makeBackup(from: f.context, migrations: [])
        file.migrations = nil
        file.version = 5
        let decoded = try BackupFile.decode(file.encode())
        #expect(decoded.migrations == nil)

        let ran = try DataMigrations.restore(decoded, into: f.context, defaults: f.defaults, backupFolder: f.folder, now: date(10, 28))
        #expect(ran == [AssistToNegative.id, AutoTitles.id])
        #expect(try weights(f.context) == [-19])
        #expect(try titles(f.context) == ["上肢訓練"])
        #expect(AutoBackup.list(folder: f.folder).map(\.migration) == [AutoTitles.id, AssistToNegative.id])
        #expect(DataMigrations.all.allSatisfy { f.defaults.bool(forKey: DataMigrations.flagKey($0.id)) })
    }

    /// 備份裡已經標記套用過的遷移不再跑（也不備份），沒標記的才跑
    @Test func importingSkipsMigrationsTheBackupAlreadyHas() throws {
        let f = try makeImportFixture()
        let all = try BackupService.makeBackup(from: f.context, migrations: DataMigrations.all.map(\.id))
        #expect(try DataMigrations.restore(all, into: f.context, defaults: f.defaults, backupFolder: f.folder).isEmpty)
        #expect(try weights(f.context) == [19])
        #expect(AutoBackup.list(folder: f.folder).isEmpty)

        // 只套用過輔助重量：名稱還要轉換，輔助重量不再動
        let assistOnly = try BackupService.makeBackup(from: f.context, migrations: [AssistToNegative.id])
        let ran = try DataMigrations.restore(assistOnly, into: f.context, defaults: f.defaults, backupFolder: f.folder,
                                             now: date(10, 28))
        #expect(ran == [AutoTitles.id])
        #expect(try weights(f.context) == [19])
        #expect(try titles(f.context) == ["上肢訓練"])
    }

    /// 自動備份記下「這個遷移之前」已經套用的遷移；不管用「從 JSON 匯入」還是「還原自動備份」，還原後都會重新轉換
    @Test func autoBackupsAreReconvertedWhenRestored() throws {
        let f = try makeImportFixture()
        #expect(DataMigrations.runIfNeeded(context: f.context, defaults: f.defaults, backupFolder: f.folder, now: date(10, 28))
                == [AssistToNegative.id, AutoTitles.id])
        let backups = AutoBackup.list(folder: f.folder)
        let beforeAssist = try BackupFile.decode(Data(contentsOf: try #require(backups.first { $0.migration == AssistToNegative.id }).url))
        let beforeTitles = try BackupFile.decode(Data(contentsOf: try #require(backups.first { $0.migration == AutoTitles.id }).url))
        #expect(beforeAssist.migrations == [])
        #expect(beforeTitles.migrations == [AssistToNegative.id])
        // 一般匯出：兩個都套用過了
        #expect(try BackupService.makeBackup(from: f.context, migrations: DataMigrations.applied(defaults: f.defaults)).migrations
                == [AssistToNegative.id, AutoTitles.id])

        // 備份裡還是遷移前的數字；還原後重新轉換，結果和遷移後一樣
        #expect(beforeAssist.sessions.flatMap { $0.items.flatMap { $0.sets.compactMap(\.weightKg) } } == [19])
        let ran = try DataMigrations.restore(beforeAssist, into: f.context, defaults: f.defaults, backupFolder: f.folder,
                                             now: date(10, 29))
        #expect(ran == [AssistToNegative.id, AutoTitles.id])
        #expect(try weights(f.context) == [-19])
        #expect(try titles(f.context) == ["上肢訓練"])
    }
}
