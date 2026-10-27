import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 第 1 層「設定」：只回答「App 怎麼運作？」——五列，點進去才是各自的內容
struct SettingsView: View {
    enum Page: String, CaseIterable, Identifiable, Hashable {
        case appearance, units, training, backup, about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .appearance: "外觀"
            case .units: "單位與進位"
            case .training: "訓練"
            case .backup: "備份與還原"
            case .about: "關於"
            }
        }

        var systemImage: String {
            switch self {
            case .appearance: "paintpalette.fill"
            case .units: "scalemass.fill"
            case .training: "timer"
            case .backup: "externaldrive.fill"
            case .about: "info.circle.fill"
            }
        }
    }

    @State private var path: [Page] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(Page.allCases) { page in
                    TapListRow { path.append(page) } label: {
                        Label(page.title, systemImage: page.systemImage).font(.body.weight(.semibold))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .hidesTabBarOnScroll("settings")
            .screenBackground()
            .navigationTitle("設定")
            .navigationDestination(for: Page.self) { page in
                Group {
                    switch page {
                    case .appearance: AppearanceSettings()
                    case .units: UnitsSettings()
                    case .training: TrainingSettings()
                    case .backup: BackupSettings()
                    case .about: AboutSettings()
                    }
                }
                .navigationTitle(page.title)
                .navigationBarTitleDisplayMode(.inline)
            }
            #if DEBUG
            // 開發用：-settingsPage backup 直接打開該頁
            .task {
                if let raw = UserDefaults.standard.string(forKey: "settingsPage"), let page = Page(rawValue: raw) { path = [page] }
            }
            #endif
        }
    }
}

/// 第 2 層頁面共用的捲動容器
private struct SettingsPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) { content }
                .padding(16)
        }
        .hidesTabBarOnScroll("settings.page")
        .screenBackground()
    }
}

// MARK: - 外觀

private struct AppearanceSettings: View {
    var body: some View {
        SettingsPage { ThemeSection() }
    }
}

// MARK: - 單位與進位

private struct UnitsSettings: View {
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    @AppStorage(RoundingSteps.barbellKgKey) private var barbellKg = RoundingSteps.barbellKgDefault
    @AppStorage(RoundingSteps.barbellLbsKey) private var barbellLbs = RoundingSteps.barbellLbsDefault
    @AppStorage(RoundingSteps.otherKgKey) private var otherKg = RoundingSteps.otherKgDefault
    @AppStorage(RoundingSteps.otherLbsKey) private var otherLbs = RoundingSteps.otherLbsDefault

    var body: some View {
        SettingsPage {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("重量單位", systemImage: "scalemass").font(.headline)
                    Spacer()
                    Picker("重量單位", selection: $unit) {
                        ForEach(WeightUnit.allCases) { Text($0.symbol).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                Text("所有畫面依這個單位顯示與輸入，資料一律存成 kg。啞鈴、壺鈴記單顆重量。")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .card()

            VStack(alignment: .leading, spacing: 10) {
                Label("強度換算表進位", systemImage: "number").font(.headline)
                stepper("槓鈴（kg）", value: $barbellKg, step: 0.5, unit: "kg")
                stepper("槓鈴（lbs）", value: $barbellLbs, step: 2.5, unit: "lb")
                stepper("其他器材（kg）", value: $otherKg, step: 0.5, unit: "kg")
                stepper("其他器材（lbs）", value: $otherLbs, step: 2.5, unit: "lb")
            }
            .card()
        }
    }

    private func stepper(_ title: String, value: Binding<Double>, step: Double, unit: String) -> some View {
        Stepper(value: value, in: step...20, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("每 \(Units.number(value.wrappedValue)) \(unit)").monospacedDigit().foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

// MARK: - 訓練

private struct TrainingSettings: View {
    @Environment(StatsCache.self) private var stats
    @AppStorage(WorkoutService.autoRestKey) private var autoRestTimer = true
    @AppStorage(LiveActivityController.enabledKey) private var liveActivityEnabled = true
    /// 0＝從來沒設定過（用近 12 週的平均）
    @AppStorage(WeeklyGoal.goalKey) private var storedGoal = 0
    @AppStorage(WeeklyGoal.cardioOnlyCountsKey) private var cardioOnlyCounts = false

    var body: some View {
        SettingsPage {
            // 每週目標（CHANGE_09 §1）
            VStack(alignment: .leading, spacing: 10) {
                let goal = WeeklyGoal.goal(stored: storedGoal, automatic: stats.snapshot.automaticWeeklyGoal)
                Stepper(value: Binding(get: { goal }, set: { storedGoal = $0 }), in: WeeklyGoal.range) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("每週目標", systemImage: "target").font(.headline)
                        Spacer()
                        Text("\(goal) 次").font(.headline.monospacedDigit())
                    }
                }
                Text(WeeklyGoal.range.contains(storedGoal)
                     ? "一週從週一開始，同一天練兩次只算 1 次，只算有完成組的訓練。首頁日曆標出達標的週，並算連續達標幾週。"
                     : "還沒設定過：依近 12 週（不含本週）的平均自動帶入，調整之後就固定用你設定的。一週從週一開始，同一天練兩次只算 1 次。")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                Divider().overlay(Theme.separator)
                Toggle(isOn: $cardioOnlyCounts) {
                    Text("只有有氧的訓練也算").font(.subheadline.weight(.semibold))
                }
                Text("關閉時，當天只做了跑步機就不算；只要有一個其他動作的完成組，那天就算。首頁日曆、訓練頻率和每週目標都用同一個算法。")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .card()
            .onChange(of: cardioOnlyCounts) { stats.recompute() }

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $autoRestTimer) {
                    Label("打勾後自動開始休息計時", systemImage: "timer").font(.headline)
                }
                Text("預設依角色：ME 主項 180 秒；DE 速度主項 60 秒；DE 爆發、下肢輔助、推、拉 90 秒；核心、補強 60 秒。每個動作可以在動作詳情的「編輯動作」裡自訂。")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .card()

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $liveActivityEnabled) {
                    Label("訓練中顯示即時動態", systemImage: "lock.iphone").font(.headline)
                }
                Text("在鎖定畫面和動態島顯示目前的組和休息倒數，不用打開 App 就能按「完成這組」。")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            .card()
            .onChange(of: liveActivityEnabled) { LiveActivityController.shared.scheduleSync() }
        }
    }
}

// MARK: - 備份與還原

private struct BackupSettings: View {
    @Environment(\.modelContext) private var context
    @State private var exportURL: URL?
    @State private var counts = (exercises: 0, sessions: 0, bodyWeights: 0)
    @State private var showingImporter = false
    @State private var pendingImport: BackupFile?
    @State private var message: String?

    var body: some View {
        SettingsPage {
            VStack(alignment: .leading, spacing: 16) {
                Text("免費簽署的 App 被刪掉後資料就沒了。記得定期匯出，存到「檔案」或用 AirDrop 傳到 Mac。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 0) {
                    stat(counts.exercises, "動作")
                    stat(counts.sessions, "次訓練")
                    stat(counts.bodyWeights, "體重")
                }
                if let exportURL {
                    ShareLink(item: exportURL) {
                        PrimaryButtonLabel(title: "匯出 JSON", systemImage: "square.and.arrow.up")
                    }
                }
                PrimaryButton(title: "從 JSON 匯入", systemImage: "square.and.arrow.down", prominent: false) {
                    showingImporter = true
                }
            }
            .card()

            AutoBackupList().card()
        }
        .onAppear(perform: refresh)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json], onCompletion: readImport)
        .alert(
            "取代目前所有資料？",
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            presenting: pendingImport
        ) { file in
            Button("匯入並取代", role: .destructive) { restore(file) }
            Button("取消", role: .cancel) {}
        } message: { file in
            Text("備份內容：\(file.exercises.count) 個動作、\(file.sessions.count) 次訓練、\(file.bodyWeights.count) 筆體重。\n目前 App 裡的資料會被刪除。建議先匯出一份目前的資料。")
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("好") {}
        }
    }

    private func stat(_ value: Int, _ title: String) -> some View {
        VStack(spacing: 2) {
            Text(String(value))
                .font(.title.bold().monospacedDigit())
                .foregroundStyle(Theme.accent)
            Text(title).font(.footnote).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 重新產生匯出檔，確保分享出去的是最新資料
    private func refresh() {
        do {
            let file = try BackupService.makeBackup(from: context)
            counts = (file.exercises.count, file.sessions.count, file.bodyWeights.count)
            let day = Date.now.formatted(.iso8601.year().month().day())
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("LiftLog-備份-\(day).json")
            try file.encode().write(to: url, options: .atomic)
            exportURL = url
        } catch {
            message = "準備匯出檔失敗：\(error.localizedDescription)"
        }
    }

    private func readImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try BackupFile.decode(Data(contentsOf: url))
        } catch {
            message = "讀不到備份檔：\(error.localizedDescription)"
        }
    }

    private func restore(_ file: BackupFile) {
        do {
            // 備份產生時還沒套用的資料遷移（輔助重量改負數、訓練名稱改成目的），匯入後補做，一樣先自動備份
            let migrated = try DataMigrations.restore(file, into: context)
            refresh()
            message = migrated.isEmpty ? "匯入完成" : "匯入完成，並更新了舊版資料：\(migrated.map(DataMigrations.title(of:)).joined(separator: "、"))"
        } catch {
            message = "匯入失敗：\(error.localizedDescription)"
        }
    }
}

// MARK: - 關於

private struct AboutSettings: View {
    var body: some View {
        SettingsPage {
            VStack(spacing: 6) {
                Label("LiftLog", systemImage: "dumbbell.fill")
                    .font(.system(.title3, design: .monospaced).bold())
                Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                if let expiration {
                    ExpirationLine(expiration: expiration)
                } else {
                    Text("簽署到期日只有裝在手機上才看得到").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .card()
        }
    }

    /// 免費簽署的到期日；開發用：啟動參數 -previewExpirationDays 6 在模擬器顯示假的到期日
    private var expiration: Date? {
        #if DEBUG
        let days = UserDefaults.standard.integer(forKey: "previewExpirationDays")
        if days > 0 { return Calendar.current.date(byAdding: .day, value: days, to: .now) }
        #endif
        return ProvisioningProfile.installedExpiration
    }
}

/// 免費簽署的到期日，剩一天以內用 warning 色提醒重新安裝
private struct ExpirationLine: View {
    var expiration: Date

    var body: some View {
        let days = ProvisioningProfile.daysLeft(until: expiration)
        let left = days > 0 ? "還有 \(days) 天" : "今天到期"
        Text("簽署到期 \(expiration.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).hour().minute()))・\(left)")
            .font(.footnote.monospacedDigit())
            .foregroundStyle(days <= 1 ? Theme.warning : Theme.textSecondary)
    }
}
