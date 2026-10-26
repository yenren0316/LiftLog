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

        let ran = DataMigrations.runIfNeeded(context: context, defaults: defaults, backupFolder: folder, now: date(10, 28))
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
        #expect(DataMigrations.runIfNeeded(context: context, defaults: defaults, backupFolder: folder).isEmpty)
        #expect(AutoBackup.list(folder: folder).count == 1 && weights(pullUp) == [-19, -19, -16.25, -15, 5])
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
}
