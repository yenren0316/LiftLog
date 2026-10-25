import unittest

from parse_log import parse_cardio, parse_line, parse_log


def one(line):
    review = []
    status, result = parse_line(line, review)
    assert status == "ok", (line, status, result)
    assert len(result) == 1
    return result[0]


class TreadmillTests(unittest.TestCase):
    def test_spaced_fields(self):
        self.assertEqual(parse_cardio("坡度 6 速度 5 30min"), (6.0, 5.0, 30.0))

    def test_no_spaces(self):
        self.assertEqual(parse_cardio("坡度13速度4 30min"), (13.0, 4.0, 30.0))

    def test_decimals_and_short_session(self):
        self.assertEqual(parse_cardio("坡度14.5 速度4.2 17min"), (14.5, 4.2, 17.0))

    def test_walk_and_run_merge_into_treadmill(self):
        walk = one("室內步行 坡度12 速度4 30min")
        run = one("跑步 坡度 6 速度 5 30min")
        self.assertEqual(walk["exercise"], "跑步機")
        self.assertEqual(run["exercise"], "跑步機")
        self.assertEqual((walk["incline"], walk["speed"], walk["minutes"]), (12.0, 4.0, 30.0))
        self.assertEqual(walk["note"], "")
        self.assertEqual(run["note"], "跑步")
        self.assertIsNone(walk["weightKg"])


class NameMappingTests(unittest.TestCase):
    def test_renamed_exercises(self):
        self.assertEqual(one("深蹲 100kg MAX")["exercise"], "深蹲")
        self.assertEqual(one("臥推 60.8kg MAX")["exercise"], "臥推")
        self.assertEqual(one("槓鈴臥推 42.6 5x5")["exercise"], "臥推")
        self.assertEqual(one("肩推 30kg 3x8")["exercise"], "肩推")
        self.assertEqual(one("單手啞鈴抓舉 12kg 3x5 一邊")["exercise"], "單手抓舉")

    def test_kettlebell_swings_are_split(self):
        self.assertEqual(one("盪壺鈴 24kg 15x3")["exercise"], "壺鈴擺盪")
        self.assertEqual(one("雙手壺鈴擺盪16kg 3次")["exercise"], "壺鈴擺盪")
        self.assertEqual(one("單手壺鈴擺盪 16kg 3次")["exercise"], "單手壺鈴擺盪")
        self.assertEqual(one("彈力繩盪壺鈴 20kg 做到沒力x3")["exercise"], "彈力繩壺鈴擺盪")

    def test_machines_are_imported_as_separate_exercises(self):
        self.assertEqual(one("腿推機 120 5x5")["exercise"], "腿推機")
        self.assertEqual(one("背部訓練機 15.9 5x5")["exercise"], "背部訓練機")
        self.assertEqual(one("背部下拉訓練機 45lbs 5x5")["exercise"], "背部下拉訓練機")
        self.assertEqual(one("臥姿腿部彎曲機 41kg 5x5")["exercise"], "臥姿腿彎舉機")
        self.assertEqual(one("肩推機 11.3 5x5")["exercise"], "肩推機")
        self.assertEqual(one("肩推 30kg 3x8")["exercise"], "肩推")

    def test_renamed_single_arm_press(self):
        self.assertEqual(one("半椅單手臥推 10kg 一邊10下x3")["exercise"], "單手啞鈴臥推")

    def test_inverted_row_is_bodyweight(self):
        row = one("反式划船 15格 5x5")
        self.assertEqual((row["weightKg"], row["reps"], row["sets"], row["note"]), (None, 5, 5, "15格"))

    def test_pull_ups(self):
        assisted = one("引體向上輔助 -19 5x5")
        self.assertEqual((assisted["exercise"], assisted["weightKg"]), ("輔助引體向上", 19.0))
        bodyweight = one("引體向上 8x3")
        self.assertEqual((bodyweight["weightKg"], bodyweight["reps"], bodyweight["sets"]), (0.0, 8, 3))
        eccentric = one("自重引體向上 離心訓練 5x5")
        self.assertEqual((eccentric["weightKg"], eccentric["note"]), (0.0, "離心"))

    def test_variant_note(self):
        self.assertEqual(one("棒式壺鈴划船 8kg 8x3")["note"], "壺鈴")


class WholeLogTests(unittest.TestCase):
    def test_body_weight_and_dates(self):
        entries, body_weights, unmatched, _, _ = parse_log("2026\n6/24 70.8kg\n臥推 42.6 5x5\n1/1 教練課\n")
        self.assertEqual(body_weights, [dict(date="2026-06-24T12:00:00+08:00", kg=70.8)])
        self.assertEqual(entries[0]["date"], "2026-06-24T12:00:00+08:00")
        self.assertEqual(len(unmatched), 1)


class UnitReviewTests(unittest.TestCase):
    def parse(self, lines):
        entries, _, _, _, review = parse_log("2026\n1/1\n" + "\n".join(lines))
        return entries, review

    def test_unitless_compared_with_explicit_records(self):
        entries, review = self.parse(["啞鈴臥推 20kg Max", "啞鈴臥推 50 MAX", "啞鈴臥推 18 5x5"])
        # 參考 20 kg × 1.5 = 30：50 → lbs，18 → kg
        self.assertEqual(entries[1]["weightKg"], 22.68)
        self.assertIn("50lbs", entries[1]["note"])
        self.assertEqual(entries[2]["weightKg"], 18)
        self.assertEqual(len(review), 2)
        self.assertTrue(review[0][4].startswith("改成 lbs"))
        self.assertTrue(review[1][4].startswith("維持 kg"))

    def test_without_reference_uses_twenty(self):
        entries, _ = self.parse(["仰臥拉舉 40 8x3", "仰臥拉舉 14 10x3"])
        self.assertEqual(entries[0]["weightKg"], 18.14)
        self.assertEqual(entries[1]["weightKg"], 14)

    def test_kettlebells_reviewed_too(self):
        entries, review = self.parse(["盪壺鈴 24kg 15x3", "盪壺鈴 24 12x3"])
        self.assertEqual(entries[1]["weightKg"], 24)
        self.assertEqual(len(review), 1)

    def test_barbell_not_reviewed(self):
        _, review = self.parse(["上斜臥推 51.6 MAX"])
        self.assertEqual(review, [])


if __name__ == "__main__":
    unittest.main()
