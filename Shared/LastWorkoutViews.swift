import SwiftUI
import WidgetKit

// 「上次訓練」小工具的畫面（CHANGE_05 第 4、5 節）。放在 Shared，小工具和 App 的預覽頁共用同一份畫面。

/// 小工具要顯示的狀態
nonisolated enum LastWorkoutStatus: Equatable, Sendable {
    /// 從來沒有訓練紀錄
    case neverTrained
    /// 有進行中的訓練
    case inProgress(startedAt: Date)
    /// 上次訓練在幾天前（今天練過為 0）
    case trained(days: Int)
}

nonisolated extension WidgetSnapshot {
    func status(at date: Date, calendar: Calendar = .current) -> LastWorkoutStatus {
        if isInProgress, let startedAt { return .inProgress(startedAt: startedAt) }
        guard let days = daysSinceLast(at: date, calendar: calendar) else { return .neverTrained }
        return .trained(days: days)
    }

    /// 點小工具開啟的連結：訓練中回到那次訓練，否則建立菜單
    var link: DeepLink { isInProgress ? .workout : .new }

    /// timeline 的時間點：現在，加上之後 7 天每天的午夜（天數自己往上加，不需要 App 喚醒）
    static func timelineDates(from now: Date, days: Int = 7, calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return [now] + (1...days).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    /// 小工具清單的預覽用
    static var sample: WidgetSnapshot {
        WidgetSnapshot(lastSessionDate: Calendar.current.date(byAdding: .day, value: -2, to: .now), lastRegion: .upper,
                       suggestedRegion: .lower, suggestedCount: 3, suggestsTreadmill: true,
                       isInProgress: false, startedAt: nil, themeID: nil, darkThemeID: nil, lightThemeID: nil)
    }
}

/// 主畫面和「今天」畫面的小型小工具
struct LastWorkoutSmallView: View {
    var snapshot: WidgetSnapshot?
    var date: Date
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let p = WidgetSnapshot.palette(for: snapshot, isDark: colorScheme == .dark)
        VStack(alignment: .leading, spacing: 0) {
            switch snapshot?.status(at: date) ?? .neverTrained {
            case .neverTrained:
                caption("上次訓練", p)
                Spacer(minLength: 4)
                Text("還沒有紀錄")
                    .font(.title2.bold())
                    .foregroundStyle(Color(hex: p.textPrimary))
                    .widgetAccentable()
                Spacer(minLength: 4)
                Label("開始第一次訓練", systemImage: "plus.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: p.accent))
            case .inProgress(let startedAt):
                Label("訓練中", systemImage: "dumbbell.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(hex: p.accent))
                Spacer(minLength: 4)
                Text(startedAt, style: .timer)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(Color(hex: p.textPrimary))
                    .widgetAccentable()
                Spacer(minLength: 4)
                caption("點一下回到訓練", p)
            case .trained(let days):
                caption("上次訓練", p)
                Spacer(minLength: 2)
                DaysText(days: days, unitFont: .title3.bold())
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: p.accent))
                    .widgetAccentable()
                if let summary = snapshot?.lastSummary() {
                    Text(summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(hex: p.textPrimary))
                }
                Spacer(minLength: 4)
                if let snapshot {
                    caption("今天建議：\(snapshot.suggestedRegion.title)", p)
                }
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(Color(hex: p.background), for: .widget)
    }

    private func caption(_ text: String, _ p: Palette) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color(hex: p.textSecondary))
    }
}

/// 「今天」或「2 天前」：數字用大字，「天前」小一點
struct DaysText: View {
    var days: Int
    var unitFont: Font

    var body: some View {
        if days == 0 {
            Text("今天")
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(days))
                Text("天前").font(unitFont)
            }
        }
    }
}
