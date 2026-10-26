import Foundation
import Testing
@testable import LiftLog

struct RoleTests {
    @Test func defaultRoleByCategory() {
        // 不是從建立菜單加入的動作：只看分類；ME、DE 只由建立菜單指定
        #expect(Role.of(category: .cardio) == .cardio)
        #expect(Role.of(category: .accessory) == .accessory)
        #expect(Role.of(category: .core) == .core)
        #expect(Role.of(category: .horizontalPush) == .push)
        #expect(Role.of(category: .verticalPush) == .push)
        #expect(Role.of(category: .horizontalPull) == .pull)
        #expect(Role.of(category: .verticalPull) == .pull)
        #expect(Role.of(category: .kneeDominant) == .lowerAssist)
        #expect(Role.of(category: .hipDominant) == .lowerAssist)
    }

    @Test func legacyRolesStayReadable() {
        // CHANGE_04 的角色存在舊紀錄裡，照樣讀得出來
        #expect(Role(rawValue: "main") == .main && Role.main.title == "主項" && Role.main.isLegacy)
        #expect(Role(rawValue: "explosive")?.isLegacy == true && Role(rawValue: "unilateral")?.isLegacy == true)
        #expect(!Role.maxEffort.isLegacy && !Role.pull.isLegacy)
        #expect([Role.maxEffort, .dynamicEffort, .lowerAssist].map(\.title) == ["ME 主項", "DE 主項", "下肢輔助"])
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
        #expect(Role.maxEffort.shortGuide == "最大肌力：逐步加重到當天的 3RM（早安式做到 5RM），組間充分休息。")
    }

    @Test func dayTypeOrder() {
        #expect(DayType.meLower.next == .meUpper)
        #expect(DayType.meUpper.next == .deLower)
        #expect(DayType.deLower.next == .deUpper)
        #expect(DayType.deUpper.next == .meLower)
        #expect(DayType.allCases.filter(\.isMaxEffort) == [.meLower, .meUpper])
        #expect(DayType.allCases.filter(\.isLower) == [.meLower, .deLower])
    }
}

/// 共軛訓練第 5 節：預設參數
struct PrescriptionTests {
    private func of(_ role: Role, _ name: String, _ tags: [ExerciseTag] = []) -> Prescription {
        Prescription.of(role: role, name: name, tags: tags)
    }

    @Test func maxEffortWorksUpToThreeRMOrFiveForGoodMornings() {
        #expect(of(.maxEffort, "深蹲", [.main]).volume == "逐步加重到當天 3RM")
        #expect(of(.maxEffort, "槓鈴早安式", [.main]).volume == "逐步加重到當天 5RM")
        #expect(of(.maxEffort, "臥推", [.main]).summary == "逐步加重到當天 3RM・充分休息")
        #expect(of(.maxEffort, "臥推", [.main]).tip == "設好安全槓")
    }

    @Test func speedLiftsHaveFixedSetsAndReps() {
        let squat = of(.dynamicEffort, "深蹲", [.main])
        #expect(squat.summary == "8 組 × 2 下・休息 45–60 秒")
        #expect(squat.setCount == 8 && squat.fixedReps == 2 && squat.restSeconds == 60 && squat.tip == nil)
        #expect(of(.dynamicEffort, "傳統硬舉", [.main]).volume == "6 組 × 1 下")
        #expect(of(.dynamicEffort, "臥推", [.main]).volume == "8 組 × 3 下")
        #expect(Prescription.isSpeed(role: .dynamicEffort, tags: [.main]))
        #expect(!Prescription.isSpeed(role: .dynamicEffort, tags: [.explosive]))
        #expect(!Prescription.isSpeed(role: .maxEffort, tags: [.main]))
    }

    @Test func explosiveLifts() {
        let swing = of(.dynamicEffort, "壺鈴擺盪", [.explosive])
        #expect(swing.volume == "6–8 組 × 8–10 下" && swing.rest == "休息 60–90 秒" && swing.tip == "速度掉了就停")
        #expect(of(.dynamicEffort, "借力推舉", [.explosive]).volume == "6–8 組 × 3–5 下")
        #expect(of(.dynamicEffort, "借力推舉", [.explosive]).fixedReps == nil)
    }

    @Test func assistanceCoreAccessoryAndCardio() {
        for role in [Role.lowerAssist, .pull, .push] {
            #expect(of(role, "x").summary == "3–4 組 × 8–12 下・休息 60–90 秒")
            #expect(of(role, "x").restSeconds == 90)
        }
        for role in [Role.core, .accessory] {
            #expect(of(role, "x").summary == "2–3 組 × 10–15 下，或 30–45 秒・休息 45–60 秒")
            #expect(of(role, "x").restSeconds == 60)
        }
        #expect(of(.cardio, "跑步機").summary == "30 分鐘，坡度和速度沿用上次")
        #expect(of(.cardio, "跑步機").setCount == 1)
    }
}
