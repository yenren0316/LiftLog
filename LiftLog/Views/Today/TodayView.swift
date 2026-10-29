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
                    WeekCardView(days: WeekCard.days(regions: snapshot.dayRegions, now: snapshot.now),
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

/// 「本週」卡：「N 天・N 組」（和訓練狀態的本週同一份數字）、週一到週日的圓點（依部位上色、今天外框）、
/// 輪替的四個膠囊、很久沒練的分類提醒。整張卡點一下打開「訓練狀態」浮窗
private struct WeekCardView: View {
    var days: [WeekCard.Day]
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
                HStack(spacing: 0) {
                    ForEach(days) { day in
                        VStack(spacing: 6) {
                            Text(day.label)
                                .font(.caption.weight(day.isToday ? .bold : .regular))
                                .foregroundStyle(day.isToday ? Theme.textPrimary : Theme.textSecondary)
                            WeekDot(day: day)
                        }
                        .frame(maxWidth: .infinity)
                    }
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

/// 一天的圓點：有完成組的日子依部位上色（全身沿對角線兩色），今天強調色外框，今天之後是空的淡色圓點。
/// 系統「不以顏色區分」開啟時，圓點裡加上部位的字（下、上、全，CHANGE_13 §3）
private struct WeekDot: View {
    var day: WeekCard.Day

    @Environment(\.accessibilityDifferentiateWithoutColor) private var withoutColor

    static let size: CGFloat = 28

    var body: some View {
        Group {
            if day.isFuture {
                Circle().stroke(Theme.field, lineWidth: 1.5)
            } else if let region = day.region {
                Circle().fill(region.fill)
                    .overlay { if withoutColor { RegionLetter(region: region, size: 13) } }
            } else {
                Circle().fill(Theme.field)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .overlay {
            if day.isToday {
                Circle().stroke(Theme.accent, lineWidth: 2).padding(-4)
            }
        }
        .padding(4)
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
