import SwiftUI
import WidgetKit

/// 「上次訓練」小工具（CHANGE_05 第 4 節）：資料來自 App 寫進 App Group 的快照
struct LastWorkoutWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LastWorkoutWidget", provider: LastWorkoutProvider()) { entry in
            LastWorkoutWidgetView(entry: entry)
        }
        .configurationDisplayName("上次訓練")
        .description("距離上次訓練幾天，以及今天建議練哪裡。")
        .supportedFamilies([.systemSmall])
    }
}

struct LastWorkoutEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct LastWorkoutProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastWorkoutEntry {
        LastWorkoutEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (LastWorkoutEntry) -> Void) {
        let snapshot = WidgetSnapshotStore.load()
        completion(LastWorkoutEntry(date: .now, snapshot: context.isPreview && snapshot == nil ? .sample : snapshot))
    }

    /// 現在一筆，加上之後 7 天每天午夜各一筆；用完再向 App Group 讀一次快照
    func getTimeline(in context: Context, completion: @escaping (Timeline<LastWorkoutEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.load()
        let entries = WidgetSnapshot.timelineDates(from: .now).map { LastWorkoutEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct LastWorkoutWidgetView: View {
    var entry: LastWorkoutEntry

    var body: some View {
        LastWorkoutSmallView(snapshot: entry.snapshot, date: entry.date)
            .widgetURL((entry.snapshot?.link ?? .new).url)
    }
}
