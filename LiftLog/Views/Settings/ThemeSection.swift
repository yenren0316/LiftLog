import SwiftUI

/// 設定頁的「主題」：石墨深灰的底配不同強調色，每個主題一張預覽卡片，點一下立即套用
struct ThemeSection: View {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .graphiteOrange

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("主題", systemImage: "paintpalette.fill").font(.headline)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AppTheme.allCases) { option in
                    Button { theme = option } label: {
                        ThemePreviewCard(theme: option, isSelected: theme == option)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .card()
    }
}

/// 用該主題自己的顏色畫：一列已完成的組、一列未完成的組、選取中的 chip、主要按鈕、兩個部位色
/// （CHANGE_13 §3；CHANGE_14 §2 起部位色六個主題都一樣，是系統的藍和橘）
struct ThemePreviewCard: View {
    var theme: AppTheme
    var isSelected: Bool

    var body: some View {
        let p = theme.palette
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: p.accent)).frame(width: 10, height: 10)
                Text(theme.title).font(.subheadline.bold()).foregroundStyle(Color(hex: p.textPrimary))
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: p.accent))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                setRow(p, done: true)
                setRow(p, done: false)
                HStack(spacing: 4) {
                    chip("單邊", fill: p.accent, text: p.onAccent)
                    chip("爆發", fill: p.field, text: p.textPrimary)
                }
                Text("開始訓練")
                    .font(.caption.bold())
                    .foregroundStyle(Color(hex: p.onAccent))
                    .frame(maxWidth: .infinity, minHeight: 24)
                    .background(Color(hex: p.accent), in: .capsule)
                HStack(spacing: 8) {
                    bodyColor("下肢", .lower, p)
                    bodyColor("上肢", .upper, p)
                }
            }
            .padding(8)
            .background(Color(hex: p.card), in: .rect(cornerRadius: 12))
        }
        .padding(10)
        .background(Color(hex: p.background), in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Theme.accent : Theme.separator, lineWidth: isSelected ? 3 : 1)
        )
        .contentShape(.rect)
    }

    private func setRow(_ p: Palette, done: Bool) -> some View {
        HStack(spacing: 4) {
            Text(done ? "1" : "2").font(.caption2.bold()).foregroundStyle(Color(hex: p.textPrimary))
                .frame(width: 16)
            Text("60").font(.caption2).foregroundStyle(Color(hex: p.textPrimary))
                .frame(maxWidth: .infinity, minHeight: 18)
                .background(Color(hex: done ? p.card : p.field).opacity(done ? 0 : 1), in: .rect(cornerRadius: 4))
            Image(systemName: "checkmark")
                .font(.caption2.bold())
                .foregroundStyle(Color(hex: done ? p.done : p.textSecondary))
                .frame(width: 22, height: 18)
                .background(Color(hex: done ? p.done : p.field).opacity(done ? 0.18 : 1), in: .rect(cornerRadius: 4))
        }
        .padding(3)
        .background(Color(hex: p.done).opacity(done ? 0.18 : 0), in: .rect(cornerRadius: 6))
    }

    private func bodyColor(_ title: String, _ part: BodyPart, _ p: Palette) -> some View {
        HStack(spacing: 4) {
            Circle().fill(part.color).frame(width: 10, height: 10)
            Text(title).font(.caption2).foregroundStyle(Color(hex: p.textSecondary))
        }
    }

    private func chip(_ text: String, fill: UInt32, text color: UInt32) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(Color(hex: color))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Color(hex: fill), in: .capsule)
    }
}
