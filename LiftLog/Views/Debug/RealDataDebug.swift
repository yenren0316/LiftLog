#if DEBUG
import Foundation
import SwiftData
import UIKit

/// 開發用（CHANGE_11 §9）：用真實的備份在模擬器上驗證統計。
/// -importBackup <路徑> 啟動時匯入備份（取代全部資料，和「從 JSON 匯入」同一條路，含補做遷移和還原設定）；
/// -fakeNow <ISO 時間> 固定 App 的「現在」（AppClock）；
/// -dumpStats <路徑> 統計快照算好後，把要和 tools/verify_real_data.py 比對的數值輸出成 JSON。
/// 備份含個人資料：路徑一律放在 tools/fixtures/ 底下（已在 .gitignore）
enum RealDataDebug {
    static func importIfRequested(into context: ModelContext) {
        guard let path = UserDefaults.standard.string(forKey: "importBackup") else { return }
        do {
            let file = try BackupFile.decode(Data(contentsOf: URL(filePath: path)))
            try DataMigrations.restore(file, into: context)
        } catch {
            print("importBackup failed: \(error)")
        }
    }

    static func dumpIfRequested(_ snapshot: StatsSnapshot, context: ModelContext) {
        guard let path = UserDefaults.standard.string(forKey: "dumpStats") else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: dump(snapshot, context: context),
                                                  options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(filePath: path))
        } catch {
            print("dumpStats failed: \(error)")
        }
    }

    /// 「本週」卡的日曆在這台裝置上的週數：螢幕寬度扣掉頁面和卡片的左右邊距（各 16 pt）
    private static var calendarWeeks: Int {
        let width = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 402
        return WeekCard.Grid.layout(width: width - 64, cell: 14).weeks
    }

    /// 和 verify_real_data.py 的 compute() 同樣的結構
    static func dump(_ snapshot: StatsSnapshot, context: ModelContext, calendar: Calendar = .current) -> [String: Any] {
        let now = snapshot.now
        let status = snapshot.trainingStatus
        func period(_ p: TrainingStatus.Period) -> [String: Any] {
            ["days": p.days, "sets": p.sets, "lower": p.lower, "upper": p.upper, "other": p.other,
             "cardioMinutes": (p.cardioMinutes * 1_000_000).rounded() / 1_000_000]
        }
        let dayFormat = Date.ISO8601FormatStyle(timeZone: calendar.timeZone).year().month().day()
        var rotation: [String: Any] = [:]
        for row in status.rotation {
            rotation[row.dayType.rawValue] = [
                "lastDate": row.lastDate.map { $0.formatted(dayFormat) } ?? NSNull(),
                "daysAgo": row.lastDate.map { TrainingStatus.daysAgo($0, now: now, calendar: calendar) } ?? NSNull(),
                "lastMain": row.lastMain ?? NSNull(),
                "nextMain": row.nextMain ?? NSNull(),
            ] as [String: Any]
        }

        // 每個「主」動作：估算 1RM（全 App 唯一的那一個）和 DE 建議重量（60%，kg、設定頁的進位）
        var mainLifts: [String: Any] = [:]
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        for exercise in exercises where exercise.tags.contains(.main) {
            let logs = exercise.logs().filter { $0.date <= now }
            let sessions = logs.map { SessionSets(sessionID: UUID(), date: $0.date, sets: $0.sets) }
            let estimate = PersonalRecords.estimated1RM(sessions, now: now, calendar: calendar)
            let advice = SlotAdvice.make(role: .dynamicEffort, exercise: PlanExercise(exercise), logs: logs, unit: .kg, now: now)
            mainLifts[exercise.name] = [
                "estimated1RM": estimate.map { ($0.record.value * 1000).rounded() / 1000 } ?? NSNull(),
                "isAllTime": estimate?.isAllTime ?? false,
                "speed60Kg": advice.speedWeightKg ?? NSNull(),
            ] as [String: Any]
        }

        // 「本週」卡（CHANGE_13 §2-2）：天數和組數、輪替膠囊、提醒；
        // 點點日曆（CHANGE_14 §1）顯示的每一天的部位（今天之後為 null），週數和這台模擬器上的卡片一樣
        var calendarDays: [String: Any] = [:]
        let weeks = WeekCard.weeks(regions: snapshot.dayRegions, now: now, count: calendarWeeks, calendar: calendar)
        for day in weeks.flatMap(\.days) {
            calendarDays[day.date.formatted(dayFormat)] = day.region?.rawValue ?? NSNull()
        }
        var capsules: [String: Any] = [:]
        for item in WeekCard.rotation(next: snapshot.nextPlan.dayType) {
            capsules[item.dayType.rawValue] = switch item.mark {
            case .done: "done"
            case .next: "next"
            case .upcoming: "upcoming"
            }
        }
        let reminder: Any = snapshot.weekReminder.map { ["category": $0.category.rawValue, "days": $0.days] as [String: Any] } ?? NSNull()

        return [
            "thisWeek": period(status.thisWeek),
            "lastWeek": period(status.lastWeek),
            "recent30": [
                "sets": Dictionary(uniqueKeysWithValues: ExerciseCategory.allCases.map { ($0.rawValue, snapshot.recentSets[$0] ?? 0) }),
                "push": snapshot.balance.push, "pull": snapshot.balance.pull,
                "unilateralSessions": snapshot.balance.unilateralSessions,
                "explosiveSessions": snapshot.balance.explosiveSessions,
            ] as [String: Any],
            "rotation": rotation,
            "nextDayType": snapshot.nextPlan.dayType.rawValue,
            "mainLifts": mainLifts,
            "weekCard": ["days": status.thisWeek.days, "sets": status.thisWeek.sets, "calendarWeeks": weeks.count,
                         "calendar": calendarDays, "rotation": capsules, "reminder": reminder] as [String: Any],
        ]
    }
}
#endif
