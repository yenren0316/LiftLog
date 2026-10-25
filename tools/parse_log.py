#!/usr/bin/env python3
"""把 workout_log.txt 轉成 App 用的 seed.json，並輸出 unmatched.txt 供人工檢查。

用法：python3 tools/parse_log.py
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOG = ROOT / "tools" / "workout_log.txt"
SEED = ROOT / "LiftLog" / "Data" / "seed.json"
UNMATCHED = ROOT / "tools" / "unmatched.txt"

KG_PER_LB = 0.45359237
TZ = "+08:00"

# ---------------------------------------------------------------- 動作庫
# (名稱, 主要部位, 次要部位, 器材, 紀錄類型)
EXERCISES = [
    # 胸
    ("槓鈴臥推", "chest", ["shoulders", "arms"], "barbell", "weight"),
    ("上斜臥推", "chest", ["shoulders", "arms"], "barbell", "weight"),
    ("啞鈴臥推", "chest", ["shoulders", "arms"], "dumbbell", "weight"),
    ("地板臥推", "chest", ["arms"], "barbell", "weight"),
    ("地板啞鈴臥推", "chest", ["arms"], "dumbbell", "weight"),
    ("半椅單手臥推", "chest", ["shoulders", "core"], "dumbbell", "weight"),
    ("滾木槓臥推", "chest", ["shoulders", "arms"], "barbell", "weight"),
    ("胸推訓練機", "chest", ["shoulders", "arms"], "machine", "weight"),
    ("雙槓撐", "chest", ["arms", "shoulders"], "bodyweight", "assisted"),
    # 肩
    ("站姿槓鈴肩推", "shoulders", ["arms", "core"], "barbell", "weight"),
    ("坐姿槓鈴肩推", "shoulders", ["arms"], "barbell", "weight"),
    ("坐姿啞鈴肩推", "shoulders", ["arms"], "dumbbell", "weight"),
    ("窄跪姿單手啞鈴肩推", "shoulders", ["core", "arms"], "dumbbell", "weight"),
    ("肩推機", "shoulders", ["arms"], "machine", "weight"),
    ("垂直舉肩訓練機", "shoulders", [], "machine", "weight"),
    ("面拉", "shoulders", ["back"], "cable", "weight"),
    ("YTW", "shoulders", ["back"], "dumbbell", "weight"),
    # 背
    ("滑輪下拉", "back", ["arms"], "cable", "weight"),
    ("引體向上", "back", ["arms", "core"], "bodyweight", "assisted"),
    ("坐姿 Cable 划船", "back", ["arms"], "cable", "weight"),
    ("背部訓練機", "back", ["arms"], "machine", "weight"),
    ("爆發划船", "back", ["posterior", "arms"], "barbell", "weight"),
    ("反式划船", "back", ["arms", "core"], "bodyweight", "weight"),
    ("棒式划船", "back", ["core", "arms"], "dumbbell", "weight"),
    ("單邊地雷管划船", "back", ["arms", "core"], "barbell", "weight"),
    ("仰臥拉舉", "back", ["chest"], "dumbbell", "weight"),
    # 手臂
    ("三頭肌滑輪下拉", "arms", [], "cable", "weight"),
    ("二頭彎舉", "arms", [], "dumbbell", "weight"),
    # 腿前側
    ("槓鈴深蹲", "quads", ["posterior", "core"], "barbell", "weight"),
    ("深蹲訓練機", "quads", ["posterior"], "machine", "weight"),
    ("超級深蹲訓練架", "quads", ["posterior"], "machine", "weight"),
    ("腿推機", "quads", ["posterior"], "machine", "weight"),
    ("保加利亞分腿蹲", "quads", ["posterior", "core"], "dumbbell", "weight"),
    ("高背槓分腿蹲", "quads", ["posterior", "core"], "barbell", "weight"),
    ("側蹲", "quads", ["posterior"], "dumbbell", "weight"),
    ("腿部伸張機", "quads", [], "machine", "weight"),
    ("六角槓階梯上下", "quads", ["posterior", "core"], "barbell", "weight"),
    # 臀腿後側
    ("傳統硬舉", "posterior", ["back", "quads", "core"], "barbell", "weight"),
    ("六角槓硬舉", "posterior", ["quads", "back"], "barbell", "weight"),
    ("相撲硬舉", "posterior", ["quads", "back"], "barbell", "weight"),
    ("羅馬尼亞硬舉", "posterior", ["back"], "dumbbell", "weight"),
    ("單腳 RDL", "posterior", ["core"], "dumbbell", "weight"),
    ("臀推", "posterior", ["quads"], "barbell", "weight"),
    ("臥姿腿彎舉機", "posterior", [], "machine", "weight"),
    ("壺鈴擺盪", "posterior", ["core", "power"], "kettlebell", "weight"),
    # 爆發／全身
    ("單手啞鈴抓舉", "power", ["shoulders", "posterior"], "dumbbell", "weight"),
    ("拋沙包", "power", ["core"], "other", "weight"),
    ("壺鈴原地起跳", "power", ["quads"], "kettlebell", "weight"),
    # 核心
    ("腹前推", "core", ["shoulders"], "cable", "weight"),
    ("地雷管抗旋轉", "core", ["shoulders"], "barbell", "weight"),
    ("腹肌滾輪", "core", [], "other", "weight"),
    ("坐姿分腿壺鈴三點搬移", "core", [], "kettlebell", "weight"),
    ("單手硬舉原地踏步", "core", ["posterior"], "barbell", "weight"),
    ("六角槓原地踏步", "core", ["posterior"], "barbell", "weight"),
    # 有氧
    ("室內步行", "cardio", [], "other", "cardio"),
    ("跑步", "cardio", [], "other", "cardio"),
]
EX_BY_NAME = {e[0]: e for e in EXERCISES}

# ---------------------------------------------------------------- 名稱對應
# 原文寫法 -> (動作名, 變化備註)
ALIASES = {
    "盪壺鈴": ("壺鈴擺盪", ""),
    "雙手壺鈴擺盪": ("壺鈴擺盪", "雙手"),
    "單手壺鈴擺盪": ("壺鈴擺盪", "單手"),
    "彈力繩盪壺鈴": ("壺鈴擺盪", "彈力繩"),
    "肩推": ("站姿槓鈴肩推", ""),
    "槓鈴肩推": ("站姿槓鈴肩推", ""),
    "啞鈴肩推": ("坐姿啞鈴肩推", ""),
    "坐姿肩推": ("坐姿啞鈴肩推", ""),
    "臥推": ("槓鈴臥推", ""),
    "羅馬尼亞蹲": ("羅馬尼亞硬舉", ""),
    "三頭下拉": ("三頭肌滑輪下拉", ""),
    "三頭滑輪下拉": ("三頭肌滑輪下拉", ""),
    "棒式啞鈴划船": ("棒式划船", "啞鈴"),
    "棒式壺鈴划船": ("棒式划船", "壺鈴"),
    "保加利亞蹲": ("保加利亞分腿蹲", ""),
    "槓鈴保加利亞蹲": ("保加利亞分腿蹲", "槓鈴"),
    "槓鈴保加利亞分腿蹲": ("保加利亞分腿蹲", "槓鈴"),
    "地震側蹲": ("側蹲", "地震"),
    "啞鈴仰臥拉舉": ("仰臥拉舉", ""),
    "背部下拉訓練機": ("背部訓練機", ""),
    "反式滑船": ("反式划船", ""),
    # 規格以外補的對應
    "硬舉": ("傳統硬舉", ""),
    "深蹲": ("槓鈴深蹲", ""),
    "啞鈴抓舉": ("單手啞鈴抓舉", ""),
    "單腳RDL": ("單腳 RDL", ""),
    "單腳啞鈴RDL": ("單腳 RDL", "啞鈴"),
    "坐姿划船": ("坐姿 Cable 划船", ""),
    "坐姿cable划船": ("坐姿 Cable 划船", ""),
    "cable划船": ("坐姿 Cable 划船", ""),
    "cable滑輪下拉": ("滑輪下拉", "Cable"),
    "臥姿腿部彎曲機": ("臥姿腿彎舉機", ""),
    "自重引體向上": ("引體向上", "自重"),
    "引體向上輔助": ("引體向上", ""),
    "雙槓撐輔助": ("雙槓撐", ""),
}
for _name in EX_BY_NAME:
    ALIASES.setdefault(_name, (_name, ""))


def squash(s):
    return re.sub(r"\s+", "", s).lower()


ALIAS_KEYS = sorted(((squash(k), k) for k in ALIASES), key=lambda t: -len(t[0]))

# 沒寫單位、超過 20 視為 lbs 的啞鈴動作
DUMBBELL_LBS_RULE = {n for n, e in EX_BY_NAME.items() if e[3] == "dumbbell"}

# ---------------------------------------------------------------- 特例
# 原文整行 -> 手動整理的結果（list，可拆成多筆）
OVERRIDES = {
    "滾木槓臥推 槓+38.4 MAX": [
        dict(name="滾木槓臥推", weight=None, isMax=True, note="槓+38.4（槓重未記）"),
    ],
    "槓鈴肩推 35 3x5 + 30 3x2": [
        dict(name="站姿槓鈴肩推", weight=35, reps=3, sets=5),
        dict(name="站姿槓鈴肩推", weight=30, reps=3, sets=2),
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
        dict(name="羅馬尼亞硬舉", weight=30 * KG_PER_LB, reps=5, sets=5, note="啞鈴 30lbs 一邊"),
    ],
}

# ---------------------------------------------------------------- 解析
NUM = r"\d+(?:\.\d+)?"


def round2(x):
    return None if x is None else round(x, 2)


def parse_body(name, rest, raw, review):
    """解析動作名後面的文字，回傳 dict。"""
    ex = EX_BY_NAME[name]
    log_type = ex[4]
    out = dict(weight=None, sets=None, reps=None, isMax=False,
               incline=None, speed=None, minutes=None, notes=[])
    s = rest

    if log_type == "cardio":
        if m := re.search(rf"坡度\s*({NUM})", s):
            out["incline"] = float(m.group(1))
        if m := re.search(rf"速度\s*({NUM})", s):
            out["speed"] = float(m.group(1))
        if m := re.search(rf"({NUM})\s*min", s):
            out["minutes"] = float(m.group(1))
        return out

    if re.search(r"max", s, re.I):
        out["isMax"] = True
        s = re.sub(r"max", " ", s, flags=re.I)

    # 輔助重量：-21.25
    if log_type == "assisted":
        if m := re.match(rf"\s*-\s*({NUM})", s):
            out["weight"] = float(m.group(1))
            s = s[m.end():]
        elif "自重" in raw:
            out["weight"] = 0.0

    # 範圍重量（8～14、16～20kg）要先處理，以免被當成次數 × 組數；取最大值
    range_value = None
    if m := re.search(rf"({NUM})\s*[～~]\s*({NUM})\s*(kg|lbs|lb)?", s, re.I):
        range_value = (float(m.group(2)), (m.group(3) or "").lower())
        out["notes"].append(f"{m.group(1)}～{m.group(2)}{m.group(3) or ''}")
        s = s[:m.start()] + " " + s[m.end():]

    # 次數 × 組數
    patterns = [
        (rf"(\d+)\s*下\s*[x×]\s*(\d+)", "rs"),
        (rf"(?<![\d.])(\d+)\s*[x×]\s*(\d+)\s*次?", "rs"),
        (rf"[x×]\s*(\d+)", "s"),
        (rf"(?<![\d.x×])(\d+)\s*次", "s"),
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
            out["notes"].append(f"{Units(value)}lbs")
        elif unit == "" and name in DUMBBELL_LBS_RULE and value > 20:
            out["weight"] = value * KG_PER_LB
            out["notes"].append(f"{Units(value)}lbs")
            review.append(("沒寫單位、超過 20 當作 lbs", raw, f"{Units(value)}lbs = {out['weight']:.2f} kg"))
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
    if out["weight"] is None and ex[3] not in ("bodyweight",) and log_type == "weight":
        review.append(("沒有重量", raw, ""))
    if out["sets"] is None and out["reps"] is None and not out["isMax"]:
        review.append(("沒有次數／組數", raw, ""))
    return out


def Units(v):
    return f"{v:g}"


def match_name(line):
    sq = squash(line)
    for key, original in ALIAS_KEYS:
        if sq.startswith(key):
            # 在原字串中找到對應的切點（忽略空白）
            count, idx = 0, 0
            while count < len(key) and idx < len(line):
                if not line[idx].isspace():
                    count += 1
                idx += 1
            return ALIASES[original], line[idx:]
    return None, None


def iso(year, month, day, minute):
    return f"{year:04d}-{month:02d}-{day:02d}T12:{minute:02d}:00{TZ}"


def main():
    entries, body_weights, unmatched, review = [], [], [], []
    year = month = day = None
    order = 0

    for lineno, raw_line in enumerate(LOG.read_text(encoding="utf-8").splitlines(), 1):
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

        date = None if year is None else (year, month, day)
        if date is None:
            unmatched.append((lineno, raw_line, "找不到日期"))
            continue

        if line in OVERRIDES:
            for item in OVERRIDES[line]:
                entries.append(dict(
                    date=iso(*date, order), exercise=item["name"],
                    weightKg=round2(item.get("weight")), sets=item.get("sets"), reps=item.get("reps"),
                    isMax=item.get("isMax", False), incline=None, speed=None, minutes=None,
                    note=item.get("note", ""),
                ))
                order += 1
            review.append(("手動整理", raw_line, " / ".join(
                f"{i['name']} {'' if i.get('weight') is None else round(i['weight'], 2)}" for i in OVERRIDES[line])))
            continue

        (name, variant), rest = match_name(line)
        if name is None:
            entries.append(dict(date=iso(*date, order), exercise=None, note=raw_line))
            unmatched.append((lineno, raw_line, "動作名稱對不上"))
            continue

        p = parse_body(name, rest, line, review)
        notes = ([variant] if variant else []) + p["notes"]
        entries.append(dict(
            date=iso(*date, order), exercise=name,
            weightKg=round2(p["weight"]), sets=p["sets"], reps=p["reps"], isMax=p["isMax"],
            incline=p["incline"], speed=p["speed"], minutes=p["minutes"],
            note=" ".join(notes),
        ))
        order += 1

    # 動作名稱對不上的紀錄無法掛在動作上，只留在 unmatched.txt
    entries = [e for e in entries if e.get("exercise")]

    seed = dict(
        version=1,
        exercises=[dict(name=n, primaryGroup=g, secondaryGroups=sec, equipment=eq, logType=lt,
                        note="", isArchived=False) for n, g, sec, eq, lt in EXERCISES],
        entries=entries,
        bodyWeights=body_weights,
    )
    SEED.parent.mkdir(parents=True, exist_ok=True)
    SEED.write_text(json.dumps(seed, ensure_ascii=False, indent=1), encoding="utf-8")

    with UNMATCHED.open("w", encoding="utf-8") as f:
        f.write("# 無法匯入的行\n")
        for lineno, text, why in unmatched:
            f.write(f"L{lineno}\t{why}\t{text}\n")
        f.write("\n# 已匯入但請確認\n")
        for why, text, detail in review:
            f.write(f"{why}\t{text}\t{detail}\n")

    used = {e["exercise"] for e in entries}
    print(f"entries={len(entries)} bodyWeights={len(body_weights)} "
          f"unmatched={len(unmatched)} review={len(review)}")
    print("從沒做過的動作：", [n for n in EX_BY_NAME if n not in used])


if __name__ == "__main__":
    main()
