import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_18 §3：新動作第一次當 ME 主項是熟悉日——處方「熟悉日：逐步加到順手的 5 下，不衝極限」，
/// 取代「做到 3RM」（早安式「做到 5RM」）；這個動作有了完成組之後，下一輪恢復正常的 ME 處方
@MainActor
struct FamiliarizationTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let frontSquat = PlanExercise(id: UUID(), name: "前蹲舉", category: .kneeDominant, tags: [.main], meRotation: 3,
                                          equipment: .barbell)
    private let goodMorning = PlanExercise(id: UUID(), name: "槓鈴早安式", category: .hipDominant, tags: [.main], meRotation: 4,
                                           equipment: .barbell)

    private func log(_ role: Role, completed: Bool = true) -> ExerciseLog {
        ExerciseLog(date: now.addingTimeInterval(-5 * 86_400), role: role,
                    sets: [SetValues(weightKg: 60, reps: 5, isCompleted: completed)])
    }

    @Test func newMaxEffortMainIsAFamiliarizationDay() {
        // 沒有任何完成組：熟悉日
        #expect(Prescription.isFamiliarization(role: .maxEffort, logs: []))
        let advice = SlotAdvice.make(role: .maxEffort, exercise: frontSquat, logs: [], unit: .kg, step: 2.5, now: now)
        #expect(advice.prescription.isFamiliarization)
        #expect(advice.prescription.volume == "熟悉日：逐步加到順手的 5 下，不衝極限")
        #expect(advice.line == "熟悉日：逐步加到順手的 5 下，不衝極限")
        #expect(advice.prescription.summary == "熟悉日：逐步加到順手的 5 下，不衝極限・充分休息")
        // 安全提示、組數、休息照舊
        #expect(advice.prescription.tip == "設好安全槓" && advice.prescription.setCount == 5 && advice.prescription.restSeconds == 180)
        // 「下一次」卡
        let line = NextCard.mainLine(dayType: .meLower, main: frontSquat, logs: [], unit: .kg, step: 2.5, now: now)
        #expect(line.text == "主項：前蹲舉・熟悉日" && !line.detailIsSuggestion)
        // 只有沒打勾的組也算新動作
        #expect(Prescription.isFamiliarization(role: .maxEffort, logs: [log(.push, completed: false)]))
    }

    @Test func anyCompletedSetRestoresTheNormalPrescription() {
        // 任何角色的完成組都算（這裡是下肢輔助）
        for role in [Role.maxEffort, .dynamicEffort, .lowerAssist] {
            let logs = [log(role)]
            #expect(!Prescription.isFamiliarization(role: .maxEffort, logs: logs), "\(role)")
            let advice = SlotAdvice.make(role: .maxEffort, exercise: frontSquat, logs: logs, unit: .kg, step: 2.5, now: now)
            #expect(advice.line == "逐步加重到當天 3RM・上次 60 kg", "\(role)")
            #expect(NextCard.mainLine(dayType: .meLower, main: frontSquat, logs: logs, unit: .kg, step: 2.5, now: now).text
                    == "主項：前蹲舉・做到 3RM", "\(role)")
        }
    }

    @Test func goodMorningToo() {
        let first = SlotAdvice.make(role: .maxEffort, exercise: goodMorning, logs: [], unit: .kg, step: 2.5, now: now)
        #expect(first.prescription.volume == "熟悉日：逐步加到順手的 5 下，不衝極限")
        #expect(NextCard.mainLine(dayType: .meLower, main: goodMorning, logs: [], unit: .kg, now: now).text == "主項：槓鈴早安式・熟悉日")
        let logs = [log(.maxEffort)]
        #expect(SlotAdvice.make(role: .maxEffort, exercise: goodMorning, logs: logs, unit: .kg, step: 2.5, now: now)
            .prescription.volume == "逐步加重到當天 5RM")
        #expect(NextCard.mainLine(dayType: .meLower, main: goodMorning, logs: logs, unit: .kg, now: now).text == "主項：槓鈴早安式・做到 5RM")
    }

    @Test func onlyMaxEffortMains() {
        // DE 主項不另外處理：速度主項沒有紀錄時照舊「用能做得很快的重量」
        let speed = SlotAdvice.make(role: .dynamicEffort, exercise: frontSquat, logs: [], unit: .kg, step: 2.5, now: now)
        #expect(!speed.prescription.isFamiliarization && speed.weightText == "用能做得很快的重量")
        // 其他角色也不是熟悉日
        for role in [Role.lowerAssist, .push, .pull, .core, .accessory] {
            #expect(!Prescription.isFamiliarization(role: role, logs: []), "\(role)")
            #expect(!SlotAdvice.make(role: role, exercise: frontSquat, logs: [], unit: .kg, now: now).prescription.isFamiliarization)
        }
    }

    /// 訓練畫面的說明列：這次訓練裡打勾了也還是熟悉日（只看這次之前的紀錄）；完成後，下一次的訓練恢復「逐步加重到當天 3RM」
    @Test func workoutCardShowsFamiliarizationUntilTheWorkoutIsDone() throws {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let squat = Exercise(name: "前蹲舉", category: .kneeDominant, tags: [.main], equipment: .barbell)
        context.insert(squat)
        let first = WorkoutActions.start(with: [squat], roles: [.maxEffort], dayType: .meLower, in: context)
        let item = try #require(first.orderedItems.first)
        #expect(item.advice(unit: .kg).prescription.summary == "熟悉日：逐步加到順手的 5 下，不衝極限・充分休息")
        let set = try #require(item.orderedSets.first)
        set.weightKg = 40
        set.reps = 5
        #expect(WorkoutActions.complete(set, placeholder: nil, in: context))
        #expect(item.advice(unit: .kg).prescription.isFamiliarization, "這次訓練裡的組不算以前的紀錄")
        #expect(WorkoutActions.finish(first, choice: .deleteIncomplete, in: context))

        // 熟悉日也算用過這個主項：下一次 ME 下肢從它往下接
        let history = PlanHistory(sessions: try context.fetch(FetchDescriptor<WorkoutSession>()))
        #expect(Rotation.lastMainID(dayType: .meLower, history: history) == squat.id)

        // 下一輪：恢復正常的 ME 處方
        first.startedAt = first.startedAt.addingTimeInterval(-7 * 86_400)
        first.endedAt = first.startedAt.addingTimeInterval(3600)
        let next = WorkoutActions.start(with: [squat], roles: [.maxEffort], dayType: .meLower, in: context)
        let advice = try #require(next.orderedItems.first).advice(unit: .kg)
        #expect(!advice.prescription.isFamiliarization)
        #expect(advice.prescription.summary == "逐步加重到當天 3RM・充分休息")
    }
}
