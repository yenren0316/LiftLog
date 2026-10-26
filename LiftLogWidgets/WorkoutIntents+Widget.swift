import AppIntents

// 系統在 App 的程序裡執行這些 LiveActivityIntent（見 Shared/WorkoutIntents.swift），
// 小工具 target 只需要型別讓按鈕可以引用，這裡的實作不會被呼叫

extension CompleteSetIntent {
    func perform() async throws -> some IntentResult { .result() }
}

extension SkipRestIntent {
    func perform() async throws -> some IntentResult { .result() }
}

extension ExtendRestIntent {
    func perform() async throws -> some IntentResult { .result() }
}

/// 「開始訓練」照設計在 App 的程序裡執行（App 的 perform 直接導向建立菜單）。
/// 萬一在小工具的程序執行，先把 liftlog://new 存進 App Group，App 回到前景時接手
extension StartWorkoutIntent {
    func perform() async throws -> some IntentResult {
        PendingDeepLink.store(.new)
        return .result()
    }
}
