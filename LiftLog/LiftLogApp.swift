import SwiftUI
import SwiftData

@main
struct LiftLogApp: App {
    private let container = LiftLogStore.container

    init() {
        #if DEBUG
        // 開發用（CHANGE_17 §2-2）：App 的程序什麼時候被啟動（例如系統為了執行即時動態的按鈕，在背景啟動 App）
        IntentDiagnostics.record(source: "App 啟動", event: "啟動")
        #endif
        AppTheme.migrateLegacySettings()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
