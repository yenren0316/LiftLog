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

/// 右上角的圓形按鈕
struct CircleIconButton: View {
    var systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 48, height: 48)
                .background(Theme.card, in: .circle)
                .overlay(Circle().stroke(Theme.separator))
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

/// 「全部／單邊／爆發」膠囊篩選列
struct TagFilterBar: View {
    @Binding var selection: TagFilter

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TagFilter.allCases) { filter in
                let selected = filter == selection
                Button { withAnimation(.tap) { selection = filter } } label: {
                    Text(filter.title)
                        .font(.headline)
                        .foregroundStyle(selected ? Theme.onAccent : Theme.textPrimary)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 40)
                        .background(selected ? Theme.accent : Theme.field, in: .capsule)
                }
                .buttonStyle(.pressable)
            }
            Spacer(minLength: 0)
        }
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
