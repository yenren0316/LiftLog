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
            #expect(tokens.count == 11, "\(theme)")
            #expect(Set(tokens.map(\.name)).count == 11, "\(theme)")
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
            (palette.accent, palette.onAccent) = (base.accent, base.onAccent)
            #expect(palette == base, "\(theme)")
        }
        #expect(Set(AppTheme.allCases.map(\.palette.accent)).count == AppTheme.allCases.count)
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
}
