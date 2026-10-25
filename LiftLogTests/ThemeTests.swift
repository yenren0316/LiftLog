import Foundation
import SwiftUI
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
