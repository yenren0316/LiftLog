import SwiftUI
import UIKit

/// 訓練中組的數字欄（CHANGE_11 §4-2）。SwiftUI 的 TextField 沒辦法設 inputAccessoryView，所以用 UIKit 的 UITextField：
/// 候選列放在 inputAccessoryView 裡的 UIInputView（inputViewStyle: .keyboard），貼齊鍵盤上緣、全寬、和鍵盤同一個背景，
/// 像輸入法的選字列。iOS 26 會把 SwiftUI 的 .keyboard toolbar 畫成浮在鍵盤上方的膠囊，全 App 不再使用。
/// 焦點由 WorkoutEditor 管（focus 綁定）：點這一格時寫入，焦點改到這一格時成為第一回應者，改到別處時放開
struct SetNumberField: UIViewRepresentable {
    let id: FieldID
    @Binding var text: String
    var placeholder: String
    var keyboard: UIKeyboardType
    @Binding var focus: FieldID?
    /// 候選列的 5 個數字；空的時候不顯示候選列
    var candidates: [SetCandidates.Candidate]
    /// 點一個候選：填入這一格並跳到下一格
    var onPick: (Double) -> Void
    /// UI 測試找欄位用
    var accessibilityID = ""

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.textAlignment = .center
        field.adjustsFontForContentSizeCategory = true
        field.font = Self.font
        field.textColor = UIColor(Theme.textPrimary)
        field.tintColor = UIColor(Theme.accent)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.accessibilityIdentifier = accessibilityID
        field.keyboardType = keyboard
        field.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [
            .foregroundColor: UIColor(Theme.textSecondary.opacity(0.55)), .font: Self.font,
        ])
        context.coordinator.updateAccessory(of: field)
        let isFocused = focus == id
        if isFocused, !field.isFirstResponder {
            // 不在畫面更新中改第一回應者（成為第一回應者會回頭寫入 focus）
            DispatchQueue.main.async { if focus == id, field.window != nil { field.becomeFirstResponder() } }
        } else if !isFocused, field.isFirstResponder {
            DispatchQueue.main.async { if focus != id { field.resignFirstResponder() } }
        }
    }

    /// 和以前 SwiftUI 的 .title3.weight(.semibold).monospacedDigit() 一樣
    private static var font: UIFont {
        let base = UIFont.preferredFont(forTextStyle: .title3)
        let semibold = UIFont.systemFont(ofSize: base.pointSize, weight: .semibold)
        let descriptor = semibold.fontDescriptor.addingAttributes([.featureSettings: [[
            UIFontDescriptor.FeatureKey.type: kNumberSpacingType, UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
        ]]])
        return UIFontMetrics(forTextStyle: .title3).scaledFont(for: UIFont(descriptor: descriptor, size: base.pointSize))
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SetNumberField
        private var bar: CandidateBar?

        init(_ parent: SetNumberField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            if parent.focus != parent.id { parent.focus = parent.id }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            if parent.focus == parent.id { parent.focus = nil }
        }

        /// 候選列：有候選時放一條 CandidateBar，沒有時拿掉；換了內容時，鍵盤開著的那一格重新載入
        func updateAccessory(of field: UITextField) {
            let candidates = parent.candidates
            if candidates.isEmpty {
                guard field.inputAccessoryView != nil else { return }
                field.inputAccessoryView = nil
                if field.isFirstResponder { field.reloadInputViews() }
                return
            }
            let bar = bar ?? CandidateBar()
            self.bar = bar
            bar.onPick = { [weak self] value in self?.parent.onPick(value) }
            let changed = bar.candidates != candidates || field.inputAccessoryView !== bar
            bar.candidates = candidates
            if field.inputAccessoryView !== bar {
                field.inputAccessoryView = bar
                if field.isFirstResponder { field.reloadInputViews() }
            } else if changed {
                bar.setNeedsLayout()
            }
        }
    }
}

/// 鍵盤上緣的候選列：UIInputView（.keyboard 樣式）讓背景和鍵盤一樣；裡面 5 個數字平均分配寬度。
/// 建議重量用強調色，數字下面加小字「建議」
final class CandidateBar: UIInputView {
    static let height: CGFloat = 48

    var candidates: [SetCandidates.Candidate] = [] {
        didSet { if candidates != oldValue { rebuild() } }
    }
    var onPick: (Double) -> Void = { _ in }

    private let stack = UIStackView()

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: Self.height), inputViewStyle: .keyboard)
        autoresizingMask = .flexibleWidth
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        accessibilityIdentifier = "candidateBar"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Self.height)
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for candidate in candidates {
            var config = UIButton.Configuration.plain()
            let number = Units.number(candidate.value)
            config.attributedTitle = AttributedString(number, attributes: AttributeContainer([
                .font: UIFont.monospacedDigitSystemFont(ofSize: 20, weight: candidate.isSuggested ? .bold : .medium),
            ]))
            config.baseForegroundColor = UIColor(candidate.isSuggested ? Theme.accent : Theme.textPrimary)
            if candidate.isSuggested {
                config.attributedSubtitle = AttributedString("建議", attributes: AttributeContainer([
                    .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: UIColor(Theme.accent),
                ]))
                config.titleAlignment = .center
                config.titlePadding = 0
            }
            config.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0)
            let button = UIButton(configuration: config, primaryAction: UIAction { [weak self] _ in
                UIDevice.current.playInputClick()
                self?.onPick(candidate.value)
            })
            button.accessibilityLabel = candidate.isSuggested ? "\(number)，建議" : number
            button.accessibilityIdentifier = "candidate-\(number)"
            stack.addArrangedSubview(button)
        }
    }
}

extension CandidateBar: UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }
}
