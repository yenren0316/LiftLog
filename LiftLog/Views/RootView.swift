import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            Tab("該練什麼", systemImage: "dumbbell.fill") {
                HomeView()
            }
            Tab("今日", systemImage: "calendar") {
                TodayView()
            }
            Tab("動作庫", systemImage: "list.bullet.rectangle") {
                LibraryView()
            }
            Tab("設定", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .task { SeedImporter.importIfNeeded(into: context) }
    }
}

#Preview {
    RootView().preferredColorScheme(.dark)
}
