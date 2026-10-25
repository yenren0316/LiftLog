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

extension StartWorkoutIntent {
    func perform() async throws -> some IntentResult { .result() }
}
