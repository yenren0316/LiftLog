import AppIntents

/// App Shortcut「開始訓練」：Siri 和捷徑都能用（語句要包含 App 名稱）
nonisolated struct LiftLogShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "用 \(.applicationName) 開始訓練",
                "在 \(.applicationName) 開始訓練",
                "\(.applicationName) 開始訓練",
            ],
            shortTitle: "開始訓練",
            systemImageName: "dumbbell.fill"
        )
    }
}
