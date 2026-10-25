import Foundation
import Testing
@testable import LiftLog

/// CHANGE_05 第 3 節：深層連結
@MainActor
struct DeepLinkTests {
    @Test func parsesOnlyOurLinks() {
        #expect(DeepLink(url: URL(string: "liftlog://new")!) == .new)
        #expect(DeepLink(url: URL(string: "liftlog://workout")!) == .workout)
        #expect(DeepLink(url: URL(string: "LiftLog://Workout")!) == .workout)
        #expect(DeepLink(url: URL(string: "liftlog://settings")!) == nil)
        #expect(DeepLink(url: URL(string: "https://new")!) == nil)
        #expect(DeepLink.new.url.absoluteString == "liftlog://new")
        #expect(DeepLink.workout.url.absoluteString == "liftlog://workout")
    }

    @Test func newOpensPlanOrTheActiveWorkout() {
        #expect(DeepLink.new.destination(hasActiveWorkout: false) == .plan)
        #expect(DeepLink.new.destination(hasActiveWorkout: true) == .workout)
    }

    @Test func workoutOpensTheActiveWorkoutOrHome() {
        #expect(DeepLink.workout.destination(hasActiveWorkout: true) == .workout)
        #expect(DeepLink.workout.destination(hasActiveWorkout: false) == .home)
    }

    @Test func routerKeepsOnlyValidLinks() {
        let router = DeepLinkRouter()
        router.open(URL(string: "liftlog://unknown")!)
        #expect(router.pending == nil)
        router.open(URL(string: "liftlog://new")!)
        #expect(router.pending == .new)
    }
}
