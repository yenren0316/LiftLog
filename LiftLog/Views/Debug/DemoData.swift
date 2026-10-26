#if DEBUG
import Foundation
import SwiftData

/// 開發用的資料（CHANGE_07 截圖驗證）：
/// - 啟動參數 -emptyData YES：清空所有資料，而且不匯入 seed，檢查空狀態
/// - 啟動參數 -demoData YES：在 seed 之外加幾筆有時間、日型、角色和備註的示範訓練（其中一次是全身），以及近期的體重（只加一次）
enum DemoData {
    static let addedKey = "debug.demoData.v2"

    /// 有 -emptyData 時清空，回傳 true 表示這次啟動不要匯入 seed
    static func wipeIfRequested(in context: ModelContext, defaults: UserDefaults = .standard) -> Bool {
        guard defaults.bool(forKey: "emptyData") else { return false }
        ((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []).forEach(context.delete)
        ((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).forEach(context.delete)
        ((try? context.fetch(FetchDescriptor<BodyWeight>())) ?? []).forEach(context.delete)
        try? context.save()
        defaults.removeObject(forKey: addedKey)
        return true
    }

    private enum Value {
        case lift(Double?, Int, SetKind = .normal)
        case cardio(minutes: Double, speed: Double, incline: Double)
    }

    private struct Item {
        var name: String
        var role: Role
        var sets: [Value]
    }

    private struct Plan {
        var daysAgo: Int
        var hour: Int, minute: Int, minutes: Int
        var dayType: DayType?
        var note = ""
        var items: [Item]
    }

    private static func lifts(_ kg: Double?, _ reps: Int, times: Int) -> [Value] {
        Array(repeating: .lift(kg, reps), count: times)
    }

    private static let plans: [Plan] = [
        Plan(daysAgo: 1, hour: 18, minute: 30, minutes: 75, dayType: .meUpper, note: "肩膀狀況不錯，最後一組三下很穩", items: [
            Item(name: "臥推", role: .maxEffort,
                 sets: [.lift(40, 5, .warmup), .lift(60, 3, .warmup), .lift(80, 3), .lift(85, 3), .lift(87.5, 2)]),
            Item(name: "滑輪下拉", role: .pull, sets: lifts(45, 10, times: 3)),
            Item(name: "坐姿啞鈴肩推", role: .push, sets: lifts(16, 10, times: 3)),
            Item(name: "面拉", role: .accessory, sets: lifts(15, 15, times: 3)),
            Item(name: "跑步機", role: .cardio, sets: [.cardio(minutes: 15, speed: 6, incline: 8)]),
        ]),
        Plan(daysAgo: 2, hour: 19, minute: 30, minutes: 30, dayType: nil, items: [
            Item(name: "跑步機", role: .cardio, sets: [.cardio(minutes: 30, speed: 6.5, incline: 6)]),
        ]),
        Plan(daysAgo: 3, hour: 7, minute: 10, minutes: 55, dayType: .deLower, items: [
            Item(name: "深蹲", role: .dynamicEffort, sets: lifts(60, 2, times: 8)),
            Item(name: "單腳 RDL", role: .lowerAssist, sets: lifts(20, 8, times: 3)),
            Item(name: "腹肌滾輪", role: .core, sets: lifts(nil, 10, times: 3)),
        ]),
        Plan(daysAgo: 5, hour: 19, minute: 0, minutes: 70, dayType: .meLower, note: "握力最後有點跟不上", items: [
            Item(name: "傳統硬舉", role: .maxEffort, sets: [.lift(60, 5, .warmup), .lift(100, 3), .lift(120, 2), .lift(135, 1)]),
            Item(name: "後腳抬高蹲", role: .lowerAssist, sets: lifts(16, 8, times: 3)),
            Item(name: "地雷管抗旋轉", role: .core, sets: lifts(10, 10, times: 3)),
            Item(name: "跑步機", role: .cardio, sets: [.cardio(minutes: 20, speed: 6, incline: 10)]),
        ]),
        // 全身（CHANGE_08：日曆的全身格子和訓練頻率的斜紋）
        Plan(daysAgo: 10, hour: 18, minute: 0, minutes: 50, dayType: nil, items: [
            Item(name: "深蹲", role: .lowerAssist, sets: lifts(70, 8, times: 3)),
            Item(name: "臥推", role: .push, sets: lifts(55, 8, times: 3)),
        ]),
        Plan(daysAgo: 8, hour: 10, minute: 0, minutes: 60, dayType: .deUpper, items: [
            Item(name: "臥推", role: .dynamicEffort, sets: lifts(50, 3, times: 8)),
            Item(name: "單手啞鈴划船", role: .pull, sets: lifts(26, 10, times: 3)),
            Item(name: "三頭肌滑輪下拉", role: .accessory, sets: lifts(25, 12, times: 3)),
        ]),
    ]

    /// 體重：（幾天前, kg）
    private static let weights: [(Int, Double)] = [(36, 70.2), (21, 69.9), (14, 69.7), (7, 69.5), (1, 69.3)]

    static func addIfRequested(in context: ModelContext, defaults: UserDefaults = .standard, now: Date = .now) {
        guard defaults.bool(forKey: "demoData"), !defaults.bool(forKey: addedKey) else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let byName = Dictionary(exercises.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        for plan in plans {
            guard let day = calendar.date(byAdding: .day, value: -plan.daysAgo, to: today),
                  let start = calendar.date(bySettingHour: plan.hour, minute: plan.minute, second: 0, of: day)
            else { continue }
            let end = start.addingTimeInterval(TimeInterval(plan.minutes * 60))
            let session = WorkoutSession(startedAt: start, endedAt: end, note: plan.note, dayType: plan.dayType)
            context.insert(session)
            let total = plan.items.reduce(0) { $0 + $1.sets.count }
            var done = 0
            for (order, item) in plan.items.enumerated() {
                guard let exercise = byName[item.name] else { continue }
                let entry = SessionExercise(session: session, exercise: exercise, order: order, role: item.role)
                context.insert(entry)
                for (index, value) in item.sets.enumerated() {
                    done += 1
                    let completedAt = start.addingTimeInterval(TimeInterval(plan.minutes * 60) * Double(done) / Double(total + 1))
                    let set: SetRecord
                    switch value {
                    case .lift(let kg, let reps, let kind):
                        set = SetRecord(sessionExercise: entry, order: index, kind: kind, weightKg: kg, reps: reps,
                                        isCompleted: true, completedAt: completedAt)
                    case .cardio(let minutes, let speed, let incline):
                        set = SetRecord(sessionExercise: entry, order: index, incline: incline, speed: speed, minutes: minutes,
                                        isCompleted: true, completedAt: completedAt)
                    }
                    context.insert(set)
                }
            }
            session.refreshAutomaticTitle()
        }
        for (daysAgo, kg) in weights {
            if let day = calendar.date(byAdding: .day, value: -daysAgo, to: today),
               let time = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: day) {
                BodyWeightLog.save(kg: kg, on: time, in: context, calendar: calendar)
            }
        }
        try? context.save()
        defaults.set(true, forKey: addedKey)
    }
}
#endif
