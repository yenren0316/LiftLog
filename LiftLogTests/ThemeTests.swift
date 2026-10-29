import Foundation
import SwiftUI
import UIKit
import Testing
@testable import LiftLog

struct ThemeTests {
    @Test func everyThemeHasEveryToken() {
        #expect(AppTheme.allCases.count == 6)
        for theme in AppTheme.allCases {
            let tokens = theme.palette.tokens
            #expect(tokens.count == 14, "\(theme)")
            #expect(Set(tokens.map(\.name)).count == 14, "\(theme)")
            #expect(tokens.allSatisfy { $0.hex <= 0xFFFFFF }, "\(theme)")
        }
    }

    @Test func paletteValuesFollowTheSpecOrder() {
        let orange = AppTheme.graphiteOrange.palette
        #expect(orange.background == 0x111214 && orange.accent == 0xFF8A3D && orange.danger == 0xEF5350)
        let blue = AppTheme.graphiteBlue.palette
        #expect(blue.accent == 0x4C7DF0 && blue.onAccent == 0xFFFFFF)
    }

    @Test func everyThemeSharesTheGraphiteBase() {
        let base = AppTheme.graphiteOrange.palette
        for theme in AppTheme.allCases {
            var palette = theme.palette
            (palette.accent, palette.onAccent, palette.lowerBody, palette.upperBody) = (base.accent, base.onAccent, base.lowerBody, base.upperBody)
            #expect(palette == base, "\(theme)")
        }
        #expect(Set(AppTheme.allCases.map(\.palette.accent)).count == AppTheme.allCases.count)
    }

    /// 色相（0–360）和彩度（HSV）
    static func hsv(_ hex: UInt32) -> (hue: Double, saturation: Double) {
        let r = Double((hex >> 16) & 0xFF) / 255, g = Double((hex >> 8) & 0xFF) / 255, b = Double(hex & 0xFF) / 255
        let maxV = max(r, g, b), minV = min(r, g, b), delta = maxV - minV
        guard delta > 0 else { return (0, 0) }
        var hue: Double
        if maxV == r { hue = (g - b) / delta } else if maxV == g { hue = (b - r) / delta + 2 } else { hue = (r - g) / delta + 4 }
        hue = (hue * 60).truncatingRemainder(dividingBy: 360)
        return (hue < 0 ? hue + 360 : hue, delta / maxV)
    }

    /// 兩個顏色的色相差（0–180）
    static func hueGap(_ a: UInt32, _ b: UInt32) -> Double {
        let gap = abs(hsv(a).hue - hsv(b).hue)
        return min(gap, 360 - gap)
    }

    static func brightness(_ hex: UInt32) -> Double {
        let r = Double((hex >> 16) & 0xFF), g = Double((hex >> 8) & 0xFF), b = Double(hex & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255
    }

    /// WCAG 2 的對比度
    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        func luminance(_ hex: UInt32) -> Double {
            func channel(_ v: UInt32) -> Double {
                let c = Double(v) / 255
                return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel((hex >> 16) & 0xFF) + 0.7152 * channel((hex >> 8) & 0xFF) + 0.0722 * channel(hex & 0xFF)
        }
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// CHANGE_13 §3：兩個部位色和該主題的強調色、warning 色都清楚可分（色相差至少 40 度；銀色沒有色相，部位色要有彩度），
    /// 兩個部位色之間至少 60 度、亮度相近，在深色底上清楚
    @Test func bodyColorsAreDistinctFromAccentAndWarning() {
        for theme in AppTheme.allCases {
            let p = theme.palette
            for (name, body) in [("lowerBody", p.lowerBody), ("upperBody", p.upperBody)] {
                #expect(Self.hsv(body).saturation >= 0.35, "\(theme) \(name)")
                if Self.hsv(p.accent).saturation >= 0.1 {
                    #expect(Self.hueGap(body, p.accent) >= 40, "\(theme) \(name) 和 accent 差 \(Self.hueGap(body, p.accent)) 度")
                }
                #expect(Self.hueGap(body, p.warning) >= 40, "\(theme) \(name) 和 warning 差 \(Self.hueGap(body, p.warning)) 度")
                #expect(Self.brightness(body) - Self.brightness(p.background) >= 0.45, "\(theme) \(name)")
            }
            #expect(Self.hueGap(p.lowerBody, p.upperBody) >= 60, "\(theme)")
            #expect(abs(Self.brightness(p.lowerBody) - Self.brightness(p.upperBody)) <= 0.15, "\(theme)")
        }
    }

    /// CHANGE_13 §3：次要文字和背景（頁面、卡片、輸入框）的對比度至少 4.5:1
    @Test func secondaryTextHasEnoughContrast() {
        for theme in AppTheme.allCases {
            let p = theme.palette
            for (name, background) in [("background", p.background), ("card", p.card), ("field", p.field)] {
                let ratio = Self.contrast(p.textSecondary, background)
                #expect(ratio >= 4.5, "\(theme) textSecondary 在 \(name) 上只有 \(ratio):1")
            }
        }
    }

    @Test func storedIDsIncludingLegacyThemes() throws {
        #expect(AppTheme(stored: nil) == .graphiteOrange)
        #expect(AppTheme(stored: "graphitePurple") == .graphitePurple)
        #expect(AppTheme(stored: "midnightBlue") == .graphiteBlue)
        #expect(AppTheme(stored: "coolGray") == .graphiteBlue)
        #expect(AppTheme(stored: "pureBlack") == .graphiteSilver)
        #expect(AppTheme(stored: "warmSand") == .graphiteOrange)
        #expect(AppTheme(stored: "nonsense") == .graphiteOrange)

        let defaults = try #require(UserDefaults(suiteName: "ThemeTests.\(UUID().uuidString)"))
        #expect(AppTheme.load(defaults) == .graphiteOrange)
        defaults.set("graphitePink", forKey: AppTheme.storageKey)
        #expect(AppTheme.load(defaults) == .graphitePink)
    }

    @Test func migratesLegacySettings() throws {
        let defaults = try #require(UserDefaults(suiteName: "ThemeTests.\(UUID().uuidString)"))
        // 沒設定過：維持沒有設定（用預設的石墨橙）
        AppTheme.migrateLegacySettings(defaults)
        #expect(defaults.string(forKey: AppTheme.storageKey) == nil)

        // 固定主題
        defaults.set("pureBlack", forKey: AppTheme.storageKey)
        AppTheme.migrateLegacySettings(defaults)
        #expect(defaults.string(forKey: AppTheme.storageKey) == "graphiteSilver")

        // 跟隨系統外觀：用當時的深色主題，舊設定刪掉
        defaults.set("warmSand", forKey: AppTheme.storageKey)
        defaults.set(true, forKey: "theme.followSystem")
        defaults.set("midnightBlue", forKey: "theme.dark")
        defaults.set("coolGray", forKey: "theme.light")
        AppTheme.migrateLegacySettings(defaults)
        #expect(defaults.string(forKey: AppTheme.storageKey) == "graphiteBlue")
        #expect(defaults.object(forKey: "theme.followSystem") == nil)
        #expect(defaults.object(forKey: "theme.dark") == nil && defaults.object(forKey: "theme.light") == nil)

        // 再跑一次不會變
        AppTheme.migrateLegacySettings(defaults)
        #expect(defaults.string(forKey: AppTheme.storageKey) == "graphiteBlue")
    }
}

/// iPhone 上 SwiftUI 會在背景的繪製執行緒取色、計算動畫；這些程式碼不能要求在主執行緒（曾因此閃退）
@MainActor
struct OffMainThreadRenderingTests {
    @Test func themeColorsResolveOffTheMainThread() async {
        let colors = [Theme.background, Theme.card, Theme.accent, Theme.done, Theme.textPrimary]
        let resolved = await Task.detached {
            colors.map { UIColor($0).resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)) }
        }.value
        #expect(resolved.count == colors.count)
    }

    @Test func shakeEffectComputesOffTheMainThread() async {
        let transform = await Task.detached {
            Shake(animatableData: 0.125).effectValue(size: CGSize(width: 100, height: 40)).m31
        }.value
        #expect(abs(transform - 8) < 0.001)
    }

    /// CHANGE_10 §4：按壓色比卡片亮、和輸入框分得開，每個主題都有
    @Test func pressedIsVisibleOnCards() {
        for theme in AppTheme.allCases {
            let p = theme.palette
            #expect(ThemeTests.brightness(p.pressed) - ThemeTests.brightness(p.card) >= 0.06, "\(theme)")
            #expect(p.pressed != p.field && p.pressed != p.separator, "\(theme)")
        }
    }
}
