import SwiftUI
import SwiftData

@main
struct LiftLogApp: App {
    private let container = LiftLogStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
