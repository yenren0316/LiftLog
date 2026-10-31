import AppIntents
import Foundation
import SwiftData
import Testing
@testable import LiftLog

/// CHANGE_16 §1：即時動態的「完成這組」。intent 帶著即時動態顯示的下一組的 id，
/// 用和 App 裡打勾同一個函式（WorkoutService.complete）完成，沿用灰字預填、還有下一組時開始休息
@MainActor
struct CompleteSetIntentTests {
    final class FakeNotifications: RestNotifying {
        var scheduled: [Date] = []
        func schedule(at endDate: Date) { scheduled.append(endDate) }
        func cancel() {}
    }

    @MainActor
    struct Fixture {
        var context: ModelContext
        var service: WorkoutService
        var notifications: FakeNotifications
        var exercises: [String: Exercise]

        subscript(name: String) -> Exercise { exercises[name]! }

        /// 即時動態現在的內容（沒有在休息時傳 nil）
        func state(rest: ClosedRange<Date>? = nil, unit: WeightUnit = .kg) -> WorkoutActivityState {
            WorkoutActivityState.make(session: WorkoutActions.activeSession(in: context)!, rest: rest, unit: unit)
        }

        /// 休息計時器現在的區間
        var rest: ClosedRange<Date>? {
            service.restTimer.startDate.flatMap { start in service.restTimer.endDate.map { start...$0 } }
        }

        /// 按即時動態的「完成這組」：帶著即時動態顯示的那一組的 id
        @discardableResult
        func pressComplete() -> WorkoutService.CompleteResult {
            service.completeSet(id: state(rest: rest).setID ?? "")
        }
    }

    /// 三天前的一次訓練裡每種組各一組（灰字預填的來源）；滑輪下拉從沒做過。之後開一次訓練：names 依序
    private func makeFixture(_ names: [String]) throws -> Fixture {
        let container = try ModelContainer(for: LiftLogStore.schema,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let all = [
            Exercise(name: "臥推", category: .horizontalPush, equipment: .barbell),
            // 輔助引體向上：重量型、自重器材，輔助量記成負重（−20 kg）
            Exercise(name: "輔助引體向上", category: .verticalPull, equipment: .bodyweight),
            Exercise(name: "雙槓撐", category: .verticalPush, equipment: .bodyweight, logType: .assisted),
            Exercise(name: "反式划船", category: .horizontalPull, equipment: .bodyweight, logType: .bodyweight),
            Exercise(name: "棒式", category: .core, equipment: .bodyweight, logType: .timed),
            Exercise(name: "跑步機", category: .cardio, equipment: .other, logType: .cardio),
            Exercise(name: "滑輪下拉", category: .verticalPull, equipment: .cable),
        ]
        for exercise in all { context.insert(exercise) }
        let exercises = Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })

        let start = Date.now.addingTimeInterval(-3 * 86_400)
        let past = WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(3600))
        context.insert(past)
        let history: [(String, [SetValues])] = [
            ("臥推", [SetValues(weightKg: 30, reps: 3), SetValues(weightKg: 32.5, reps: 3), SetValues(weightKg: 32.5, reps: 3)]),
            ("輔助引體向上", [SetValues(weightKg: -20, reps: 5)]),
            ("雙槓撐", [SetValues(weightKg: 19, reps: 5)]),
            ("反式划船", [SetValues(reps: 12)]),
            ("棒式", [SetValues(seconds: 45)]),
            ("跑步機", [SetValues(incline: 12, speed: 5.5, minutes: 30)]),
        ]
        for (order, (name, sets)) in history.enumerated() {
            let item = SessionExercise(session: past, exercise: exercises[name]!, order: order)
            context.insert(item)
            for (i, v) in sets.enumerated() {
                context.insert(SetRecord(sessionExercise: item, order: i, weightKg: v.weightKg, reps: v.reps, incline: v.incline,
                                         speed: v.speed, minutes: v.minutes, seconds: v.seconds,
                                         isCompleted: true, completedAt: start))
            }
        }
        try context.save()

        let defaults = try #require(UserDefaults(suiteName: "CompleteSetIntentTests.\(UUID().uuidString)"))
        let notifications = FakeNotifications()
        let service = WorkoutService(context: context, restTimer: RestTimer(defaults: defaults, notifications: notifications),
                                     defaults: defaults)
        WorkoutActions.start(with: names.map { exercises[$0]! }, in: context)
        return Fixture(context: context, service: service, notifications: notifications, exercises: exercises)
    }

    private func sets(_ f: Fixture) -> [SetRecord] {
        WorkoutActions.activeSession(in: f.context)!.orderedItems.flatMap(\.orderedSets)
    }

    // MARK: - 下一組的選擇

    @Test func nextSetIsTheFirstUncheckedSetInOrderAcrossExercises() throws {
        let f = try makeFixture(["臥推", "滑輪下拉"])
        let all = sets(f)
        #expect(all.count == 6)   // 臥推照上次 3 組，滑輪下拉沒有紀錄 3 組
        var state = f.state()
        #expect(state.setID == all[0].id.uuidString)
        #expect(state.nextSetText == "下一組：臥推・第 1／3 組")

        // 先在 App 裡打勾第 2 組：下一組還是第 1 組（依順序第一個沒打勾的）
        #expect(f.service.complete(all[1]))
        state = f.state()
        #expect(state.setID == all[0].id.uuidString && state.nextSetText == "下一組：臥推・第 1／3 組")

        // 第 1、3 組完成後，換到下一個動作的第 1 組
        #expect(f.pressComplete() == .completed)
        #expect(f.state().nextSetText == "下一組：臥推・第 3／3 組")
        #expect(f.pressComplete() == .completed)
        state = f.state()
        #expect(state.setID == all[3].id.uuidString)
        #expect(state.nextSetText == "下一組：滑輪下拉・第 1／3 組")
    }

    // MARK: - 記錄的值

    /// 已填的值優先，沒填用灰字預填；即時動態顯示的值、按「完成這組」記錄的值、App 裡打勾記錄的值三者完全相同
    @Test func recordedValueIsEnteredFirstThenPrefillSameAsTheAppCheck() throws {
        let lock = try makeFixture(["臥推"])
        let app = try makeFixture(["臥推"])
        for f in [lock, app] {
            // 第 1 組只填了 kg，次數沿用灰字預填的 3；第 2 組沒填，全部用預填
            sets(f)[0].weightKg = 35
        }

        for index in 0..<2 {
            let shown = lock.state()
            #expect(lock.pressComplete() == .completed)
            #expect(app.service.complete(sets(app)[index]))
            let recordedByLock = sets(lock)[index].values
            let recordedByApp = sets(app)[index].values
            #expect(recordedByLock.weightKg == recordedByApp.weightKg && recordedByLock.reps == recordedByApp.reps)
            #expect(recordedByLock.isCompleted && recordedByApp.isCompleted)
            #expect(shown.value == SetFormat.single(recordedByLock, logType: .weight, unit: .kg))
        }
        #expect(sets(lock)[0].weightKg == 35 && sets(lock)[0].reps == 3)
        #expect(sets(lock)[1].weightKg == 32.5 && sets(lock)[1].reps == 3)
        // 兩邊所有的組（包括還沒打勾的第 3 組）都一樣
        #expect(sets(lock).map { [$0.weightKg, $0.reps.map(Double.init)] } == sets(app).map { [$0.weightKg, $0.reps.map(Double.init)] })
        #expect(sets(lock).map(\.isCompleted) == sets(app).map(\.isCompleted))
    }

    @Test func shownValueFollowsWhatIsEntered() throws {
        let f = try makeFixture(["臥推"])
        #expect(f.state().value == "30 kg × 3")
        sets(f)[0].reps = 5
        #expect(f.state().value == "30 kg × 5")
        #expect(f.state(unit: .lbs).value == "66 lbs × 5")
    }

    // MARK: - 沒有可以記錄的值

    @Test func noRecordableValueCannotCompleteAndAsksToOpenTheApp() throws {
        let f = try makeFixture(["滑輪下拉"])
        let state = f.state()
        #expect(state.value == nil && !state.canComplete)
        #expect(state.phase(isStale: false) == .needsInput)
        #expect(WorkoutActivityState.needsInputText == "打開 App 填寫")
        // 就算 intent 被執行了也不會完成
        #expect(f.service.completeSet(id: try #require(state.setID)) == .cannotComplete)
        #expect(sets(f).allSatisfy { !$0.isCompleted })
        #expect(!f.service.restTimer.isRunning)

        // 只填了 kg（沒有次數）也一樣
        sets(f)[0].weightKg = 40
        let partial = f.state()
        #expect(partial.value == "40 kg" && partial.phase(isStale: false) == .needsInput)
        // 填了次數就可以完成
        sets(f)[0].reps = 10
        #expect(f.state().phase(isStale: false) == .ready(setID: sets(f)[0].id.uuidString))
    }

    // MARK: - 完成後休息

    @Test func completingStartsRestAndTheActivityRests() throws {
        let f = try makeFixture(["臥推", "滑輪下拉"])
        let first = sets(f)[0]
        #expect(f.state().phase(isStale: false) == .ready(setID: first.id.uuidString))
        #expect(f.pressComplete() == .completed)
        #expect(first.isCompleted && first.weightKg == 30 && first.reps == 3)
        // 臥推的角色是「推」：休息 90 秒，並排程休息結束的通知
        let rest = try #require(f.rest)
        #expect(f.service.restTimer.duration == 90)
        #expect(f.notifications.scheduled == [rest.upperBound])
        let state = f.state(rest: rest)
        #expect(state.phase(isStale: false) == .resting(rest))
        // 休息時下一組照樣顯示，沒有「完成這組」
        #expect(state.nextSetText == "下一組：臥推・第 2／3 組")
        // 休息結束（系統把內容標成過期）後回到下一組和「完成這組」
        #expect(state.phase(isStale: true) == .ready(setID: sets(f)[1].id.uuidString))
    }

    @Test func autoRestOffCompletesWithoutRest() throws {
        let f = try makeFixture(["臥推"])
        f.service.restTimer.skip()
        let defaults = try #require(UserDefaults(suiteName: "CompleteSetIntentTests.off.\(UUID().uuidString)"))
        defaults.set(false, forKey: WorkoutService.autoRestKey)
        let service = WorkoutService(context: f.context, restTimer: f.service.restTimer, defaults: defaults)
        #expect(service.completeSet(id: f.state().setID ?? "") == .completed)
        #expect(!service.restTimer.isRunning)
    }

    // MARK: - 全部完成

    @Test func lastSetShowsAllDone() throws {
        let f = try makeFixture(["輔助引體向上", "跑步機"])
        #expect(f.pressComplete() == .completed)
        // 還有下一組（跑步機）：開始休息
        let rest = try #require(f.rest)
        #expect(f.state(rest: rest).phase(isStale: false) == .resting(rest))

        #expect(f.pressComplete() == .completed)
        // 最後一組：沒有下一組，不再開始新的休息（剛才那次休息的結束時間不變）
        #expect(f.rest == rest)
        #expect(f.notifications.scheduled.count == 1)
        // 就算前一組的休息還在倒數，即時動態也是全部完成，沒有按鈕
        let state = f.state(rest: f.rest)
        #expect(state.phase(isStale: false) == .allDone)
        #expect(state.setID == nil && state.nextSetText == nil)
        #expect(state.completedSets == 2 && state.totalSets == 2)
        #expect(WorkoutActivityState.allDoneText == "全部完成，打開 App 結束訓練")
    }

    @Test func lastSetCheckedInTheAppDoesNotStartRestEither() throws {
        let f = try makeFixture(["棒式"])
        #expect(f.service.complete(sets(f)[0]))
        #expect(!f.service.restTimer.isRunning)
        #expect(f.state().phase(isStale: false) == .allDone)
    }

    @Test func workoutWithoutSetsIsNotAllDone() throws {
        let f = try makeFixture([])
        #expect(f.state().phase(isStale: false) == .noSets)
        #expect(f.pressComplete() == .notFound)
    }

    // MARK: - 防止重複

    @Test func alreadyCompletedSetIsNotCompletedAgain() throws {
        let f = try makeFixture(["臥推", "滑輪下拉"])
        let shown = f.state()
        // 即時動態顯示第 1 組時，先在 App 裡打勾了
        #expect(f.service.complete(sets(f)[0]))
        let restBefore = f.rest
        let scheduledBefore = f.notifications.scheduled
        let before = sets(f).map(\.values)

        // 即時動態還沒更新，按下的「完成這組」帶著第 1 組的 id：不完成任何一組，也不重新開始休息
        #expect(f.service.completeSet(id: try #require(shown.setID)) == .alreadyCompleted)
        #expect(sets(f).map(\.values) == before)
        #expect(f.rest == restBefore && f.notifications.scheduled == scheduledBefore)
        // 更新後的即時動態顯示第 2 組
        #expect(f.state().nextSetText == "下一組：臥推・第 2／3 組")

        // 不在這次訓練裡的 id（組被刪掉了）也不改任何資料
        #expect(f.service.completeSet(id: UUID().uuidString) == .notFound)
        #expect(sets(f).map(\.values) == before)
    }

    @Test func intentCarriesTheSetIDAndNeedsNoUnlock() {
        let intent = CompleteSetIntent(setID: "A1B2")
        #expect(intent.setID == "A1B2")
        #expect(CompleteSetIntent.authenticationPolicy == .alwaysAllowed)
    }

    // MARK: - 各種組的值的格式

    /// 和 App 的訓練畫面一樣的欄位順序和單位；重量和摘要同一個寫法（WorkoutUnit 的顯示精度、負重的「+」、輔助的「輔助」）
    @Test func valueFormatForEveryKindOfSet() {
        let single = SetFormat.single
        // 重量型
        #expect(single(SetValues(weightKg: 32.5, reps: 3), .weight, .kg) == "32.5 kg × 3")
        #expect(single(SetValues(weightKg: 60, reps: 5), .weight, .lbs) == "132.5 lbs × 5")
        // 輔助引體向上：重量型的負重量，和 App 的灰字預填、上一次、摘要一樣是系統數字格式的負號
        #expect(single(SetValues(weightKg: -20, reps: 5), .weight, .kg) == "-20 kg × 5")
        #expect(single(SetValues(reps: 8), .weight, .kg) == "8 下")
        // 輔助型（雙槓撐）
        #expect(single(SetValues(weightKg: 19, reps: 5), .assisted, .kg) == "輔助 19 kg × 5")
        #expect(single(SetValues(weightKg: 0, reps: 5), .assisted, .kg) == "自重 × 5")
        // 自重
        #expect(single(SetValues(reps: 12), .bodyweight, .kg) == "12 下")
        #expect(single(SetValues(weightKg: 10, reps: 12), .bodyweight, .kg) == "+10 kg × 12")
        // 計時
        #expect(single(SetValues(seconds: 45), .timed, .kg) == "45 秒")
        #expect(single(SetValues(weightKg: 24, seconds: 60), .timed, .kg) == "+24 kg × 60 秒")
        // 跑步機
        #expect(single(SetValues(minutes: 30), .cardio, .kg) == "30 分鐘")
        #expect(single(SetValues(incline: 12, speed: 5.5, minutes: 30), .cardio, .kg) == "坡度 12・速度 5.5・30 分鐘")
        #expect(single(SetValues(), .weight, .kg) == nil)
        #expect(single(SetValues(), .cardio, .kg) == nil)
    }

    /// 實際的訓練：每一種組的下一組都顯示那一組會記錄的值，按「完成這組」記錄的就是它
    @Test func everyKindOfSetCompletesWithTheShownValue() throws {
        let f = try makeFixture(["輔助引體向上", "雙槓撐", "反式划船", "棒式", "跑步機"])
        let expected = ["-20 kg × 5", "輔助 19 kg × 5", "12 下", "45 秒", "坡度 12・速度 5.5・30 分鐘"]
        for (index, text) in expected.enumerated() {
            let state = f.state(rest: f.rest)
            #expect(state.value == text)
            #expect(state.canComplete)
            let set = sets(f)[index]
            #expect(state.setID == set.id.uuidString)
            #expect(f.pressComplete() == .completed)
            let logType = try #require(set.sessionExercise?.exercise?.logType)
            #expect(SetFormat.single(set.values, logType: logType, unit: .kg) == text)
        }
        #expect(f.state(rest: f.rest).phase(isStale: false) == .allDone)
    }
}
