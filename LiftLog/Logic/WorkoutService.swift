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

    /// 打勾完成一組（CHANGE_16 §1）：訓練畫面和編輯訓練的 ✓、即時動態的「完成這組」都呼叫這個函式，沒有另外的完成邏輯。
    /// 沒輸入的欄位用灰字預填值（和畫面上同一份 setHints）；必要欄位不齊時不改任何東西，回傳 false。
    /// 進行中的訓練完成後還有下一組時開始休息倒數（設定頁可關閉）；最後一組完成時沒有下一組，不開始
    @discardableResult
    func complete(_ set: SetRecord) -> Bool {
        guard WorkoutActions.complete(set, placeholder: set.placeholder, in: context) else { return false }
        if let item = set.sessionExercise, let session = item.session, session.isActive, session.currentSet != nil {
            startRest(after: item)
        }
        return true
    }

    /// 即時動態「完成這組」的結果
    enum CompleteResult: Equatable {
        case completed
        /// 那一組已經完成（例如已經在 App 裡打勾，即時動態還沒更新）：不完成任何一組
        case alreadyCompleted
        /// 沒有進行中的訓練，或那一組已經不在這次訓練裡
        case notFound
        /// 沒有可以記錄的值（沒填，也沒有灰字預填）
        case cannotComplete
    }

    /// 即時動態的「完成這組」（CHANGE_16 §1）：只處理 intent 帶來的那一組（即時動態顯示的下一組），
    /// 用和 App 裡打勾同一個函式完成；那一組已經完成或不在了時不改任何資料
    @discardableResult
    func completeSet(id: String) -> CompleteResult {
        guard let session = WorkoutActions.activeSession(in: context),
              let set = session.items.flatMap(\.sets).first(where: { $0.id.uuidString == id }) else { return .notFound }
        guard !set.isCompleted else { return .alreadyCompleted }
        return complete(set) ? .completed : .cannotComplete
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
