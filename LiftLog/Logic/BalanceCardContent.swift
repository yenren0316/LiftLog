import Foundation

/// 歷程統計的「平衡」卡下半部（CHANGE_13 §2-4、CHANGE_14 §5）：近 30 天 9 個分類的組數。
/// 完全沒有任何完成組的紀錄時（不是只有 30 天內）整張卡只寫「還沒有紀錄」，不顯示推拉比和 9 列；
/// 有紀錄、但某些分類 30 天內是 0 組時照舊寫「0 沒練」
nonisolated enum BalanceCardContent: Equatable, Sendable {
    case noRecords
    case rows([Row])

    struct Row: Equatable, Sendable, Identifiable {
        var category: ExerciseCategory
        var count: Int

        var id: ExerciseCategory { category }
        /// 30 天內 0 組：提醒（warning 色，「沒練」兩個字本身就是提醒，不只靠顏色）
        var isNeglected: Bool { count == 0 }
        var text: String { isNeglected ? "0 沒練" : "\(count)" }
    }

    static func make(_ snapshot: StatsSnapshot) -> BalanceCardContent {
        guard snapshot.hasCompletedSets else { return .noRecords }
        return .rows(ExerciseCategory.allCases.map { Row(category: $0, count: snapshot.recentSets[$0] ?? 0) })
    }
}
