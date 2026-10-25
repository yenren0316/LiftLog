#!/usr/bin/env python3
"""把 workout_log.txt 轉成 App 用的 seed.json，並輸出 unmatched.txt 與 unit_review.txt 供人工檢查。

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
UNIT_REVIEW = ROOT / "tools" / "unit_review.txt"

KG_PER_LB = 0.45359237
TZ = "+08:00"
# 用名稱產生固定的 UUID，重新產生 seed.json 時 id 不會變
ID_NAMESPACE = uuid.UUID("6f1d3c52-8a4e-4b7a-9c1e-2f5b7d9e0a11")


# ---------------------------------------------------------------- 動作庫
def ex(name, category, tags, aliases, equipment, log_type, archived=False):
    return dict(name=name, category=category, tags=tags, aliases=aliases,
                equipment=equipment, logType=log_type, archived=archived)


U, X = "unilateral", "explosive"

EXERCISES = [
    # 下肢推（膝主導）
    ex("背蹲舉", "kneeDominant", [], ["深蹲", "槓鈴深蹲", "高背深蹲"], "barbell", "weight"),
    ex("後腳抬高蹲", "kneeDominant", [U], ["保加利亞分腿蹲", "保加利亞蹲", "槓鈴保加利亞蹲", "槓鈴保加利亞分腿蹲"], "dumbbell", "weight"),
    ex("高背槓分腿蹲", "kneeDominant", [U], [], "barbell", "weight"),
    ex("側蹲", "kneeDominant", [U], ["地震側蹲"], "dumbbell", "weight"),
    ex("六角槓階梯上下", "kneeDominant", [U], [], "barbell", "weight"),
    ex("壺鈴原地起跳", "kneeDominant", [X], [], "kettlebell", "weight"),
    ex("前蹲舉", "kneeDominant", [], [], "barbell", "weight"),
    ex("前抱式深蹲", "kneeDominant", [], ["高腳杯深蹲", "抱蹲"], "dumbbell", "weight"),
    ex("分腿蹲", "kneeDominant", [U], [], "dumbbell", "weight"),
    ex("單腳深蹲", "kneeDominant", [U], [], "bodyweight", "bodyweight"),
    ex("跳箱", "kneeDominant", [X], ["箱上跳"], "box", "bodyweight"),
    # 下肢拉（髖主導）
    ex("傳統硬舉", "hipDominant", [], ["硬舉"], "barbell", "weight"),
    ex("六角槓硬舉", "hipDominant", [], [], "barbell", "weight"),
    ex("相撲硬舉", "hipDominant", [], [], "barbell", "weight"),
    ex("羅馬尼亞式硬舉", "hipDominant", [], ["羅馬尼亞蹲", "RDL"], "dumbbell", "weight"),
    ex("單腳 RDL", "hipDominant", [U], ["單腳羅馬尼亞式硬舉", "單腳啞鈴 RDL", "單側 RDL"], "dumbbell", "weight"),
    ex("臀推", "hipDominant", [], [], "barbell", "weight"),
    ex("壺鈴擺盪", "hipDominant", [X], ["盪壺鈴", "雙手壺鈴擺盪"], "kettlebell", "weight"),
    ex("單手壺鈴擺盪", "hipDominant", [U, X], [], "kettlebell", "weight"),
    ex("彈力繩壺鈴擺盪", "hipDominant", [X], ["彈力繩盪壺鈴"], "kettlebell", "weight"),
    ex("單手抓舉", "hipDominant", [U, X], ["單手啞鈴抓舉", "啞鈴抓舉"], "dumbbell", "weight"),
    ex("拋沙包", "hipDominant", [X], [], "other", "weight"),
    ex("早安運動", "hipDominant", [], [], "barbell", "weight"),
    ex("單手分腿抓舉", "hipDominant", [U, X], [], "dumbbell", "weight"),
    # 上肢水平推
    ex("臥推", "horizontalPush", [], ["槓鈴臥推"], "barbell", "weight"),
    ex("上斜臥推", "horizontalPush", [], [], "barbell", "weight"),
    ex("地板臥推", "horizontalPush", [], [], "barbell", "weight"),
    ex("啞鈴臥推", "horizontalPush", [], [], "dumbbell", "weight"),
    ex("地板啞鈴臥推", "horizontalPush", [], [], "dumbbell", "weight"),
    ex("單手啞鈴臥推", "horizontalPush", [U], ["半椅單手臥推"], "dumbbell", "weight"),
    ex("滾木槓臥推", "horizontalPush", [], [], "barbell", "weight"),
    ex("伏地挺身", "horizontalPush", [], [], "bodyweight", "bodyweight"),
    # 上肢水平拉
    ex("爆發划船", "horizontalPull", [X], [], "barbell", "weight"),
    ex("反式划船", "horizontalPull", [], ["反式滑船"], "bodyweight", "bodyweight"),
    ex("棒式划船", "horizontalPull", [U], ["棒式啞鈴划船", "棒式壺鈴划船"], "dumbbell", "weight"),
    ex("單邊地雷管划船", "horizontalPull", [U], [], "barbell", "weight"),
    ex("坐姿 Cable 划船", "horizontalPull", [], ["坐姿划船", "Cable 划船", "坐姿cable划船"], "cable", "weight"),
    ex("屈體划船", "horizontalPull", [], ["曲體划船"], "barbell", "weight"),
    ex("單手啞鈴划船", "horizontalPull", [U], ["單邊划船"], "dumbbell", "weight"),
    # 上肢垂直推
    ex("肩推", "verticalPush", [], ["站姿槓鈴肩推", "槓鈴肩推"], "barbell", "weight"),
    ex("坐姿槓鈴肩推", "verticalPush", [], [], "barbell", "weight"),
    ex("坐姿啞鈴肩推", "verticalPush", [], ["啞鈴肩推", "坐姿肩推"], "dumbbell", "weight"),
    ex("窄跪姿單手啞鈴肩推", "verticalPush", [U], [], "dumbbell", "weight"),
    ex("雙槓撐", "verticalPush", [], ["雙槓撐輔助"], "bodyweight", "assisted"),
    ex("爆發上推", "verticalPush", [X], ["Push Press"], "barbell", "weight"),
    # 上肢垂直拉
    ex("輔助引體向上", "verticalPull", [], ["引體向上輔助", "引體向上", "自重引體向上"], "bodyweight", "assisted"),
    ex("仰臥拉舉", "verticalPull", [], ["Pull over", "啞鈴仰臥拉舉"], "dumbbell", "weight"),
    ex("滑輪下拉", "verticalPull", [], ["Cable 滑輪下拉"], "cable", "weight"),
    # 轉體
    ex("腹前推", "rotation", [], [], "cable", "weight"),
    ex("地雷管抗旋轉", "rotation", [], [], "barbell", "weight"),
    ex("坐姿分腿壺鈴三點搬移", "rotation", [], [], "kettlebell", "weight"),
    ex("攪拌式", "rotation", [], [], "ball", "timed"),
    # 負重行走
    ex("單手硬舉原地踏步", "loadedCarry", [U], [], "barbell", "weight"),
    ex("六角槓原地踏步", "loadedCarry", [], [], "barbell", "weight"),
    ex("農夫走路", "loadedCarry", [], [], "dumbbell", "timed"),
    ex("單手負重行走", "loadedCarry", [U], [], "dumbbell", "timed"),
    # 違常姿勢
    ex("熊爬", "unusualPosture", [], [], "bodyweight", "timed"),
    ex("懸吊", "unusualPosture", [], [], "bar", "timed"),
    # 補強
    ex("腹肌滾輪", "accessory", [], [], "other", "weight"),
    ex("三頭肌滑輪下拉", "accessory", [], ["三頭下拉", "三頭滑輪下拉"], "cable", "weight"),
    ex("二頭彎舉", "accessory", [], [], "dumbbell", "weight"),
    ex("面拉", "accessory", [], [], "cable", "weight"),
    ex("YTW", "accessory", [], [], "dumbbell", "weight"),
    # 有氧
    ex("跑步機", "cardio", [], ["室內步行", "跑步"], "other", "cardio"),
    # 固定軌道的機台：封存（不出現在預設清單，歷史保留）
    ex("腿推機", "kneeDominant", [], [], "machine", "weight", archived=True),
    ex("深蹲訓練機", "kneeDominant", [], [], "machine", "weight", archived=True),
    ex("超級深蹲訓練架", "kneeDominant", [], [], "machine", "weight", archived=True),
    ex("腿部伸張機", "kneeDominant", [], [], "machine", "weight", archived=True),
    ex("臥姿腿彎舉機", "hipDominant", [], ["臥姿腿部彎曲機"], "machine", "weight", archived=True),
    ex("胸推訓練機", "horizontalPush", [], [], "machine", "weight", archived=True),
    ex("肩推機", "verticalPush", [], [], "machine", "weight", archived=True),
    ex("垂直舉肩訓練機", "accessory", [], [], "machine", "weight", archived=True),
    ex("背部訓練機", "horizontalPull", [], [], "machine", "weight", archived=True),
    ex("背部下拉訓練機", "verticalPull", [], [], "machine", "weight", archived=True),
]
EX_BY_NAME = {e["name"]: e for e in EXERCISES}

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
    for e in EXERCISES:
        for written in [e["name"], *e["aliases"]]:
            table[squash(written)] = (e["name"], VARIANT_NOTES.get(written, ""))
    return sorted(table.items(), key=lambda kv: -len(kv[0]))


LOOKUP = build_lookup()

# 記單顆重量、需要審查沒寫單位數字的器材
SINGLE_WEIGHT_EQUIPMENT = {"dumbbell", "kettlebell"}
# 沒有明確單位的參考紀錄時，超過這個數字視為 lbs
UNITLESS_LBS_THRESHOLD = 20
# 有參考紀錄時，超過「明確單位紀錄的最大值 × 這個倍數」視為 lbs
UNITLESS_LBS_RATIO = 1.5

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
    """解析動作名後面的文字，回傳 dict。

    啞鈴／壺鈴沒寫單位的數字先當 kg，記在 unitless，最後由 resolve_units 依參考紀錄決定是否改成 lbs。
    """
    e = EX_BY_NAME[name]
    equipment, log_type = e["equipment"], e["logType"]
    out = dict(weight=None, sets=None, reps=None, isMax=False,
               incline=None, speed=None, minutes=None, notes=[], unitless=None, explicit=False)
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
            out["explicit"] = True
        else:
            out["weight"] = value
            out["explicit"] = unit == "kg"
            if unit == "" and equipment in SINGLE_WEIGHT_EQUIPMENT:
                out["unitless"] = value
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
    """回傳 ((動作名, 變化備註), 剩下的文字)；對不上回傳 (None, None)"""
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
    """解析一行動作。回傳 ("ok", [entry...]) 或 ("unmatched", 原因)。

    entry 會帶 _unitless / _explicit / _raw 給 resolve_units 使用，輸出前移除。
    """
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

    p = parse_body(name, rest, line, review)
    notes = ([variant] if variant else []) + p["notes"]
    e = entry(name, p["weight"], p["sets"], p["reps"], p["isMax"],
              p["incline"], p["speed"], p["minutes"], " ".join(notes))
    e["_unitless"], e["_explicit"], e["_raw"] = p["unitless"], p["explicit"], line
    return "ok", [e]


def resolve_units(entries):
    """啞鈴／壺鈴沒寫單位的數字：比同動作有明確單位的紀錄大很多，就當成 lbs。

    參考值 = 同動作有寫 kg 或 lbs 的紀錄中最重的（換算成 kg）。
    - 有參考值：數字 > 參考值 × 1.5 → lbs
    - 沒有參考值：數字 > 20 → lbs
    回傳審查清單 [(日期, 動作, 原文, 目前存的值, 建議)]。
    """
    reference = {}
    for e in entries:
        if e.get("_explicit") and e["weightKg"] is not None:
            reference[e["exercise"]] = max(reference.get(e["exercise"], 0), e["weightKg"])

    review = []
    for e in entries:
        value = e.get("_unitless")
        if value is None:
            continue
        ref = reference.get(e["exercise"])
        limit = ref * UNITLESS_LBS_RATIO if ref else UNITLESS_LBS_THRESHOLD
        basis = f"參考：同動作有寫單位的最大值 {fmt(ref)} kg" if ref else "沒有參考紀錄，以 20 為界"
        if value > limit:
            kg = round(value * KG_PER_LB, 2)
            e["weightKg"] = kg
            e["note"] = " ".join(filter(None, [e["note"], f"{fmt(value)}lbs"]))
            decision = f"改成 lbs：{fmt(value)} lbs = {kg} kg（{basis}，上限 {fmt(round(limit, 2))}）"
        else:
            decision = f"維持 kg（{basis}，未超過 {fmt(round(limit, 2))}）"
        review.append((e["date"][:10], e["exercise"], e["_raw"], e["weightKg"], decision))
    return review


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

    unit_review = resolve_units(entries)
    for e in entries:
        for key in ("_unitless", "_explicit", "_raw"):
            e.pop(key, None)
    return entries, body_weights, unmatched, review, unit_review


def exercise_id(name):
    return str(uuid.uuid5(ID_NAMESPACE, name)).upper()


def main():
    entries, body_weights, unmatched, review, unit_review = parse_log(LOG.read_text(encoding="utf-8"))

    for e in entries:
        e["exerciseId"] = exercise_id(e.pop("exercise"))

    seed = dict(
        version=2,
        exercises=[dict(id=exercise_id(e["name"]), name=e["name"], category=e["category"], tags=e["tags"],
                        aliases=e["aliases"], englishName="", equipment=e["equipment"], logType=e["logType"],
                        note="", isArchived=e["archived"])
                   for e in EXERCISES],
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

    with UNIT_REVIEW.open("w", encoding="utf-8") as f:
        f.write("# 啞鈴／壺鈴沒寫單位的紀錄（啞鈴、壺鈴一律記單顆重量）\n")
        f.write("# 日期\t動作\t原文\t目前存的值 (kg)\t判斷\n")
        for date, name, raw, kg, decision in unit_review:
            f.write(f"{date}\t{name}\t{raw}\t{kg}\t{decision}\n")
        f.write("\n# 手動整理的特例\n")
        f.write("2026-07-10\t羅馬尼亞式硬舉\t羅馬尼亞蹲 5x5 （啞鈴 30一邊）\t13.61\t改成 lbs：30 lbs = 13.61 kg\n")

    used = {e["exerciseId"] for e in entries}
    converted = sum(1 for r in unit_review if r[4].startswith("改成"))
    print(f"entries={len(entries)} bodyWeights={len(body_weights)} unmatched={len(unmatched)} "
          f"review={len(review)} unitReview={len(unit_review)} (改成 lbs {converted})")
    print("從沒做過的動作：", [e["name"] for e in EXERCISES if exercise_id(e["name"]) not in used])


if __name__ == "__main__":
    main()
