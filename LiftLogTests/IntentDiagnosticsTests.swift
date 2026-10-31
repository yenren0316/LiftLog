#if DEBUG
import Foundation
import Testing
@testable import LiftLog

/// CHANGE_17 §2-2：診斷紀錄（只在 DEBUG）寫得進去、讀得出來、鎖定時也能寫（保護等級 .none），可以清除
@MainActor
struct IntentDiagnosticsTests {
    private func temporaryURL() -> URL {
        URL.temporaryDirectory.appending(path: "IntentDiagnosticsTests-\(UUID().uuidString)/Diagnostics/intent-log.jsonl")
    }

    @Test func recordsAreReadBackNewestFirst() throws {
        let url = temporaryURL()
        defer { IntentDiagnostics.clear(at: url) }
        IntentDiagnostics.record(source: "完成這組", event: "開始", parameters: "setID=A", protectedDataAvailable: false,
                                 appState: "background", detail: "資料庫 CompleteUntilFirstUserAuthentication", to: url)
        IntentDiagnostics.record(source: "完成這組", event: "成功", parameters: "setID=A", to: url)

        let entries = IntentDiagnostics.recent(from: url)
        #expect(entries.map(\.event) == ["成功", "開始"])
        let first = try #require(entries.last)
        #expect(first.source == "完成這組")
        #expect(first.parameters == "setID=A")
        #expect(first.protectedDataAvailable == false)
        #expect(first.appState == "background")
        #expect(first.detail == "資料庫 CompleteUntilFirstUserAuthentication")
        #expect(first.process == Bundle.main.bundleIdentifier)
        // 拿不到的值是 nil，不是猜的
        #expect(entries.first?.protectedDataAvailable == nil)
        #expect(entries.first?.appState == nil)
        // 時間含毫秒和時區，和系統日誌對照
        #expect(abs(first.date.timeIntervalSinceNow) < 60)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains(/"date":"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}(Z|[+-]\d{2}:?\d{2})"/))
        #expect(text.split(separator: "\n").count == 2)
    }

    @Test func onlyTheLatestFiftyAreListed() {
        let url = temporaryURL()
        defer { IntentDiagnostics.clear(at: url) }
        for i in 1...55 {
            IntentDiagnostics.record(source: "+15 秒", event: "\(i)", to: url)
        }
        let entries = IntentDiagnostics.recent(from: url)
        #expect(entries.count == 50)
        #expect(entries.first?.event == "55")
        #expect(entries.last?.event == "6")
    }

    @Test func theFileIsWritableWhileLocked() {
        let url = temporaryURL()
        defer { IntentDiagnostics.clear(at: url) }
        IntentDiagnostics.record(source: "跳過休息", event: "開始", to: url)
        // 模擬器沒有資料保護，屬性讀出來不一定有值；有值時一定是 None
        let protection = IntentDiagnostics.protection(of: url)
        #expect(protection == "None" || protection == "未設定")
        #expect(IntentDiagnostics.protection(of: url.appending(path: "missing")) == "沒有檔案")
    }

    @Test func clearRemovesEverything() {
        let url = temporaryURL()
        IntentDiagnostics.record(source: "跳過休息", event: "開始", to: url)
        #expect(IntentDiagnostics.recent(from: url).count == 1)
        IntentDiagnostics.clear(at: url)
        #expect(IntentDiagnostics.recent(from: url).isEmpty)
        // 清除後可以繼續寫
        IntentDiagnostics.record(source: "跳過休息", event: "成功", to: url)
        #expect(IntentDiagnostics.recent(from: url).map(\.event) == ["成功"])
        IntentDiagnostics.clear(at: url)
    }
}
#endif
