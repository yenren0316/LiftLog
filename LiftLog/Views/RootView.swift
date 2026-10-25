import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("該練什麼", systemImage: "dumbbell.fill") {
                PlaceholderScreen(title: "該練什麼")
            }
            Tab("今日", systemImage: "calendar") {
                PlaceholderScreen(title: "今日")
            }
            Tab("動作庫", systemImage: "list.bullet.rectangle") {
                PlaceholderScreen(title: "動作庫")
            }
            Tab("設定", systemImage: "gearshape.fill") {
                PlaceholderScreen(title: "設定")
            }
        }
    }
}

private struct PlaceholderScreen: View {
    var title: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: title)
                Text("施工中").foregroundStyle(.secondary).card()
            }
            .padding(16)
        }
        .screenBackground()
    }
}

#Preview {
    RootView().preferredColorScheme(.dark)
}
