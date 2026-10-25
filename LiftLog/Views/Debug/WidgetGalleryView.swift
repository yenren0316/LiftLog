#if DEBUG
import SwiftUI

/// 開發用：把小工具和即時動態的畫面（Shared 裡同一份程式碼）以系統的尺寸排出來截圖。
/// 啟動參數 -widgetGallery small｜lock｜live
struct WidgetGalleryView: View {
    var page: String
    @Environment(\.colorScheme) private var colorScheme

    private static let smallSize = CGSize(width: 170, height: 170)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch page {
                case "lock":
                    lockPage
                default:
                    smallPage
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(wallpaper.ignoresSafeArea())
    }

    // MARK: - 小型小工具

    private var smallPage: some View {
        LazyVGrid(columns: [GridItem(.fixed(Self.smallSize.width), spacing: 22),
                            GridItem(.fixed(Self.smallSize.width))], alignment: .leading, spacing: 18) {
            labeled("上次訓練") { small(Self.trained) }
            labeled("今天練過") { small(Self.trainedToday) }
            labeled("還沒有紀錄") { small(Self.never) }
            labeled("訓練中") { small(Self.inProgress) }
        }
    }

    private func small(_ snapshot: WidgetSnapshot) -> some View {
        let p = WidgetSnapshot.palette(for: snapshot, isDark: colorScheme == .dark)
        return LastWorkoutSmallView(snapshot: snapshot, date: .now)
            .padding(16)
            .frame(width: Self.smallSize.width, height: Self.smallSize.height)
            .background(Color(hex: p.background), in: .rect(cornerRadius: 24, style: .continuous))
    }

    // MARK: - 鎖定畫面小工具（系統以單色顯示，這裡用白色模擬）

    private var lockPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            lockRow("上次訓練 2 天前", Self.trained)
            lockRow("今天練過", Self.trainedToday)
            lockRow("訓練中", Self.inProgress)
            lockRow("還沒有紀錄", Self.never)
        }
        .foregroundStyle(.white)
    }

    private func lockRow(_ title: String, _ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
            LastWorkoutInlineView(snapshot: snapshot, date: .now)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 14) {
                LastWorkoutCircularView(snapshot: snapshot, date: .now)
                    .frame(width: 76, height: 76)
                    .background(.white.opacity(0.18), in: .circle)
                LastWorkoutRectangularView(snapshot: snapshot, date: .now)
                    .frame(width: 172, height: 76)
            }
        }
    }

    private func labeled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 6) {
            content()
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white)
        }
    }

    private var wallpaper: some View {
        LinearGradient(colors: [Color(hex: 0x2B3A67), Color(hex: 0x0E1A2B)], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - 範例快照

    private static func snapshot(daysAgo: Int?, inProgressMinutes: Int? = nil) -> WidgetSnapshot {
        var s = WidgetSnapshot.sample
        s.lastSessionDate = daysAgo.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now) }
        s.lastRegion = daysAgo == nil ? nil : .upper
        if let minutes = inProgressMinutes {
            s.isInProgress = true
            s.startedAt = Date.now.addingTimeInterval(TimeInterval(-minutes * 60 - 17))
        }
        return s
    }

    static let trained = snapshot(daysAgo: 2)
    static let trainedToday = snapshot(daysAgo: 0)
    static let never = snapshot(daysAgo: nil)
    static let inProgress = snapshot(daysAgo: 2, inProgressMinutes: 32)
}
#endif
