import Foundation
import Testing
@testable import LiftLog

struct FilterTests {
    @Test func searchMatchesNameAliasAndEnglish() {
        let aliases = ["保加利亞分腿蹲", "槓鈴保加利亞蹲"]
        func match(_ q: String) -> Bool {
            ExerciseSearch.matches(query: q, name: "後腳抬高蹲", aliases: aliases, englishName: "Rear Foot Elevated Split Squat")
        }
        #expect(match(""))
        #expect(match("後腳"))
        #expect(match("保加利亞"))
        #expect(match("split squat"))   // 忽略大小寫
        #expect(match("RearFoot"))      // 忽略空白
        #expect(!match("臥推"))
    }
}
