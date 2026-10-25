import SwiftUI
import SwiftData

@main
struct LiftLogApp: App {
    private let container = LiftLogStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.green)
        }
        .modelContainer(container)
    }
}
