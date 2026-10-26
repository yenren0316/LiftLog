#if DEBUG
import SwiftUI

/// 開發用：把小工具和即時動態的畫面（Shared 裡同一份程式碼）以系統的尺寸排出來截圖。
/// 啟動參數 -widgetGallery small｜lock｜live｜island｜control
struct WidgetGalleryView: View {
    var page: String

    private static let smallSize = CGSize(width: 170, height: 170)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch page {
                case "lock":
                    lockPage
                case "live":
                    livePage
                case "island":
                    islandPage
                case "control":
                    controlPage
                default:
                    smallPage
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(wallpaper.ignoresSafeArea())
    }

    // MARK: - 小型小工具

    private var smallPage: some View {
        LazyVGrid(columns: [GridItem(.fixed(Self.smallSize.width), spacing: 22),
                            GridItem(.fixed(Self.smallSize.width))], alignment: .leading, spacing: 18) {
            labeled("上次訓練") { small(Self.trained) }
            labeled("今天練過") { small(Self.trainedToday) }
            labeled("還沒有紀錄") { small(Self.never) }
            labeled("訓練中") { small(Self.inProgress) }
        }
    }

    private func small(_ snapshot: WidgetSnapshot) -> some View {
        let p = WidgetSnapshot.palette(for: snapshot)
        return LastWorkoutSmallView(snapshot: snapshot, date: .now)
            .padding(16)
            .frame(width: Self.smallSize.width, height: Self.smallSize.height)
            .background(Color(hex: p.background), in: .rect(cornerRadius: 24, style: .continuous))
    }

    // MARK: - 鎖定畫面小工具（系統以單色顯示，這裡用白色模擬）

    private var lockPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            lockRow("上次訓練 \(RelativeDay.text(2))", Self.trained)
            lockRow("今天練過", Self.trainedToday)
            lockRow("訓練中", Self.inProgress)
            lockRow("還沒有紀錄", Self.never)
        }
        .foregroundStyle(.white)
    }

    private func lockRow(_ title: String, _ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
            LastWorkoutInlineView(snapshot: snapshot, date: .now)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 14) {
                LastWorkoutCircularView(snapshot: snapshot, date: .now)
                    .frame(width: 76, height: 76)
                    .background(.white.opacity(0.18), in: .circle)
                LastWorkoutRectangularView(snapshot: snapshot, date: .now)
                    .frame(width: 172, height: 76)
            }
        }
    }

    // MARK: - 即時動態（動態島的黑色底和形狀是模擬的）

    private var livePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            caption("鎖定畫面・非休息中")
            lockScreen(Self.activityState(resting: false))
            caption("鎖定畫面・休息中")
            lockScreen(Self.activityState(resting: true))
        }
    }

    private var islandPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            caption("動態島・縮小（非休息中／休息中）")
            compact(Self.activityState(resting: false))
            compact(Self.activityState(resting: true))
            caption("動態島・最小（非休息中／休息中）")
            HStack(spacing: 12) {
                minimal(Self.activityState(resting: false))
                minimal(Self.activityState(resting: true))
            }
            caption("動態島・展開（非休息中）")
            expanded(Self.activityState(resting: false))
            caption("動態島・展開（休息中）")
            expanded(Self.activityState(resting: true))
        }
    }

    private func lockScreen(_ state: WorkoutActivityState) -> some View {
        WorkoutActivityLockScreenView(attributes: activityAttributes, state: state, isStale: false)
            .frame(width: 370)
            .background(.black.opacity(0.72), in: .rect(cornerRadius: 24, style: .continuous))
            .environment(\.colorScheme, .dark)
    }

    private func compact(_ state: WorkoutActivityState) -> some View {
        HStack {
            WorkoutActivityCompactLeading(attributes: activityAttributes, state: state)
            Spacer()
            WorkoutActivityCompactTrailing(attributes: activityAttributes, state: state, isStale: false)
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 14)
        .frame(width: 250, height: 37)
        .background(.black, in: .capsule)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    private func minimal(_ state: WorkoutActivityState) -> some View {
        WorkoutActivityMinimal(attributes: activityAttributes, state: state, isStale: false)
            .font(.subheadline.weight(.semibold))
            .frame(width: 44, height: 37)
            .background(.black, in: .capsule)
            .environment(\.colorScheme, .dark)
    }

    private func expanded(_ state: WorkoutActivityState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                WorkoutActivityCompactLeading(attributes: activityAttributes, state: state).font(.title2)
                Spacer()
                Text(state.startedAt, style: .timer)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
            }
            WorkoutActivityBody(attributes: activityAttributes, state: state, isStale: false, countdownSize: 32)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .frame(width: 370)
        .background(.black, in: .rect(cornerRadius: 44, style: .continuous))
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - 控制中心（控制項的外觀由系統決定，這裡模擬 1×1 和 2×1 兩種大小）

    private var controlPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            caption("控制中心・1×1")
            controlButton(wide: false)
            caption("控制中心・2×1")
            controlButton(wide: true)
            caption("在「設定 › 動作按鈕 › 控制項」也能選「開始訓練」")
        }
    }

    private func controlButton(wide: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "dumbbell.fill")
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(.white.opacity(wide ? 0.18 : 0), in: .circle)
            if wide {
                VStack(alignment: .leading, spacing: 0) {
                    Text("開始訓練").font(.subheadline.weight(.semibold))
                    Text("LiftLog").font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(.white)
        .padding(wide ? 10 : 10)
        .frame(width: wide ? 160 : 68, height: 68)
        .background(.white.opacity(0.14), in: .rect(cornerRadius: 34, style: .continuous))
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
    }

    private var activityAttributes: WorkoutActivityAttributes {
        let palette = AppTheme.load().palette
        return WorkoutActivityAttributes(sessionID: "preview", accent: palette.accent, done: palette.done)
    }

    private static func activityState(resting: Bool) -> WorkoutActivityState {
        let now = Date.now
        return WorkoutActivityState(
            title: "臥推＋輔助引體向上＋跑步機", startedAt: now.addingTimeInterval(-24 * 60 - 32),
            exerciseName: "臥推", roleTitle: "推", roleSymbol: Role.push.symbol,
            setNumber: 2, setCount: 5, target: "60 kg × 5", canComplete: true,
            completedSets: 6, totalSets: 15,
            restStartDate: resting ? now.addingTimeInterval(-35) : nil,
            restEndDate: resting ? now.addingTimeInterval(145) : nil
        )
    }

    private func labeled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 6) {
            content()
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white)
        }
    }

    private var wallpaper: some View {
        LinearGradient(colors: [Color(hex: 0x2B3A67), Color(hex: 0x0E1A2B)], startPoint: .top, endPoint: .bottom)
    }

    // MARK: - 範例快照

    private static func snapshot(daysAgo: Int?, inProgressMinutes: Int? = nil) -> WidgetSnapshot {
        var s = WidgetSnapshot.sample
        s.lastSessionDate = daysAgo.flatMap { Calendar.current.date(byAdding: .day, value: -$0, to: .now) }
        s.lastRegion = daysAgo == nil ? nil : .lower
        s.lastDayType = daysAgo == nil ? nil : .meLower
        if let minutes = inProgressMinutes {
            s.isInProgress = true
            s.startedAt = Date.now.addingTimeInterval(TimeInterval(-minutes * 60 - 17))
        }
        return s
    }

    static let trained = snapshot(daysAgo: 2)
    static let trainedToday = snapshot(daysAgo: 0)
    static let never = snapshot(daysAgo: nil)
    static let inProgress = snapshot(daysAgo: 2, inProgressMinutes: 32)
}
#endif
