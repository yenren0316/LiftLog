import ActivityKit
import Foundation

/// 即時動態的資料（CHANGE_05 第 6-2 節）。App 用 ActivityKit 直接更新，不經過 App Group。
nonisolated struct WorkoutActivityAttributes: ActivityAttributes, Sendable {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        /// 訓練名稱（鎖定畫面）
        var title: String
        /// 動態島展開時左上角的日型簡稱（「DE 上肢」，CHANGE_11 §6）；沒有日型為 nil，顯示「訓練」。
        /// 選填：舊版 App 建立的即時動態沒有這個欄位也能解碼
        var dayTypeTitle: String?
        var startedAt: Date
        /// 目前的組：依動作順序，第一個還沒打勾的組；全部打勾時這幾個欄位為 nil
        var exerciseName: String?
        var roleTitle: String?
        var roleSymbol: String?
        /// 第幾組（從 1 開始）／這個動作共幾組
        var setNumber: Int
        var setCount: Int
        /// 這一組的預填值，例如「60 kg × 5」
        var target: String?
        /// 預填值夠不夠直接完成這組；不夠時按鈕改成打開 App
        var canComplete: Bool
        /// 進度：已完成組數／總組數
        var completedSets: Int
        var totalSets: Int
        /// 休息中：開始與結束時間；沒在休息時為 nil
        var restStartDate: Date?
        var restEndDate: Date?

        var hasCurrentSet: Bool { exerciseName != nil }

        /// 動態島展開時左上角：日型簡稱，沒有日型時「訓練」（不顯示完整的訓練名稱）
        var islandTitle: String { dayTypeTitle ?? Self.islandTitle(dayType: nil) }

        static func islandTitle(dayType: DayType?) -> String {
            dayType?.title ?? "訓練"
        }

        /// 「第 2／5 組」
        var setText: String { "第 \(setNumber)／\(setCount) 組" }

        /// 休息倒數的區間；休息結束後系統把內容標成過期（staleDate），就不再算休息中
        func restInterval(isStale: Bool) -> ClosedRange<Date>? {
            guard !isStale, let restStartDate, let restEndDate, restStartDate < restEndDate else { return nil }
            return restStartDate...restEndDate
        }
    }

    var sessionID: String
    /// 開始時的主題顏色（0xRRGGBB）
    var accent: UInt32
    var done: UInt32
}
