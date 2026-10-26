import SwiftUI

// 共用的畫面元件，顏色都用 Theme 的 token（Shared/Theme.swift）

struct CardModifier: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.separator.opacity(0.6)))
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View {
        modifier(CardModifier(padding: padding))
    }

    /// 頁面共用的背景與文字顏色
    func screenBackground() -> some View {
        foregroundStyle(Theme.textPrimary)
            .background(Theme.background.ignoresSafeArea())
    }
}

/// 細長膠囊進度條，fraction 介於 0...1
struct ThinBar: View {
    var fraction: Double
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.field)
                Capsule()
                    .fill(color)
                    .frame(width: max(8, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 8)
    }
}

/// 共用尺寸
enum Metrics {
    /// 主按鈕、選項膠囊、訓練中橫條的高度（全 App 一致）
    static let controlHeight: CGFloat = 50
    /// 篩選膠囊的高度
    static let capsuleHeight: CGFloat = 38
}

/// 主按鈕的外觀（Button 和 ShareLink 共用）：prominent 是 accent 實心，否則是 field 底
struct PrimaryButtonLabel: View {
    var title: String
    var systemImage: String?
    var prominent = true
    var isEnabled = true

    var body: some View {
        Group {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .font(.headline)
        .foregroundStyle(prominent ? Theme.onAccent : Theme.textPrimary)
        .frame(maxWidth: .infinity, minHeight: Metrics.controlHeight)
        .background(prominent ? Theme.accent.opacity(isEnabled ? 1 : 0.4) : Theme.field, in: .capsule)
        .contentShape(.capsule)
    }
}

/// 主按鈕：全 App 只有這一種（CHANGE_07 B-4）
struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var prominent = true
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            PrimaryButtonLabel(title: title, systemImage: systemImage, prominent: prominent, isEnabled: isEnabled)
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
    }
}

/// 篩選或選項用的膠囊：全 App 只有這一種樣式。選中時 accent 底；fill 為 true 時撐滿寬度、高度同主按鈕
struct FilterCapsule: View {
    var title: String
    var isSelected: Bool
    var fill = false
    var action: () -> Void

    var body: some View {
        Button { withAnimation(.tap, action) } label: {
            Text(title)
                .font(fill ? .headline : .subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.textPrimary)
                .padding(.horizontal, 14)
                .frame(maxWidth: fill ? .infinity : nil,
                       minHeight: fill ? Metrics.controlHeight : Metrics.capsuleHeight)
                .background(isSelected ? Theme.accent : Theme.field, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.pressable)
    }
}

/// 經過時間（每秒更新）：「1:05:30」，可加前綴（「訓練中 」）
struct ElapsedTimeText: View {
    var since: Date
    var prefix = ""

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(prefix + WorkoutSession.format(duration: context.date.timeIntervalSince(since)))
                .monospacedDigit()
        }
    }
}

/// 頁面大標題列：左邊標題、右邊可選的按鈕
struct ScreenHeader<Trailing: View>: View {
    var title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack {
            Text(title)
                .font(.largeTitle.bold())
            Spacer()
            trailing
        }
        .padding(.horizontal, 4)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

extension Staleness {
    var color: Color {
        switch self {
        case .never: Theme.danger
        case .fresh: Theme.done
        case .stale: Theme.warning
        case .cold: Theme.danger
        }
    }
}

extension Date {
    /// 2026/10/20
    var shortDate: String {
        formatted(.dateTime.year().month(.twoDigits).day(.twoDigits))
    }
}

/// 小膠囊標籤（分類、tags）
struct Chip: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Theme.field, in: .capsule)
    }
}

// MARK: - 點擊回饋與動畫

extension Animation {
    /// 點選後狀態改變的動畫（選取、打勾、篩選、新增或刪除一組…），全 App 一致
    nonisolated static let tap = Animation.snappy(duration: 0.3, extraBounce: 0.05)
}

/// 按下時微微縮小、變淡，放開時用彈簧彈回；取代 .plain，讓每次點擊都有回饋
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }

    /// 小按鈕（例如打勾）縮得明顯一點
    static func pressable(scale: CGFloat) -> PressableButtonStyle { PressableButtonStyle(scale: scale) }
}

// MARK: - 捲動時隱藏分頁列

extension View {
    /// 分頁裡的捲動畫面用：往下滑隱藏分頁列，往上滑或回到頂端時出現（像 Threads）
    func hidesTabBarOnScroll() -> some View {
        modifier(TabBarAutoHideModifier())
    }
}

private struct TabBarAutoHideModifier: ViewModifier {
    @State private var isHidden = false
    @State private var autoHide = TabBarAutoHide()
    @State private var isScrolling = false

    private struct Metrics: Equatable {
        var offset: CGFloat
        var maxOffset: CGFloat
    }

    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { _, phase in isScrolling = phase.isScrolling }
            .onScrollGeometryChange(for: Metrics.self) { geometry in
                let insets = geometry.contentInsets
                return Metrics(offset: geometry.contentOffset.y + insets.top,
                               maxOffset: geometry.contentSize.height + insets.top + insets.bottom - geometry.containerSize.height)
            } action: { _, metrics in
                autoHide.update(offset: metrics.offset, maxOffset: metrics.maxOffset, isScrolling: isScrolling)
                if autoHide.isHidden != isHidden {
                    withAnimation(.snappy(duration: 0.3)) { isHidden = autoHide.isHidden }
                }
            }
            // 沒有要隱藏時交給系統（.automatic），下一頁的 .toolbar(.hidden, for: .tabBar) 才會生效
            .toolbarVisibility(isHidden ? .hidden : .automatic, for: .tabBar)
            // 切換分頁或進入下一頁時恢復顯示
            .onDisappear {
                autoHide.reset()
                isHidden = false
            }
    }
}
