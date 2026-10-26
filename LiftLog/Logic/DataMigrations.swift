import Foundation
import SwiftData

/// 資料遷移前的自動備份（CHANGE_07 執行規則 6）：在 Documents/AutoBackups 寫一份完整的備份 JSON，
/// 檔名包含日期時間和遷移名稱。設定的「備份與還原」列出這些檔案，可以匯出或還原
nonisolated enum AutoBackup {
    struct Entry: Identifiable, Equatable, Sendable {
        var url: URL
        var date: Date
        /// 遷移的 id，例如 assistToNegative
        var migration: String
        var id: URL { url }

        var title: String { DataMigrations.title(of: migration) }
    }

    static var defaultFolder: URL {
        URL.documentsDirectory.appending(path: "AutoBackups", directoryHint: .isDirectory)
    }

    /// auto-2026-10-26-1310-assistToNegative.json
    static func fileName(migration: String, date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let stamp = String(format: "%04d-%02d-%02d-%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0, c.hour ?? 0, c.minute ?? 0)
        return "auto-\(stamp)-\(migration).json"
    }

    static func write(_ file: BackupFile, migration: String, date: Date = .now, folder: URL = defaultFolder) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: fileName(migration: migration, date: date))
        try file.encode().write(to: url, options: .atomic)
        return url
    }

    /// 由新到舊
    static func list(folder: URL = defaultFolder) -> [Entry] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return urls.filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("auto-") }.map { url in
            let date = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            // auto-yyyy-MM-dd-HHmm-<遷移>.json
            let parts = url.deletingPathExtension().lastPathComponent.split(separator: "-", maxSplits: 5)
            return Entry(url: url, date: date, migration: parts.count == 6 ? String(parts[5]) : "")
        }
        // 同一秒建立的檔案再依檔名（含日期時間）排
        .sorted { $0.date != $1.date ? $0.date > $1.date : $0.url.lastPathComponent > $1.url.lastPathComponent }
    }
}

/// App 啟動時各執行一次的資料遷移。每個遷移先看有沒有要改的資料，有的話先自動備份再改
enum DataMigrations {
    struct Migration {
        var id: String
        /// 實際修改資料；回傳改了幾筆
        var run: (ModelContext) throws -> Int
        /// 有沒有要改的資料（沒有就不備份，只記為已執行）
        var isNeeded: (ModelContext) throws -> Bool
    }

    static let all: [Migration] = [
        Migration(id: AssistToNegative.id,
                  run: { try AssistToNegative.apply(in: $0).count },
                  isNeeded: { try !AssistToNegative.targets(in: $0).isEmpty }),
        Migration(id: AutoTitles.id,
                  run: { try AutoTitles.apply(in: $0).regenerated },
                  isNeeded: { try AutoTitles.isNeeded(in: $0) }),
    ]

    static func flagKey(_ id: String) -> String { "migration.\(id)" }

    /// 設定的自動備份清單顯示的名稱
    nonisolated static let titles = ["assistToNegative": "輔助重量改記負數", "autoTitles": "訓練名稱改成訓練目的"]

    nonisolated static func title(of id: String) -> String {
        titles[id] ?? id
    }

    /// 回傳這次執行了哪些遷移
    @discardableResult
    static func runIfNeeded(context: ModelContext, migrations: [Migration] = all, defaults: UserDefaults = .standard,
                            backupFolder: URL = AutoBackup.defaultFolder, now: Date = .now) -> [String] {
        var ran: [String] = []
        for migration in migrations where !defaults.bool(forKey: flagKey(migration.id)) {
            do {
                if try migration.isNeeded(context) {
                    // 先備份，備份失敗就不改資料，下次啟動再試。備份裡記下已經套用的遷移（不含這一個）
                    _ = try AutoBackup.write(BackupService.makeBackup(from: context, migrations: applied(migrations: migrations, defaults: defaults)),
                                             migration: migration.id, date: now, folder: backupFolder)
                    _ = try migration.run(context)
                    try context.save()
                    ran.append(migration.id)
                }
                defaults.set(true, forKey: flagKey(migration.id))
            } catch {
                print("Migration \(migration.id) failed: \(error)")
            }
        }
        return ran
    }

    /// 目前的資料已經套用過的遷移（旗標為 true；沒有要改的資料也算），寫進備份檔
    static func applied(migrations: [Migration] = all, defaults: UserDefaults = .standard) -> [String] {
        migrations.map(\.id).filter { defaults.bool(forKey: flagKey($0)) }
    }

    /// 執行規則 7：從 JSON 匯入（包括還原自動備份）。備份產生時還沒套用的遷移，匯入後不看「只執行一次」的旗標，
    /// 對匯入的資料再跑一次（一樣先自動備份）；備份裡已經套用的遷移不再跑。回傳這次實際改了資料的遷移
    @discardableResult
    static func restore(_ file: BackupFile, into context: ModelContext, migrations: [Migration] = all,
                        defaults: UserDefaults = .standard, backupFolder: URL = AutoBackup.defaultFolder,
                        now: Date = .now) throws -> [String] {
        try BackupService.restore(file, into: context)
        let done = Set(file.migrations ?? [])
        for migration in migrations {
            if done.contains(migration.id) {
                defaults.set(true, forKey: flagKey(migration.id))
            } else {
                defaults.removeObject(forKey: flagKey(migration.id))
            }
        }
        return runIfNeeded(context: context, migrations: migrations, defaults: defaults, backupFolder: backupFolder, now: now)
    }
}

/// A-1：輔助引體向上在 CHANGE_06 改成負重制之前記的是輔助重量（正數），改成負數。
/// 雙槓撐仍是 assisted 型時不動；如果之後也改成負重制，用同樣的規則處理
enum AssistToNegative {
    static let id = "assistToNegative"
    static let exerciseNames = ["輔助引體向上", "雙槓撐"]

    /// CHANGE_06 上線那天（2026-10-26）的開始。這天以前的正數一定是舊的輔助量；
    /// 之後的正數可能是真的加重（負重引體向上），不轉換
    static var cutoff: Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 26)) ?? .distantPast
    }

    struct Change: Equatable {
        var date: Date
        var exerciseName: String
        var from: Double
        var to: Double
    }

    /// 篩選條件：動作已經是負重制（自重器材的重量型），這組的重量是正數，而且那次訓練在 cutoff 之前
    nonisolated static func shouldConvert(weightKg: Double?, sessionDate: Date, logType: LogType, equipment: Equipment,
                                          cutoff: Date) -> Bool {
        guard SetLogic.allowsNegativeLoad(logType: logType, equipment: equipment), let weightKg else { return false }
        return weightKg > 0 && sessionDate < cutoff
    }

    static func targets(in context: ModelContext, cutoff: Date = cutoff) throws -> [SetRecord] {
        let exercises = try context.fetch(FetchDescriptor<Exercise>()).filter { exerciseNames.contains($0.name) }
        return exercises.flatMap { exercise in
            exercise.sessionItems.flatMap { item -> [SetRecord] in
                guard let date = item.session?.startedAt else { return [] }
                return item.sets.filter {
                    shouldConvert(weightKg: $0.weightKg, sessionDate: date, logType: exercise.logType,
                                  equipment: exercise.equipment, cutoff: cutoff)
                }
            }
        }
    }

    @discardableResult
    static func apply(in context: ModelContext, cutoff: Date = cutoff) throws -> [Change] {
        // CHANGE_06 寫進動作備註的「舊紀錄沒有轉換」已經不成立
        for exercise in try context.fetch(FetchDescriptor<Exercise>())
        where exercise.name == ConjugateLibrary.negativeLoadExercise && exercise.note == ConjugateLibrary.negativeLoadNote {
            exercise.note = ConjugateLibrary.negativeLoadNoteConverted
        }
        return try targets(in: context, cutoff: cutoff).compactMap { set in
            guard let kg = set.weightKg else { return nil }
            set.weightKg = -kg
            return Change(date: set.sessionExercise?.session?.startedAt ?? .distantPast,
                          exerciseName: set.sessionExercise?.exercise?.name ?? "", from: kg, to: -kg)
        }
    }
}

/// C-5：訓練名稱改成訓練目的。符合舊自動格式（動作名稱用「＋」串起來、或「等 N 項」）的視為自動名稱，重新產生；
/// 其他視為自訂，保留不動並標成 isTitleCustom。已經是自訂、或已經是訓練目的的不動，所以重複執行也不會改變結果
/// （匯入的備份可能已經遷移過）
enum AutoTitles {
    static let id = "autoTitles"

    struct Result {
        var regenerated = 0
        /// 視為自訂、保留不動的訓練
        var custom: [(date: Date, title: String)] = []
    }

    static func exerciseNames(in context: ModelContext) throws -> Set<String> {
        Set(try context.fetch(FetchDescriptor<Exercise>()).flatMap { [$0.name] + $0.aliases })
    }

    /// 要處理的訓練：不是自訂名稱、名稱也還不是訓練目的
    static func pending(in context: ModelContext) throws -> [WorkoutSession] {
        try context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startedAt)]))
            .filter { !$0.isTitleCustom && $0.title != $0.automaticTitle() }
    }

    static func isNeeded(in context: ModelContext) throws -> Bool {
        try !pending(in: context).isEmpty
    }

    @discardableResult
    static func apply(in context: ModelContext) throws -> Result {
        let names = try exerciseNames(in: context)
        var result = Result()
        for session in try pending(in: context) {
            if SessionTitle.isLegacyAutomatic(session.title, exerciseNames: names) {
                session.restoreAutomaticTitle()
                result.regenerated += 1
            } else {
                session.isTitleCustom = true
                result.custom.append((session.startedAt, session.title))
            }
        }
        return result
    }
}
