import AppIntents

// 即時動態按鈕的實際動作：系統在 App 的程序裡執行，直接透過 WorkoutService 改資料，再更新即時動態。
// DEBUG 時每一次執行都寫進診斷紀錄（CHANGE_17 §2-2，IntentDiagnostics）：開始、成功或失敗

extension CompleteSetIntent {
    nonisolated func perform() async throws -> some IntentResult {
        #if DEBUG
        await IntentDiagnostics.begin("完成這組", parameters: "setID=\(setID)")
        #endif
        let result = await WorkoutIntentActions.completeSet(id: setID)
        #if DEBUG
        await IntentDiagnostics.end("完成這組", parameters: "setID=\(setID)", succeeded: result == .completed,
                                    result: "\(result)")
        #endif
        return .result()
    }
}

extension SkipRestIntent {
    nonisolated func perform() async throws -> some IntentResult {
        #if DEBUG
        await IntentDiagnostics.begin("跳過休息")
        let wasResting = await RestTimer.shared.isRunning
        #endif
        await WorkoutIntentActions.skipRest()
        #if DEBUG
        await IntentDiagnostics.end("跳過休息", succeeded: wasResting, result: wasResting ? "已跳過" : "沒有在休息，沒有作用")
        #endif
        return .result()
    }
}

extension ExtendRestIntent {
    nonisolated func perform() async throws -> some IntentResult {
        #if DEBUG
        await IntentDiagnostics.begin("+15 秒")
        let wasResting = await RestTimer.shared.isRunning
        #endif
        await WorkoutIntentActions.extendRest()
        #if DEBUG
        await IntentDiagnostics.end("+15 秒", succeeded: wasResting, result: wasResting ? "已延後" : "沒有在休息，沒有作用")
        #endif
        return .result()
    }
}

enum WorkoutIntentActions {
    /// 只完成這一組（和 App 裡打勾同一個函式）；已經完成、不在了或沒有值時不改資料。不管結果如何都更新即時動態
    @discardableResult
    static func completeSet(id: String) async -> WorkoutService.CompleteResult {
        let result = WorkoutService.shared.completeSet(id: id)
        await LiveActivityController.shared.sync()
        return result
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
