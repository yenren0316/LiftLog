import AppIntents

// 即時動態的按鈕（CHANGE_05 第 6-5 節）。LiveActivityIntent 由系統在 App 的程序裡執行，可以直接改 SwiftData：
// 實際的 perform 在 App 的 Intents/WorkoutIntents+App.swift；小工具 target 只放空的實作
// （LiftLogWidgets/WorkoutIntents+Widget.swift），讓按鈕可以引用這些型別。

/// 完成這組：目前的組採用預填值，完成後依角色開始休息
nonisolated struct CompleteSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "完成這組"
    static let isDiscoverable = false
}

/// 跳過休息：清掉倒數並取消休息結束的通知
nonisolated struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "跳過休息"
    static let isDiscoverable = false
}

/// 休息加 15 秒，並重新排程通知
nonisolated struct ExtendRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "休息加 15 秒"
    static let isDiscoverable = false
}

/// 開始訓練：控制中心、動作按鈕、Siri、捷徑和小工具的＋共用。
/// 打開 App，行為和 liftlog://new 相同：進入建立菜單；有進行中的訓練時先問「繼續目前訓練／建立新菜單」
nonisolated struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "開始訓練"
    static let description = IntentDescription("打開 LiftLog 建立今天的菜單；有進行中的訓練時先問要繼續還是建立新菜單。")
    static let supportedModes: IntentModes = .foreground(.immediate)
}
