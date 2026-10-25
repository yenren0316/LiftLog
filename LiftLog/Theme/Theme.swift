import SwiftUI
import UIKit

// 配色系統（CHANGE_04 第 6 節）：所有顏色都集中在這個檔案，畫面只用 Theme 的 token。

/// 一個主題的 11 個顏色（0xRRGGBB）
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

    /// 依 background / card / field / separator / textPrimary / textSecondary / accent / onAccent / done / warning / danger 的順序
    init(_ hex: [UInt32]) {
        precondition(hex.count == 11)
        (background, card, field, separator, textPrimary, textSecondary) = (hex[0], hex[1], hex[2], hex[3], hex[4], hex[5])
        (accent, onAccent, done, warning, danger) = (hex[6], hex[7], hex[8], hex[9], hex[10])
    }

    var tokens: [(name: String, hex: UInt32)] {
        [("background", background), ("card", card), ("field", field), ("separator", separator),
         ("textPrimary", textPrimary), ("textSecondary", textSecondary), ("accent", accent), ("onAccent", onAccent),
         ("done", done), ("warning", warning), ("danger", danger)]
    }
}

nonisolated enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case graphiteOrange, midnightBlue, pureBlack, warmSand, coolGray

    static let storageKey = "theme.id"
    static let followSystemKey = "theme.followSystem"
    static let darkKey = "theme.dark"
    static let lightKey = "theme.light"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .graphiteOrange: "石墨橙"
        case .midnightBlue: "午夜藍"
        case .pureBlack: "純黑"
        case .warmSand: "暖砂"
        case .coolGray: "冷灰"
        }
    }

    var subtitle: String {
        switch self {
        case .graphiteOrange, .midnightBlue: "深色"
        case .pureBlack: "深色，適合 OLED"
        case .warmSand, .coolGray: "淺色"
        }
    }

    var isDark: Bool {
        switch self {
        case .graphiteOrange, .midnightBlue, .pureBlack: true
        case .warmSand, .coolGray: false
        }
    }

    var palette: Palette {
        switch self {
        case .graphiteOrange:
            Palette([0x111214, 0x1B1C1F, 0x2A2B30, 0x34363B, 0xF3F3F4, 0x9C9DA3, 0xFF8A3D, 0x111214, 0x3FB97C, 0xF2C14E, 0xEF5350])
        case .midnightBlue:
            Palette([0x0B1220, 0x141D30, 0x1F2A40, 0x2A3650, 0xE8EDF6, 0x8B97AD, 0x4C7DF0, 0xFFFFFF, 0x2BB673, 0xF3B63F, 0xF06262])
        case .pureBlack:
            Palette([0x000000, 0x111111, 0x1E1E1E, 0x2A2A2A, 0xFFFFFF, 0x8E8E93, 0xE6E6E6, 0x000000, 0x34C759, 0xFFCC00, 0xFF453A])
        case .warmSand:
            Palette([0xF6F1EA, 0xFFFFFF, 0xEFE7DC, 0xE2D8CA, 0x2B2622, 0x7D7368, 0xC2602F, 0xFFFFFF, 0x3E8E5E, 0xB8860B, 0xC0392B])
        case .coolGray:
            Palette([0xF2F4F7, 0xFFFFFF, 0xE9EDF2, 0xDDE2E8, 0x1A1F26, 0x6B7480, 0x2F6FEB, 0xFFFFFF, 0x1F9D63, 0xC98A0B, 0xD64545])
        }
    }

    static var darkThemes: [AppTheme] { allCases.filter(\.isDark) }
    static var lightThemes: [AppTheme] { allCases.filter { !$0.isDark } }
}

/// 主題設定（AppStorage）：預設石墨橙；跟隨系統外觀時預設午夜藍／冷灰
nonisolated struct ThemeSettings: Equatable, Sendable {
    var theme: AppTheme = .graphiteOrange
    var followSystem = false
    var dark: AppTheme = .midnightBlue
    var light: AppTheme = .coolGray

    static func load(_ defaults: UserDefaults = .standard) -> ThemeSettings {
        var settings = ThemeSettings()
        if let raw = defaults.string(forKey: AppTheme.storageKey), let theme = AppTheme(rawValue: raw) { settings.theme = theme }
        settings.followSystem = defaults.bool(forKey: AppTheme.followSystemKey)
        if let raw = defaults.string(forKey: AppTheme.darkKey), let theme = AppTheme(rawValue: raw) { settings.dark = theme }
        if let raw = defaults.string(forKey: AppTheme.lightKey), let theme = AppTheme(rawValue: raw) { settings.light = theme }
        return settings
    }

    /// 目前要用的主題；跟隨系統時依系統深淺
    func active(systemIsDark: Bool) -> AppTheme {
        followSystem ? (systemIsDark ? dark : light) : theme
    }

    /// 讓鍵盤、sheet 等系統元件的深淺和主題一致；跟隨系統時不指定
    var colorScheme: ColorScheme? {
        followSystem ? nil : (theme.isDark ? .dark : .light)
    }

    /// 設定改變時用來重建畫面
    var key: String { [theme.rawValue, String(followSystem), dark.rawValue, light.rawValue].joined(separator: ",") }
}

/// 畫面使用的顏色 token：依目前主題（或跟隨系統時依深淺）動態決定
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

    static let cardRadius: CGFloat = 28

    private static func token(_ value: @escaping @Sendable (Palette) -> UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let theme = ThemeSettings.load().active(systemIsDark: traits.userInterfaceStyle == .dark)
            return UIColor(hex: value(theme.palette))
        })
    }
}

extension Color {
    /// 0xRRGGBB
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.separator.opacity(0.6)))
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View {
        modifier(CardModifier(padding: padding))
    }

    /// 頁面共用的背景與文字顏色
    func screenBackground() -> some View {
        foregroundStyle(Theme.textPrimary)
            .background(Theme.background.ignoresSafeArea())
    }
}

/// 細長膠囊進度條，fraction 介於 0...1
struct ThinBar: View {
    var fraction: Double
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.field)
                Capsule()
                    .fill(color)
                    .frame(width: max(8, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 8)
    }
}

/// 右上角的圓形按鈕
struct CircleIconButton: View {
    var systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 48, height: 48)
                .background(Theme.card, in: .circle)
                .overlay(Circle().stroke(Theme.separator))
        }
    }
}

/// 頁面大標題列：左邊標題、右邊可選的按鈕
struct ScreenHeader<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.largeTitle.bold())
            Spacer()
            trailing
        }
        .padding(.horizontal, 4)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

extension Staleness {
    var color: Color {
        switch self {
        case .never: Theme.danger
        case .fresh: Theme.done
        case .stale: Theme.warning
        case .cold: Theme.danger
        }
    }
}

extension Date {
    /// 2026/10/20
    var shortDate: String {
        formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }
}

/// 「全部／單邊／爆發」膠囊篩選列
struct TagFilterBar: View {
    @Binding var selection: TagFilter

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TagFilter.allCases) { filter in
                let selected = filter == selection
                Button { selection = filter } label: {
                    Text(filter.title)
                        .font(.headline)
                        .foregroundStyle(selected ? Theme.onAccent : Theme.textPrimary)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 40)
                        .background(selected ? Theme.accent : Theme.field, in: .capsule)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}

/// 小膠囊標籤（分類、tags）
struct Chip: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Theme.field, in: .capsule)
    }
}
