import Foundation
import Testing
@testable import LiftLog

/// CHANGE_07 B-2：動作庫分類清單的排序與篩選
struct LibraryTests {
    private struct Item {
        var name: String
        var daysAgo: Double?
        var count = 0
    }

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func order(_ items: [Item], _ sort: LibrarySort) -> [String] {
        sort.sorted(items, lastDate: { $0.daysAgo.map { now.addingTimeInterval(-$0 * 86_400) } },
                    count: \.count, name: \.name).map(\.name)
    }

    private var items: [Item] {
        [Item(name: "Squat", daysAgo: 3, count: 21), Item(name: "Front", daysAgo: nil, count: 0),
         Item(name: "Lateral", daysAgo: 200, count: 3), Item(name: "Rear", daysAgo: 30, count: 3),
         Item(name: "Split", daysAgo: nil, count: 0)]
    }

    @Test func fourSorts() {
        // 名稱用英文，排序最後的名稱比較不受模擬器語系影響
        // T5：最久沒練（沒練過的排最前）、最近練過、次數最少、次數最多；條件相同時最久沒練的在前，再依名稱
        #expect(order(items, .stalest) == ["Front", "Split", "Lateral", "Rear", "Squat"])
        #expect(order(items, .recent) == ["Squat", "Rear", "Lateral", "Front", "Split"])
        #expect(order(items, .fewest) == ["Front", "Split", "Lateral", "Rear", "Squat"])
        #expect(order(items, .most) == ["Squat", "Lateral", "Rear", "Front", "Split"])
        #expect(LibrarySort.allCases.map(\.title) == ["最久沒練", "最近練過", "次數最少", "次數最多"])
    }

    @Test func sortChoiceIsRemembered() throws {
        #expect(LibrarySort(rawValue: LibrarySort.recent.rawValue) == .recent)
        #expect(LibrarySort.storageKey == "library.sort")
    }

    @Test func tagFilterIsAnIntersection() {
        var filter = LibraryFilter()
        #expect(filter.matches(tags: []))
        filter.tags = [.main]
        #expect(filter.matches(tags: [.main]) && !filter.matches(tags: [.unilateral]))
        filter.tags = [.unilateral, .explosive]
        #expect(filter.matches(tags: [.unilateral, .explosive]))
        #expect(!filter.matches(tags: [.unilateral]))   // 兩個標籤都要有
    }
}
