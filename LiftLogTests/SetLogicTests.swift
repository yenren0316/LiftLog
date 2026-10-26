import Foundation
import Testing
@testable import LiftLog

struct SetLogicTests {
    private func s(_ w: Double?, _ r: Int?, _ kind: SetKind = .normal, done: Bool = true, at: Date? = nil) -> SetValues {
        SetValues(kind: kind, weightKg: w, reps: r, isCompleted: done, completedAt: done ? (at ?? .now) : nil)
    }

    // MARK: 上一次的組對應

    @Test func previousMapsBySetOrder() {
        let last = [s(60, 5), s(65, 3), s(70, 1, .max)]
        #expect(SetLogic.previous(at: 0, lastSets: last) == last[0])
        #expect(SetLogic.previous(at: 2, lastSets: last) == last[2])
        #expect(SetLogic.previous(at: 3, lastSets: last) == nil)
        #expect(SetLogic.previous(at: 0, lastSets: []) == nil)
    }

    // MARK: 預填

    @Test func placeholderPrefersPreviousThenPriorSet() {
        let previous = s(60, 5)
        let prior = s(62.5, 5, done: false)
        #expect(SetLogic.placeholder(previous: previous, priorInSession: prior) == previous)
        #expect(SetLogic.placeholder(previous: nil, priorInSession: prior) == prior)
        #expect(SetLogic.placeholder(previous: nil, priorInSession: nil) == nil)
    }

    @Test func resolvedUsesEnteredThenPlaceholder() {
        let entered = SetValues(weightKg: 65, reps: nil)
        let resolved = SetLogic.resolved(entered: entered, placeholder: s(60, 5))
        #expect(resolved.weightKg == 65)
        #expect(resolved.reps == 5)
    }

    @Test func cannotCompleteWithoutValues() {
        #expect(!SetLogic.canComplete(SetValues(), logType: .weight, equipment: .barbell))
        #expect(!SetLogic.canComplete(SetValues(weightKg: 60), logType: .weight, equipment: .barbell))
        #expect(SetLogic.canComplete(SetValues(weightKg: 60, reps: 5), logType: .weight, equipment: .barbell))
        #expect(SetLogic.canComplete(SetValues(reps: 10), logType: .weight, equipment: .bodyweight))
        #expect(SetLogic.canComplete(SetValues(weightKg: 0, reps: 5), logType: .assisted, equipment: .bodyweight))
        #expect(!SetLogic.canComplete(SetValues(reps: 5), logType: .assisted, equipment: .bodyweight))
        #expect(SetLogic.canComplete(SetValues(minutes: 30), logType: .cardio, equipment: .other))
    }

    // MARK: 完成訓練時未打勾的組

    @Test func finishDeletingIncompleteDropsEmptyExercises() {
        let items = [[s(60, 5), s(60, 5, done: false)], [s(20, 10, done: false)]]
        let result = SetLogic.finish(items, choice: .deleteIncomplete, now: .now)
        #expect(result[0].count == 1)
        #expect(result[1].isEmpty)   // 沒有完成的組 → 之後從這次訓練移除
    }

    @Test func finishCompletingAllMarksEverything() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let result = SetLogic.finish([[s(60, 5), s(60, 5, done: false)]], choice: .completeAll, now: now)
        #expect(result[0].allSatisfy { $0.isCompleted })
        #expect(result[0][1].completedAt == now)
    }

    // MARK: 幾天前只計算已完成的組

    @Test func lastCompletedDateIgnoresIncompleteSets() {
        let old = Date(timeIntervalSince1970: 1_700_000_000)
        let sets = [s(60, 5, at: old), SetValues(weightKg: 60, reps: 5, isCompleted: false)]
        #expect(SetLogic.lastCompletedDate(sets) == old)
        #expect(SetLogic.lastCompletedDate([SetValues(weightKg: 60, isCompleted: false)]) == nil)
    }

    // MARK: 新紀錄

    @Test func newRecordForWeight() {
        let history = [s(60.8, 1, .max), s(58.5, 5)]
        #expect(SetLogic.isNewRecord(session: [s(61, 1, .max)], history: history, logType: .weight))
        #expect(!SetLogic.isNewRecord(session: [s(60.8, 3)], history: history, logType: .weight))
        // 熱身組和未完成的組不算
        #expect(!SetLogic.isNewRecord(session: [s(80, 1, .warmup), s(90, 1, done: false)], history: history, logType: .weight))
        // 沒有歷史不算新紀錄
        #expect(!SetLogic.isNewRecord(session: [s(61, 1)], history: [], logType: .weight))
    }

    @Test func newRecordForAssistedIsLowerAssistance() {
        let history = [s(13.75, 5), s(12, 5)]
        #expect(SetLogic.isNewRecord(session: [s(11.25, 5)], history: history, logType: .assisted))
        #expect(!SetLogic.isNewRecord(session: [s(12, 5)], history: history, logType: .assisted))
        #expect(SetLogic.isNewRecord(session: [s(0, 3)], history: history, logType: .assisted))
    }

    // MARK: 顯示格式

    @Test func compactFormats() {
        #expect(SetFormat.compact([s(42.6, 5), s(42.6, 5), s(42.6, 5)], logType: .weight) == "42.6 kg × 5 下 × 3 組")
        #expect(SetFormat.compact([s(60, 5), s(65, 3), s(70, 1, .max)], logType: .weight) == "60×5、65×3、70×1 (MAX)")
        #expect(SetFormat.compact([s(55, 1, .max)], logType: .weight) == "55 kg × 1 下 (MAX)")
        #expect(SetFormat.compact([s(20, 10, .warmup), s(40, 5)], logType: .weight) == "40 kg × 5 下")
        #expect(SetFormat.compact([s(12, 5), s(12, 5)], logType: .assisted) == "輔助 12 kg × 5 下 × 2 組")
        #expect(SetFormat.compact([SetValues(incline: 12, speed: 4, minutes: 30)], logType: .cardio) == "坡度 12%・4.0 km/h・30 分")
    }

    @Test func sessionTitles() {
        #expect(SessionTitle.automatic(["臥推"]) == "臥推")
        #expect(SessionTitle.automatic(["臥推", "滑輪下拉", "跑步機"]) == "臥推＋滑輪下拉＋跑步機")
        #expect(SessionTitle.automatic(["A", "B", "C", "D"]) == "A＋B 等 4 項")
    }

    @Test func onlyBodyweightLoadsCanBeNegative() {
        // 輔助引體向上：輔助 20 kg 記 −20 kg
        #expect(SetLogic.allowsNegativeLoad(logType: .weight, equipment: .bodyweight))
        #expect(!SetLogic.allowsNegativeLoad(logType: .weight, equipment: .barbell))
        #expect(!SetLogic.allowsNegativeLoad(logType: .assisted, equipment: .bodyweight))
        // 負重可以不填，負數照樣能完成
        #expect(SetLogic.canComplete(SetValues(weightKg: -20, reps: 5), logType: .weight, equipment: .bodyweight))
        #expect(SetFormat.compact([SetValues(weightKg: -20, reps: 5)], logType: .weight) == "-20 kg × 5 下")
    }
}
