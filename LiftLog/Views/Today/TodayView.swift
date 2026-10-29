import SwiftUI
import SwiftData

/// 第 1 層「今天」：只回答「下一次該練什麼？」——「下一次」卡和「本週」卡（CHANGE_13 §2）。
/// 標題是系統的大標題（§2-5），右上角的齒輪打開設定的 sheet（§1）。統計都從 StatsCache 讀，body 裡不掃描訓練紀錄
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Environment(WorkoutLauncher.self) private var launcher
    @Environment(StatsCache.self) private var stats
    @AppStorage(WeightUnit.storageKey) private var unit: WeightUnit = .kg
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil }) private var active: [WorkoutSession]

    var body: some View {
        let snapshot = stats.snapshot
        let session = active.first
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    NextCardView(content: NextCard.content(
                        active: session.map { NextCard.Active(dayType: $0.dayType, title: $0.title, startedAt: $0.startedAt) },
                        answers: snapshot.nextPlan, main: snapshot.suggestedMain, mainLogs: snapshot.suggestedMainLogs,
                        unit: unit, now: snapshot.now)
                    ) {
                        // 有進行中的訓練：打開訓練畫面；沒有：帶著預設答案進入建立菜單（WorkoutLauncher）
                        if session != nil {
                            coordinator.isExpanded = true
                        } else {
                            launcher.requestPlan(snapshot.nextPlan, context: context)
                        }
                    }
                    WeekCardView(regions: snapshot.dayRegions, now: snapshot.now,
                                 week: snapshot.trainingStatus.thisWeek, next: snapshot.nextPlan.dayType,
                                 reminder: snapshot.weekReminder) {
                        coordinator.showingTrainingStatus = true
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .screenBackground()
            .navigationTitle("今天")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("設定", systemImage: "gearshape") { coordinator.showingSettings = true }
                }
            }
        }
    }
}

/// 「下一次」卡：小字「下一次」、大字的日型、主項一行、動作數一行、全寬的「開始」。
/// 有進行中的訓練時改成「進行中」、日型和訓練名稱、經過時間、「繼續」。整張卡（含按鈕）是一個按鈕
private struct NextCardView: View {
    var content: NextCard.Content
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 4) {
                switch content {
                case let .next(dayType, main, volume):
                    caption("下一次")
                    Text(dayType.title).font(.title.bold())
                    mainText(main)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(volume).font(.subheadline).foregroundStyle(Theme.textSecondary)
                    PrimaryButtonLabel(title: "開始").padding(.top, 10)
                case let .active(active):
                    caption("進行中")
                    Text(active.dayType?.title ?? title(active)).font(.title.bold()).lineLimit(1)
                    // 沒有日型（自由選動作）時，名稱已經是大字
                    if active.dayType != nil {
                        Text(title(active)).font(.subheadline.weight(.semibold)).lineLimit(1)
                    }
                    Label { ElapsedTimeText(since: active.startedAt) } icon: { Image(systemName: "timer") }
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                    PrimaryButtonLabel(title: "繼續").padding(.top, 10)
                }
            }
            .padding(16)
        }
        // 整張卡都能點，按下時換成按壓色（CHANGE_10 §4）
        .buttonStyle(.tapCard)
        .accessibilityIdentifier("nextCard")
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
    }

    private func title(_ active: NextCard.Active) -> String {
        active.title.isEmpty ? "訓練" : active.title
    }

    /// 建議主項和建議重量用強調色（CHANGE_13 §3）
    private func mainText(_ main: NextCard.MainLine) -> Text {
        let name = Text(main.name ?? "—").foregroundStyle(main.name == nil ? Theme.textSecondary : Theme.accent)
        guard let detail = main.detail else { return Text("主項：\(name)") }
        let detailText = Text(detail).foregroundStyle(main.detailIsSuggestion ? Theme.accent : Theme.textPrimary)
        return Text("主項：\(name)・\(detailText)")
    }
}

/// 「本週」卡：「N 天・N 組」（和訓練狀態的本週同一份數字）、點點日曆（最右邊一欄是本週，CHANGE_14 §1）和圖例、
/// 輪替的四個膠囊、很久沒練的分類提醒。整張卡點一下打開「訓練狀態」浮窗；日曆的格子本身不能點
private struct WeekCardView: View {
    var regions: [Date: DayRegion]
    var now: Date
    var week: TrainingStatus.Period
    var next: DayType
    var reminder: WeekCard.Reminder?
    var onOpen: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("本週").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(week.days) 天・\(week.sets) 組").font(.subheadline.weight(.semibold).monospacedDigit())
                }
                VStack(alignment: .leading, spacing: 8) {
                    WeekCalendar(regions: regions, now: now)
                    RegionLegend(style: .cells)
                }
                // 和建立菜單的日型一樣兩排：ME 一排、DE 一排
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(WeekCard.rotation(next: next), id: \.dayType) { item in
                        RotationCapsule(dayType: item.dayType, mark: item.mark)
                    }
                }
                if let reminder {
                    Label(reminder.text, systemImage: "exclamationmark.circle")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                }
            }
            .padding(16)
        }
        .buttonStyle(.tapCard)
        .accessibilityIdentifier("weekCard")
        .accessibilityHint("打開訓練狀態")
    }
}

/// 點點日曆（CHANGE_14 §1）：每一欄是一週，由上到下是週一到週日，最右邊一欄是本週。
/// 欄數是卡片寬度放得下的週數（格子 14 pt、間距 3 pt，至少 12 週）；上方在每個月第一個週一那一欄標月份
private struct WeekCalendar: View {
    var regions: [Date: DayRegion]
    var now: Date

    /// 格子的大小（12～14 pt）：首頁要一個畫面放得下
    static let cell: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let layout = WeekCard.Grid.layout(width: geo.size.width, cell: Self.cell)
            let weeks = WeekCard.weeks(regions: regions, now: now, count: layout.weeks)
            VStack(alignment: .leading, spacing: WeekCard.Grid.monthRow - WeekCard.Grid.monthLabel) {
                monthLabels(weeks, cell: layout.cell)
                HStack(alignment: .top, spacing: WeekCard.Grid.gap) {
                    ForEach(weeks) { week in
                        VStack(spacing: WeekCard.Grid.gap) {
                            ForEach(week.days) { CalendarCell(day: $0, size: layout.cell) }
                        }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("近 \(layout.weeks) 週的訓練日曆")
        }
        .frame(height: WeekCard.Grid.monthRow + WeekCard.Grid.height(cell: Self.cell))
    }

    /// 月份標在那個月第一個週一的那一欄；最右邊一欄的字靠右對齊，不超出日曆
    private func monthLabels(_ weeks: [WeekCard.Week], cell: CGFloat) -> some View {
        HStack(spacing: WeekCard.Grid.gap) {
            ForEach(weeks) { week in
                Text(week.month ?? "")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize()
                    .frame(width: cell, height: WeekCard.Grid.monthLabel,
                           alignment: week.id == weeks.last?.id ? .trailing : .leading)
            }
        }
    }
}

/// 日曆的一格：有完成組的日子依部位上色（全身沿對角線兩色、有氧與其他中性灰），沒練的日子 field，
/// 本週今天之後只畫外框；今天在格子外面一圈主要文字色的外框（不用強調色）。
/// 系統「不以顏色區分」開啟時格子裡不放字（太小），圖例裡有
private struct CalendarCell: View {
    var day: WeekCard.Day
    var size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size / 4)
        Group {
            if day.isFuture {
                shape.strokeBorder(Theme.field, lineWidth: 1.5)
            } else if let region = day.region {
                shape.fill(region.fill)
            } else {
                shape.fill(Theme.field)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            if day.isToday {
                RoundedRectangle(cornerRadius: size / 4 + 2)
                    .strokeBorder(Theme.textPrimary, lineWidth: 1.5)
                    .padding(-2.5)
            }
        }
    }
}

/// 輪替的一個日型：這一輪練過的加勾勾；「下一次」強調色外框、「DE 上肢・下一次」；之後的不加標記
private struct RotationCapsule: View {
    var dayType: DayType
    var mark: WeekCard.RotationMark

    var body: some View {
        HStack(spacing: 4) {
            if mark == .done {
                Image(systemName: "checkmark").font(.caption.weight(.bold))
            }
            Text(mark == .next ? "\(dayType.title)・下一次" : dayType.title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(mark == .upcoming ? Theme.textSecondary : Theme.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 30)
        .background(Theme.field, in: .capsule)
        .overlay {
            if mark == .next { Capsule().stroke(Theme.accent, lineWidth: 1.5) }
        }
    }
}
