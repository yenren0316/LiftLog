import SwiftUI
import SwiftData

/// 第 1 層「歷程」：只回答「我練了什麼、進步了多少？」。分段「紀錄｜統計」（記住上次的選擇），右上角 ⋯ 裡是「補登訓練」
/// （CHANGE_15 §2：打開和建立菜單同一個畫面，最上面多一張日期和時間的卡片）
struct HistoryView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case records, stats

        var id: String { rawValue }
        var title: String { self == .records ? "紀錄" : "統計" }
    }

    @Environment(\.modelContext) private var context
    @Environment(WorkoutLauncher.self) private var launcher
    @Environment(WorkoutCoordinator.self) private var coordinator
    @AppStorage("history.segment") private var segment: Segment = .records

    var body: some View {
        // 導覽路徑在 coordinator：補登時切到歷程、推入摘要頁（CHANGE_14 §4）
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.historyPath) {
            VStack(spacing: 0) {
                Picker("分段", selection: $segment.animation(.tap)) {
                    ForEach(Segment.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                switch segment {
                case .records: HistoryRecordsList()
                case .stats: HistoryStatsView()
                }
            }
            .screenBackground()
            .navigationTitle("歷程")
            // 大字的標題和右上角的 ⋯ 在同一列，「紀錄｜統計」在標題下方（CHANGE_15 §1）
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("補登訓練", systemImage: "calendar.badge.plus", action: backfill)
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("更多")
                }
            }
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
            .navigationDestination(for: WorkoutSession.self) { WorkoutSummaryPage(session: $0) }
            #if DEBUG
            // 開發用：-historySegment stats 切到統計；-openBackfill YES 打開補登；
            // -scrollToBottom 紀錄｜統計 切到那個分段並捲到最底部（CHANGE_08 §2）
            .task {
                if let raw = UserDefaults.standard.string(forKey: "historySegment"), let value = Segment(rawValue: raw) {
                    segment = value
                }
                if let raw = UserDefaults.standard.string(forKey: "scrollToBottom"),
                   let value = Segment.allCases.first(where: { $0.title == raw || $0.rawValue == raw }) {
                    segment = value
                }
                if UserDefaults.standard.bool(forKey: "openBackfill") { backfill() }
            }
            #endif
        }
    }

    /// 補登：和建立菜單同一個畫面（RootView 呈現），預設今天、現在往前 1 小時到現在；建立後切到歷程、推入摘要頁並打開編輯
    private func backfill() {
        launcher.requestPlan(backfill: SessionTimeEdit.defaultBackfill(), context: context)
    }
}

/// 紀錄：依月份分組（「2026 年 10 月・12 次」），點一列推入訓練摘要頁（CHANGE_14 §4）
private struct HistoryRecordsList: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]
    @Environment(WorkoutCoordinator.self) private var coordinator

    var body: some View {
        let months = Self.months(sessions)
        List {
            if sessions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("還沒有訓練紀錄").font(.headline)
                    Text("完成第一次訓練後會出現在這裡；以前的訓練可以從右上角的 ⋯ 補登。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, 8)
                .listRowBackground(Theme.card)
            }
            ForEach(months, id: \.start) { month in
                Section {
                    ForEach(month.sessions) { session in
                        TapListRow { coordinator.historyPath.append(session) } label: {
                            HistoryRow(session: session)
                        }
                        .id(session.id)
                    }
                } header: {
                    Text(Self.monthTitle(month.start, count: month.sessions.count))
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
        .listSectionSpacing(12)
        .scrollContentBackground(.hidden)
        #if DEBUG
        .debugScrollToBottom("紀錄", "records", last: months.last?.sessions.last?.id)
        #endif
    }

    /// 「2026 年 10 月・12 次」
    static func monthTitle(_ start: Date, count: Int, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month], from: start)
        return "\(parts.year ?? 0) 年 \(parts.month ?? 0) 月・\(count) 次"
    }

    /// 由新到舊的月份
    private static func months(_ sessions: [WorkoutSession]) -> [(start: Date, sessions: [WorkoutSession])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessions) { calendar.dateInterval(of: .month, for: $0.startedAt)?.start ?? $0.startedAt }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }
}

/// 日期與星期、訓練名稱、「時長・N 個動作」（沒有時間資料的舊紀錄不顯示時長）
private struct HistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                // 只有數字（中文的 .day() 會帶「日」而換行）
                Text(String(Calendar.current.component(.day, from: session.startedAt)))
                    .font(.title3.bold().monospacedDigit())
                Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 44, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title.isEmpty ? "訓練" : session.title)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        let count = session.items.filter { !$0.completedSets.isEmpty }.count
        let exercises = "\(count) 個動作"
        guard session.hasTime, let duration = session.duration else { return exercises }
        return "\(Int((duration / 60).rounded())) 分・\(exercises)"
    }
}

#if DEBUG
struct DebugScrollToBottom: ViewModifier {
    var names: [String]
    /// 最後一列的 id
    var last: AnyHashable?

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content.task {
                guard let raw = UserDefaults.standard.string(forKey: "scrollToBottom"), names.contains(raw), let last else { return }
                try? await Task.sleep(for: .milliseconds(800))
                // 先用動畫捲；List 的動畫捲動到很遠的列會沒有反應，之後再直接跳一次
                withAnimation(.easeInOut(duration: 1.2)) { proxy.scrollTo(last, anchor: .bottom) }
                try? await Task.sleep(for: .milliseconds(1400))
                proxy.scrollTo(last, anchor: .bottom)
            }
        }
    }
}

extension View {
    /// 開發用：-scrollToBottom 紀錄｜統計｜動作庫（或 records｜stats｜library）時，出現後捲到最底部
    func debugScrollToBottom(_ names: String..., last: AnyHashable?) -> some View {
        modifier(DebugScrollToBottom(names: names, last: last))
    }
}
#endif
