import SwiftUI
import UIKit

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
        // 先收起鍵盤再執行（CHANGE_10 §1）
        Button {
            dismissKeyboard()
            action()
        } label: {
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

/// 經過時間：「0:54」「24:30」「1:05:30」，可加前綴（「訓練中 」）。
/// 系統的計時文字自己跳秒，不用每秒重畫（CHANGE_12 §1）
struct ElapsedTimeText: View {
    var since: Date
    var prefix = ""

    var body: some View {
        Text("\(prefix)\(Text(timerInterval: since...Date.distantFuture, countsDown: false))")
            .monospacedDigit()
    }
}

extension Staleness {
    /// 「N 天前」：不用紅綠燈（CHANGE_13 §3），很久沒練是提醒（warning 色加圖示），其他中性
    func text(_ string: String, normal: Color = Theme.textSecondary) -> Text {
        .warning(string, when: isNeglected, normal: normal)
    }
}

extension Text {
    /// 提醒和警示：warning 色，前面一定加上圖示，不只靠顏色（CHANGE_14 §2）；不是提醒時用 normal 色、不加圖示
    static func warning(_ string: String, when isWarning: Bool = true, normal: Color = Theme.textSecondary) -> Text {
        guard isWarning else { return Text(string).foregroundStyle(normal) }
        return Text("\(Image(systemName: "exclamationmark.circle")) \(string)").foregroundStyle(Theme.warning)
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

// MARK: - 可以點的卡片和列（CHANGE_10 §4）

/// 可以點的卡片和列：整塊都能點，按下時背景換成主題的按壓色（Theme.pressed），放開恢復。
/// 全 App 可以點的卡片和列都用這一個，不再用列尾的「›」當提示；不能點的卡片（有氧、平衡）不用
struct TapSurfaceStyle: ButtonStyle {
    enum Kind {
        /// 一整張卡片：平常是卡片的底色和外框
        case card
        /// 卡片裡的一列：平常透明
        case row
        /// 清單（List）的一列：填滿整格，圓角交給清單
        case listRow
    }

    var kind: Kind

    private var radius: CGFloat {
        switch kind {
        case .card: Theme.cardRadius
        case .row: 12
        case .listRow: 0
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect(cornerRadius: radius))
            .background(configuration.isPressed ? Theme.pressed : (kind == .card ? Theme.card : Color.clear),
                        in: .rect(cornerRadius: radius))
            .overlay {
                if kind == .card {
                    RoundedRectangle(cornerRadius: radius).stroke(Theme.separator.opacity(0.6))
                }
            }
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == TapSurfaceStyle {
    static var tapCard: TapSurfaceStyle { TapSurfaceStyle(kind: .card) }
    static var tapRow: TapSurfaceStyle { TapSurfaceStyle(kind: .row) }
    static var tapListRow: TapSurfaceStyle { TapSurfaceStyle(kind: .listRow) }
}

/// 清單（List）裡可以點的一列：整列都能點，按下時整列換成按壓色（TapSurfaceStyle）；沒有列尾的「›」。
/// 列的內距和系統清單一樣，swipeActions、contextMenu 照樣掛在這一列上
struct TapListRow<Label: View>: View {
    var action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            label
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
        }
        .buttonStyle(.tapListRow)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Theme.card)
    }
}

/// 卡片裡可以點的一列：按壓色左右多留一點，文字還是和卡片裡其他內容對齊
extension View {
    func tapRowInset() -> some View {
        padding(.horizontal, 8).padding(.vertical, 4)
    }

    func tapRowOutset() -> some View {
        padding(.horizontal, -8)
    }
}

/// 按下時微微縮小、變淡，放開時用彈簧彈回；取代 .plain，讓每次點擊都有回饋。
/// 小按鈕用（膠囊、文字按鈕、圖示、打勾）；可以點的卡片和列用 TapSurfaceStyle
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
