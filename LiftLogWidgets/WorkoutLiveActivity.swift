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
                // 展開的高度有限（約 160 pt），上方只放角色圖示和經過時間，標題留在鎖定畫面
                DynamicIslandExpandedRegion(.leading) {
                    WorkoutActivityCompactLeading(attributes: context.attributes, state: context.state)
                        .font(.title2)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 64, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    WorkoutActivityBody(attributes: context.attributes, state: context.state,
                                        isStale: context.isStale, countdownSize: 32)
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
