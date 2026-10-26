import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_07 A-2：開始訓練的唯一入口
@MainActor
struct WorkoutLauncherTests {
    final class SilentNotifications: RestNotifying {
        func schedule(at endDate: Date) {}
        func cancel() {}
    }

    struct Fixture {
        var context: ModelContext
        var launcher: WorkoutLauncher
        var timer: RestTimer
        var bench: Exercise
        var row: Exercise
        /// 進行中的訓練：臥推第一組已完成，第二組還沒
        var current: WorkoutSession
    }

    private func makeFixture() throws -> Fixture {
        let context = ModelContext(try ModelContainer(for: LiftLogStore.schema,
                                                      configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let defaults = try #require(UserDefaults(suiteName: "WorkoutLauncherTests.\(UUID().uuidString)"))
        let timer = RestTimer(defaults: defaults, notifications: SilentNotifications())
        let launcher = WorkoutLauncher(coordinator: WorkoutCoordinator(), restTimer: timer)
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        let row = Exercise(name: "坐姿 Cable 划船", category: .horizontalPull, equipment: .cable)
        [bench, row].forEach(context.insert)
        let current = try #require(launcher.start(.init(exercises: [bench]), context: context))
        let first = current.orderedItems[0].orderedSets[0]
        first.weightKg = 40; first.reps = 5; first.isCompleted = true; first.completedAt = .now
        launcher.coordinator.isExpanded = false
        return Fixture(context: context, launcher: launcher, timer: timer, bench: bench, row: row, current: current)
    }

    @Test func cancellingThePlanLeavesTheCurrentWorkoutAlone() throws {
        // T2：有進行中的訓練 → 先問；選「建立新菜單」還不結束；在建立菜單裡取消，原本的訓練完全不受影響
        let f = try makeFixture()
        let setCount = f.current.items.flatMap(\.sets).count
        f.launcher.requestPlan(context: f.context)
        #expect(f.launcher.planWithActive != nil && f.launcher.planRequest == nil)
        f.launcher.openPlanKeepingCurrent()
        #expect(f.launcher.planRequest != nil && f.launcher.planWithActive == nil)
        #expect(f.current.isActive)
        // 按「開始訓練」：先等確認，還沒結束
        #expect(f.launcher.start(.init(exercises: [f.row], dayType: .meUpper, origin: .plan), context: f.context) == nil)
        #expect(f.launcher.pendingStart?.origin == .plan && f.current.isActive)
        // 取消確認，再取消建立菜單
        f.launcher.cancelPendingStart()
        f.launcher.planRequest = nil
        f.launcher.sheetDismissed()
        #expect(f.current.isActive && f.current.items.flatMap(\.sets).count == setCount)
        #expect(f.current.orderedItems[0].orderedSets.map(\.isCompleted) == [true, false, false])
        #expect(try f.context.fetchCount(FetchDescriptor<WorkoutSession>()) == 1)
        #expect(!f.launcher.coordinator.isExpanded)
    }

    @Test func confirmingEndsTheCurrentWorkoutStopsTheRestAndStarts() throws {
        let f = try makeFixture()
        f.timer.start(seconds: 90)
        f.launcher.start(.init(exercises: [f.row], dayType: .meUpper, origin: .plan), context: f.context)
        let started = try #require(f.launcher.confirmPendingStart(context: f.context))
        // 舊訓練結束（未完成的組刪除），休息倒數不延續，新的訓練開始；sheet 關掉後才展開
        #expect(f.current.endedAt != nil && f.current.orderedItems[0].sets.count == 1)
        #expect(!f.timer.isRunning)
        #expect(started.isActive && started.dayType == .meUpper && WorkoutActions.activeSession(in: f.context) === started)
        #expect(f.launcher.planRequest == nil && !f.launcher.coordinator.isExpanded)
        f.launcher.sheetDismissed()
        #expect(f.launcher.coordinator.isExpanded)
    }

    @Test func continueCurrentOpensTheWorkout() throws {
        let f = try makeFixture()
        f.launcher.requestPlan(context: f.context)
        f.launcher.continueCurrent()
        #expect(f.launcher.planWithActive == nil && f.launcher.planRequest == nil && f.launcher.coordinator.isExpanded)
    }

    @Test func withoutAnActiveWorkoutThePlanOpensDirectly() throws {
        let f = try makeFixture()
        WorkoutActions.discard(f.current, in: f.context)
        f.launcher.requestPlan(context: f.context)
        #expect(f.launcher.planRequest != nil && f.launcher.planWithActive == nil)
        let session = try #require(f.launcher.start(.init(openAdd: true, origin: .plan), context: f.context))
        // 自由選動作：沒有日型、沒有動作，展開時打開新增動作
        #expect(session.dayType == nil && session.items.isEmpty)
        f.launcher.sheetDismissed()
        #expect(f.launcher.coordinator.isExpanded && f.launcher.coordinator.openAddOnExpand)
    }

    @Test func repeatCarriesRolesAndDayType() throws {
        let f = try makeFixture()
        let squat = Exercise(name: "深蹲", category: .kneeDominant, tags: [.main], equipment: .barbell)
        let curl = Exercise(name: "二頭彎舉", category: .accessory, equipment: .dumbbell)
        [squat, curl].forEach(f.context.insert)
        WorkoutActions.finish(f.current, choice: .deleteIncomplete, in: f.context)
        let past = WorkoutActions.start(with: [squat, curl], roles: [.dynamicEffort, .core], dayType: .deLower, in: f.context)
        past.items.flatMap(\.sets).forEach { $0.weightKg = 60; $0.reps = 2; $0.isCompleted = true }
        WorkoutActions.finish(past, choice: .deleteIncomplete, in: f.context)
        f.launcher.repeatSession(past, origin: .root, context: f.context)
        let again = try #require(WorkoutActions.activeSession(in: f.context))
        #expect(again.orderedItems.map { $0.exercise?.name } == ["深蹲", "二頭彎舉"])
        #expect(again.orderedItems.map(\.role) == [.dynamicEffort, .core])
        #expect(again.dayType == .deLower && f.launcher.coordinator.isExpanded)
    }
}
