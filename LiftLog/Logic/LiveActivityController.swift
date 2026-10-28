import ActivityKit
import Foundation
import SwiftData

extension WorkoutActivityAttributes.ContentState {
    /// 依進行中的訓練和休息計時器算出即時動態的內容
    static func make(session: WorkoutSession, rest: ClosedRange<Date>?, unit: WeightUnit) -> Self {
        let items = session.orderedItems.filter { $0.exercise != nil }
        var state = Self(
            title: session.title.isEmpty ? "訓練中" : session.title,
            dayTypeTitle: session.dayType.map { Self.islandTitle(dayType: $0) },
            startedAt: session.startedAt,
            setNumber: 0, setCount: 0, canComplete: false,
            completedSets: items.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count },
            totalSets: items.reduce(0) { $0 + $1.sets.count },
            restStartDate: rest?.lowerBound, restEndDate: rest?.upperBound
        )
        if let current = session.currentSet, let exercise = current.item.exercise {
            let placeholder = current.item.setHints().first { $0.set === current.set }?.placeholder
            let values = SetLogic.resolved(entered: current.set.values, placeholder: placeholder)
            state.exerciseName = exercise.name
            state.roleTitle = current.item.role.title
            state.roleSymbol = current.item.role.symbol
            state.setNumber = current.index + 1
            state.setCount = current.item.sets.count
            state.target = target(values, logType: exercise.logType, unit: unit)
            state.canComplete = SetLogic.canComplete(values, logType: exercise.logType, equipment: exercise.equipment)
        }
        return state
    }

    /// 這一組的目標：「60 kg × 5」「輔助 19 kg × 5」「8 下」「30 秒」「坡度 12・速度 5・30 分鐘」
    static func target(_ v: SetValues, logType: LogType, unit: WeightUnit) -> String? {
        let weight = v.weightKg.map { unit.formatWithUnit(kg: $0) }
        let reps = v.reps.map { "\($0) 下" }
        let parts: [String?]
        switch logType {
        case .weight:
            parts = [weight.map { w in v.reps.map { "\(w) × \($0)" } ?? w } ?? reps]
        case .assisted:
            parts = [weight.map { w in v.reps.map { "輔助 \(w) × \($0)" } ?? "輔助 \(w)" } ?? reps]
        case .bodyweight:
            parts = [reps]
        case .timed:
            parts = [weight, v.seconds.map { "\(Units.number($0)) 秒" }]
        case .cardio:
            parts = [v.incline.map { "坡度 \(Units.number($0))" }, v.speed.map { "速度 \(Units.number($0))" },
                     v.minutes.map { "\(Units.number($0)) 分鐘" }]
        }
        let text = parts.compactMap { $0 }.joined(separator: "・")
        return text.isEmpty ? nil : text
    }
}

/// 即時動態的開始、更新與結束（CHANGE_05 第 6-1 節）。
/// 依「現在有沒有進行中的訓練」同步：有就確保有一個即時動態並更新內容；沒有（完成或捨棄）就結束。
/// App 重新開啟時發現有進行中的訓練但即時動態不見了，也會重新建立。
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()
    /// 設定頁「訓練中顯示即時動態」，預設開啟
    static let enabledKey = "liveActivity.enabled"

    private var lastSent: WorkoutActivityAttributes.ContentState?
    private var pending: Task<Void, Never>?
    private var saveObserver: NSObjectProtocol?

    private var isEnabled: Bool { UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true }

    /// App 在前景時呼叫：之後資料庫存檔、休息計時器改變時自動同步
    func start() {
        // 單元測試以 App 當 host 時不建立即時動態：系統會為了顯示它啟動小工具擴充，測試會連不上
        guard ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] == nil else { return }
        if saveObserver == nil {
            saveObserver = NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { LiveActivityController.shared.scheduleSync() }
            }
            RestTimer.shared.onChange = { LiveActivityController.shared.scheduleSync() }
        }
        scheduleSync()
    }

    /// 連續的變化合併成一次
    func scheduleSync() {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await sync()
        }
    }

    func sync() async {
        var desired: (attributes: WorkoutActivityAttributes, state: WorkoutActivityState)?
        let context = LiftLogStore.container.mainContext
        if isEnabled, ActivityAuthorizationInfo().areActivitiesEnabled,
           let session = WorkoutActions.activeSession(in: context) {
            let palette = AppTheme.load().palette
            let timer = RestTimer.shared
            let rest = timer.startDate.flatMap { start in timer.endDate.map { start...$0 } }
            let unit = WeightUnit.current
            desired = (WorkoutActivityAttributes(sessionID: session.id.uuidString, accent: palette.accent, done: palette.done),
                       WorkoutActivityState.make(session: session, rest: rest, unit: unit))
        }
        let previous = lastSent
        lastSent = desired?.state
        await Self.apply(desired, previous: previous)
    }

    /// ActivityKit 的 Activity 不是 Sendable，所以查詢和操作都在這個函式裡完成。
    /// desired 為 nil（沒有進行中的訓練或已關閉）就全部結束；否則沿用同一次訓練、同樣主題顏色的即時動態，不然重建。
    @concurrent
    private nonisolated static func apply(_ desired: (attributes: WorkoutActivityAttributes, state: WorkoutActivityState)?,
                                          previous: WorkoutActivityState?) async {
        let activities = Activity<WorkoutActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
        guard let (attributes, state) = desired else {
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
            return
        }
        // 休息結束時系統把內容標成過期，畫面就切回「完成這組」，不需要 App 被喚醒
        let content = ActivityContent(state: state, staleDate: state.restEndDate)
        let current = activities.first {
            $0.attributes.sessionID == attributes.sessionID && $0.attributes.accent == attributes.accent
                && $0.attributes.done == attributes.done
        }
        for activity in activities where activity.id != current?.id {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        if let current {
            if state != previous { await current.update(content) }
        } else {
            // 只有 App 在前景時能建立；在背景（例如按鈕觸發）失敗就等下次回到前景
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        }
    }
}
