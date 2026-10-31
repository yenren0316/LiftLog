import AppIntents

// 即時動態的按鈕（CHANGE_05 第 6-5 節）。LiveActivityIntent 由系統在 App 的程序裡執行，可以直接改 SwiftData：
// 實際的 perform 在 App 的 Intents/WorkoutIntents+App.swift；小工具 target 只放空的實作
// （LiftLogWidgets/WorkoutIntents+Widget.swift），讓按鈕可以引用這些型別。

/// 完成這組（CHANGE_16 §1）：帶著即時動態顯示的那一組的 id，用和 App 裡打勾同一個函式完成（沿用灰字預填，
/// 還有下一組時開始休息）。那一組已經完成（例如已經在 App 裡打勾、即時動態還沒更新）或不在了時，不完成任何一組，只更新即時動態。
/// 鎖定畫面不用解鎖就能執行（authenticationPolicy 是系統的預設 alwaysAllowed，這裡寫明）。
/// 有 @Parameter 的型別不能整個標 nonisolated（Swift 6 不允許 nonisolated 的 @Parameter 屬性），
/// 改成協定的符合標 nonisolated，系統會用到的成員各自標 nonisolated
struct CompleteSetIntent: nonisolated LiveActivityIntent {
    nonisolated static let title: LocalizedStringResource = "完成這組"
    nonisolated static let isDiscoverable = false
    nonisolated static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "組")
    var setID: String

    nonisolated init() {}

    init(setID: String) {
        self.setID = setID
    }
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
