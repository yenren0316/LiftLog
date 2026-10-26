import Foundation

/// 首頁「最近 30 天」：各分類完成的組數（不含熱身）與推拉比
nonisolated struct RecentVolume: Equatable {
    var sets: [ExerciseCategory: Int]

    /// 組數達到這個數量算練得夠（綠色）；0 組紅色，其他黃色
    static let enoughSets = 10

    init(history: PlanHistory, now: Date = .now) {
        var sets: [ExerciseCategory: Int] = [:]
        for category in ExerciseCategory.allCases {
            sets[category] = history.setCount(within: now) { $0.category == category }
        }
        self.sets = sets
    }

    subscript(category: ExerciseCategory) -> Int { sets[category] ?? 0 }

    /// 推＝上肢水平推＋上肢垂直推
    var push: Int { self[.horizontalPush] + self[.verticalPush] }
    /// 拉＝上肢水平拉＋上肢垂直拉
    var pull: Int { self[.horizontalPull] + self[.verticalPull] }
    /// 拉少於推時用警示色
    var pullIsShort: Bool { pull < push }
}

/// 首頁「主項紀錄」的一列：最近一次 ME 紀錄和上一次的估算 1RM 差距
nonisolated struct MainLiftSummary: Equatable {
    var latest: MaxEffortRecords.Record?
    /// 最近一次減上一次的估算 1RM；只有一筆紀錄時為 nil
    var change: Double?

    init(logs: [ExerciseLog]) {
        let records = MaxEffortRecords.records(logs)
        latest = records.first
        change = records.count >= 2 ? records[0].estimated1RM - records[1].estimated1RM : nil
    }
}
