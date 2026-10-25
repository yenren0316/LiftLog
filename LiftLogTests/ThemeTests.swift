import Foundation
import SwiftUI
import UIKit
import Testing
@testable import LiftLog

struct ThemeTests {
    @Test func everyThemeHasEveryToken() {
        #expect(AppTheme.allCases.count == 5)
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
        let sand = AppTheme.warmSand.palette
        #expect(sand.card == 0xFFFFFF && sand.textPrimary == 0x2B2622 && sand.done == 0x3E8E5E)
        #expect(AppTheme.pureBlack.palette.onAccent == 0x000000)
    }

    @Test func darkAndLightGroups() {
        #expect(AppTheme.darkThemes == [.graphiteOrange, .midnightBlue, .pureBlack])
        #expect(AppTheme.lightThemes == [.warmSand, .coolGray])
    }

    @Test func settingsDefaultsAndFollowSystem() throws {
        let defaults = try #require(UserDefaults(suiteName: "ThemeTests.\(UUID().uuidString)"))
        var settings = ThemeSettings.load(defaults)
        #expect(settings == ThemeSettings(theme: .graphiteOrange, followSystem: false, dark: .midnightBlue, light: .coolGray))
        #expect(settings.colorScheme == .dark)
        #expect(settings.active(systemIsDark: false) == .graphiteOrange)

        defaults.set("warmSand", forKey: AppTheme.storageKey)
        settings = ThemeSettings.load(defaults)
        #expect(settings.colorScheme == .light)

        defaults.set(true, forKey: AppTheme.followSystemKey)
        settings = ThemeSettings.load(defaults)
        #expect(settings.colorScheme == nil)
        #expect(settings.active(systemIsDark: true) == .midnightBlue)
        #expect(settings.active(systemIsDark: false) == .coolGray)
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
