import Foundation
import Testing
@testable import LiftLog

/// CHANGE_05 第 3 節、CHANGE_07 D-3（T10）：深層連結與小工具的導向
@MainActor
struct DeepLinkTests {
    private func isolatedDefaults() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: "DeepLinkTests.\(UUID().uuidString)"))
    }

    @Test func parsesOnlyOurLinks() {
        #expect(DeepLink(url: URL(string: "liftlog://new")!) == .new)
        #expect(DeepLink(url: URL(string: "liftlog://workout")!) == .workout)
        #expect(DeepLink(url: URL(string: "LiftLog://Workout")!) == .workout)
        #expect(DeepLink(url: URL(string: "liftlog://today")!) == .today)
        #expect(DeepLink(url: URL(string: "liftlog://settings")!) == nil)
        #expect(DeepLink(url: URL(string: "https://new")!) == nil)
        #expect(DeepLink.new.url.absoluteString == "liftlog://new")
        #expect(DeepLink.workout.url.absoluteString == "liftlog://workout")
        #expect(DeepLink.today.url.absoluteString == "liftlog://today")
    }

    @Test func newAlwaysGoesToThePlanFlow() {
        // 有進行中的訓練時由 WorkoutLauncher 先問「繼續目前訓練／建立新菜單」
        #expect(DeepLink.new.destination(hasActiveWorkout: false) == .plan)
        #expect(DeepLink.new.destination(hasActiveWorkout: true) == .plan)
    }

    @Test func workoutOpensTheActiveWorkoutOrToday() {
        #expect(DeepLink.workout.destination(hasActiveWorkout: true) == .workout)
        #expect(DeepLink.workout.destination(hasActiveWorkout: false) == .today)
    }

    @Test func todayAlwaysGoesToTheTodayTab() {
        #expect(DeepLink.today.destination(hasActiveWorkout: false) == .today)
        #expect(DeepLink.today.destination(hasActiveWorkout: true) == .today)
    }

    @Test func routerKeepsOnlyValidLinks() {
        let router = DeepLinkRouter()
        router.open(URL(string: "liftlog://unknown")!)
        #expect(router.pending == nil)
        router.open(URL(string: "liftlog://new")!)
        #expect(router.pending == .new)
    }

    /// 小工具的＋如果在小工具的程序執行，連結留在 App Group；App 回到前景時接手一次就清掉
    @Test func pendingLinkFromTheWidgetIsConsumedOnce() throws {
        let defaults = try isolatedDefaults()
        let router = DeepLinkRouter()
        router.consumePendingLink(from: defaults)
        #expect(router.pending == nil)

        PendingDeepLink.store(.new, in: defaults)
        router.consumePendingLink(from: defaults)
        #expect(router.pending == .new)
        #expect(PendingDeepLink.consume(from: defaults) == nil)

        router.pending = nil
        router.consumePendingLink(from: defaults)
        #expect(router.pending == nil)
    }

    @Test func unknownPendingValueIsIgnoredAndCleared() throws {
        let defaults = try isolatedDefaults()
        defaults.set("settings", forKey: PendingDeepLink.key)
        #expect(PendingDeepLink.consume(from: defaults) == nil)
        #expect(defaults.string(forKey: PendingDeepLink.key) == nil)
    }

    /// 點小工具其他地方：訓練中打開那次訓練，否則回到「今天」
    @Test func widgetTapTarget() {
        var snapshot = WidgetSnapshot.sample
        snapshot.isInProgress = false
        #expect(snapshot.link == .today)
        #expect(snapshot.link.destination(hasActiveWorkout: false) == .today)
        snapshot.isInProgress = true
        snapshot.startedAt = .now
        #expect(snapshot.link == .workout)
        #expect(snapshot.link.destination(hasActiveWorkout: true) == .workout)
    }

    /// 「開始訓練」intent 在 App 的程序裡執行時直接導向建立菜單，並清掉小工具留下的連結
    @Test func startWorkoutIntentOpensThePlanFlow() async throws {
        let router = DeepLinkRouter.shared
        router.pending = nil
        PendingDeepLink.store(.new)
        _ = try await StartWorkoutIntent().perform()
        #expect(router.pending == .new)
        #expect(router.pending?.destination(hasActiveWorkout: false) == .plan)
        #expect(PendingDeepLink.consume() == nil)
        router.pending = nil
    }
}
