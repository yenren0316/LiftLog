import AppIntents

// 即時動態按鈕的實際動作：系統在 App 的程序裡執行，直接透過 WorkoutService 改資料，再更新即時動態

extension CompleteSetIntent {
    nonisolated func perform() async throws -> some IntentResult {
        await WorkoutIntentActions.completeSet()
        return .result()
    }
}

extension SkipRestIntent {
    nonisolated func perform() async throws -> some IntentResult {
        await WorkoutIntentActions.skipRest()
        return .result()
    }
}

extension ExtendRestIntent {
    nonisolated func perform() async throws -> some IntentResult {
        await WorkoutIntentActions.extendRest()
        return .result()
    }
}

enum WorkoutIntentActions {
    static func completeSet() async {
        WorkoutService.shared.completeCurrentSet()
        await LiveActivityController.shared.sync()
    }

    static func skipRest() async {
        WorkoutService.shared.skipRest()
        await LiveActivityController.shared.sync()
    }

    static func extendRest() async {
        WorkoutService.shared.extendRest()
        await LiveActivityController.shared.sync()
    }
}
