#if DEBUG
import SwiftUI

/// 開發用（CHANGE_17 §2-2）：設定最下面的「診斷紀錄」。即時動態按鈕的 intent 執行紀錄最近 50 筆（新的在上面），可以清除。
/// 往下拉重新讀取；文字可以選取複製
struct IntentDiagnosticsView: View {
    @State private var entries: [IntentDiagnostics.Entry] = []
    @State private var confirmClear = false

    var body: some View {
        List {
            if entries.isEmpty {
                Text("還沒有紀錄").foregroundStyle(Theme.textSecondary)
                    .listRowBackground(Theme.card)
            }
            ForEach(entries) { entry in
                row(entry).listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .refreshable { reload() }
        .onAppear(perform: reload)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("清除") { confirmClear = true }
                    .disabled(entries.isEmpty)
            }
        }
        .alert("清除診斷紀錄？", isPresented: $confirmClear) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                IntentDiagnostics.clear()
                reload()
            }
        }
    }

    private func row(_ entry: IntentDiagnostics.Entry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(entry.source)・\(entry.event)").font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(entry.date.formatted(.dateTime.month(.twoDigits).day(.twoDigits).hour().minute().second()
                    .secondFraction(.fractional(3))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(details(entry))
                .font(.caption.monospaced())
                .foregroundStyle(Theme.textSecondary)
        }
        .textSelection(.enabled)
    }

    private func details(_ entry: IntentDiagnostics.Entry) -> String {
        let protected = entry.protectedDataAvailable.map { $0 ? "可用" : "不可用" } ?? "拿不到"
        var lines = ["程序 \(entry.process)", "受保護資料 \(protected)・App 狀態 \(entry.appState ?? "拿不到")"]
        if !entry.parameters.isEmpty { lines.append("參數 \(entry.parameters)") }
        if !entry.detail.isEmpty { lines.append(entry.detail) }
        return lines.joined(separator: "\n")
    }

    private func reload() {
        entries = IntentDiagnostics.recent()
    }
}
#endif
