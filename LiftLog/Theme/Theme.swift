import SwiftUI

/// 仿 Habits First：深色底、大圓角灰卡片、綠色主色、細進度條
enum Theme {
    static let background = Color(red: 0.125, green: 0.125, blue: 0.141)
    static let card = Color(red: 0.165, green: 0.165, blue: 0.180)
    static let cardBorder = Color.white.opacity(0.06)
    static let field = Color.white.opacity(0.08)
    static let track = Color.white.opacity(0.10)

    static let green = Color(red: 0.30, green: 0.78, blue: 0.36)
    static let yellow = Color(red: 0.95, green: 0.78, blue: 0.27)
    static let orange = Color(red: 0.95, green: 0.58, blue: 0.25)
    static let red = Color(red: 0.92, green: 0.34, blue: 0.34)

    static let cardRadius: CGFloat = 28
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: Theme.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.cardRadius).stroke(Theme.cardBorder))
    }
}

extension View {
    func card(padding: CGFloat = 20) -> some View {
        modifier(CardModifier(padding: padding))
    }

    /// 頁面共用的深色背景
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

/// 細長膠囊進度條，fraction 介於 0...1
struct ThinBar: View {
    var fraction: Double
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
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
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Theme.card, in: .circle)
                .overlay(Circle().stroke(Color.white.opacity(0.15)))
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
