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
            #expect(tokens.count == 13, "\(theme)")
            #expect(Set(tokens.map(\.name)).count == 13, "\(theme)")
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
            (palette.accent, palette.onAccent, palette.upperBody) = (base.accent, base.onAccent, base.upperBody)
            #expect(palette == base, "\(theme)")
        }
        #expect(Set(AppTheme.allCases.map(\.palette.accent)).count == AppTheme.allCases.count)
    }

    /// CHANGE_08 §4：上肢的顏色和 accent（下肢）色相明顯不同、亮度相近，在深色底上清楚
    @Test func upperBodyIsDistinctFromAccent() {
        func hsv(_ hex: UInt32) -> (hue: Double, saturation: Double) {
            let r = Double((hex >> 16) & 0xFF) / 255, g = Double((hex >> 8) & 0xFF) / 255, b = Double(hex & 0xFF) / 255
            let maxV = max(r, g, b), minV = min(r, g, b), delta = maxV - minV
            guard delta > 0 else { return (0, 0) }
            var hue: Double
            if maxV == r { hue = (g - b) / delta } else if maxV == g { hue = (b - r) / delta + 2 } else { hue = (r - g) / delta + 4 }
            hue = (hue * 60).truncatingRemainder(dividingBy: 360)
            return (hue < 0 ? hue + 360 : hue, delta / maxV)
        }
        func brightness(_ hex: UInt32) -> Double {
            let r = Double((hex >> 16) & 0xFF), g = Double((hex >> 8) & 0xFF), b = Double(hex & 0xFF)
            return (0.299 * r + 0.587 * g + 0.114 * b) / 255
        }
        for theme in AppTheme.allCases {
            let p = theme.palette
            let accent = hsv(p.accent), upper = hsv(p.upperBody)
            if accent.saturation < 0.1 {
                // 銀色沒有色相：上肢要有明顯的彩度
                #expect(upper.saturation >= 0.35, "\(theme)")
            } else {
                let gap = abs(accent.hue - upper.hue)
                #expect(min(gap, 360 - gap) >= 60, "\(theme)")
            }
            #expect(abs(brightness(p.accent) - brightness(p.upperBody)) <= 0.15, "\(theme)")
            #expect(brightness(p.upperBody) - brightness(p.background) >= 0.45, "\(theme)")
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
        func brightness(_ hex: UInt32) -> Double {
            let r = Double((hex >> 16) & 0xFF), g = Double((hex >> 8) & 0xFF), b = Double(hex & 0xFF)
            return (0.299 * r + 0.587 * g + 0.114 * b) / 255
        }
        for theme in AppTheme.allCases {
            let p = theme.palette
            #expect(brightness(p.pressed) - brightness(p.card) >= 0.06, "\(theme)")
            #expect(p.pressed != p.field && p.pressed != p.separator, "\(theme)")
        }
    }
}
