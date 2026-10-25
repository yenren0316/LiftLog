import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @AppStorage("autoRestTimer") private var autoRestTimer = true
    @AppStorage(LiveActivityController.enabledKey) private var liveActivityEnabled = true
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    @AppStorage(RoundingSteps.barbellKgKey) private var barbellKg = RoundingSteps.barbellKgDefault
    @AppStorage(RoundingSteps.barbellLbsKey) private var barbellLbs = RoundingSteps.barbellLbsDefault
    @AppStorage(RoundingSteps.otherKgKey) private var otherKg = RoundingSteps.otherKgDefault
    @AppStorage(RoundingSteps.otherLbsKey) private var otherLbs = RoundingSteps.otherLbsDefault
    @State private var exportURL: URL?
    @State private var counts = (exercises: 0, sessions: 0, bodyWeights: 0)
    @State private var showingImporter = false
    @State private var pendingImport: BackupFile?
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "設定")

                ThemeSection()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("重量單位", systemImage: "scalemass").font(.headline)
                        Spacer()
                        Picker("重量單位", selection: $unit) {
                            ForEach(WeightUnit.allCases) { Text($0.symbol).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
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

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $autoRestTimer) {
                        Label("打勾後自動開始休息計時", systemImage: "timer").font(.headline)
                    }
                    Text("預設依角色：主項、爆發、推、拉 180 秒；單邊、核心 90 秒；補強 60 秒。每個動作可以在動作詳情的「編輯」裡自訂。")
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

                VStack(alignment: .leading, spacing: 16) {
                    Label("備份", systemImage: "externaldrive.fill")
                        .font(.title3.bold())
                    Text("免費簽署的 App 被刪掉後資料就沒了。記得定期匯出，存到「檔案」或用 AirDrop 傳到 Mac。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)

                    HStack(spacing: 0) {
                        stat(counts.exercises, "動作")
                        stat(counts.sessions, "次訓練")
                        stat(counts.bodyWeights, "體重")
                    }
                    .padding(.vertical, 8)

                    if let exportURL {
                        ShareLink(item: exportURL) {
                            actionLabel("匯出 JSON", icon: "square.and.arrow.up", filled: true)
                        }
                    }
                    Button { showingImporter = true } label: {
                        actionLabel("從 JSON 匯入", icon: "square.and.arrow.down", filled: false)
                    }
                    .buttonStyle(.plain)
                }
                .card()

                VStack(spacing: 6) {
                    Label("LiftLog", systemImage: "dumbbell.fill")
                        .font(.system(.title3, design: .monospaced).bold())
                    Text("版本 \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
            }
            .padding(16)
        }
        .screenBackground()
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

    private func stepper(_ title: String, value: Binding<Double>, step: Double, unit: String) -> some View {
        Stepper(value: value, in: step...20, step: step) {
            HStack {
                Text(title)
                Spacer()
                Text("每 \(Units.number(value.wrappedValue)) \(unit)").monospacedDigit().foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func stat(_ value: Int, _ title: String) -> some View {
        VStack(spacing: 2) {
            Text(String(value))
                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.accent)
            Text(title).font(.footnote).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionLabel(_ title: String, icon: String, filled: Bool) -> some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(filled ? Theme.onAccent : Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(filled ? Theme.accent : Theme.field, in: .capsule)
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
            try BackupService.restore(file, into: context)
            refresh()
            message = "匯入完成"
        } catch {
            message = "匯入失敗：\(error.localizedDescription)"
        }
    }
}
