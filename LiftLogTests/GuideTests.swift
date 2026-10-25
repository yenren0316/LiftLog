import Foundation
import Testing
@testable import LiftLog

@MainActor
struct GuideTests {
    private func bundledGuides() throws -> [String: GuideImporter.Guide] {
        let url = try #require(Bundle.main.url(forResource: "ExerciseGuides", withExtension: "json"))
        return try JSONDecoder().decode([String: GuideImporter.Guide].self, from: Data(contentsOf: url))
    }

    @Test func everySeedExerciseHasAGuide() throws {
        let guides = try bundledGuides()
        let seedURL = try #require(Bundle.main.url(forResource: "seed", withExtension: "json"))
        let seed = try BackupFile.decode(Data(contentsOf: seedURL))
        #expect(Set(seed.exercises.map(\.name)) == Set(guides.keys))
    }

    @Test func coachVariationsAreLeftForTheCoach() throws {
        let guides = try bundledGuides()
        let pending = ["爆發划船", "窄跪姿單手啞鈴肩推", "坐姿分腿壺鈴三點搬移", "地雷管抗旋轉",
                       "拋沙包", "滾木槓臥推", "單手硬舉原地踏步", "六角槓原地踏步"]
        for name in pending {
            let guide = try #require(guides[name])
            #expect(guide.cues == ["待補（請向教練確認）"], "\(name)")
            #expect(guide.mistakes == ["待補（請向教練確認）"], "\(name)")
        }
    }

    @Test func applyMatchesByAliasAndKeepsExistingEdits() {
        let guide = GuideImporter.Guide(core: "抗彎曲", cues: ["a"], mistakes: ["b"], regression: "r", progression: "p")
        let renamed = Exercise(name: "我的深蹲", category: .kneeDominant, aliases: ["背蹲舉"], equipment: .barbell)
        let edited = Exercise(name: "背蹲舉", category: .kneeDominant, equipment: .barbell)
        edited.guideCore = "我自己寫的"
        GuideImporter.apply(["背蹲舉": guide], to: [renamed, edited])
        #expect(renamed.guideCore == "抗彎曲" && renamed.guideCues == ["a"])
        #expect(edited.guideCore == "我自己寫的")
    }
}
