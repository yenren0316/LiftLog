import SwiftUI
import SwiftData

@main
struct LiftLogApp: App {
    private let container = LiftLogStore.container

    init() {
        AppTheme.migrateLegacySettings()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
