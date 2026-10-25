import SwiftUI
import SwiftData

@main
struct LiftLogApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.green)
        }
        .modelContainer(for: [Exercise.self, WorkoutEntry.self, BodyWeight.self])
    }
}
