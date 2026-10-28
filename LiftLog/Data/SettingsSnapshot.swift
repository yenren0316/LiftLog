import Foundation

/// 備份裡的設定值（CHANGE_11 §8，備份格式 version 7）：設定頁的每一個值。匯出時照目前的值寫入（沒改過的寫預設值），
/// 還原時一併寫回；舊的備份檔沒有這一段時，設定維持目前的值。
/// 畫面的記憶（歷程的分段、動作庫的排序、訓練頻率的週／月）不是設定，不放進來
nonisolated struct SettingsSnapshot: Codable, Equatable, Sendable {
    /// 每週目標；nil 表示沒設定過，用近 12 週的平均（WeeklyGoal）
    var weeklyGoal: Int?
    var cardioOnlyCounts: Bool
    var weightUnit: String
    var roundBarbellKg: Double
    var roundBarbellLbs: Double
    var roundOtherKg: Double
    var roundOtherLbs: Double
    /// 打勾後自動開始休息計時
    var autoRestTimer: Bool
    var liveActivity: Bool
    var theme: String

    /// 鍵的定義有些在 MainActor 的型別裡（休息計時、即時動態），讀寫都在 MainActor
    @MainActor
    static func read(from defaults: UserDefaults = .standard) -> SettingsSnapshot {
        func double(_ key: String, _ fallback: Double) -> Double {
            defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
        }
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
        }
        let goal = defaults.integer(forKey: WeeklyGoal.goalKey)
        return SettingsSnapshot(
            weeklyGoal: goal > 0 ? goal : nil,
            cardioOnlyCounts: bool(WeeklyGoal.cardioOnlyCountsKey, false),
            weightUnit: defaults.string(forKey: WeightUnit.storageKey) ?? WeightUnit.kg.rawValue,
            roundBarbellKg: double(RoundingSteps.barbellKgKey, RoundingSteps.barbellKgDefault),
            roundBarbellLbs: double(RoundingSteps.barbellLbsKey, RoundingSteps.barbellLbsDefault),
            roundOtherKg: double(RoundingSteps.otherKgKey, RoundingSteps.otherKgDefault),
            roundOtherLbs: double(RoundingSteps.otherLbsKey, RoundingSteps.otherLbsDefault),
            autoRestTimer: bool(WorkoutService.autoRestKey, true),
            liveActivity: bool(LiveActivityController.enabledKey, true),
            theme: defaults.string(forKey: AppTheme.storageKey) ?? AppTheme.graphiteOrange.rawValue
        )
    }

    /// 寫回 UserDefaults（@AppStorage 的畫面會跟著更新）。認不得的單位或主題不寫，維持目前的值
    @MainActor
    func apply(to defaults: UserDefaults = .standard) {
        if let weeklyGoal {
            defaults.set(weeklyGoal, forKey: WeeklyGoal.goalKey)
        } else {
            defaults.removeObject(forKey: WeeklyGoal.goalKey)
        }
        defaults.set(cardioOnlyCounts, forKey: WeeklyGoal.cardioOnlyCountsKey)
        if WeightUnit(rawValue: weightUnit) != nil { defaults.set(weightUnit, forKey: WeightUnit.storageKey) }
        defaults.set(roundBarbellKg, forKey: RoundingSteps.barbellKgKey)
        defaults.set(roundBarbellLbs, forKey: RoundingSteps.barbellLbsKey)
        defaults.set(roundOtherKg, forKey: RoundingSteps.otherKgKey)
        defaults.set(roundOtherLbs, forKey: RoundingSteps.otherLbsKey)
        defaults.set(autoRestTimer, forKey: WorkoutService.autoRestKey)
        defaults.set(liveActivity, forKey: LiveActivityController.enabledKey)
        if AppTheme(rawValue: theme) != nil { defaults.set(theme, forKey: AppTheme.storageKey) }
    }
}
