import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_15 §4：新紀錄＝這次的估算 1RM 高於這次訓練開始之前最好的估算 1RM（全 App 同一個定義：Epley、1～10 下的正式組和 MAX 組）
struct NewRecordsTests {
    private func set(_ kg: Double, _ reps: Int, _ kind: SetKind = .normal, done: Bool = true) -> SetValues {
        SetValues(kind: kind, weightKg: kg, reps: reps, isCompleted: done)
    }

    private func entry(_ name: String, _ sets: [SetValues], earlier: [SetValues], logType: LogType = .weight) -> NewRecords.Entry {
        NewRecords.Entry(exerciseID: UUID(), name: name, logType: logType, sets: sets, earlier: earlier)
    }

    @Test func onlyAboveThePreviousBestCounts() throws {
        let earlier = [set(100, 3), set(90, 5)]           // 110、105
        let records = NewRecords.find([entry("深蹲", [set(100, 4)], earlier: earlier)])  // 113.3
        let record = try #require(records.first)
        #expect(records.count == 1 && record.name == "深蹲")
        #expect(abs(record.estimated1RM - 100 * (1 + 4.0 / 30)) < 1e-9 && abs(record.previous1RM - 110) < 1e-9)
        // 比較低不算
        #expect(NewRecords.find([entry("深蹲", [set(95, 3)], earlier: earlier)]).isEmpty)
    }

    @Test func equalIsNotARecord() {
        // 一樣的組
        #expect(NewRecords.find([entry("臥推", [set(100, 3)], earlier: [set(100, 3)])]).isEmpty)
        // 不同的組合、估算 1RM 一樣（90 × 10 和 100 × 6 都是 120；浮點數的誤差以內算相等）
        #expect(abs(PersonalRecords.epley(weight: 90, reps: 10) - PersonalRecords.epley(weight: 100, reps: 6)) < 1e-9)
        #expect(NewRecords.find([entry("臥推", [set(90, 10)], earlier: [set(100, 6)])]).isEmpty)
        #expect(NewRecords.find([entry("臥推", [set(100, 6)], earlier: [set(90, 10)])]).isEmpty)
    }

    @Test func noEarlierRecordIsNotARecord() {
        #expect(NewRecords.find([entry("前蹲舉", [set(80, 3)], earlier: [])]).isEmpty)
        // 以前只有不能算的組（熱身、超過 10 下、沒打勾）也一樣
        let uncountable = [set(60, 5, .warmup), set(50, 12), set(90, 3, done: false)]
        #expect(NewRecords.find([entry("前蹲舉", [set(80, 3)], earlier: uncountable)]).isEmpty)
    }

    @Test func warmupsAndMoreThanTenRepsDoNotCount() throws {
        let earlier = [set(100, 3)]  // 110
        // 這次的熱身組、超過 10 下的組、沒打勾的組都不算
        #expect(NewRecords.find([entry("深蹲", [set(120, 3, .warmup), set(90, 12), set(130, 3, done: false), set(90, 3)],
                                        earlier: earlier)]).isEmpty)
        // 以前的熱身組和超過 10 下也不算進「之前最好」：之前最好是 110，所以 105 × 3（115.5）是新紀錄
        let records = NewRecords.find([entry("深蹲", [set(105, 3)], earlier: earlier + [set(120, 3, .warmup), set(100, 15)])])
        #expect(abs(try #require(records.first).previous1RM - 110) < 1e-9)
        // MAX 組算；10 下算
        #expect(NewRecords.find([entry("深蹲", [set(110, 1, .max)], earlier: earlier)]).count == 1)
        #expect(NewRecords.find([entry("深蹲", [set(90, 10)], earlier: earlier)]).count == 1)   // 120
    }

    @Test func everyExerciseThatBeatsItsBestIsListed() {
        let records = NewRecords.find([
            entry("深蹲", [set(105, 3)], earlier: [set(100, 3)]),
            entry("單腳 RDL", [set(20, 8)], earlier: [set(22, 8)]),
            entry("臥推", [set(72.5, 3)], earlier: [set(70, 3)]),
            entry("跑步機", [SetValues(minutes: 30, isCompleted: true)], earlier: [SetValues(minutes: 20, isCompleted: true)],
                  logType: .cardio),
        ])
        #expect(records.map(\.name) == ["深蹲", "臥推"])
    }

    @Test func onlyWeightExercisesHaveAnEstimatedMax() {
        // 估算 1RM 只有重量型的動作有（和個人紀錄一樣）：輔助型的輔助重量、自重型的負重不算
        #expect(NewRecords.find([entry("雙槓撐", [set(10, 5)], earlier: [set(20, 5)], logType: .assisted)]).isEmpty)
        #expect(NewRecords.find([entry("反式划船", [set(10, 8)], earlier: [set(5, 8)], logType: .bodyweight)]).isEmpty)
        // 負的重量（輔助引體向上記成負重）沒有估算 1RM
        #expect(NewRecords.find([entry("輔助引體向上", [set(-10, 5)], earlier: [set(-20, 5)])]).isEmpty)
    }

    /// SwiftData：完成畫面（剛結束的訓練）和摘要頁（以前的訓練）都只和那次訓練開始之前的紀錄比較
    @MainActor
    @Test func sessionsCompareOnlyWithEarlierSessions() throws {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let squat = Exercise(name: "深蹲", category: .kneeDominant, tags: [.main], equipment: .barbell)
        let curl = Exercise(name: "二頭彎舉", category: .accessory, equipment: .dumbbell)
        [squat, curl].forEach(context.insert)
        func session(_ daysAgo: Double, _ squatKg: Double, curlKg: Double = 10) -> WorkoutSession {
            let start = Date.now.addingTimeInterval(-daysAgo * 86_400)
            let s = WorkoutActions.start(with: [squat, curl], backfill: DateInterval(start: start, duration: 3600), in: context)
            for (item, kg) in zip(s.orderedItems, [squatKg, curlKg]) {
                for set in item.sets { set.weightKg = kg; set.reps = 3; set.isCompleted = true; set.completedAt = start }
            }
            WorkoutActions.save(context)
            return s
        }
        let first = session(10, 100)
        let second = session(5, 110, curlKg: 12)
        let third = session(1, 105)
        #expect(NewRecords.find(in: first).isEmpty)                         // 以前沒有紀錄
        #expect(NewRecords.find(in: second).map(\.name) == ["深蹲", "二頭彎舉"]) // 之後的 105 不影響
        #expect(NewRecords.find(in: third).isEmpty)                          // 低於 5 天前的 110
    }
}
