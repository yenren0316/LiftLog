import Foundation
import SwiftData
import WidgetKit

extension WidgetSnapshot {
    /// 依訓練紀錄和主題設定算出快照（純函式，方便測試）
    static func make(history: PlanHistory, activeStartedAt: Date?, theme: ThemeSettings) -> WidgetSnapshot {
        let suggestion = PlanDefaults.answers(history)
        let last = history.sessions.first
        return WidgetSnapshot(
            lastSessionDate: last?.date,
            lastRegion: last?.region,
            suggestedRegion: suggestion.region,
            suggestedCount: suggestion.count,
            suggestsTreadmill: suggestion.cardio,
            isInProgress: activeStartedAt != nil,
            startedAt: activeStartedAt,
            themeID: theme.followSystem ? nil : theme.theme.rawValue,
            darkThemeID: theme.followSystem ? theme.dark.rawValue : nil,
            lightThemeID: theme.followSystem ? theme.light.rawValue : nil
        )
    }
}

/// App 端更新小工具快照：啟動、資料庫存檔（開始、完成、捨棄、編輯或刪除訓練都會存檔）、切換主題時。
/// 內容有變才寫入 App Group 並請小工具重新載入。
@MainActor
final class SnapshotWriter {
    static let shared = SnapshotWriter()

    private var context: ModelContext?
    private var pending: Task<Void, Never>?
    private var saveObserver: NSObjectProtocol?

    /// 啟動時更新一次，之後監聽資料庫存檔
    func start(context: ModelContext) {
        self.context = context
        update()
        guard saveObserver == nil else { return }
        saveObserver = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { SnapshotWriter.shared.scheduleUpdate() }
        }
    }

    /// 訓練中連續編輯時合併成一次更新
    func scheduleUpdate() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            update()
        }
    }

    func update() {
        guard let context else { return }
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        let snapshot = WidgetSnapshot.make(
            history: PlanHistory(sessions: sessions),
            activeStartedAt: sessions.first(where: \.isActive)?.startedAt,
            theme: ThemeSettings.load()
        )
        if WidgetSnapshotStore.save(snapshot) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
