import SwiftUI
import WidgetKit

@main
struct LiftLogWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LastWorkoutWidget()
        StartWorkoutControl()
        WorkoutLiveActivity()
    }
}
