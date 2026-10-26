import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_05 第 6 節：目前的組、即時動態按鈕（完成這組、跳過休息、+15 秒）和本機通知
@MainActor
struct WorkoutServiceTests {
    /// 記錄休息通知的排程與取消
    final class FakeNotifications: RestNotifying {
        var scheduled: [Date] = []
        var cancelCount = 0
        func schedule(at endDate: Date) { scheduled.append(endDate) }
        func cancel() { cancelCount += 1 }
    }

    struct Fixture {
        var context: ModelContext
        var service: WorkoutService
        var notifications: FakeNotifications
        var defaults: UserDefaults
        var session: WorkoutSession
        var bench: Exercise
        var pulldown: Exercise
    }

    /// 臥推上次做了 60 kg × 5 兩組；滑輪下拉從沒做過。開一次訓練：臥推（2 組）＋滑輪下拉（3 組）
    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(for: LiftLogStore.schema,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let bench = Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell)
        let pulldown = Exercise(name: "滑輪下拉", category: .verticalPull, equipment: .cable)
        context.insert(bench)
        context.insert(pulldown)
        let start = Date.now.addingTimeInterval(-3 * 86_400)
        let past = WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(3600))
        context.insert(past)
        let item = SessionExercise(session: past, exercise: bench, order: 0)
        context.insert(item)
        for i in 0..<2 {
            context.insert(SetRecord(sessionExercise: item, order: i, weightKg: 60, reps: 5, isCompleted: true, completedAt: start))
        }
        try context.save()

        let defaults = try #require(UserDefaults(suiteName: "WorkoutServiceTests.\(UUID().uuidString)"))
        let notifications = FakeNotifications()
        let timer = RestTimer(defaults: defaults, notifications: notifications)
        let service = WorkoutService(context: context, restTimer: timer, defaults: defaults)
        let session = WorkoutActions.start(with: [bench, pulldown], in: context)
        return Fixture(context: context, service: service, notifications: notifications, defaults: defaults,
                       session: session, bench: bench, pulldown: pulldown)
    }

    // MARK: - 目前的組

    @Test func currentSetCrossesExercises() {
        let position = SetLogic.currentSet([[true, true], [true, false, false]])
        #expect(position?.item == 1 && position?.set == 1)
        // 沒有組的動作跳過
        let skipEmpty = SetLogic.currentSet([[], [false]])
        #expect(skipEmpty?.item == 1 && skipEmpty?.set == 0)
        // 前面的動作有漏掉的組，先回到那一組
        let gap = SetLogic.currentSet([[true, false], [true]])
        #expect(gap?.item == 0 && gap?.set == 1)
    }

    @Test func allCompletedHasNoCurrentSet() {
        #expect(SetLogic.currentSet([[true, true], [true]]) == nil)
        #expect(SetLogic.currentSet([]) == nil)
    }

    @Test func sessionCurrentSetMovesToTheNextExercise() throws {
        let f = try makeFixture()
        let current = try #require(f.session.currentSet)
        #expect(current.item.exercise === f.bench && current.index == 0)
        for set in f.session.orderedItems[0].orderedSets { set.isCompleted = true }
        let next = try #require(f.session.currentSet)
        #expect(next.item.exercise === f.pulldown && next.index == 0)
        for set in f.session.orderedItems[1].orderedSets { set.isCompleted = true }
        #expect(f.session.currentSet == nil)
    }

    // MARK: - 完成這組

    @Test func completeUsesPrefillAndStartsRestByRole() throws {
        let f = try makeFixture()
        #expect(f.service.completeCurrentSet())
        let first = f.session.orderedItems[0].orderedSets[0]
        #expect(first.isCompleted && first.completedAt != nil)
        #expect(first.weightKg == 60 && first.reps == 5)
        // 臥推的角色是「推」：休息 90 秒，並排程休息結束的通知
        let end = try #require(f.service.restTimer.endDate)
        #expect(f.service.restTimer.duration == 90)
        #expect(f.notifications.scheduled == [end])

        // 第二次完成第二組
        #expect(f.service.completeCurrentSet())
        #expect(f.session.orderedItems[0].orderedSets[1].isCompleted)
        #expect(f.session.currentSet?.item.exercise === f.pulldown)
    }

    @Test func completeUsesTheExercisesOwnRestSeconds() throws {
        let f = try makeFixture()
        f.bench.restSeconds = 120
        #expect(f.service.completeCurrentSet())
        #expect(f.service.restTimer.duration == 120)
    }

    @Test func completeRespectsTheAutoRestSetting() throws {
        let f = try makeFixture()
        f.defaults.set(false, forKey: WorkoutService.autoRestKey)
        #expect(f.service.completeCurrentSet())
        #expect(!f.service.restTimer.isRunning)
        #expect(f.notifications.scheduled.isEmpty)
    }

    @Test func completeWithoutPrefillChangesNothing() throws {
        let f = try makeFixture()
        for set in f.session.orderedItems[0].orderedSets { set.isCompleted = true }
        // 滑輪下拉沒有上一次紀錄，也還沒輸入，無法直接完成
        #expect(!f.service.completeCurrentSet())
        #expect(f.session.orderedItems[1].orderedSets.allSatisfy { !$0.isCompleted })
        #expect(!f.service.restTimer.isRunning)
    }

    @Test func completeKeepsWhatWasEntered() throws {
        let f = try makeFixture()
        let first = f.session.orderedItems[0].orderedSets[0]
        first.weightKg = 62.5
        #expect(f.service.completeCurrentSet())
        // 有輸入用輸入，沒輸入的欄位用預填
        #expect(first.weightKg == 62.5 && first.reps == 5)
    }

    // MARK: - 跳過休息、+15 秒

    @Test func skipRestClearsTheTimerAndCancelsTheNotification() throws {
        let f = try makeFixture()
        f.service.restTimer.start(seconds: 90)
        f.service.skipRest()
        #expect(f.service.restTimer.endDate == nil)
        #expect(f.notifications.cancelCount == 1)
        #expect(f.notifications.scheduled.count == 1)
    }

    @Test func extendRestMovesTheEndAndReschedules() throws {
        let f = try makeFixture()
        f.service.restTimer.start(seconds: 90)
        let end = try #require(f.service.restTimer.endDate)
        f.service.extendRest()
        #expect(f.service.restTimer.endDate == end.addingTimeInterval(15))
        #expect(f.service.restTimer.duration == 105)
        #expect(f.notifications.scheduled == [end, end.addingTimeInterval(15)])
    }

    @Test func extendRestWithoutRestDoesNothing() throws {
        let f = try makeFixture()
        f.service.extendRest()
        #expect(f.service.restTimer.endDate == nil)
        #expect(f.notifications.scheduled.isEmpty)
    }

    // MARK: - 即時動態的內容

    @Test func activityStateShowsTheCurrentSet() throws {
        let f = try makeFixture()
        var state = WorkoutActivityState.make(session: f.session, rest: nil, unit: .kg)
        #expect(state.exerciseName == "臥推" && state.roleTitle == "推")
        #expect(state.setText == "第 1／2 組")
        #expect(state.target == "60 kg × 5" && state.canComplete)
        #expect(state.completedSets == 0 && state.totalSets == 5)
        #expect(state.restInterval(isStale: false) == nil)

        #expect(f.service.completeCurrentSet())
        let rest = try #require(f.service.restTimer.startDate.flatMap { s in f.service.restTimer.endDate.map { s...$0 } })
        state = WorkoutActivityState.make(session: f.session, rest: rest, unit: .lbs)
        #expect(state.setText == "第 2／2 組")
        #expect(state.target == "132.5 lbs × 5")
        #expect(state.completedSets == 1)
        #expect(state.restInterval(isStale: false) == rest)
        // 休息結束後系統標成過期，就不算休息中
        #expect(state.restInterval(isStale: true) == nil)
    }

    @Test func activityStateWithoutPrefillAsksToOpenTheApp() throws {
        let f = try makeFixture()
        for set in f.session.orderedItems[0].orderedSets { set.isCompleted = true }
        let state = WorkoutActivityState.make(session: f.session, rest: nil, unit: .kg)
        #expect(state.exerciseName == "滑輪下拉" && state.setText == "第 1／3 組")
        #expect(state.target == nil && !state.canComplete)
    }

    @Test func targetText() {
        let target = WorkoutActivityState.target
        #expect(target(SetValues(weightKg: 19, reps: 5), .assisted, .kg) == "輔助 19 kg × 5")
        #expect(target(SetValues(reps: 8), .bodyweight, .kg) == "8 下")
        #expect(target(SetValues(seconds: 30), .timed, .kg) == "30 秒")
        #expect(target(SetValues(incline: 12, speed: 5.5, minutes: 30), .cardio, .kg) == "坡度 12・速度 5.5・30 分鐘")
        #expect(target(SetValues(), .weight, .kg) == nil)
    }
}
