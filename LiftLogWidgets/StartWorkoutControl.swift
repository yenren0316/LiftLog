import AppIntents
import SwiftUI
import WidgetKit

/// 控制中心與動作按鈕的「開始訓練」（CHANGE_05 第 7 節）：按下後打開 App，行為和 liftlog://new 相同
struct StartWorkoutControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.aaronhou.LiftLog.StartWorkout") {
            ControlWidgetButton(action: StartWorkoutIntent()) {
                Label("開始訓練", systemImage: "dumbbell.fill")
            }
        }
        .displayName("開始訓練")
        .description("打開 LiftLog 建立今天的菜單。")
    }
}
