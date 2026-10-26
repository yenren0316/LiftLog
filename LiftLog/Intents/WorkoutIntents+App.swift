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

extension StartWorkoutIntent {
    /// App 已經被系統帶到前景，交給深層連結導向
    nonisolated func perform() async throws -> some IntentResult {
        await MainActor.run {
            // 小工具那邊如果也留了連結，一起清掉，避免重複打開
            _ = PendingDeepLink.consume()
            DeepLinkRouter.shared.pending = .new
        }
        return .result()
    }
}
