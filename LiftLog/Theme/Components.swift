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
                Button { selection = filter } label: {
                    Text(filter.title)
                        .font(.headline)
                        .foregroundStyle(selected ? Theme.onAccent : Theme.textPrimary)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 40)
                        .background(selected ? Theme.accent : Theme.field, in: .capsule)
                }
                .buttonStyle(.plain)
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
