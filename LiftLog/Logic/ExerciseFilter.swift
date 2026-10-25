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
