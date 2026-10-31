#if DEBUG
import Foundation
import os

/// 開發用（CHANGE_17 §2-2）：即時動態按鈕的 intent 執行紀錄，查實機鎖定時按鈕要求解鎖的原因。
/// App 和小工具擴充都會寫（系統在哪一個程序執行 perform 都看得到）：App Group 容器的
/// Library/Diagnostics/intent-log.jsonl，一行一筆 JSON；同一筆也寫進系統日誌（subsystem com.aaronhou.LiftLog，category intent），
/// 和手機的系統日誌對照。資料夾和檔案的保護等級是 .none，鎖定時也寫得進去。
/// 設定的最下面「診斷紀錄」列出最近 50 筆，可以清除
nonisolated enum IntentDiagnostics {
    struct Entry: Codable, Hashable, Identifiable, Sendable {
        var id = UUID()
        var date: Date
        /// 寫這一筆的程序（App 或小工具擴充的 bundle id）
        var process: String
        /// 「完成這組」「跳過休息」「+15 秒」，或「App 啟動」「存檔」
        var source: String
        /// 開始、成功、失敗……
        var event: String
        var parameters: String
        /// UIApplication.isProtectedDataAvailable；小工具擴充裡和 App 剛啟動時拿不到
        var protectedDataAvailable: Bool?
        /// UIApplication.applicationState；拿不到時 nil
        var appState: String?
        var detail: String
    }

    static let fileName = "intent-log.jsonl"

    static var defaultURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshotStore.appGroupID)?
            .appending(path: "Library/Diagnostics/\(fileName)")
    }

    private static let logger = Logger(subsystem: "com.aaronhou.LiftLog", category: "intent")

    static func record(source: String, event: String, parameters: String = "", protectedDataAvailable: Bool? = nil,
                       appState: String? = nil, detail: String = "", to url: URL? = defaultURL) {
        let entry = Entry(date: .now, process: Bundle.main.bundleIdentifier ?? "?", source: source, event: event,
                          parameters: parameters, protectedDataAvailable: protectedDataAvailable, appState: appState,
                          detail: detail)
        let protected = protectedDataAvailable.map { $0 ? "yes" : "no" } ?? "?"
        logger.notice("""
            LiftLogDiag \(source, privacy: .public) \(event, privacy: .public) process=\(entry.process, privacy: .public) \
            params=\(parameters, privacy: .public) protectedData=\(protected, privacy: .public) \
            appState=\(appState ?? "?", privacy: .public) detail=\(detail, privacy: .public)
            """)
        guard let url else { return }
        do {
            try append(entry, to: url)
        } catch {
            logger.error("LiftLogDiag 寫入失敗：\(String(describing: error), privacy: .public)")
        }
    }

    /// 最近的 limit 筆，新的在前面
    static func recent(limit: Int = 50, from url: URL? = defaultURL) -> [Entry] {
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            return try Date(string, strategy: timeFormat)
        }
        let entries = text.split(separator: "\n").compactMap { try? decoder.decode(Entry.self, from: Data($0.utf8)) }
        return Array(entries.suffix(limit).reversed())
    }

    static func clear(at url: URL? = defaultURL) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// 檔案的保護等級（FileProtectionType 的原始值，去掉 NSFileProtection 前綴）；檔案不存在時「沒有檔案」
    static func protection(of url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)) else {
            return "沒有檔案"
        }
        guard let type = attributes[.protectionKey] as? FileProtectionType else { return "未設定" }
        return type.rawValue.replacingOccurrences(of: "NSFileProtection", with: "")
    }

    /// 時間含毫秒和時區，和系統日誌對照
    private static let timeFormat = Date.ISO8601FormatStyle(includingFractionalSeconds: true, timeZone: .current)

    private static func append(_ entry: Entry, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(timeFormat))
        }
        var line = try encoder.encode(entry)
        line.append(0x0A)
        let manager = FileManager.default
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                    attributes: [.protectionKey: FileProtectionType.none])
        if manager.fileExists(atPath: url.path(percentEncoded: false)) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } else {
            try line.write(to: url, options: .noFileProtection)
        }
    }
}
#endif
