import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var coordinator: WorkoutCoordinator
    @State private var launcher: WorkoutLauncher
    @State private var restTimer = RestTimer.shared
    @State private var stats = StatsCache.shared
    @AppStorage(AppTheme.storageKey) private var theme: AppTheme = .graphiteOrange
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil }) private var active: [WorkoutSession]
    private let router = DeepLinkRouter.shared

    init() {
        let coordinator = WorkoutCoordinator()
        _coordinator = State(initialValue: coordinator)
        _launcher = State(initialValue: WorkoutLauncher(coordinator: coordinator))
    }

    var body: some View {
        #if DEBUG
        // 開發用：-widgetGallery small｜lock｜live 顯示小工具和即時動態的預覽
        if let page = UserDefaults.standard.string(forKey: "widgetGallery") {
            WidgetGalleryView(page: page).preferredColorScheme(.dark)
        } else {
            content
        }
        #else
        content
        #endif
    }

    private var content: some View {
        // 換主題時重建畫面，讓所有 token 重新取色；主題都是深色，鍵盤、sheet 等系統元件也固定深色
        tabs
            .id(theme)
            .animation(.easeInOut(duration: 0.35), value: theme)
            .tint(Theme.accent)
            .preferredColorScheme(.dark)
            .onChange(of: theme) {
                SnapshotWriter.shared.update()
                LiveActivityController.shared.scheduleSync()
            }
            // 即時動態的目標重量依單位顯示
            .onChange(of: unit) { LiveActivityController.shared.scheduleSync() }
            .onOpenURL { router.open($0) }
            // 小工具的＋如果在小工具的程序執行，連結留在 App Group，回到前景時接手
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { router.consumePendingLink() }
            }
            .onChange(of: router.pending, initial: true) { _, link in
                if let link { handle(link) }
            }
    }

    /// 深層連結：workout 打開進行中的訓練；new 進入建立菜單（有進行中的訓練時由 WorkoutLauncher 先詢問）
    private func handle(_ link: DeepLink) {
        router.pending = nil
        let coverShown = coordinator.isExpanded && (active.first != nil || coordinator.summary != nil)
        switch link.destination(hasActiveWorkout: !active.isEmpty) {
        case .workout:
            coordinator.summary = nil
            coordinator.isExpanded = true
        case .plan:
            closeWorkoutCover()
            coordinator.tab = .today
            if coverShown {
                // 等全螢幕畫面關掉再開 sheet
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    launcher.requestPlan(context: context)
                }
            } else {
                launcher.requestPlan(context: context)
            }
        case .today:
            closeWorkoutCover()
            coordinator.summarySession = nil
            coordinator.tab = .today
            coordinator.todayPath = NavigationPath()
        }
    }

    private func closeWorkoutCover() {
        coordinator.isExpanded = false
        coordinator.summary = nil
    }

    private var tabs: some View {
        TabView(selection: $coordinator.tab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    Group {
                        switch tab {
                        case .today: TodayView()
                        case .history: HistoryView()
                        case .library: LibraryView()
                        case .settings: SettingsView()
                        }
                    }
                    .workoutMiniBar()
                }
            }
        }
        .environment(coordinator)
        .environment(launcher)
        .environment(restTimer)
        .environment(stats)
        .sheet(item: $launcher.planRequest, onDismiss: launcher.sheetDismissed) { request in
            PlanFlowView(request: request)
                .environment(coordinator)
                .environment(launcher)
                .environment(stats)
        }
        .sheet(item: $coordinator.summarySession, onDismiss: launcher.sheetDismissed) { session in
            WorkoutSummarySheet(session: session)
                .environment(coordinator)
                .environment(launcher)
                .environment(stats)
        }
        .planEntryQuestion(launcher)
        .launchConfirmation(launcher, origin: .root, context: context)
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
            .environment(launcher)
            .environment(restTimer)
            .environment(stats)
            .preferredColorScheme(.dark)
        }
        .alert("沒有完成任何一組", isPresented: Binding(
            get: { coordinator.showEmptyFinishNotice },
            set: { coordinator.showEmptyFinishNotice = $0 }
        )) {
            Button("好") {}
        } message: {
            Text("這次訓練沒有打勾的組，已經刪除。")
        }
        .task {
            SeedImporter.importIfNeeded(into: context)
            GuideImporter.importIfNeeded(into: context)
            LibraryAdditions.applyIfNeeded(into: context)
            ConjugateLibrary.applyIfNeeded(into: context)
            // 資料遷移：每個遷移執行前先在 Documents/AutoBackups 自動備份
            DataMigrations.runIfNeeded(context: context)
            stats.start(context: context)
            SnapshotWriter.shared.start(context: context)
            LiveActivityController.shared.start()
            #if DEBUG
            // 開發用：啟動參數 -startTab 1 直接切到該分頁（0 今天、1 歷程、2 動作庫、3 設定）
            let index = UserDefaults.standard.integer(forKey: "startTab")
            if AppTab.allCases.indices.contains(index) { coordinator.tab = AppTab.allCases[index] }
            // 開發用：啟動參數 -demoWorkout YES 開一個示範訓練
            if UserDefaults.standard.bool(forKey: "demoWorkout"), active.isEmpty {
                let names = ["臥推", "輔助引體向上", "跑步機"]
                let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
                launcher.start(.init(exercises: names.compactMap { n in all.first { $0.name == n } }), context: context)
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
