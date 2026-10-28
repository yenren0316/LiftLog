import SwiftUI
import SwiftData
import UIKit

/// 「訓練狀態」浮窗（CHANGE_10 §3）：點今天的日曆卡打開。高度等於內容的高度（CHANGE_11 §7，拿掉半高）：
/// 量捲動內容的高度加上標題列和底部的安全區域，打開就看得到全部；超過螢幕（例如系統字級很大）時用全高，內容可以捲動。
/// 本週三行；輪替狀態四列（ME 下肢、ME 上肢、DE 下肢、DE 上肢）。數字都從 StatsCache 讀（TrainingStatus）
struct TrainingStatusSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(StatsCache.self) private var stats
    @Environment(WorkoutCoordinator.self) private var coordinator
    @Environment(WorkoutLauncher.self) private var launcher
    @Environment(\.dismiss) private var dismiss
    /// 每週目標：設定過就用設定的，沒設定過用近 12 週的平均（CHANGE_09 §1）
    @AppStorage(WeeklyGoal.goalKey) private var storedGoal = 0
    /// 內容需要的高度（量到之前用半高）
    @State private var contentHeight: CGFloat?

    var body: some View {
        let status = stats.snapshot.trainingStatus
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    weekCard(status)
                    rotationCard(status)
                }
                .padding(16)
            }
            // 捲動內容＋上下的 inset（標題列、Home 指示條）就是浮窗需要的高度
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                (geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom).rounded(.up)
            } action: { _, height in
                contentHeight = height
            }
            .screenBackground()
            .navigationTitle("訓練狀態")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([detent])
        .presentationDragIndicator(.visible)
    }

    /// 內容的高度；比螢幕高時用全高（內容捲動）
    private var detent: PresentationDetent {
        guard let contentHeight else { return .medium }
        return contentHeight >= Self.screenHeight ? .large : .height(contentHeight)
    }

    private static var screenHeight: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? 800
    }

    private func weekCard(_ status: TrainingStatus) -> some View {
        let goal = WeeklyGoal.goal(stored: storedGoal, automatic: stats.snapshot.automaticWeeklyGoal)
        let week = status.thisWeek, last = status.lastWeek
        return VStack(alignment: .leading, spacing: 6) {
            Text("本週・\(week.days) 天（目標 \(goal)）・\(week.sets) 組")
                .font(.headline.monospacedDigit())
            Text("下肢 \(week.lower)・上肢 \(week.upper)・其他 \(week.other) 組・有氧 \(Units.number(week.cardioMinutes)) 分鐘")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
            Text("上週同期：\(last.days) 天・\(last.sets) 組")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
        .card(padding: 16)
    }

    private func rotationCard(_ status: TrainingStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("輪替狀態").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 4)
            ForEach(Array(status.rotation.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider().overlay(Theme.separator) }
                if let id = row.lastSessionID {
                    // 有紀錄的列：整列可以點，打開那次訓練的摘要浮窗（和歷程同一個元件）
                    Button { openSummary(id) } label: { rotationRow(row).tapRowInset() }
                        .buttonStyle(.tapRow)
                        .tapRowOutset()
                } else {
                    rotationRow(row)
                }
            }
        }
        .card(padding: 16)
    }

    private func rotationRow(_ row: TrainingStatus.Rotation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.dayType.title).font(.headline)
                if row.isNext { AccentChip(text: "下一次") }
                Spacer(minLength: 8)
                lastText(row)
            }
            Text(mainText(row))
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, 6)
    }

    /// 「12 天前（10/15）」；超過 14 天用 warning 色；沒有紀錄「還沒練過」
    @ViewBuilder
    private func lastText(_ row: TrainingStatus.Rotation) -> some View {
        if let date = row.lastDate {
            let days = TrainingStatus.daysAgo(date, now: stats.snapshot.now, calendar: .current)
            Text("\(days) 天前（\(date.formatted(.dateTime.month(.defaultDigits).day()))）")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(TrainingStatus.isStale(daysAgo: days) ? Theme.warning : Theme.textSecondary)
        } else {
            Text("還沒練過").font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
    }

    /// 「主項：上次 深蹲 → 下次 傳統硬舉」；沒有上次「主項：下次 深蹲」
    private func mainText(_ row: TrainingStatus.Rotation) -> String {
        let next = row.nextMain.map { "下次 \($0)" } ?? "下次 —"
        guard let last = row.lastMain else { return "主項：\(next)" }
        return "主項：上次 \(last) → \(next)"
    }

    /// 摘要浮窗和這個浮窗都由 RootView 呈現：先關掉這個，關完再打開摘要
    private func openSummary(_ id: UUID) {
        var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let session = try? context.fetch(descriptor).first else { return }
        launcher.afterSheetDismiss { [coordinator] in coordinator.showSummary(of: session) }
        coordinator.showingTrainingStatus = false
    }
}
