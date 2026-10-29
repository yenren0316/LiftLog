import Foundation
import Testing
@testable import LiftLog

/// CHANGE_14 §5：平衡卡完全沒有紀錄時只寫「還沒有紀錄」；有紀錄但 30 天內 0 組的分類照舊「0 沒練」
struct BalanceCardTests {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return c
    }()

    private func date(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 19))!
    }

    private func session(_ when: Date, _ category: ExerciseCategory, completed: Bool = true) -> PlanHistory.Session {
        PlanHistory.Session(date: when, items: [
            PlanHistory.Item(exerciseID: UUID(), category: category, role: .push,
                             sets: [SetValues(weightKg: 40, reps: 8, isCompleted: completed)]),
        ])
    }

    @Test func noRecordsAtAll() {
        // 空的資料、只有沒打勾的組：都是「還沒有紀錄」
        let empty = StatsSnapshot.make(history: PlanHistory([]), exercises: [], now: date(10, 28), calendar: calendar)
        #expect(!empty.hasCompletedSets)
        #expect(BalanceCardContent.make(empty) == .noRecords)
        let unchecked = StatsSnapshot.make(history: PlanHistory([session(date(10, 20), .horizontalPush, completed: false)]),
                                           exercises: [], now: date(10, 28), calendar: calendar)
        #expect(BalanceCardContent.make(unchecked) == .noRecords)
    }

    @Test func recordsOlderThanThirtyDaysShowZeroNotTrained() {
        // 有紀錄，但都在 30 天以前：9 列都是「0 沒練」，不是「還沒有紀錄」
        let old = StatsSnapshot.make(history: PlanHistory([session(date(8, 1), .kneeDominant)]),
                                     exercises: [], now: date(10, 28), calendar: calendar)
        #expect(old.hasCompletedSets)
        guard case .rows(let rows) = BalanceCardContent.make(old) else {
            Issue.record("有紀錄時要列出 9 個分類")
            return
        }
        #expect(rows.map(\.category) == ExerciseCategory.allCases)
        #expect(rows.allSatisfy { $0.count == 0 && $0.isNeglected && $0.text == "0 沒練" })

        // 30 天內有練的分類寫組數，其他的照舊「0 沒練」
        let recent = StatsSnapshot.make(history: PlanHistory([session(date(10, 20), .horizontalPush), session(date(8, 1), .kneeDominant)]),
                                        exercises: [], now: date(10, 28), calendar: calendar)
        guard case .rows(let recentRows) = BalanceCardContent.make(recent) else {
            Issue.record("有紀錄時要列出 9 個分類")
            return
        }
        let push = recentRows.first { $0.category == .horizontalPush }
        #expect(push?.count == 1 && push?.text == "1" && push?.isNeglected == false)
        #expect(recentRows.first { $0.category == .kneeDominant }?.text == "0 沒練")
    }
}
