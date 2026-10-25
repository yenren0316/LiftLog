import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var coordinator = WorkoutCoordinator()
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil }) private var active: [WorkoutSession]

    var body: some View {
        TabView {
            Tab("該練什麼", systemImage: "dumbbell.fill") {
                HomeView().workoutMiniBar()
            }
            Tab("訓練", systemImage: "figure.strengthtraining.traditional") {
                SessionsView().workoutMiniBar()
            }
            Tab("動作庫", systemImage: "list.bullet.rectangle") {
                LibraryView().workoutMiniBar()
            }
            Tab("設定", systemImage: "gearshape.fill") {
                SettingsView().workoutMiniBar()
            }
        }
        .environment(coordinator)
        .fullScreenCover(isPresented: Binding(
            get: { coordinator.isExpanded && active.first != nil },
            set: { coordinator.isExpanded = $0 }
        )) {
            if let session = active.first {
                WorkoutView(session: session)
                    .environment(coordinator)
                    .preferredColorScheme(.dark)
            }
        }
        .workoutStartConflictDialog(coordinator, context: context)
        .task {
            SeedImporter.importIfNeeded(into: context)
            #if DEBUG
            // 開發用：啟動參數 -demoWorkout YES 開一個示範訓練
            if UserDefaults.standard.bool(forKey: "demoWorkout"), active.isEmpty {
                let names = ["臥推", "輔助引體向上", "跑步機"]
                let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
                coordinator.requestStart(names.compactMap { n in all.first { $0.name == n } }, context: context)
            } else if UserDefaults.standard.bool(forKey: "demoWorkout") {
                coordinator.isExpanded = true
            }
            #endif
        }
    }
}

#Preview {
    RootView().preferredColorScheme(.dark)
}
