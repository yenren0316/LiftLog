import SwiftUI

/// 設定頁的「主題」：每個主題一張預覽卡片，點一下立即套用；可跟隨系統外觀
struct ThemeSection: View {
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .graphiteOrange
    @AppStorage(AppTheme.followSystemKey) private var followSystem = false
    @AppStorage(AppTheme.darkKey) private var darkTheme: AppTheme = .midnightBlue
    @AppStorage(AppTheme.lightKey) private var lightTheme: AppTheme = .coolGray

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("主題", systemImage: "paintpalette.fill").font(.headline)
            Toggle("跟隨系統外觀", isOn: $followSystem)
                .font(.body.weight(.semibold))
            if followSystem {
                Text("深色模式").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                grid(AppTheme.darkThemes, selection: $darkTheme)
                Text("淺色模式").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                grid(AppTheme.lightThemes, selection: $lightTheme)
            } else {
                grid(AppTheme.allCases, selection: $theme)
            }
        }
        .card()
    }

    private func grid(_ themes: [AppTheme], selection: Binding<AppTheme>) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(themes) { option in
                Button { selection.wrappedValue = option } label: {
                    ThemePreviewCard(theme: option, isSelected: selection.wrappedValue == option)
                }
                .buttonStyle(.pressable)
            }
        }
    }
}

/// 用該主題自己的顏色畫：一列已完成的組、一列未完成的組、選取中的 chip、主要按鈕、近 30 天長條
struct ThemePreviewCard: View {
    var theme: AppTheme
    var isSelected: Bool

    var body: some View {
        let p = theme.palette
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(theme.title).font(.subheadline.bold()).foregroundStyle(Color(hex: p.textPrimary))
                    Text(theme.subtitle).font(.caption2).foregroundStyle(Color(hex: p.textSecondary))
                }
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
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(hex: p.field))
                        Capsule().fill(Color(hex: p.accent)).frame(width: geo.size.width * 0.65)
                    }
                }
                .frame(height: 5)
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

    private func chip(_ text: String, fill: UInt32, text color: UInt32) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundStyle(Color(hex: color))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Color(hex: fill), in: .capsule)
    }
}
