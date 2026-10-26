import Foundation

/// 深層連結（CHANGE_05 第 3 節）：小工具、即時動態、控制項打開 App 時使用
nonisolated enum DeepLink: String, Sendable {
    /// 建立菜單（帶入預設答案）；有進行中的訓練時先問「繼續目前訓練／建立新菜單」
    case new
    /// 打開進行中的訓練；沒有的話回到「今天」
    case workout
    /// 切到「今天」分頁並回到第 1 層（CHANGE_07 D-3：沒有訓練時點小工具）
    case today

    static let scheme = "liftlog"

    var url: URL { URL(string: "\(Self.scheme)://\(rawValue)")! }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let host = url.host()?.lowercased(),
              let link = DeepLink(rawValue: host)
        else { return nil }
        self = link
    }
}
