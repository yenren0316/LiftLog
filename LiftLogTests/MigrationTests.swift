import Foundation
import Testing
@testable import LiftLog

struct MigrationTests {
    private let bench = UUID()
    private let row = UUID()
    private let treadmill = UUID()

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }

    private func date(_ m: Int, _ d: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: m, day: d, hour: 12, minute: minute))!
    }

    private func entry(_ exercise: UUID, _ date: Date, weight: Double? = nil, sets: Int? = nil, reps: Int? = nil,
                       isMax: Bool = false, incline: Double? = nil, speed: Double? = nil, minutes: Double? = nil,
                       note: String = "") -> SessionMigration.LegacyEntry {
        .init(date: date, exerciseID: exercise, weightKg: weight, sets: sets, reps: reps, isMax: isMax,
              incline: incline, speed: speed, minutes: minutes, note: note, healthWorkoutID: nil)
    }

    private func expand(_ e: SessionMigration.LegacyEntry) -> [SetValues] {
        SessionMigration.expand(e, completedAt: e.date).map(\.values)
    }

    @Test func fiveByFive() {
        let sets = expand(entry(bench, date(10, 1), weight: 42.6, sets: 5, reps: 5))
        #expect(sets.count == 5)
        #expect(sets.allSatisfy { $0.weightKg == 42.6 && $0.reps == 5 && $0.kind == .normal && $0.isCompleted })
    }

    @Test func tenByThreeIsThreeSetsOfTen() {
        let sets = expand(entry(row, date(10, 1), weight: 25, sets: 3, reps: 10))
        #expect(sets.count == 3)
        #expect(sets.allSatisfy { $0.reps == 10 })
    }

    @Test func maxBecomesOneMaxSet() {
        let unknownReps = expand(entry(bench, date(10, 1), weight: 60.8, isMax: true))
        #expect(unknownReps == [SetValues(kind: .max, weightKg: 60.8, reps: 1, isCompleted: true, completedAt: date(10, 1))])
        let knownReps = expand(entry(bench, date(10, 1), weight: 55, reps: 3, isMax: true))
        #expect(knownReps.count == 1 && knownReps[0].reps == 3 && knownReps[0].kind == .max)
    }

    @Test func treadmillIsOneSet() {
        let sets = expand(entry(treadmill, date(10, 1), incline: 12, speed: 4, minutes: 30))
        #expect(sets == [SetValues(incline: 12, speed: 4, minutes: 30, isCompleted: true, completedAt: date(10, 1))])
    }

    @Test func missingSetsOrRepsKeepsKnownFields() {
        // 「相撲硬舉 119kg」：沒有組數也沒有次數 → 一組
        #expect(expand(entry(bench, date(10, 1), weight: 119)).count == 1)
        // 「盪壺鈴 24kg 做到沒力x3」：只知道組數 → 3 組、次數空白
        let sets = expand(entry(bench, date(10, 1), weight: 24, sets: 3))
        #expect(sets.count == 3 && sets.allSatisfy { $0.reps == nil && $0.weightKg == 24 })
    }

    @Test func groupsByDayKeepingOrderAndMergingSameExercise() {
        let plans = SessionMigration.plan([
            entry(row, date(10, 2, 1), weight: 50, sets: 5, reps: 5),
            entry(bench, date(10, 2, 0), weight: 35, sets: 5, reps: 3, note: "A"),
            entry(bench, date(10, 2, 2), weight: 30, sets: 2, reps: 3, note: "B"),
            entry(treadmill, date(10, 1), incline: 12, speed: 4, minutes: 30),
        ], calendar: calendar)
        #expect(plans.count == 2)
        #expect(plans[0].items.map(\.exerciseID) == [treadmill])
        let day2 = plans[1]
        #expect(day2.items.map(\.exerciseID) == [bench, row])
        #expect(day2.items[0].sets.map(\.values.weightKg) == [35, 35, 35, 35, 35, 30, 30])
        #expect(day2.items[0].note == "A；B")
        #expect(day2.startedAt == date(10, 2, 0))
    }
}
