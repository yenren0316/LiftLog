import SwiftUI
import SwiftData

/// 第 1 層「歷程」：只回答「我練了什麼、進步了多少？」。分段「紀錄｜統計」（記住上次的選擇），右上角 ⋯ 裡是「補登訓練」
struct HistoryView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case records, stats

        var id: String { rawValue }
        var title: String { self == .records ? "紀錄" : "統計" }
    }

    @Environment(\.modelContext) private var context
    @Environment(WorkoutLauncher.self) private var launcher
    @AppStorage("history.segment") private var segment: Segment = .records
    @State private var path = NavigationPath()
    @State private var showingBackfill = false
    /// 補登第 1 步選好之後，等 sheet 關掉再進入下一步
    @State private var pendingBackfill: (interval: DateInterval, followsPlan: Bool)?

    var body: some View {
        NavigationStack(path: $path) {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("補登訓練", systemImage: "calendar.badge.plus") { showingBackfill = true }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("更多")
                }
            }
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
            .sheet(isPresented: $showingBackfill, onDismiss: continueBackfill) {
                BackfillSheet { interval, followsPlan in
                    pendingBackfill = (interval, followsPlan)
                    showingBackfill = false
                }
            }
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
                if UserDefaults.standard.bool(forKey: "openBackfill") { showingBackfill = true }
            }
            #endif
        }
    }

    /// 補登第 2 步：照建議走建立菜單，或自由選動作（建立已結束的訓練後直接進入編輯）
    private func continueBackfill() {
        guard let pending = pendingBackfill else { return }
        pendingBackfill = nil
        if pending.followsPlan {
            launcher.requestPlan(backfill: pending.interval, context: context)
        } else {
            launcher.start(.init(openAdd: true, backfill: pending.interval), context: context)
        }
    }
}

/// 紀錄：依月份分組（「2026 年 10 月・12 次」），點一列打開訓練摘要浮窗
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
                        Button { coordinator.showSummary(of: session) } label: {
                            HistoryRow(session: session).contentShape(.rect)
                        }
                        .buttonStyle(.pressable)
                        .listRowBackground(Theme.card)
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
        .hidesTabBarOnScroll("history.records")
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

/// 補登第 1 步：日期、開始時間、結束時間（預設今天、現在往前 1 小時到現在），再選照建議建立菜單或自由選動作
private struct BackfillSheet: View {
    var onChoose: (DateInterval, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var day = Date.now
    @State private var start = max(Calendar.current.startOfDay(for: .now), Date.now.addingTimeInterval(-3600))
    @State private var end = Date.now

    private var interval: DateInterval? {
        let s = SessionTimeEdit.combine(day: day, time: start), e = SessionTimeEdit.combine(day: day, time: end)
        return e > s ? DateInterval(start: s, end: e) : nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 12) {
                    row("日期") { DatePicker("日期", selection: $day, in: ...Date.now, displayedComponents: .date) }
                    row("開始時間") { DatePicker("開始時間", selection: $start, displayedComponents: .hourAndMinute) }
                    row("結束時間") { DatePicker("結束時間", selection: $end, displayedComponents: .hourAndMinute) }
                    if interval == nil {
                        Text("結束時間必須晚於開始時間").font(.footnote).foregroundStyle(Theme.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .card()
                Text("補登的訓練是已經結束的訓練：沒有休息計時、即時動態，也不會影響進行中的訓練。")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                PrimaryButton(title: "照建議建立菜單", isEnabled: interval != nil) {
                    if let interval { onChoose(interval, true) }
                }
                PrimaryButton(title: "自由選動作", prominent: false, isEnabled: interval != nil) {
                    if let interval { onChoose(interval, false) }
                }
            }
            .padding(16)
            .screenBackground()
            .navigationTitle("補登訓練")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
        .presentationDetents([.large])
    }

    private func row(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
        HStack {
            Text(title).foregroundStyle(Theme.textSecondary)
            Spacer()
            picker().labelsHidden()
        }
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
                TabBarAutoHideLog.note("scrollToBottom \(raw) -> \(last)")
                // 先用動畫捲（捲動中才會觸發分頁列的切換）；List 的動畫捲動到很遠的列會沒有反應，之後再直接跳一次
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
