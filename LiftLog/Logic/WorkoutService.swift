import Foundation
import SwiftData

/// 訓練中的操作，訓練中畫面和即時動態的按鈕（LiveActivityIntent，在 App 的程序裡執行）共用，
/// 兩邊操作的結果一致；因為用的是同一個資料庫 context 和休息計時器，App 畫面開著時也會即時反映（CHANGE_05 第 6-5 節）
@MainActor
final class WorkoutService {
    static let shared = WorkoutService(context: LiftLogStore.container.mainContext, restTimer: .shared)

    static let autoRestKey = "autoRestTimer"

    let context: ModelContext
    let restTimer: RestTimer
    private let defaults: UserDefaults

    init(context: ModelContext, restTimer: RestTimer, defaults: UserDefaults = .standard) {
        self.context = context
        self.restTimer = restTimer
        self.defaults = defaults
    }

    /// 打勾後開始休息倒數（設定頁可關閉）：秒數依角色，動作有自訂時以自訂為準
    func startRest(after item: SessionExercise) {
        guard defaults.object(forKey: Self.autoRestKey) as? Bool ?? true else { return }
        restTimer.start(seconds: item.restSeconds)
    }

    /// 「完成這組」：目前的組採用預填值打勾，效果和在 App 裡沒輸入數字直接按 ✓ 一樣，完成後開始休息。
    /// 沒有進行中的訓練、全部打勾，或預填值不夠完成時回傳 false，不做任何改變
    @discardableResult
    func completeCurrentSet() -> Bool {
        guard let session = WorkoutActions.activeSession(in: context), let current = session.currentSet else { return false }
        let placeholder = current.item.setHints().first { $0.set === current.set }?.placeholder
        guard WorkoutActions.complete(current.set, placeholder: placeholder, in: context) else { return false }
        startRest(after: current.item)
        return true
    }

    /// 「跳過休息」：清掉倒數，並取消休息結束的通知
    func skipRest() {
        restTimer.skip()
    }

    /// 「+15 秒」：延後休息結束時間，並重新排程通知
    func extendRest(by seconds: TimeInterval = 15) {
        restTimer.adjust(by: seconds)
    }
}
