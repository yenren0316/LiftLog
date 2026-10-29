import Foundation
import Testing
@testable import LiftLog

struct LogTypeAndUnitTests {
    private func done(_ v: SetValues) -> SetValues {
        var v = v
        v.isCompleted = true
        v.completedAt = .now
        return v
    }

    // MARK: bodyweight / timed

    @Test func completionRulesForNewTypes() {
        #expect(SetLogic.canComplete(SetValues(reps: 12), logType: .bodyweight, equipment: .bodyweight))
        #expect(!SetLogic.canComplete(SetValues(weightKg: 10), logType: .bodyweight, equipment: .bodyweight))
        #expect(SetLogic.canComplete(SetValues(seconds: 30), logType: .timed, equipment: .bodyweight))   // 熊爬
        #expect(!SetLogic.canComplete(SetValues(seconds: 60), logType: .timed, equipment: .dumbbell))    // 農夫走路要負重
        #expect(SetLogic.canComplete(SetValues(weightKg: 24, seconds: 60), logType: .timed, equipment: .dumbbell))
    }

    @Test func formatsForNewTypes() {
        let pushUps = Array(repeating: done(SetValues(reps: 12)), count: 3)
        #expect(SetFormat.compact(pushUps, logType: .bodyweight) == "12 下 × 3 組")
        let weighted = [done(SetValues(weightKg: 10, reps: 8))]
        #expect(SetFormat.compact(weighted, logType: .bodyweight) == "+10 kg × 8 下")
        let hang = Array(repeating: done(SetValues(seconds: 45)), count: 2)
        #expect(SetFormat.compact(hang, logType: .timed) == "45 秒 × 2 組")
        #expect(SetFormat.short(SetValues(weightKg: 24, seconds: 60), logType: .timed) == "60″ (+24)")
        #expect(SetFormat.short(SetValues(reps: 12), logType: .bodyweight) == "12")
    }

    // MARK: kg ↔ lbs

    @Test func conversionRoundTrips() {
        for kg in [0.0, 1.25, 20, 42.6, 60.8, 142, 222.5] {
            #expect(abs(WeightUnit.lbs.toKg(WeightUnit.lbs.fromKg(kg)) - kg) < 1e-9)
        }
        #expect(abs(WeightUnit.lbs.toKg(45) - 20.41165665) < 1e-6)
        #expect(WeightUnit.kg.fromKg(42.6) == 42.6)
    }

    @Test func displayPrecision() {
        #expect(WeightUnit.kg.format(kg: 58.54) == "58.5")
        #expect(WeightUnit.kg.format(kg: 60) == "60")
        #expect(WeightUnit.lbs.format(kg: 20.41165665) == "45")       // 45 lb
        #expect(WeightUnit.lbs.format(kg: 42.6) == "94")              // 93.92 → 94
        #expect(WeightUnit.lbs.format(kg: 42.4) == "93.5")            // 93.48 → 93.5
        #expect(WeightUnit.lbs.columnTitle(equipment: .dumbbell) == "lbs（單顆）")
        #expect(WeightUnit.kg.columnTitle(equipment: .barbell) == "kg")
    }

    @Test func compactUsesUnit() {
        let sets = Array(repeating: done(SetValues(weightKg: 20.41165665, reps: 5)), count: 5)
        #expect(SetFormat.compact(sets, logType: .weight, unit: .lbs) == "45 lbs × 5 下 × 5 組")
        #expect(SetFormat.compact(sets, logType: .weight, unit: .kg) == "20.4 kg × 5 下 × 5 組")
    }
}
