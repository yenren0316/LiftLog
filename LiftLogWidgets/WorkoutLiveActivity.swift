import SwiftUI
import WidgetKit

/// 訓練中的即時動態（CHANGE_05 第 6 節）：鎖定畫面與動態島。內容由 App 透過 ActivityKit 更新。
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutActivityLockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.72))
                .activitySystemActionForegroundColor(Color(hex: context.attributes.accent))
                .widgetURL(DeepLink.workout.url)
        } dynamicIsland: { context in
            let accent = Color(hex: context.attributes.accent)
            return DynamicIsland {
                // 展開的高度有限（約 160 pt）：和鎖定畫面一樣的資訊層級。第 1 列放在左右區域（名稱、經過時間），
                // 下面是第 2～4 列，倒數小一點；字級最大到 large，文字一律一行
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.leading, 4)
                        .dynamicTypeSize(...DynamicTypeSize.large)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // 經過時間一定完整顯示：先縮小，還是放不下就移到下一行（CHANGE_10 §0-4）
                    WorkoutActivityElapsedTime(startedAt: context.state.startedAt, font: .caption)
                        .padding(.trailing, 4)
                        .dynamicTypeSize(...DynamicTypeSize.large)
                        .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WorkoutActivityBody(attributes: context.attributes, state: context.state, isStale: context.isStale,
                                        middleHeight: LiveActivityLayout.islandMiddleHeight,
                                        countdownSize: LiveActivityLayout.islandCountdownSize)
                        .dynamicTypeSize(...DynamicTypeSize.large)
                }
            } compactLeading: {
                WorkoutActivityCompactLeading(attributes: context.attributes, state: context.state)
            } compactTrailing: {
                WorkoutActivityCompactTrailing(attributes: context.attributes, state: context.state, isStale: context.isStale)
            } minimal: {
                WorkoutActivityMinimal(attributes: context.attributes, state: context.state, isStale: context.isStale)
            }
            .widgetURL(DeepLink.workout.url)
            .keylineTint(accent)
        }
    }
}
