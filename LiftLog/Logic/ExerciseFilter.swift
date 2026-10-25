import Foundation

/// 首頁與動作庫的「全部／單邊／爆發」篩選
nonisolated enum TagFilter: Hashable, CaseIterable, Identifiable {
    case all
    case tag(ExerciseTag)

    static var allCases: [TagFilter] { [.all] + ExerciseTag.allCases.map(TagFilter.tag) }

    var id: String {
        switch self {
        case .all: "all"
        case .tag(let t): t.rawValue
        }
    }

    var title: String {
        switch self {
        case .all: "全部"
        case .tag(let t): t.title
        }
    }

    func matches(_ tags: [ExerciseTag]) -> Bool {
        switch self {
        case .all: true
        case .tag(let t): tags.contains(t)
        }
    }
}

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

extension Exercise {
    func matches(_ filter: TagFilter, query: String = "") -> Bool {
        filter.matches(tags)
            && ExerciseSearch.matches(query: query, name: name, aliases: aliases, englishName: englishName)
    }
}

/// 動作庫分類內的四組，依顯示順序排列
nonisolated enum LibraryGroup: Int, CaseIterable, Comparable {
    case bilateral, unilateral, explosive, cable

    /// 爆發優先；同時有爆發與單邊的歸爆發
    static func of(tags: [ExerciseTag], equipment: Equipment) -> LibraryGroup {
        if tags.contains(.explosive) { return .explosive }
        if tags.contains(.unilateral) { return .unilateral }
        if equipment == .cable { return .cable }
        return .bilateral
    }

    static func < (a: LibraryGroup, b: LibraryGroup) -> Bool { a.rawValue < b.rawValue }
}

nonisolated enum LibraryOrder {
    /// 雙邊自由重量 → 單邊 → 爆發 → Cable；同組內訓練次數多到少，再依名稱
    static func sorted<T>(
        _ items: [T],
        tags: (T) -> [ExerciseTag],
        equipment: (T) -> Equipment,
        count: (T) -> Int,
        name: (T) -> String
    ) -> [T] {
        items.sorted { a, b in
            let ga = LibraryGroup.of(tags: tags(a), equipment: equipment(a))
            let gb = LibraryGroup.of(tags: tags(b), equipment: equipment(b))
            if ga != gb { return ga < gb }
            if count(a) != count(b) { return count(a) > count(b) }
            return name(a) < name(b)
        }
    }
}

/// 動作庫篩選：練過／未練過（單選）與 tags（複選），兩組取交集；選多個 tag 時要全部符合
nonisolated struct LibraryFilter: Equatable {
    enum Trained: String, CaseIterable, Identifiable {
        case all, trained, untrained

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: "全部"
            case .trained: "練過"
            case .untrained: "未練過"
            }
        }
    }

    var trained: Trained = .all
    var tags: Set<ExerciseTag> = []

    func matches(tags exerciseTags: [ExerciseTag], trainingCount: Int) -> Bool {
        let trainedOK = switch trained {
        case .all: true
        case .trained: trainingCount > 0
        case .untrained: trainingCount == 0
        }
        return trainedOK && tags.isSubset(of: Set(exerciseTags))
    }
}

/// 各清單要列哪些動作：封存的動作不出現在預設清單與新增動作清單
enum ExerciseLists {
    static func library(_ all: [Exercise], showArchived: Bool, filter: LibraryFilter, query: String) -> [Exercise] {
        all.filter { e in
            (showArchived || !e.isArchived)
                && filter.matches(tags: e.tags, trainingCount: e.trainingCount)
                && ExerciseSearch.matches(query: query, name: e.name, aliases: e.aliases, englishName: e.englishName)
        }
    }

    /// 訓練中「新增動作」與「換動作」
    static func picker(_ all: [Exercise], category: ExerciseCategory?, excluding: Exercise?, query: String) -> [Exercise] {
        all.filter { e in
            !e.isArchived
                && e !== excluding
                && (category == nil || e.category == category)
                && ExerciseSearch.matches(query: query, name: e.name, aliases: e.aliases, englishName: e.englishName)
        }
    }
}
