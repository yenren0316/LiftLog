import SwiftUI
import UIKit

// 部位的顏色（CHANGE_08 §3、§4）：「今天」本週卡的點點日曆（CHANGE_14 §1）和歷程「訓練頻率」的長條共用。
// 顏色是六個主題共用的系統色（BodyPart，CHANGE_14 §2）

extension DayRegion {
    /// 依 swatch 的顏色：全身沿對角線各一半；有氧與其他 textSecondary 40%
    var fill: AnyShapeStyle {
        switch swatch {
        case .solid(let part): AnyShapeStyle(part.color)
        case .split(let first, let second):
            AnyShapeStyle(LinearGradient(stops: [.init(color: first.color, location: 0.5),
                                                 .init(color: second.color, location: 0.5)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
        case .neutral: AnyShapeStyle(Theme.textSecondary.opacity(0.4))
        }
    }

    /// 長條用：全身改成兩色的斜紋。細長的長條上，沿對角線分一半看起來會像下肢和上肢疊在一起
    var barFill: AnyShapeStyle {
        guard case .split(let first, let second) = swatch else { return fill }
        return AnyShapeStyle(RegionStripes(first: first, second: second))
    }

    /// 長條由下往上疊的順序
    static let stackOrder: [DayRegion] = [.lower, .upper, .full, .cardio]
}

/// 全身的斜紋：兩個系統色先依畫面的環境（深色、增加對比）解析，再畫成一格 45 度的圖案。
/// SwiftUI 可能在背景的繪製執行緒解析樣式，所以不綁在主執行緒
nonisolated struct RegionStripes: ShapeStyle {
    var first: BodyPart
    var second: BodyPart

    func resolve(in environment: EnvironmentValues) -> some ShapeStyle {
        func resolved(_ part: BodyPart) -> UIColor { UIColor(Color(part.color.resolve(in: environment))) }
        return ImagePaint(image: Image(uiImage: Self.tile(resolved(first), resolved(second))), scale: 1 / 3)
    }

    /// 斜紋的一格：兩色各一半，45 度
    private static func tile(_ first: UIColor, _ second: UIColor) -> UIImage {
        let size: CGFloat = 24
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            first.setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            second.setFill()
            let band = UIBezierPath()
            // 兩條平行的斜帶，拼起來是連續的斜紋
            for offset in [-size, 0] as [CGFloat] {
                band.move(to: CGPoint(x: offset, y: size))
                band.addLine(to: CGPoint(x: offset + size / 2, y: size))
                band.addLine(to: CGPoint(x: offset + size * 1.5, y: 0))
                band.addLine(to: CGPoint(x: offset + size, y: 0))
                band.close()
            }
            band.fill()
        }
    }
}

/// 部位的字（下、上、全）：系統「不以顏色區分」開啟時，放在圖例的色塊裡（CHANGE_13 §3；CHANGE_14 §1 起日曆的格子太小，不放字）
struct RegionLetter: View {
    var region: DayRegion
    var size: CGFloat

    var body: some View {
        if let letter = region.letter {
            Text(letter)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(Theme.background)
        }
    }
}

/// 部位的圖例：「■ 下肢　■ 上肢　◩ 全身　■ 有氧與其他」，用圖形實際的顏色：訓練頻率的長條（全身是斜紋）、
/// 「本週」卡的日曆格子（全身沿對角線兩色，CHANGE_14 §1）。「不以顏色區分」開啟時色塊放大、裡面加上部位的字
struct RegionLegend: View {
    enum Style {
        case bars, cells
    }

    var style: Style = .bars

    @Environment(\.accessibilityDifferentiateWithoutColor) private var withoutColor

    var body: some View {
        HStack(spacing: 12) {
            ForEach(DayRegion.stackOrder, id: \.self) { region in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: withoutColor ? 3 : 2)
                        .fill(style == .bars ? region.barFill : region.fill)
                        .frame(width: withoutColor ? 14 : 9, height: withoutColor ? 14 : 9)
                        .overlay { if withoutColor { RegionLetter(region: region, size: 9) } }
                    Text(region.title)
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(Theme.textSecondary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("圖例：\(DayRegion.stackOrder.map(\.title).joined(separator: "、"))")
    }
}

/// 浮在圖表上方的小標籤（訓練頻率、有氧、體重）
struct PeekLabel: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.field, in: .capsule)
            .overlay(Capsule().stroke(Theme.separator))
            .fixedSize()
    }
}
