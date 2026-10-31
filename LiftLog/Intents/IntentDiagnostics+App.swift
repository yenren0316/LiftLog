#if DEBUG
import ActivityKit
import Foundation
import SwiftData
import UIKit

/// 開發用（CHANGE_17 §2-2）：App 這邊才拿得到的狀態：UIApplication 的資料保護和程序狀態、資料檔的保護等級、即時動態、休息倒數
@MainActor
extension IntentDiagnostics {
    /// perform 開始：記下執行時的環境
    static func begin(_ source: String, parameters: String = "") {
        recordInApp(source, event: "開始", parameters: parameters, detail: environment())
    }

    /// perform 結束：結果、之後的即時動態和休息倒數
    static func end(_ source: String, parameters: String = "", succeeded: Bool, result: String) {
        recordInApp(source, event: succeeded ? "成功" : "失敗", parameters: parameters,
                    detail: [result, liveActivitySummary, restSummary].joined(separator: "；"))
    }

    static func recordInApp(_ source: String, event: String, parameters: String = "", detail: String) {
        let app = UIApplication.shared
        record(source: source, event: event, parameters: parameters, protectedDataAvailable: app.isProtectedDataAvailable,
               appState: describe(app.applicationState), detail: detail)
    }

    /// 資料檔的保護等級（資料庫、UserDefaults、App Group 的 UserDefaults、這份紀錄）、即時動態、休息倒數
    private static func environment() -> String {
        let store = LiftLogStore.container.configurations.first?.url
        let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshotStore.appGroupID)
        let files: [(String, URL?)] = [
            ("資料庫", store),
            ("資料庫 wal", store.map { URL(filePath: $0.path(percentEncoded: false) + "-wal") }),
            ("UserDefaults", URL.libraryDirectory.appending(path: "Preferences/\(Bundle.main.bundleIdentifier ?? "").plist")),
            ("App Group", group?.appending(path: "Library/Preferences/\(WidgetSnapshotStore.appGroupID).plist")),
            ("診斷紀錄", defaultURL),
        ]
        let protections = files.map { name, url in "\(name) \(url.map(protection(of:)) ?? "拿不到路徑")" }
        return (protections + [liveActivitySummary, restSummary]).joined(separator: "；")
    }

    private static var liveActivitySummary: String {
        let activities = Activity<WorkoutActivityAttributes>.activities
        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled ? "允許" : "不允許"
        return "即時動態\(enabled)・\(activities.count) 個 \(activities.map { "\($0.activityState)" })"
    }

    private static var restSummary: String {
        guard let end = RestTimer.shared.endDate else { return "沒有在休息" }
        return "休息到 \(end.formatted(.dateTime.hour().minute().second()))"
    }

    private static func describe(_ state: UIApplication.State) -> String {
        switch state {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "unknown(\(state.rawValue))"
        }
    }
}
#endif
