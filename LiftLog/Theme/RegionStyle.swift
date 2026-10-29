import SwiftUI

// 部位的顏色（CHANGE_08 §3、§4）：「今天」本週卡的圓點（CHANGE_13 §2-2）和歷程「訓練頻率」的長條共用

extension DayRegion {
    /// 依 swatch 的顏色：全身沿對角線各一半；有氧與其他 textSecondary 40%
    var fill: AnyShapeStyle {
        switch swatch(AppTheme.load().palette) {
        case .solid(let hex): AnyShapeStyle(Color(hex: hex))
        case .split(let first, let second):
            AnyShapeStyle(LinearGradient(stops: [.init(color: Color(hex: first), location: 0.5),
                                                 .init(color: Color(hex: second), location: 0.5)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
        case .neutral: AnyShapeStyle(Theme.textSecondary.opacity(0.4))
        }
    }

    /// 長條用：全身改成兩色的斜紋。細長的長條上，沿對角線分一半看起來會像下肢和上肢疊在一起
    var barFill: AnyShapeStyle {
        guard case .split(let first, let second) = swatch(AppTheme.load().palette) else { return fill }
        return AnyShapeStyle(ImagePaint(image: Image(uiImage: Self.stripes(first, second)), scale: 1 / 3))
    }

    /// 斜紋的一格：兩色各一半，45 度
    private static func stripes(_ first: UInt32, _ second: UInt32) -> UIImage {
        let size: CGFloat = 24
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            UIColor(hex: first).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
            UIColor(hex: second).setFill()
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

    /// 長條由下往上疊的順序
    static let stackOrder: [DayRegion] = [.lower, .upper, .full, .cardio]
}

/// 訓練頻率的圖例：「■ 下肢　■ 上肢　▨ 全身　■ 有氧與其他」，用長條實際的顏色（全身是斜紋）
struct RegionLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(DayRegion.stackOrder, id: \.self) { region in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(region.barFill).frame(width: 9, height: 9)
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
