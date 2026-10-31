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
        // 開發用：-widgetGallery small｜lock｜live｜liveStates｜island｜control 顯示小工具和即時動態的預覽
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
            // 收起鍵盤（CHANGE_10 §1）：可以捲動的畫面往下捲時收起；點輸入框以外的地方收起（window 上的點擊，sheet 也適用）
            .scrollDismissesKeyboard(.interactively)
            .background(KeyboardDismissOnTap())
            .preferredColorScheme(.dark)
            // 設定（CHANGE_13 §1）：放在換主題重建的範圍外面，在「外觀」換主題時 sheet 不會被關掉重開；
            // 裡面自己依主題重建（導覽路徑在 coordinator，留在原本那一頁）
            .sheet(isPresented: $coordinator.showingSettings, onDismiss: settingsDismissed) {
                SettingsView()
                    .id(theme)
                    .environment(coordinator)
                    .environment(launcher)
                    .environment(stats)
                    .preferredColorScheme(.dark)
            }
            .onChange(of: theme) {
                SnapshotWriter.shared.update()
                LiveActivityController.shared.scheduleSync()
            }
            // 即時動態的目標重量依單位顯示
            .onChange(of: unit) { LiveActivityController.shared.scheduleSync() }
            .onOpenURL { router.open($0) }
            // 小工具的＋如果在小工具的程序執行，連結留在 App Group，回到前景時接手
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active else { return }
                router.consumePendingLink()
                // 回到前景：日期和上次計算時不同就重算統計（CHANGE_11 §2）
                stats.refresh(.foreground)
            }
            .onChange(of: router.pending, initial: true) { _, link in
                if let link { handle(link) }
            }
    }

    /// 深層連結：workout 打開進行中的訓練；new 進入建立菜單（有進行中的訓練時由 WorkoutLauncher 先詢問）。
    /// 設定的 sheet 開著時先關掉，關完再導向（同一時間只能呈現一個）
    private func handle(_ link: DeepLink) {
        router.pending = nil
        guard !coordinator.showingSettings else {
            // 關完再交回 router，用那時候的狀態（有沒有進行中的訓練）導向
            launcher.afterSheetDismiss { [router] in router.pending = link }
            coordinator.showingSettings = false
            return
        }
        let workoutShown = coordinator.isExpanded && (active.first != nil || coordinator.summary != nil)
        switch link.destination(hasActiveWorkout: !active.isEmpty) {
        case .workout:
            coordinator.summary = nil
            coordinator.isExpanded = true
        case .plan:
            closeWorkout()
            coordinator.tab = .today
            if workoutShown {
                // 等訓練畫面的 sheet 關掉再開建立菜單的 sheet
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    launcher.requestPlan(context: context)
                }
            } else {
                launcher.requestPlan(context: context)
            }
        case .today:
            closeWorkout()
            coordinator.tab = .today
        }
    }

    private func settingsDismissed() {
        coordinator.settingsPath = []
        launcher.sheetDismissed()
    }

    private func closeWorkout() {
        coordinator.isExpanded = false
        coordinator.summary = nil
    }

    private var tabs: some View {
        TabView(selection: $coordinator.tab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    switch tab {
                    case .today: TodayView()
                    case .history: HistoryView()
                    case .library: LibraryView()
                    }
                }
            }
        }
        // 分頁列交給系統（CHANGE_11 §1）：往下捲縮小、往上捲恢復；「訓練中」橫條放在系統的附屬列
        .tabBarMinimizeBehavior(.onScrollDown)
        .workoutMiniBar(active.first)
        .environment(coordinator)
        .environment(launcher)
        .environment(restTimer)
        .environment(stats)
        .sheet(item: $launcher.planRequest, onDismiss: launcher.sheetDismissed) { request in
            PlanSheet(request: request)
                .environment(coordinator)
                .environment(launcher)
                .environment(stats)
        }
        .sheet(isPresented: $coordinator.showingTrainingStatus, onDismiss: launcher.sheetDismissed) {
            TrainingStatusSheet()
                .environment(coordinator)
                .environment(launcher)
                .environment(stats)
        }
        .planEntryQuestion(launcher)
        .launchConfirmation(launcher, origin: .root, context: context)
        // 訓練畫面（CHANGE_15 §3）：系統的 sheet，只有全高。往下拖關閉＝縮小到附屬列的「訓練中」橫條，訓練繼續
        // （和左上角的收合一樣，只是 isExpanded 變成 false）；內容捲到最上面時才會往下拖關閉，是系統的行為。
        // 完成畫面不能往下拖關閉，要按「完成」（避免還沒存今天體重就關掉）
        .sheet(isPresented: Binding(
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
            .presentationDetents([.large])
            .interactiveDismissDisabled(coordinator.summary != nil)
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
            #if DEBUG
            // 開發用：-emptyData YES 清空所有資料、不匯入 seed，檢查空狀態
            let importsData = !DemoData.wipeIfRequested(in: context)
            #else
            let importsData = true
            #endif
            if importsData {
                SeedImporter.importIfNeeded(into: context)
                GuideImporter.importIfNeeded(into: context)
                LibraryAdditions.applyIfNeeded(into: context)
                ConjugateLibrary.applyIfNeeded(into: context)
                // 資料遷移：每個遷移執行前先在 Documents/AutoBackups 自動備份
                DataMigrations.runIfNeeded(context: context)
            }
            #if DEBUG
            // 開發用：-demoData YES 在 seed 之外加幾筆示範訓練和近期體重（只加一次）；
            // -demoDeletable YES 加一筆「刪除測試」（摘要頁刪除的 UI 測試，CHANGE_14 §4）
            DemoData.addIfRequested(in: context)
            DemoData.addDeletableIfRequested(in: context)
            // 開發用：-importBackup <路徑> 匯入備份（CHANGE_11 §9，真實資料驗證）
            RealDataDebug.importIfRequested(into: context)
            #endif
            stats.start(context: context)
            #if DEBUG
            // 開發用：-dumpStats <路徑> 輸出統計快照裡要比對的數值（搭配 -fakeNow 固定「現在」）
            RealDataDebug.dumpIfRequested(stats.snapshot, context: context)
            #endif
            SnapshotWriter.shared.start(context: context)
            LiveActivityController.shared.start()
            #if DEBUG
            // 開發用：啟動參數 -startTab 1 直接切到該分頁（0 今天、1 歷程、2 動作庫）
            let index = UserDefaults.standard.integer(forKey: "startTab")
            if AppTab.allCases.indices.contains(index) { coordinator.tab = AppTab.allCases[index] }
            // 開發用：-openSettings YES 打開設定的 sheet；-settingsPage backup 打開設定並直接進入該頁（CHANGE_13 §1）
            if let raw = UserDefaults.standard.string(forKey: "settingsPage"), let page = SettingsView.Page(rawValue: raw) {
                coordinator.settingsPath = [page]
                coordinator.showingSettings = true
            } else if UserDefaults.standard.bool(forKey: "openSettings") {
                coordinator.showingSettings = true
            }
            // 開發用：啟動參數 -demoWorkout YES 開一個示範訓練；-demoWorkoutElapsed 3930 把開始時間往前推（即時動態的經過時間）；
            // -demoWorkoutRoles dynamicEffort,pull,cardio 指定三個動作的角色（臥推當 DE 主項，截建議重量用）；
            // -demoWorkoutDayType deUpper 指定日型、-demoWorkoutTitle <名稱> 用自訂的名稱（動態島的日型簡稱，CHANGE_11 V3）
            if UserDefaults.standard.bool(forKey: "demoWorkout"), active.isEmpty {
                let names = ["臥推", "輔助引體向上", "跑步機"]
                let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
                let roles = UserDefaults.standard.string(forKey: "demoWorkoutRoles")?
                    .split(separator: ",").compactMap { Role(rawValue: String($0)) }
                let dayType = UserDefaults.standard.string(forKey: "demoWorkoutDayType").flatMap(DayType.init(rawValue:))
                let session = launcher.start(.init(exercises: names.compactMap { n in all.first { $0.name == n } },
                                                   roles: roles?.count == names.count ? roles : nil, dayType: dayType), context: context)
                if let session, let title = UserDefaults.standard.string(forKey: "demoWorkoutTitle") {
                    session.title = title
                    session.isTitleCustom = true
                    WorkoutActions.save(context)
                }
                let elapsed = UserDefaults.standard.double(forKey: "demoWorkoutElapsed")
                if let session, elapsed > 0 {
                    session.startedAt = .now.addingTimeInterval(-elapsed)
                    WorkoutActions.save(context)
                }
            } else if UserDefaults.standard.bool(forKey: "demoWorkout") {
                coordinator.isExpanded = true
            }
            // 開發用：-trainingStatus YES 打開「訓練狀態」浮窗（截圖用）
            if UserDefaults.standard.bool(forKey: "trainingStatus") { coordinator.showingTrainingStatus = true }
            // 開發用：-discardActive YES 捨棄進行中的訓練，測試沒有訓練時的狀態。
            // 和訓練畫面的「捨棄訓練」一樣，休息倒數一起停掉（CHANGE_16：不然下一個測試的即時動態一開始就在休息）
            if UserDefaults.standard.bool(forKey: "discardActive") {
                RestTimer.shared.skip()
                if let session = active.first { WorkoutActions.discard(session, in: context) }
            }
            // 開發用：-openSummary latest 切到歷程、推入最近一次訓練的摘要頁；-openSummary edit 直接進入編輯
            if let mode = UserDefaults.standard.string(forKey: "openSummary") {
                var latest = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endedAt != nil },
                                                             sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
                latest.fetchLimit = 1
                if let session = try? context.fetch(latest).first {
                    coordinator.showSummary(of: session, editing: mode == "edit")
                }
            }
            // 開發用：-demoBackfillPrompt YES 補登今天 07:00–08:00 的訓練，深蹲填了數字但沒打勾、單腳 RDL 沒填，
            // 搭配 -editorFinishPrompt YES 截「完成」的詢問（CHANGE_08 V5）
            if UserDefaults.standard.bool(forKey: "demoBackfillPrompt") {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: .now)
                let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
                if let start = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: today),
                   let session = launcher.start(.init(exercises: ["深蹲", "單腳 RDL"].compactMap { n in all.first { $0.name == n } },
                                                      backfill: DateInterval(start: start, duration: 3600)), context: context) {
                    for set in session.orderedItems.first?.orderedSets ?? [] {
                        set.weightKg = 80
                        set.reps = 5
                    }
                    WorkoutActions.save(context)
                }
            }
            // 開發用：-previewFinishSummary YES 用最近一次訓練顯示完成畫面（看今天體重的鍵盤）
            if UserDefaults.standard.bool(forKey: "previewFinishSummary") {
                var latest = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endedAt != nil },
                                                             sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
                latest.fetchLimit = 1
                if let session = try? context.fetch(latest).first {
                    coordinator.summary = WorkoutSummary(session: session, unit: unit)
                    coordinator.isExpanded = true
                }
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
