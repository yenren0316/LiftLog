import Foundation
import SwiftData

enum ExerciseMerge {
    /// 來源的名稱與別名併入目標（去重、排除目標本身的名稱）
    nonisolated static func mergedAliases(target: String, targetAliases: [String],
                                          source: String, sourceAliases: [String]) -> [String] {
        var result: [String] = []
        for alias in targetAliases + [source] + sourceAliases
        where alias != target && !result.contains(alias) {
            result.append(alias)
        }
        return result
    }

    /// 紀錄全部移到 target，併入別名後刪除 source
    static func merge(_ source: Exercise, into target: Exercise, context: ModelContext) throws {
        precondition(source !== target, "不能合併到自己")
        for entry in source.entries {
            entry.exercise = target
        }
        target.aliases = mergedAliases(target: target.name, targetAliases: target.aliases,
                                       source: source.name, sourceAliases: source.aliases)
        context.delete(source)
        try context.save()
    }
}
