import Foundation
import Testing
@testable import LiftLog

struct ExerciseStatsTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func day(_ daysAgo: Double) -> Date { now.addingTimeInterval(-daysAgo * 86_400) }

    private func s(_ w: Double?, _ r: Int?, _ kind: SetKind = .normal, done: Bool = true) -> SetValues {
        SetValues(kind: kind, weightKg: w, reps: r, isCompleted: done, completedAt: done ? now : nil)
    }

    private func session(_ daysAgo: Double, _ sets: [SetValues], id: UUID = UUID()) -> SessionSets {
        SessionSets(sessionID: id, date: day(daysAgo), sets: sets)
    }

    // MARK: Epley

    @Test func epleyFormula() {
        #expect(PersonalRecords.epley(weight: 100, reps: 1) == 100 * (1 + 1.0 / 30))
        #expect(abs(PersonalRecords.epley(weight: 60, reps: 5) - 70) < 1e-9)
    }

    @Test func estimateOnlyCountsOneToTenRepsAndNoWarmups() {
        let sessions = [session(10, [
            s(100, 15),             // 超過 10 下：不算
            s(90, 3, .warmup),      // 熱身：不算
            s(80, 0),               // 0 下：不算
            s(60, 5),               // 70
            s(70, 1, .max),         // 72.33
            s(80, 4, done: false),  // 未完成：不算
        ])]
        let result = PersonalRecords.estimated1RM(sessions, now: now)
        #expect(result?.isAllTime == false)
        #expect(abs((result?.record.value ?? 0) - 70 * (1 + 1.0 / 30)) < 1e-9)
    }

    @Test func estimateFallsBackToAllTimeWithCaption() {
        let old = UUID()
        let sessions = [session(200, [s(60, 5)], id: old), session(30, [s(nil, 10)])]
        let result = PersonalRecords.estimated1RM(sessions, now: now)
        #expect(result?.isAllTime == true)
        #expect(result?.record.sessionID == old)
        #expect(result?.record.caption != nil)
        #expect(result?.record.date == day(200))
    }

    @Test func weightRecords() {
        let heavy = UUID()
        let sessions = [
            session(40, [s(60, 5), s(62.5, 3)]),
            session(20, [s(20, 10, .warmup), s(70, 1, .max)], id: heavy),
        ]
        let records = PersonalRecords.records(sessions, logType: .weight, now: now)
        let byTitle = Dictionary(uniqueKeysWithValues: records.map { ($0.title, $0) })
        #expect(byTitle["最重單次"]?.value == 70)
        #expect(byTitle["最重單次"]?.sessionID == heavy)
        #expect(byTitle["1RM 最佳"]?.value == 70)
        #expect(byTitle["3RM 最佳"]?.value == 62.5)
        #expect(byTitle["5RM 最佳"]?.value == 60)
        #expect(byTitle["估算 1RM"] != nil)
    }

    @Test func assistedRecordIsLowestWithFivePlusReps() {
        let sessions = [session(10, [s(12, 5), s(10, 3), s(11.25, 5)])]
        let records = PersonalRecords.records(sessions, logType: .assisted, now: now)
        #expect(records.map(\.value) == [11.25])
    }

    // MARK: 折線圖

    @Test func chartPointsSkipWarmupsAndMarkMax() {
        let sessions = [
            session(30, [s(100, 1, .warmup), s(60, 5), s(65, 3)]),
            session(10, [s(70, 1, .max), s(40, 10, .warmup)]),
            session(5, [s(20, 10, .warmup)]),     // 只有熱身：沒有點
        ]
        let points = ChartPoints.points(sessions, logType: .weight, metric: .heaviest)
        #expect(points.map(\.value) == [65, 70])
        #expect(points.map(\.isMax) == [false, true])
    }

    @Test func assistedChartTakesLowestAndIsReversed() {
        let sessions = [session(10, [s(19, 5), s(16.25, 5)])]
        #expect(ChartPoints.points(sessions, logType: .assisted, metric: .heaviest).map(\.value) == [16.25])
        #expect(ChartPoints.isReversed(.assisted))
        #expect(!ChartPoints.isReversed(.weight))
    }

    @Test func chartRangeFilters() {
        let sessions = [session(400, [s(50, 5)]), session(100, [s(55, 5)]), session(30, [s(60, 5)])]
        let points = ChartPoints.points(sessions, logType: .weight, metric: .heaviest)
        #expect(ChartPoints.filter(points, range: .threeMonths, now: now).count == 1)
        #expect(ChartPoints.filter(points, range: .oneYear, now: now).count == 2)
        #expect(ChartPoints.filter(points, range: .all, now: now).count == 3)
    }

    @Test func timedDefaultMetricDependsOnLoad() {
        let loaded = [session(1, [SetValues(weightKg: 24, seconds: 60, isCompleted: true)])]
        let unloaded = [session(1, [SetValues(seconds: 45, isCompleted: true)])]
        #expect(ChartMetric.defaultMetric(for: .timed, sessions: loaded) == .load)
        #expect(ChartMetric.defaultMetric(for: .timed, sessions: unloaded) == .seconds)
    }

    // MARK: 強度換算表

    @Test func roundingToPlateSteps() {
        #expect(IntensityTable.rounded(71.3, step: 2.5) == 72.5)
        #expect(IntensityTable.rounded(71.2, step: 2.5) == 70)
        #expect(IntensityTable.rounded(157, step: 5) == 155)
        #expect(IntensityTable.rounded(158, step: 5) == 160)
        #expect(IntensityTable.rounded(18.4, step: 1) == 18)
        #expect(IntensityTable.defaultStep(equipment: .barbell, unit: .kg) == 2.5)
        #expect(IntensityTable.defaultStep(equipment: .barbell, unit: .lbs) == 5)
        #expect(IntensityTable.defaultStep(equipment: .dumbbell, unit: .kg) == 1)
        #expect(IntensityTable.defaultStep(equipment: .dumbbell, unit: .lbs) == 2.5)
    }

    @Test func tableRowsInUnitWithPurposes() {
        let rows = IntensityTable.rows(base1RMKg: 100, unit: .kg, step: 2.5)
        #expect(rows.map(\.percent) == [60, 65, 70, 75, 80, 85, 90, 95])
        #expect(rows.map(\.weight) == [60, 65, 70, 75, 80, 85, 90, 95])
        #expect(rows[0].purposes == ["爆發力"])
        #expect(rows[1].purposes == ["爆發力", "肌肥大"])
        #expect(rows[5].purposes == ["肌肥大", "最大肌力"])
        #expect(rows[7].purposes == ["最大肌力"])
        // lbs：100 kg = 220.46 lb，60% = 132.3 → 130
        #expect(IntensityTable.rows(base1RMKg: 100, unit: .lbs, step: 5)[0].weight == 130)
    }
}
