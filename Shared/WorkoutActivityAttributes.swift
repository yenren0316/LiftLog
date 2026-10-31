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
        /// 下一組（CHANGE_16 §1）：依動作順序，第一個還沒打勾的組；全部打勾時這幾個欄位為 nil
        var exerciseName: String?
        var roleTitle: String?
        var roleSymbol: String?
        /// 第幾組（從 1 開始）／這個動作共幾組
        var setNumber: Int
        var setCount: Int
        /// 下一組的 id：「完成這組」帶著它，只完成這一組（CHANGE_16 §1）。選填：舊的即時動態沒有也能解碼
        var setID: String?
        /// 這一組會記錄的值（已填的值，沒填用灰字預填），例如「32.5 kg × 3」（SetFormat.single）
        var value: String?
        /// 這些值夠不夠直接完成這組；不夠時沒有按鈕，改成「打開 App 填寫」
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

        /// 「下一組：臥推・第 3／8 組」；全部打勾時為 nil
        var nextSetText: String? { exerciseName.map { "下一組：\($0)・\(setText)" } }

        static let completeTitle = "完成這組"
        static let needsInputText = "打開 App 填寫"
        static let allDoneText = "全部完成，打開 App 結束訓練"
        static let noSetsText = "打開 App 加入動作"

        /// 即時動態現在是哪一種狀態（CHANGE_16 §1）；鎖定畫面、動態島的展開、縮小、最小都依它顯示
        enum Phase: Equatable {
            /// 休息中（倒數的區間）：「跳過休息」「+15 秒」，沒有「完成這組」
            case resting(ClosedRange<Date>)
            /// 下一組可以直接完成：主要按鈕「完成這組」帶著這一組的 id
            case ready(setID: String)
            /// 下一組沒有可以記錄的值：沒有按鈕，次要文字「打開 App 填寫」
            case needsInput
            /// 全部的組都完成：「全部完成，打開 App 結束訓練」，沒有按鈕
            case allDone
            /// 這次訓練還沒有任何組（自由選動作、還沒加入動作）
            case noSets
        }

        /// 全部打勾時不管有沒有在休息都是全部完成（最後一組完成時不開始休息，CHANGE_16 §1）
        func phase(isStale: Bool) -> Phase {
            guard hasCurrentSet else { return totalSets == 0 ? .noSets : .allDone }
            if let rest = restInterval(isStale: isStale) { return .resting(rest) }
            if canComplete, let setID { return .ready(setID: setID) }
            return .needsInput
        }

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
