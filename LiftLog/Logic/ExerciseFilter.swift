import Foundation

nonisolated enum ExerciseSearch {
    /// 比對名稱、別名、英文名，忽略空白與大小寫；空字串全部符合
    static func matches(query: String, name: String, aliases: [String], englishName: String) -> Bool {
        let q = normalize(query)
        guard !q.isEmpty else { return true }
        return ([name, englishName] + aliases).contains { normalize($0).contains(q) }
    }

    static func normalize(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace }
    }
}

/// 動作庫分類清單的排序（CHANGE_07 B-2），記住上次的選擇
nonisolated enum LibrarySort: String, CaseIterable, Identifiable {
    case stalest, recent, fewest, most

    static let storageKey = "library.sort"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stalest: "最久沒練"
        case .recent: "最近練過"
        case .fewest: "次數最少"
        case .most: "次數最多"
        }
    }

    /// 最久沒練：沒練過的排最前，再由舊到新；最近練過：由新到舊，沒練過的排最後；
    /// 次數：同次數時最久沒練的在前。最後都依名稱
    func sorted<T>(_ items: [T], lastDate: (T) -> Date?, count: (T) -> Int, name: (T) -> String) -> [T] {
        func staler(_ a: T, _ b: T) -> Bool? {
            switch (lastDate(a), lastDate(b)) {
            case (nil, nil): return nil
            case (nil, _): return true
            case (_, nil): return false
            case let (da?, db?): return da == db ? nil : da < db
            }
        }
        return items.sorted { a, b in
            let decided: Bool?
            switch self {
            case .stalest:
                decided = staler(a, b)
            case .recent:
                decided = staler(a, b).map(!)
            case .fewest:
                decided = count(a) != count(b) ? count(a) < count(b) : staler(a, b)
            case .most:
                decided = count(a) != count(b) ? count(a) > count(b) : staler(a, b)
            }
            return decided ?? (name(a).localizedStandardCompare(name(b)) == .orderedAscending)
        }
    }
}

/// 動作庫分類清單的標籤篩選：主、單、爆三個開關，條件取交集
nonisolated struct LibraryFilter: Equatable {
    var tags: Set<ExerciseTag> = []

    func matches(tags exerciseTags: [ExerciseTag]) -> Bool {
        tags.isSubset(of: Set(exerciseTags))
    }
}

/// 各清單要列哪些動作：封存的動作不出現在預設清單與新增動作清單
enum ExerciseLists {
    /// 動作庫的搜尋：所有分類、不含封存
    static func search(_ all: [Exercise], query: String) -> [Exercise] {
        all.filter { e in
            !e.isArchived && ExerciseSearch.matches(query: query, name: e.name, aliases: e.aliases, englishName: e.englishName)
        }
    }

    /// 訓練中「新增動作」
    static func picker(_ all: [Exercise], category: ExerciseCategory?, excluding: Exercise?, query: String) -> [Exercise] {
        all.filter { e in
            !e.isArchived
                && e !== excluding
                && (category == nil || e.category == category)
                && ExerciseSearch.matches(query: query, name: e.name, aliases: e.aliases, englishName: e.englishName)
        }
    }
}
