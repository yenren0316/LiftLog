import SwiftUI
import SwiftData

@main
struct LiftLogApp: App {
    private let container = LiftLogStore.container

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
