import SwiftUI
import SwiftData

/// 訓練摘要（CHANGE_07 C-2；CHANGE_14 §4 從浮窗改成推入的頁面）：唯讀，內容不能點進下一層。
/// 歷程「紀錄」的列和動作詳情的「歷史」、個人紀錄都在各自的 NavigationStack 推入這一頁（全高、系統的返回、左邊緣往右滑返回）；
/// 補登和深層連結這類從別的地方打開的，切到歷程再推入（WorkoutCoordinator.showSummary）。
/// 右上角 ⋯：編輯（全螢幕）、再做一次、刪除（確認後返回上一頁，返回完才刪）
struct WorkoutSummaryPage: View {
    let session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Environment(WorkoutLauncher.self) private var launcher
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg

    @State private var editing = false
    @State private var confirmingDelete = false
    /// 確認刪除後先返回上一頁，頁面消失時才刪，畫面不會再讀到已刪除的資料
    @State private var deletesOnDisappear = false
    @State private var weightEntry: BodyWeightEntryRequest?
    @Query(sort: \BodyWeight.date) private var weights: [BodyWeight]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                let records = Set(NewRecords.find(in: session).map(\.exerciseID))
                ForEach(session.orderedItems.filter { !$0.completedSets.isEmpty }) { item in
                    ExerciseLine(item: item, isNewRecord: item.exercise.map { records.contains($0.id) } ?? false, unit: unit)
                }
                if session.orderedItems.allSatisfy({ $0.completedSets.isEmpty }) {
                    Text("這次沒有完成的組").foregroundStyle(Theme.textSecondary)
                }
                if !session.note.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("備註").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                        Text(session.note)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .screenBackground()
        .navigationTitle("訓練摘要")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("編輯", systemImage: "pencil") { editing = true }
                    // 頁面不是 sheet：開始衝突的確認由 RootView 呈現，開始後直接展開訓練畫面
                    Button("再做一次", systemImage: "arrow.clockwise") {
                        launcher.repeatSession(session, origin: .root, context: context)
                    }
                    Button("刪除", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("更多")
            }
        }
        .alert("刪除這次訓練？", isPresented: $confirmingDelete) {
            Button("刪除", role: .destructive) {
                deletesOnDisappear = true
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("這次訓練的所有組都會刪除，無法復原。")
        }
        .onDisappear {
            guard deletesOnDisappear else { return }
            deletesOnDisappear = false
            WorkoutActions.discard(session, in: context)
        }
        .sheet(item: $weightEntry) { BodyWeightEntrySheet(date: $0.date) }
        .fullScreenCover(isPresented: $editing) {
            SessionEditorView(session: session, openAddOnAppear: coordinator.openAddInEditor) {
                coordinator.openAddInEditor = false
            }
        }
        .onAppear {
            // 補登：頁面一推入就進入編輯
            if coordinator.editOnSummaryOpen {
                coordinator.editOnSummaryOpen = false
                editing = true
            }
        }
        .accessibilityIdentifier("workoutSummaryPage")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.title.isEmpty ? "訓練" : session.title)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text(session.startedAt.formatted(.dateTime.year().month().day().weekday(.wide)))
                .foregroundStyle(Theme.textSecondary)
            Text(Self.timeText(session))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
            // 當天的體重；沒有紀錄時可以補記
            if let weight = weights.last(where: { Calendar.current.isDate($0.date, inSameDayAs: session.startedAt) }) {
                Label("體重 \(unit.formatWithUnit(kg: weight.kg))", systemImage: "scalemass")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Button("＋ 記錄當天體重") { weightEntry = BodyWeightEntryRequest(date: session.startedAt) }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .buttonStyle(.pressable)
            }
        }
    }

    /// 「09:10–10:25・75 分」；沒有時間資料的舊紀錄「未記錄時間」
    static func timeText(_ session: WorkoutSession, calendar: Calendar = .current) -> String {
        guard session.hasTime, let end = session.endedAt else { return "未記錄時間" }
        // 固定 24 小時制：跟著地區格式在 12 小時制下會變成沒有上午／下午的「06:30」
        func clock(_ date: Date) -> String {
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
        }
        let minutes = Int((end.timeIntervalSince(session.startedAt) / 60).rounded())
        return "\(clock(session.startedAt))–\(clock(end))・\(minutes) 分"
    }
}

/// 一個動作：名稱、新紀錄的小獎盃（這次訓練刷新了估算 1RM，CHANGE_15 §4）、角色、精簡紀錄（「60×5、65×3、70×1 (MAX)」）
private struct ExerciseLine: View {
    var item: SessionExercise
    var isNewRecord: Bool
    var unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(item.exercise?.name ?? "").font(.headline)
                if isNewRecord {
                    Image(systemName: "trophy.fill")
                        .font(.caption)
                        .accessibilityLabel("新紀錄")
                        .accessibilityIdentifier("newRecordTrophy")
                }
                RoleBadge(role: item.role)
            }
            Text(item.summary(unit: unit))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !item.note.isEmpty {
                Text(item.note).font(.footnote).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14)
    }
}
