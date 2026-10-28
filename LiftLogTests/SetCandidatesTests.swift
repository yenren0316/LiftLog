import Foundation
import Testing
@testable import LiftLog

/// CHANGE_11 §4-2：鍵盤上緣候選列的數字
struct SetCandidatesTests {
    private func values(_ list: [SetCandidates.Candidate]) -> [Double] { list.map(\.value) }

    // MARK: kg 欄

    @Test func weightWithoutSuggestionIsMinusOneToPlusThreeSteps() {
        // 進位 2.5 kg：目前 60 → 57.5、60、62.5、65、67.5
        let list = SetCandidates.weight(current: 60, placeholder: 50, suggested: nil, step: 2.5)
        #expect(values(list) == [57.5, 60, 62.5, 65, 67.5])
        #expect(list.allSatisfy { !$0.isSuggested })
    }

    @Test func weightIncludesTheSuggestionInAccent() {
        // 建議 55 一定在裡面，其餘從 −1 步開始補滿 5 個，由小到大
        let list = SetCandidates.weight(current: 60, placeholder: nil, suggested: 55, step: 2.5)
        #expect(values(list) == [55, 57.5, 60, 62.5, 65])
        #expect(list.filter(\.isSuggested).map(\.value) == [55])
    }

    @Test func suggestionThatIsAlreadyACandidateIsNotRepeated() {
        // 建議 62.5 剛好是 +1 步：去掉重複，往後補到 +3 步
        let list = SetCandidates.weight(current: 60, placeholder: nil, suggested: 62.5, step: 2.5)
        #expect(values(list) == [57.5, 60, 62.5, 65, 67.5])
        #expect(list.filter(\.isSuggested).map(\.value) == [62.5])
    }

    @Test func emptyFieldUsesThePlaceholder() {
        // 這一格是空的：用灰字預填的值當中心
        #expect(values(SetCandidates.weight(current: nil, placeholder: 40, suggested: nil, step: 2.5)) == [37.5, 40, 42.5, 45, 47.5])
        // 兩個都沒有：不顯示候選列
        #expect(SetCandidates.weight(current: nil, placeholder: nil, suggested: nil, step: 2.5).isEmpty)
        #expect(SetCandidates.weight(current: nil, placeholder: nil, suggested: 55, step: 2.5).isEmpty)
    }

    @Test func roundingStepsFollowTheSettings() {
        // 進位 1 kg
        #expect(values(SetCandidates.weight(current: 12, placeholder: nil, suggested: nil, step: 1)) == [11, 12, 13, 14, 15])
        // 進位 5 lbs（lbs 模式時數字和進位都是 lb）
        #expect(values(SetCandidates.weight(current: 135, placeholder: nil, suggested: nil, step: 5)) == [130, 135, 140, 145, 150])
        // 浮點誤差不會產生 42.499999
        #expect(values(SetCandidates.weight(current: 42.5, placeholder: nil, suggested: nil, step: 2.5)) == [40, 42.5, 45, 47.5, 50])
    }

    @Test func negativeOnlyWhenTheExerciseAllowsIt() {
        // 0 kg（自重）：不能記負數時不列 −2.5，往後多補一步
        #expect(values(SetCandidates.weight(current: 0, placeholder: nil, suggested: nil, step: 2.5)) == [0, 2.5, 5, 7.5, 10])
        // 輔助引體向上（負重制）：可以是負數
        #expect(values(SetCandidates.weight(current: -20, placeholder: nil, suggested: nil, step: 1, allowsNegative: true))
                == [-21, -20, -19, -18, -17])
    }

    // MARK: 次數欄

    @Test func repsCenterOnThePrescription() {
        // 處方 3 下 → 1～5
        #expect(values(SetCandidates.reps(prescribed: 3...3)) == [1, 2, 3, 4, 5])
        // 處方 8～12 下 → 8～12
        #expect(values(SetCandidates.reps(prescribed: 8...12)) == [8, 9, 10, 11, 12])
        // 最小是 1：處方 1 下（硬舉速度）→ 1～5
        #expect(values(SetCandidates.reps(prescribed: 1...1)) == [1, 2, 3, 4, 5])
        // 處方 2 下 → 1～5（不從 0 開始）
        #expect(values(SetCandidates.reps(prescribed: 2...2)) == [1, 2, 3, 4, 5])
        // 沒有處方次數（有氧）：不顯示
        #expect(SetCandidates.reps(prescribed: nil).isEmpty)
    }

    @Test func prescriptionsCarryTheRepRanges() {
        #expect(Prescription.of(role: .maxEffort, name: "深蹲", tags: [.main]).reps == 3...3)
        #expect(Prescription.of(role: .maxEffort, name: "槓鈴早安式", tags: [.main]).reps == 5...5)
        #expect(Prescription.of(role: .dynamicEffort, name: "臥推", tags: [.main]).reps == 3...3)
        #expect(Prescription.of(role: .dynamicEffort, name: "壺鈴擺盪", tags: [.explosive]).reps == 8...10)
        #expect(Prescription.of(role: .pull, name: "滑輪下拉", tags: []).reps == 8...12)
        #expect(Prescription.of(role: .core, name: "腹前推", tags: []).reps == 10...15)
        #expect(Prescription.of(role: .cardio, name: "跑步機", tags: []).reps == nil)
        // 說明文字不變
        #expect(Prescription.of(role: .dynamicEffort, name: "負重原地起跳", tags: [.explosive]).volume == "6–8 組 × 3–5 下")
    }
}
