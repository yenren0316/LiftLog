import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var coordinator = WorkoutCoordinator()
    @State private var restTimer = RestTimer()
    @State private var tab = 0
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .graphiteOrange
    @AppStorage(AppTheme.followSystemKey) private var followSystem = false
    @AppStorage(AppTheme.darkKey) private var darkTheme: AppTheme = .midnightBlue
    @AppStorage(AppTheme.lightKey) private var lightTheme: AppTheme = .coolGray
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil }) private var active: [WorkoutSession]
    private let router = DeepLinkRouter.shared

    private var themeSettings: ThemeSettings {
        ThemeSettings(theme: theme, followSystem: followSystem, dark: darkTheme, light: lightTheme)
    }

    var body: some View {
        #if DEBUG
        // 開發用：-widgetGallery small｜lock｜live 顯示小工具和即時動態的預覽
        if let page = UserDefaults.standard.string(forKey: "widgetGallery") {
            WidgetGalleryView(page: page).preferredColorScheme(themeSettings.colorScheme)
        } else {
            content
        }
        #else
        content
        #endif
    }

    private var content: some View {
        // 換主題時重建畫面，讓所有 token 重新取色
        tabs
            .id(themeSettings.key)
            .tint(Theme.accent)
            .preferredColorScheme(themeSettings.colorScheme)
            .onChange(of: themeSettings.key) { SnapshotWriter.shared.update() }
            .onOpenURL { router.open($0) }
            .onChange(of: router.pending, initial: true) { _, link in
                if let link { handle(link) }
            }
    }

    /// 深層連結：有進行中的訓練就打開它；建立菜單交給首頁開啟
    private func handle(_ link: DeepLink) {
        router.pending = nil
        let coverShown = coordinator.isExpanded && (active.first != nil || coordinator.summary != nil)
        switch link.destination(hasActiveWorkout: !active.isEmpty) {
        case .workout:
            coordinator.summary = nil
            coordinator.isExpanded = true
        case .plan:
            closeWorkoutCover()
            tab = 0
            if coverShown {
                // 等全螢幕畫面關掉再開 sheet
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    coordinator.planRequestedByLink = true
                }
            } else {
                coordinator.planRequestedByLink = true
            }
        case .home:
            closeWorkoutCover()
            tab = 0
        }
    }

    private func closeWorkoutCover() {
        coordinator.isExpanded = false
        coordinator.summary = nil
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("該練什麼", systemImage: "dumbbell.fill", value: 0) {
                HomeView().workoutMiniBar()
            }
            Tab("訓練", systemImage: "figure.strengthtraining.traditional", value: 1) {
                SessionsView().workoutMiniBar()
            }
            Tab("動作庫", systemImage: "list.bullet.rectangle", value: 2) {
                LibraryView().workoutMiniBar()
            }
            Tab("設定", systemImage: "gearshape.fill", value: 3) {
                SettingsView().workoutMiniBar()
            }
        }
        .environment(coordinator)
        .environment(restTimer)
        .fullScreenCover(isPresented: Binding(
            get: { coordinator.isExpanded && (active.first != nil || coordinator.summary != nil) },
            set: { coordinator.isExpanded = $0 }
        )) {
            Group {
                if let summary = coordinator.summary {
                    WorkoutSummaryView(summary: summary) {
                        coordinator.isExpanded = false
                        coordinator.summary = nil
                    }
                } else if let session = active.first {
                    WorkoutView(session: session)
                }
            }
            .environment(coordinator)
            .environment(restTimer)
            .preferredColorScheme(themeSettings.colorScheme)
        }
        .alert("沒有完成任何一組", isPresented: Binding(
            get: { coordinator.showEmptyFinishNotice },
            set: { coordinator.showEmptyFinishNotice = $0 }
        )) {
            Button("好") {}
        } message: {
            Text("這次訓練沒有打勾的組，已經刪除。")
        }
        .workoutStartConflictDialog(coordinator, context: context)
        .task {
            SeedImporter.importIfNeeded(into: context)
            GuideImporter.importIfNeeded(into: context)
            LibraryAdditions.applyIfNeeded(into: context)
            SnapshotWriter.shared.start(context: context)
            #if DEBUG
            // 開發用：啟動參數 -startTab 1 直接切到該分頁
            tab = UserDefaults.standard.integer(forKey: "startTab")
            // 開發用：啟動參數 -demoWorkout YES 開一個示範訓練
            if UserDefaults.standard.bool(forKey: "demoWorkout"), active.isEmpty {
                let names = ["臥推", "輔助引體向上", "跑步機"]
                let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
                coordinator.requestStart(names.compactMap { n in all.first { $0.name == n } }, context: context)
            } else if UserDefaults.standard.bool(forKey: "demoWorkout") {
                coordinator.isExpanded = true
            }
            // 開發用：-discardActive YES 捨棄進行中的訓練，測試沒有訓練時的狀態
            if UserDefaults.standard.bool(forKey: "discardActive"), let session = active.first {
                WorkoutActions.discard(session, in: context)
            }
            // 開發用：-openURL liftlog://new 模擬點小工具（simctl openurl 會先跳出確認視窗）
            if let link = UserDefaults.standard.string(forKey: "openURL"), let url = URL(string: link) {
                router.open(url)
            }
            #endif
        }
    }
}

#Preview {
    RootView()
}
