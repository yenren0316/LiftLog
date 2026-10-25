#!/usr/bin/env python3
"""把 workout_log.txt 轉成 App 用的 seed.json，並輸出 unmatched.txt 供人工檢查。

用法：python3 tools/parse_log.py
測試：python3 -m unittest discover tools
"""
import json
import re
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOG = ROOT / "tools" / "workout_log.txt"
SEED = ROOT / "LiftLog" / "Data" / "seed.json"
UNMATCHED = ROOT / "tools" / "unmatched.txt"

KG_PER_LB = 0.45359237
TZ = "+08:00"
# 用名稱產生固定的 UUID，重新產生 seed.json 時 id 不會變
ID_NAMESPACE = uuid.UUID("6f1d3c52-8a4e-4b7a-9c1e-2f5b7d9e0a11")

# ---------------------------------------------------------------- 動作庫
# (名稱, 分類, tags, 別名, 器材, 紀錄類型)
EXERCISES = [
    # 下肢推（膝主導）
    ("背蹲舉", "kneeDominant", [], ["深蹲", "槓鈴深蹲"], "barbell", "weight"),
    ("後腳抬高蹲", "kneeDominant", ["unilateral"],
     ["保加利亞分腿蹲", "保加利亞蹲", "槓鈴保加利亞蹲", "槓鈴保加利亞分腿蹲"], "dumbbell", "weight"),
    ("高背槓分腿蹲", "kneeDominant", ["unilateral"], [], "barbell", "weight"),
    ("側蹲", "kneeDominant", ["unilateral"], ["地震側蹲"], "dumbbell", "weight"),
    ("六角槓階梯上下", "kneeDominant", ["unilateral"], [], "barbell", "weight"),
    ("壺鈴原地起跳", "kneeDominant", ["explosive"], [], "kettlebell", "weight"),
    # 下肢拉（髖主導）
    ("傳統硬舉", "hipDominant", [], ["硬舉"], "barbell", "weight"),
    ("六角槓硬舉", "hipDominant", [], [], "barbell", "weight"),
    ("相撲硬舉", "hipDominant", [], [], "barbell", "weight"),
    ("羅馬尼亞式硬舉", "hipDominant", [], ["羅馬尼亞蹲", "RDL"], "dumbbell", "weight"),
    ("單腳 RDL", "hipDominant", ["unilateral"],
     ["單腳羅馬尼亞式硬舉", "單腳啞鈴 RDL", "單側 RDL"], "dumbbell", "weight"),
    ("臀推", "hipDominant", [], [], "barbell", "weight"),
    ("壺鈴擺盪", "hipDominant", ["explosive"], ["盪壺鈴", "雙手壺鈴擺盪"], "kettlebell", "weight"),
    ("單手壺鈴擺盪", "hipDominant", ["unilateral", "explosive"], [], "kettlebell", "weight"),
    ("彈力繩壺鈴擺盪", "hipDominant", ["explosive"], ["彈力繩盪壺鈴"], "kettlebell", "weight"),
    ("單手抓舉", "hipDominant", ["unilateral", "explosive"], ["單手啞鈴抓舉", "啞鈴抓舉"], "dumbbell", "weight"),
    ("拋沙包", "hipDominant", ["explosive"], [], "other", "weight"),
    # 上肢水平推
    ("臥推", "horizontalPush", [], ["槓鈴臥推"], "barbell", "weight"),
    ("上斜臥推", "horizontalPush", [], [], "barbell", "weight"),
    ("地板臥推", "horizontalPush", [], [], "barbell", "weight"),
    ("啞鈴臥推", "horizontalPush", [], [], "dumbbell", "weight"),
    ("地板啞鈴臥推", "horizontalPush", [], [], "dumbbell", "weight"),
    ("半椅單手臥推", "horizontalPush", ["unilateral"], [], "dumbbell", "weight"),
    ("滾木槓臥推", "horizontalPush", [], [], "barbell", "weight"),
    # 上肢水平拉
    ("爆發划船", "horizontalPull", ["explosive"], [], "barbell", "weight"),
    ("反式划船", "horizontalPull", [], ["反式滑船"], "bodyweight", "weight"),
    ("棒式划船", "horizontalPull", ["unilateral"], ["棒式啞鈴划船", "棒式壺鈴划船"], "dumbbell", "weight"),
    ("單邊地雷管划船", "horizontalPull", ["unilateral"], [], "barbell", "weight"),
    ("坐姿 Cable 划船", "horizontalPull", [], ["坐姿划船", "Cable 划船", "坐姿cable划船"], "cable", "weight"),
    # 上肢垂直推
    ("肩推", "verticalPush", [], ["站姿槓鈴肩推", "槓鈴肩推"], "barbell", "weight"),
    ("坐姿槓鈴肩推", "verticalPush", [], [], "barbell", "weight"),
    ("坐姿啞鈴肩推", "verticalPush", [], ["啞鈴肩推", "坐姿肩推"], "dumbbell", "weight"),
    ("窄跪姿單手啞鈴肩推", "verticalPush", ["unilateral"], [], "dumbbell", "weight"),
    ("雙槓撐", "verticalPush", [], ["雙槓撐輔助"], "bodyweight", "assisted"),
    # 上肢垂直拉
    ("輔助引體向上", "verticalPull", [], ["引體向上輔助", "引體向上", "自重引體向上"], "bodyweight", "assisted"),
    ("仰臥拉舉", "verticalPull", [], ["Pull over", "啞鈴仰臥拉舉"], "dumbbell", "weight"),
    ("滑輪下拉", "verticalPull", [], ["Cable 滑輪下拉"], "cable", "weight"),
    # 轉體
    ("腹前推", "rotation", [], [], "cable", "weight"),
    ("地雷管抗旋轉", "rotation", [], [], "barbell", "weight"),
    ("坐姿分腿壺鈴三點搬移", "rotation", [], [], "kettlebell", "weight"),
    # 負重行走
    ("單手硬舉原地踏步", "loadedCarry", ["unilateral"], [], "barbell", "weight"),
    ("六角槓原地踏步", "loadedCarry", [], [], "barbell", "weight"),
    # 補強
    ("腹肌滾輪", "accessory", [], [], "other", "weight"),
    ("三頭肌滑輪下拉", "accessory", [], ["三頭下拉", "三頭滑輪下拉"], "cable", "weight"),
    ("二頭彎舉", "accessory", [], [], "dumbbell", "weight"),
    ("面拉", "accessory", [], [], "cable", "weight"),
    ("YTW", "accessory", [], [], "dumbbell", "weight"),
    # 有氧
    ("跑步機", "cardio", [], ["室內步行", "跑步"], "other", "cardio"),
]
EX_BY_NAME = {e[0]: e for e in EXERCISES}

# 暫不放入動作庫的機械動作：舊紀錄不匯入，列在 unmatched.txt
SKIPPED_MACHINES = [
    "腿推機", "深蹲訓練機", "超級深蹲訓練架", "腿部伸張機", "臥姿腿彎舉機", "臥姿腿部彎曲機",
    "胸推訓練機", "背部訓練機", "背部下拉訓練機", "肩推機", "垂直舉肩訓練機",
]

# 原文用這個別名時，把器材變化寫進備註
VARIANT_NOTES = {
    "棒式啞鈴划船": "啞鈴",
    "棒式壺鈴划船": "壺鈴",
    "槓鈴保加利亞蹲": "槓鈴",
    "槓鈴保加利亞分腿蹲": "槓鈴",
    "地震側蹲": "地震",
    "Cable 滑輪下拉": "Cable",
    "單腳啞鈴 RDL": "啞鈴",
    "跑步": "跑步",
}


def squash(s):
    return re.sub(r"\s+", "", s).lower()


def build_lookup():
    """忽略空白與大小寫的名稱表，長的排前面，比對時取最長相符"""
    table = {}
    for name, _, _, aliases, _, _ in EXERCISES:
        for written in [name, *aliases]:
            table[squash(written)] = (name, VARIANT_NOTES.get(written, ""))
    for machine in SKIPPED_MACHINES:
        table[squash(machine)] = (None, machine)
    return sorted(table.items(), key=lambda kv: -len(kv[0]))


LOOKUP = build_lookup()

# 沒寫單位、超過 20 視為 lbs 的啞鈴動作
DUMBBELL_LBS_RULE = {n for n, e in EX_BY_NAME.items() if e[4] == "dumbbell"}

# ---------------------------------------------------------------- 特例
# 原文整行 -> 手動整理的結果（list，可拆成多筆）
OVERRIDES = {
    "滾木槓臥推 槓+38.4 MAX": [
        dict(name="滾木槓臥推", weight=None, isMax=True, note="槓+38.4（槓重未記）"),
    ],
    "槓鈴肩推 35 3x5 + 30 3x2": [
        dict(name="肩推", weight=35, reps=3, sets=5),
        dict(name="肩推", weight=30, reps=3, sets=2),
    ],
    "滑輪下拉 14.7x2 10x3": [
        dict(name="滑輪下拉", weight=14.7, reps=10, sets=3, note="一邊（雙 Cable）"),
    ],
    "滑輪下拉 14.7一邊 5x5": [
        dict(name="滑輪下拉", weight=14.7, reps=5, sets=5, note="一邊（雙 Cable）"),
    ],
    "Cable 滑輪下拉 14.7kg一邊 5x5": [
        dict(name="滑輪下拉", weight=14.7, reps=5, sets=5, note="Cable 一邊（雙 Cable）"),
    ],
    "羅馬尼亞蹲 5x5 （啞鈴 30一邊）": [
        dict(name="羅馬尼亞式硬舉", weight=30 * KG_PER_LB, reps=5, sets=5, note="啞鈴 30lbs 一邊"),
    ],
    "自重引體向上 離心訓練 5x5": [
        dict(name="輔助引體向上", weight=0, reps=5, sets=5, note="離心"),
    ],
}

# ---------------------------------------------------------------- 解析
NUM = r"\d+(?:\.\d+)?"


def fmt(v):
    return f"{v:g}"


def parse_cardio(text):
    """「坡度 12 速度 4 30min」→ (12.0, 4.0, 30.0)；缺的欄位為 None"""
    def grab(pattern):
        m = re.search(pattern, text)
        return float(m.group(1)) if m else None
    return grab(rf"坡度\s*({NUM})"), grab(rf"速度\s*({NUM})"), grab(rf"({NUM})\s*min")


def parse_body(name, rest, raw, review):
    """解析動作名後面的文字，回傳 dict。"""
    _, _, _, _, equipment, log_type = EX_BY_NAME[name]
    out = dict(weight=None, sets=None, reps=None, isMax=False,
               incline=None, speed=None, minutes=None, notes=[])
    s = rest

    if log_type == "cardio":
        out["incline"], out["speed"], out["minutes"] = parse_cardio(s)
        if None in (out["incline"], out["speed"], out["minutes"]):
            review.append(("跑步機欄位不完整", raw, ""))
        return out

    if re.search(r"max", s, re.I):
        out["isMax"] = True
        s = re.sub(r"max", " ", s, flags=re.I)

    # 輔助重量：-21.25；沒寫就是自重（輔助 0）
    if log_type == "assisted":
        if m := re.match(rf"\s*-\s*({NUM})", s):
            out["weight"] = float(m.group(1))
            s = s[m.end():]
        else:
            out["weight"] = 0.0

    # 範圍重量（8～14、16～20kg）要先處理，以免被當成次數 × 組數；取最大值
    range_value = None
    if m := re.search(rf"({NUM})\s*[～~]\s*({NUM})\s*(kg|lbs|lb)?", s, re.I):
        range_value = (float(m.group(2)), (m.group(3) or "").lower())
        out["notes"].append(f"{m.group(1)}～{m.group(2)}{m.group(3) or ''}")
        s = s[:m.start()] + " " + s[m.end():]

    # 次數 × 組數
    patterns = [
        (r"(\d+)\s*下\s*[x×]\s*(\d+)", "rs"),
        (r"(?<![\d.])(\d+)\s*[x×]\s*(\d+)\s*次?", "rs"),
        (r"[x×]\s*(\d+)", "s"),
        (r"(?<![\d.x×])(\d+)\s*次", "s"),
    ]
    for pat, kind in patterns:
        if m := re.search(pat, s):
            if kind == "rs":
                out["reps"], out["sets"] = int(m.group(1)), int(m.group(2))
            else:
                out["sets"] = int(m.group(1))
            s = s[:m.start()] + " " + s[m.end():]
            break

    # 重量：只看括號前面的部分；「15格」不是重量
    head = re.split(r"[（(]", s, maxsplit=1)[0]
    if range_value:
        (value, unit), span = range_value, (0, 0)
    elif m := re.search(rf"({NUM})(?![\d.])\s*(kg|lbs|lb)?(?!\s*格)", head, re.I):
        value, unit = float(m.group(1)), (m.group(2) or "").lower()
        span = m.span()
    else:
        value, unit, span = None, "", None

    if value is not None and out["weight"] is None:
        if unit.startswith("lb"):
            out["weight"] = value * KG_PER_LB
            out["notes"].append(f"{fmt(value)}lbs")
        elif unit == "" and name in DUMBBELL_LBS_RULE and value > 20:
            out["weight"] = value * KG_PER_LB
            out["notes"].append(f"{fmt(value)}lbs")
            review.append(("沒寫單位、超過 20 當作 lbs", raw, f"{fmt(value)}lbs = {out['weight']:.2f} kg"))
        else:
            out["weight"] = value
        s = s.replace(head, head[:span[0]] + " " + head[span[1]:], 1)

    leftover = re.sub(r"\s+", " ", s).strip(" ，,")
    leftover = leftover.replace("（", "(").replace("）", ")")
    if leftover.count("(") > leftover.count(")"):
        leftover += ")"
    if leftover:
        out["notes"].append(leftover)

    if "?" in raw:
        review.append(("原文有問號", raw, ""))
    if out["weight"] is None and equipment != "bodyweight":
        review.append(("沒有重量", raw, ""))
    if out["sets"] is None and out["reps"] is None and not out["isMax"]:
        review.append(("沒有次數／組數", raw, ""))
    return out


def match_name(line):
    """回傳 ((動作名或 None, 變化備註), 剩下的文字)；動作名為 None 代表是暫不匯入的機械"""
    sq = squash(line)
    for key, value in LOOKUP:
        if sq.startswith(key):
            # 在原字串中找到對應的切點（忽略空白）
            count, idx = 0, 0
            while count < len(key) and idx < len(line):
                if not line[idx].isspace():
                    count += 1
                idx += 1
            return value, line[idx:]
    return None, None


def entry(name, weight=None, sets=None, reps=None, isMax=False,
          incline=None, speed=None, minutes=None, note=""):
    return dict(exercise=name, weightKg=None if weight is None else round(weight, 2),
                sets=sets, reps=reps, isMax=isMax,
                incline=incline, speed=speed, minutes=minutes, note=note)


def parse_line(line, review):
    """解析一行動作。回傳 ("ok", [entry...]) 或 ("skip"/"unmatched", 原因)"""
    if line in OVERRIDES:
        items = OVERRIDES[line]
        review.append(("手動整理", line, " / ".join(
            f"{i['name']} {'' if i.get('weight') is None else round(i['weight'], 2)}" for i in items)))
        return "ok", [entry(i["name"], i.get("weight"), i.get("sets"), i.get("reps"),
                            i.get("isMax", False), note=i.get("note", "")) for i in items]

    matched, rest = match_name(line)
    if matched is None:
        return "unmatched", "動作名稱對不上"
    name, variant = matched
    if name is None:
        return "skip", f"機械動作（{variant}）暫不匯入"

    p = parse_body(name, rest, line, review)
    notes = ([variant] if variant else []) + p["notes"]
    return "ok", [entry(name, p["weight"], p["sets"], p["reps"], p["isMax"],
                        p["incline"], p["speed"], p["minutes"], " ".join(notes))]


def iso(year, month, day, minute):
    return f"{year:04d}-{month:02d}-{day:02d}T12:{minute:02d}:00{TZ}"


def parse_log(text):
    entries, body_weights, unmatched, review = [], [], [], []
    year = month = day = None
    order = 0

    for lineno, raw_line in enumerate(text.splitlines(), 1):
        line = raw_line.strip()
        if not line or line.lower().startswith("workout tracking"):
            continue
        if re.fullmatch(r"\d{4}", line):
            year = int(line)
            continue
        if m := re.match(r"^(\d{1,2})/(\d{1,2})\s*(?:[（(][^)）]*[)）])?\s*(.*)$", line):
            month, day, extra = int(m.group(1)), int(m.group(2)), m.group(3).strip()
            order = 0
            if extra:
                if bw := re.fullmatch(rf"({NUM})\s*(kg)?", extra):
                    body_weights.append(dict(date=iso(year, month, day, 0), kg=float(bw.group(1))))
                else:
                    unmatched.append((lineno, raw_line, "日期後面的文字不是體重，沒有對應的動作"))
            continue
        if year is None or month is None:
            unmatched.append((lineno, raw_line, "找不到日期"))
            continue

        status, result = parse_line(line, review)
        if status != "ok":
            unmatched.append((lineno, raw_line, result))
            continue
        for e in result:
            e["date"] = iso(year, month, day, order)
            order += 1
            entries.append(e)

    return entries, body_weights, unmatched, review


def exercise_id(name):
    return str(uuid.uuid5(ID_NAMESPACE, name)).upper()


def main():
    entries, body_weights, unmatched, review = parse_log(LOG.read_text(encoding="utf-8"))

    for e in entries:
        e["exerciseId"] = exercise_id(e.pop("exercise"))

    seed = dict(
        version=2,
        exercises=[dict(id=exercise_id(n), name=n, category=cat, tags=tags, aliases=aliases,
                        englishName="", equipment=eq, logType=lt, note="", isArchived=False)
                   for n, cat, tags, aliases, eq, lt in EXERCISES],
        entries=entries,
        bodyWeights=body_weights,
    )
    SEED.parent.mkdir(parents=True, exist_ok=True)
    SEED.write_text(json.dumps(seed, ensure_ascii=False, indent=1), encoding="utf-8")

    with UNMATCHED.open("w", encoding="utf-8") as f:
        f.write("# 沒有匯入的行\n")
        for lineno, text, why in unmatched:
            f.write(f"L{lineno}\t{why}\t{text}\n")
        f.write("\n# 已匯入但請確認\n")
        for why, text, detail in review:
            f.write(f"{why}\t{text}\t{detail}\n")

    used = {e["exerciseId"] for e in entries}
    print(f"entries={len(entries)} bodyWeights={len(body_weights)} "
          f"unmatched={len(unmatched)} review={len(review)}")
    print("從沒做過的動作：", [n for n in EX_BY_NAME if exercise_id(n) not in used])


if __name__ == "__main__":
    main()
