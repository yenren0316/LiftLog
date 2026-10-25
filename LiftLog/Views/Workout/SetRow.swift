import SwiftUI

enum SetField: Int, CaseIterable {
    case weight, reps, seconds, incline, speed, minutes

    static func fields(for logType: LogType) -> [SetField] {
        switch logType {
        case .weight, .assisted: [.weight, .reps]
        case .bodyweight: [.reps, .weight]
        case .timed: [.seconds, .weight]
        case .cardio: [.incline, .speed, .minutes]
        }
    }

    var isDecimal: Bool { self != .reps && self != .seconds }

    /// 鍵盤快捷鍵 -2.5／+2.5／+5 只作用在重量欄
    var acceptsWeightSteps: Bool { self == .weight }
}

struct FieldID: Hashable {
    var set: UUID
    var field: SetField
}

/// 欄位寬度，讓標題列與每一組對齊
enum SetColumns {
    static let number: CGFloat = 34
    static let field: CGFloat = 64
    static let check: CGFloat = 40
}

/// 一組：組號｜上一次｜數值欄位｜✓
struct SetRow: View {
    let set: SetRecord
    let number: String
    let previous: SetValues?
    let placeholder: SetValues?
    let logType: LogType
    let unit: WeightUnit
    let text: (SetField) -> Binding<String>
    let focus: FocusState<FieldID?>.Binding
    /// 回傳 false 代表欄位不齊全
    let onToggle: () -> Bool
    let onKind: (SetKind) -> Void
    let onDelete: () -> Void

    @State private var shakes = 0

    var body: some View {
        HStack(spacing: 8) {
            if logType != .cardio {
                Menu {
                    Picker("種類", selection: Binding(get: { set.kind }, set: { onKind($0) })) {
                        ForEach(SetKind.allCases) { Text($0.title).tag($0) }
                    }
                    Button("刪除此組", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Text(number)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(numberColor)
                        .frame(width: SetColumns.number, height: 36)
                        .background(Theme.field, in: .rect(cornerRadius: 8))
                }
            }

            Text(previous.map { SetFormat.short($0, logType: logType, unit: unit) } ?? "—")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(SetField.fields(for: logType), id: \.self) { field in
                TextField("", text: text(field), prompt: Text(placeholderText(field)).foregroundStyle(Theme.textSecondary.opacity(0.55)))
                    .keyboardType(field.isDecimal ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.center)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .frame(width: SetColumns.field, height: 40)
                    .background(Theme.field, in: .rect(cornerRadius: 8))
                    .focused(focus, equals: FieldID(set: set.id, field: field))
            }

            Button {
                if !onToggle() {
                    withAnimation(.linear(duration: 0.4)) { shakes += 1 }
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(set.isCompleted ? Theme.done : Theme.textSecondary)
                    .frame(width: SetColumns.check, height: 40)
                    .background(set.isCompleted ? Theme.done.opacity(0.18) : Theme.field, in: .rect(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .modifier(Shake(animatableData: CGFloat(shakes)))
        .sensoryFeedback(.success, trigger: set.isCompleted) { _, done in done }
        .sensoryFeedback(.error, trigger: shakes)
    }

    private var numberColor: Color {
        switch set.kind {
        case .normal: Theme.textPrimary
        case .warmup: Theme.accent
        case .max: Theme.warning
        }
    }

    private func placeholderText(_ field: SetField) -> String {
        guard let p = placeholder else { return "" }
        switch field {
        case .weight: return p.weightKg.map { unit.format(kg: $0) } ?? ""
        case .reps: return p.reps.map(String.init) ?? ""
        case .seconds: return p.seconds.map(Units.number) ?? ""
        case .incline: return p.incline.map(Units.number) ?? ""
        case .speed: return p.speed.map(Units.number) ?? ""
        case .minutes: return p.minutes.map(Units.number) ?? ""
        }
    }
}

/// 欄位不齊全時左右晃動。SwiftUI 可能在背景的繪製執行緒計算動畫，所以不綁在主執行緒
nonisolated struct Shake: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}

/// 欄位標題列
struct SetHeaderRow: View {
    let logType: LogType
    let unilateral: Bool
    let unit: WeightUnit
    let equipment: Equipment

    var body: some View {
        HStack(spacing: 8) {
            if logType != .cardio {
                Text("組").frame(width: SetColumns.number)
            }
            Text("上一次").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(titles, id: \.self) { Text($0).frame(width: SetColumns.field) }
            Image(systemName: "checkmark").frame(width: SetColumns.check)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.textSecondary)
    }

    private var titles: [String] {
        let reps = unilateral ? "次／邊" : "次"
        let weight = unit.columnTitle(equipment: equipment)
        return switch logType {
        case .weight: [weight, reps]
        case .assisted: ["輔助 \(unit.symbol)", reps]
        case .bodyweight: [reps, "負重"]
        case .timed: ["秒", "負重"]
        case .cardio: ["坡度", "速度", "分鐘"]
        }
    }
}
