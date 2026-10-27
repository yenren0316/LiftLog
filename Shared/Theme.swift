import SwiftUI
import UIKit

// 配色系統（CHANGE_04 第 6 節）：所有顏色都集中在這個檔案，畫面只用 Theme 的 token。
// 這個檔案在 Shared 資料夾，App 和小工具（CHANGE_05）共用；畫面元件在 App 的 Theme/Components.swift。

/// 一個主題的 12 個顏色（0xRRGGBB）
nonisolated struct Palette: Equatable, Sendable {
    /// 頁面底色
    var background: UInt32
    /// 卡片與分區
    var card: UInt32
    /// 輸入框和未選取的 chip
    var field: UInt32
    /// 分隔線
    var separator: UInt32
    var textPrimary: UInt32
    var textSecondary: UInt32
    /// 主要按鈕、選取狀態、圖表線條、分頁列的強調色
    var accent: UInt32
    /// accent 上面的文字顏色
    var onAccent: UInt32
    /// 完成的組（整列底色用 18% 透明度，打勾符號用原色）
    var done: UInt32
    /// 超過 60 天、MAX 標記
    var warning: UInt32
    /// 超過 180 天、刪除
    var danger: UInt32
    /// 上肢（日曆格子、訓練頻率長條；下肢用 accent）。色相和 accent 明顯不同、亮度相近（CHANGE_08 §4）
    var upperBody: UInt32 = 0x4FA3FF
    /// 可以點的卡片和列按下時的底色（CHANGE_10 §4）：比卡片亮，和輸入框分得開
    var pressed: UInt32 = 0x2F3035

    /// 依 background / card / field / separator / textPrimary / textSecondary / accent / onAccent / done / warning / danger 的順序
    init(_ hex: [UInt32]) {
        precondition(hex.count == 11)
        (background, card, field, separator, textPrimary, textSecondary) = (hex[0], hex[1], hex[2], hex[3], hex[4], hex[5])
        (accent, onAccent, done, warning, danger) = (hex[6], hex[7], hex[8], hex[9], hex[10])
    }

    /// 亮色的底（例如即時動態按鈕的顏色）配黑字，暗色配白字
    static func isLight(_ hex: UInt32) -> Bool {
        let r = Double((hex >> 16) & 0xFF), g = Double((hex >> 8) & 0xFF), b = Double(hex & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.6
    }

    var tokens: [(name: String, hex: UInt32)] {
        [("background", background), ("card", card), ("field", field), ("separator", separator),
         ("textPrimary", textPrimary), ("textSecondary", textSecondary), ("accent", accent), ("onAccent", onAccent),
         ("done", done), ("warning", warning), ("danger", danger), ("upperBody", upperBody), ("pressed", pressed)]
    }
}

/// 主題：都用石墨深灰的底，只換強調色（accent 和 accent 上的文字顏色）
nonisolated enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case graphiteOrange, graphiteBlue, graphitePurple, graphitePink, graphiteCyan, graphiteSilver

    static let storageKey = "theme.id"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .graphiteOrange: "石墨橙"
        case .graphiteBlue: "石墨藍"
        case .graphitePurple: "石墨紫"
        case .graphitePink: "石墨粉"
        case .graphiteCyan: "石墨青"
        case .graphiteSilver: "石墨銀"
        }
    }

    /// 石墨深灰的底；accent、onAccent、upperBody 由各主題決定
    private static let graphite = Palette([0x111214, 0x1B1C1F, 0x2A2B30, 0x34363B, 0xF3F3F4, 0x9C9DA3,
                                           0xFF8A3D, 0x111214, 0x3FB97C, 0xF2C14E, 0xEF5350])

    var palette: Palette {
        var palette = Self.graphite
        (palette.accent, palette.onAccent, palette.upperBody) = switch self {
        case .graphiteOrange: (0xFF8A3D, 0x111214, 0x4FA3FF)   // 上肢：天藍
        case .graphiteBlue: (0x4C7DF0, 0xFFFFFF, 0xE07A35)     // 上肢：橘
        case .graphitePurple: (0xA683FF, 0x111214, 0x2EC4D6)   // 上肢：青
        case .graphitePink: (0xFF6B9D, 0x111214, 0x4FA3FF)     // 上肢：天藍
        case .graphiteCyan: (0x2EC4D6, 0x111214, 0xB48CFF)     // 上肢：淡紫
        case .graphiteSilver: (0xE6E6E6, 0x111214, 0x9BCBFF)   // 上肢：淺藍（銀色沒有色相，用有彩度的藍）
        }
        return palette
    }

    /// 讀存起來的主題 id。CHANGE_04 的舊主題換成強調色相近的新主題（午夜藍、冷灰 → 藍，純黑 → 銀），
    /// 其他或讀不到時用石墨橙。小工具讀快照時也用這個，App 還沒開過的舊快照一樣能對應
    init(stored raw: String?) {
        switch raw {
        case "midnightBlue", "coolGray": self = .graphiteBlue
        case "pureBlack": self = .graphiteSilver
        default: self = raw.flatMap(AppTheme.init(rawValue:)) ?? .graphiteOrange
        }
    }

    /// 目前的主題
    static func load(_ defaults: UserDefaults = .standard) -> AppTheme {
        AppTheme(stored: defaults.string(forKey: storageKey))
    }

    /// 啟動時把 CHANGE_04 的主題設定換成新的：跟隨系統外觀時用當時選的深色主題，再刪掉不用的設定
    static func migrateLegacySettings(_ defaults: UserDefaults = .standard) {
        let followSystem = "theme.followSystem", dark = "theme.dark", light = "theme.light"
        let stored = defaults.bool(forKey: followSystem)
            ? defaults.string(forKey: dark) ?? "midnightBlue"
            : defaults.string(forKey: storageKey)
        if let stored { defaults.set(AppTheme(stored: stored).rawValue, forKey: storageKey) }
        [followSystem, dark, light].forEach(defaults.removeObject(forKey:))
    }
}

/// 畫面使用的顏色 token：依目前主題動態決定
enum Theme {
    static let background = token { $0.background }
    static let card = token { $0.card }
    static let field = token { $0.field }
    static let separator = token { $0.separator }
    static let textPrimary = token { $0.textPrimary }
    static let textSecondary = token { $0.textSecondary }
    static let accent = token { $0.accent }
    static let onAccent = token { $0.onAccent }
    static let done = token { $0.done }
    static let warning = token { $0.warning }
    static let danger = token { $0.danger }
    static let upperBody = token { $0.upperBody }
    static let pressed = token { $0.pressed }

    static let cardRadius: CGFloat = 28

    /// SwiftUI 在 iPhone 上可能從背景的繪製執行緒取色（例如動畫中），所以取色的 closure 不能綁在主執行緒：
    /// App target 預設是 MainActor，Swift 6 會在執行時檢查，不在主執行緒就閃退。
    /// 每次取色都重新讀主題，換主題後重建畫面就會拿到新顏色
    nonisolated private static func token(_ value: @escaping @Sendable (Palette) -> UInt32) -> Color {
        Color(uiColor: UIColor { _ in UIColor(hex: value(AppTheme.load().palette)) })
    }
}

nonisolated extension Color {
    /// 0xRRGGBB
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

nonisolated extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
