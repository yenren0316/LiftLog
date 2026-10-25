import Foundation
import Testing
@testable import LiftLog

struct RoleTests {
    @Test func rulesInOrder() {
        #expect(Role.of(category: .cardio, tags: []) == .cardio)
        #expect(Role.of(category: .accessory, tags: []) == .accessory)
        #expect(Role.of(category: .core, tags: [.explosive]) == .core)          // 單手壺鈴擺盪：分類優先於標籤
        #expect(Role.of(category: .horizontalPush, tags: []) == .push)
        #expect(Role.of(category: .verticalPush, tags: []) == .push)
        #expect(Role.of(category: .horizontalPull, tags: [.explosive]) == .pull) // 爆發划船是上肢：拉
        #expect(Role.of(category: .verticalPull, tags: []) == .pull)
        #expect(Role.of(category: .kneeDominant, tags: [.explosive]) == .explosive)
        #expect(Role.of(category: .hipDominant, tags: [.unilateral]) == .unilateral)
        #expect(Role.of(category: .kneeDominant, tags: []) == .main)
    }

    @Test func explosiveWinsWhenBothTags() {
        // 單手抓舉：單邊＋爆發
        #expect(Role.of(category: .hipDominant, tags: [.unilateral, .explosive]) == .explosive)
        #expect(Role.of(category: .hipDominant, tags: [.explosive, .unilateral]) == .explosive)
    }

    @Test func regionLooksOnlyAtUpperAndLower() {
        #expect(Region.infer([.kneeDominant, .core, .cardio]) == .lower)
        #expect(Region.infer([.horizontalPush, .verticalPull, .accessory]) == .upper)
        #expect(Region.infer([.hipDominant, .verticalPush]) == .full)
        #expect(Region.infer([.core, .accessory, .cardio]) == .unspecified)
        #expect(Region.infer([]) == .unspecified)
    }

    @Test func shortGuideIsFirstSentence() {
        #expect(Role.main.shortGuide == "雙邊、能承受大重量，是最大肌力的主要來源。")
        #expect(Role.core.shortGuide == Role.core.guide)
        #expect(Role.push.guide == Role.pull.guide)
    }
}
