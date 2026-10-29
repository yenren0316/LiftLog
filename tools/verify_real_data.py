#!/usr/bin/env python3
"""CHANGE_11 §9、CHANGE_13 R1、CHANGE_14 R1：用備份 JSON 獨立驗算統計，和 App 的 -dumpStats 比對。

只依 SPEC.md 的文字規則自己算一次，不呼叫、不複製 App 的程式碼。
備份含個人資料：所有輸出只能放在 tools/fixtures/ 底下（已在 .gitignore），終端機只印「一致／不一致」。

用法：
  python3 tools/verify_real_data.py times  --backup tools/fixtures/real_backup.json
      印出兩個驗證時間點（備份最後一筆訓練的隔天中午、之後第一個週一 00:05），寫到 tools/fixtures/times.json
  python3 tools/verify_real_data.py compare --backup tools/fixtures/real_backup.json --now <ISO> --app tools/fixtures/app_X.json
      腳本自己算的結果寫到 tools/fixtures/script_<now>.json，和 App 的輸出逐項比對
  加 --details 時，不一致的項目另外印出兩邊的值（只給本機除錯用，不要貼進報告）
"""

import argparse
import json
import math
import sys
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

FIXTURES = Path(__file__).resolve().parent / "fixtures"

# SPEC「動作分類」：9 類，依此順序
CATEGORIES = ["kneeDominant", "hipDominant", "horizontalPush", "horizontalPull",
              "verticalPush", "verticalPull", "core", "accessory", "cardio"]
LOWER = {"kneeDominant", "hipDominant"}
UPPER = {"horizontalPush", "horizontalPull", "verticalPush", "verticalPull"}
OTHER = {"core", "accessory"}
PUSH = {"horizontalPush", "verticalPush"}
PULL = {"horizontalPull", "verticalPull"}
# CHANGE_04 刪除的三類，讀舊資料時當成核心
LEGACY_CORE = {"rotation", "loadedCarry", "unusualPosture"}

# SPEC 1-1：日型順序 ME 下肢 → ME 上肢 → DE 下肢 → DE 上肢 → ME 下肢
DAY_TYPES = ["meLower", "meUpper", "deLower", "deUpper"]

# SPEC 7：強度換算表的進位，槓鈴 2.5 kg，其他 1 kg（設定頁的預設值；備份沒有設定時用預設）
BARBELL_STEP_KG = 2.5
OTHER_STEP_KG = 1.0


def parse_time(text):
    return datetime.fromisoformat(text.replace("Z", "+00:00"))


class Data:
    def __init__(self, backup, tz):
        self.tz = tz
        self.exercises = {}
        for e in backup["exercises"]:
            category = e["category"]
            if category in LEGACY_CORE:
                category = "core"
            self.exercises[e["id"]] = {
                "id": e["id"], "name": e["name"], "category": category, "tags": set(e.get("tags", [])),
                "archived": bool(e.get("isArchived", False)), "equipment": e.get("equipment"),
                "me": e.get("meRotation"), "de": e.get("deRotation"),
            }
        # SPEC「推導規則」：統計只算已結束的訓練、已完成的組；動作不存在的項目略過
        self.sessions = []
        for s in backup["sessions"]:
            if not s.get("endedAt"):
                continue
            items = []
            for it in s["items"]:
                ex = self.exercises.get(it.get("exerciseId"))
                if ex is None:
                    continue
                sets = [st for st in sorted(it["sets"], key=lambda x: x.get("order", 0)) if st.get("isCompleted")]
                items.append({"exercise": ex, "role": it.get("role"), "order": it.get("order", 0), "sets": sets})
            items.sort(key=lambda x: x["order"])
            self.sessions.append({"date": parse_time(s["startedAt"]).astimezone(tz), "dayType": s.get("dayType"),
                                  "items": items})
        # 由新到舊
        self.sessions.sort(key=lambda x: x["date"], reverse=True)

    def local_day(self, dt):
        return dt.astimezone(self.tz).date()


def start_of_day(day, tz):
    return datetime(day.year, day.month, day.day, tzinfo=tz)


def days_between(earlier, later):
    """以日曆日算：昨天晚上做的，今天早上看就是 1 天"""
    return (later - earlier).days


def working(st):
    """正式組和 MAX 組（熱身不算）"""
    return st.get("kind") != "warmup"


def set_count(data, start, end, categories):
    """SPEC 1：組數只算已結束訓練中打勾的正式組和 MAX 組"""
    n = 0
    for s in data.sessions:
        if start <= s["date"] < end:
            for it in s["items"]:
                if it["exercise"]["category"] in categories:
                    n += sum(1 for st in it["sets"] if working(st))
    return n


def cardio_minutes(data, start, end):
    """跑步機（有氧分類）的分鐘"""
    total = 0.0
    for s in data.sessions:
        if start <= s["date"] < end:
            for it in s["items"]:
                if it["exercise"]["category"] == "cardio":
                    total += sum(st.get("minutes") or 0 for st in it["sets"])
    return total


def counted_days(data, cardio_only_counts=False):
    """SPEC「訓練次數的規則」：有完成組的已結束訓練，以天為單位；「只有有氧的訓練也算」關閉時，
    當天只有有氧動作的完成組就不算"""
    days = {}
    for s in data.sessions:
        day = data.local_day(s["date"])
        for it in s["items"]:
            if not it["sets"]:
                continue
            if it["exercise"]["category"] != "cardio" or cardio_only_counts:
                days[day] = True
            else:
                days.setdefault(day, False)
    return {d for d, counts in days.items() if counts}


def period(data, start, end, days):
    lower = set_count(data, start, end, LOWER)
    upper = set_count(data, start, end, UPPER)
    other = set_count(data, start, end, OTHER)
    return {
        "days": sum(1 for d in days if start <= start_of_day(d, data.tz) < end),
        "sets": lower + upper + other, "lower": lower, "upper": upper, "other": other,
        "cardioMinutes": round(cardio_minutes(data, start, end), 6),
    }


def week_start(day):
    """一週從週一開始"""
    return day - timedelta(days=day.weekday())


def category_last_dates(data):
    """CHANGE_13 §2-2：每個分類最近一次完成組的日期（任何動作，含封存）"""
    last = {}
    for s in data.sessions:  # 由新到舊
        for it in s["items"]:
            c = it["exercise"]["category"]
            if it["sets"] and c not in last:
                last[c] = s["date"]
    return last


def session_region(s):
    """SPEC「部位推算」：只看上肢和下肢分類的動作（有完成組的）；都沒有時是「有氧與其他」；沒有完成組的訓練不算"""
    categories = [it["exercise"]["category"] for it in s["items"] if it["sets"]]
    if not categories:
        return None
    lower = any(c in LOWER for c in categories)
    upper = any(c in UPPER for c in categories)
    return "full" if lower and upper else "lower" if lower else "upper" if upper else "cardio"


def day_regions(data):
    """同一天多次訓練合併：下肢＋上肢 = 全身，有氧不影響有重訓的日子"""
    regions = {}
    for s in data.sessions:
        r = session_region(s)
        if r is not None:
            regions.setdefault(data.local_day(s["date"]), []).append(r)
    merged = {}
    for day, rs in regions.items():
        lower = any(r in ("lower", "full") for r in rs)
        upper = any(r in ("upper", "full") for r in rs)
        merged[day] = "full" if lower and upper else "lower" if lower else "upper" if upper else "cardio"
    return merged


# CHANGE_13 §2-2：提醒只看下肢推、下肢拉和四個上肢分類，超過 14 天
REMINDER_CATEGORIES = [c for c in CATEGORIES if c in LOWER or c in UPPER]
STALE_DAYS = 14


def rotation_pool(data, day_type):
    """SPEC 1-1：主項格的候選是該日型的輪替表（ME 或 DE 順序），下肢日用下肢分類、上肢日用上肢分類；只列使用中的動作"""
    key = "me" if day_type.startswith("me") else "de"
    categories = LOWER if day_type.endswith("Lower") else UPPER
    pool = [e for e in data.exercises.values()
            if e[key] is not None and e["category"] in categories and not e["archived"]]
    return sorted(pool, key=lambda e: e[key])


def last_main(data, day_type):
    """同日型最近一次訓練中角色為 ME 主項或 DE 主項的動作"""
    for s in data.sessions:
        if s["dayType"] != day_type:
            continue
        for it in s["items"]:
            if it["role"] in ("maxEffort", "dynamicEffort") and it["sets"]:
                return it["exercise"]
    return None


def next_main(data, day_type):
    """從上次主項的下一個開始照順序，上次用的排最後；沒有紀錄或不在輪替表裡時從 1 開始"""
    pool = rotation_pool(data, day_type)
    if not pool:
        return None
    last = last_main(data, day_type)
    ids = [e["id"] for e in pool]
    if last is None or last["id"] not in ids:
        return pool[0]
    i = ids.index(last["id"])
    return pool[(i + 1) % len(pool)]


def epley(weight, reps):
    return weight * (1 + reps / 30)


def estimated_1rm(data, exercise_id, now):
    """SPEC 7：估算 1RM（Epley，只算 1–10 下的正式組與 MAX 組；取最近 90 天最大值，90 天內沒有則取全期）"""
    cutoff = now - timedelta(days=90)
    recent, overall = None, None
    for s in data.sessions:
        if s["date"] > now:
            continue
        for it in s["items"]:
            if it["exercise"]["id"] != exercise_id:
                continue
            for st in it["sets"]:
                w, r = st.get("weightKg"), st.get("reps")
                if not working(st) or w is None or r is None or not (1 <= r <= 10):
                    continue
                v = epley(w, r)
                overall = v if overall is None else max(overall, v)
                if s["date"] >= cutoff:
                    recent = v if recent is None else max(recent, v)
    if recent is not None:
        return recent, False
    return overall, overall is not None


def round_half_away(x):
    return math.floor(x + 0.5) if x >= 0 else -math.floor(-x + 0.5)


def calendar_weeks(screen_width):
    """CHANGE_14 §1：點點日曆的週數＝卡片裡放得下的週數（格子 14 pt、間距 3 pt），至少 12 週；
    卡片裡的寬度是螢幕寬度扣掉頁面和卡片的左右邊距（各 16 pt）"""
    width, cell, gap = screen_width - 64, 14, 3
    return max(12, int((width + gap) // (cell + gap)))


def compute(data, now, screen_width=402):
    tz = data.tz
    today = now.astimezone(tz).date()
    tomorrow = start_of_day(today + timedelta(days=1), tz)
    days = counted_days(data)

    # 本週：週一 0 點到明天 0 點；上週同期：往前 7 天
    this_start = start_of_day(week_start(today), tz)
    last_start = start_of_day(week_start(today) - timedelta(days=7), tz)
    last_end = start_of_day(today + timedelta(days=1) - timedelta(days=7), tz)

    # 近 30 天：含今天的 30 個日曆日
    r_start = start_of_day(today - timedelta(days=29), tz)
    recent_sets = {c: set_count(data, r_start, tomorrow, {c}) for c in CATEGORIES}
    recent_sessions = [s for s in data.sessions if r_start <= s["date"] < tomorrow]

    def sessions_with(tag):
        return sum(1 for s in recent_sessions
                   if any(tag in it["exercise"]["tags"] and it["sets"] for it in s["items"]))

    # 輪替狀態：上次（該日型、有完成組的已結束訓練）、幾天前、上次主項、下次主項
    rotation = {}
    for dt in DAY_TYPES:
        last = next((s for s in data.sessions if s["dayType"] == dt and any(it["sets"] for it in s["items"])), None)
        lm = None
        if last is not None:
            lm = next((it["exercise"]["name"] for it in last["items"]
                       if it["role"] in ("maxEffort", "dynamicEffort") and it["sets"]), None)
        nm = next_main(data, dt)
        rotation[dt] = {
            "lastDate": data.local_day(last["date"]).isoformat() if last else None,
            "daysAgo": days_between(data.local_day(last["date"]), today) if last else None,
            "lastMain": lm,
            "nextMain": nm["name"] if nm else None,
        }

    # 「下一次」的日型：最近一次有日型的訓練的下一個；都沒有時 ME 下肢
    latest_typed = next((s for s in data.sessions if s["dayType"] in DAY_TYPES), None)
    next_day_type = DAY_TYPES[(DAY_TYPES.index(latest_typed["dayType"]) + 1) % 4] if latest_typed else "meLower"

    # 每個「主」動作：估算 1RM 和 60% 建議重量（強度換算表的進位）
    main_lifts = {}
    for e in data.exercises.values():
        if "main" not in e["tags"]:
            continue
        value, all_time = estimated_1rm(data, e["id"], now)
        step = BARBELL_STEP_KG if e["equipment"] == "barbell" else OTHER_STEP_KG
        main_lifts[e["name"]] = {
            "estimated1RM": round(value, 3) if value is not None else None,
            "isAllTime": all_time,
            "speed60Kg": round_half_away(value * 0.6 / step) * step if value is not None else None,
        }

    # 「本週」卡（CHANGE_13 §2-2）：天數和組數、輪替膠囊、提醒；
    # 點點日曆（CHANGE_14 §1）：最右邊一欄是本週，每一天的部位（今天之後為 null）
    week = period(data, this_start, tomorrow, days)
    regions = day_regions(data)
    weeks = calendar_weeks(screen_width)
    first_monday = week_start(today) - timedelta(days=7 * (weeks - 1))
    calendar = {}
    for i in range(7 * weeks):
        d = first_monday + timedelta(days=i)
        calendar[d.isoformat()] = None if d > today else regions.get(d)
    nxt = DAY_TYPES.index(next_day_type)
    capsules = {dt: "done" if i < nxt else "next" if i == nxt else "upcoming" for i, dt in enumerate(DAY_TYPES)}
    last = category_last_dates(data)
    stale = [(max(0, days_between(data.local_day(last[c]), today)), -i, c)
             for i, c in enumerate(REMINDER_CATEGORIES) if c in last]
    stale = [x for x in stale if x[0] > STALE_DAYS]
    reminder = None
    if stale:
        top = max(stale)
        reminder = {"category": top[2], "days": top[0]}

    return {
        "thisWeek": week,
        "lastWeek": period(data, last_start, last_end, days),
        "recent30": {"sets": recent_sets,
                     "push": sum(recent_sets[c] for c in PUSH), "pull": sum(recent_sets[c] for c in PULL),
                     "unilateralSessions": sessions_with("unilateral"),
                     "explosiveSessions": sessions_with("explosive")},
        "rotation": rotation,
        "nextDayType": next_day_type,
        "mainLifts": main_lifts,
        "weekCard": {"days": week["days"], "sets": week["sets"], "calendarWeeks": weeks, "calendar": calendar,
                     "rotation": capsules, "reminder": reminder},
    }


def flatten(value, prefix=""):
    """{"a": {"b": 1}} → {"a.b": 1}"""
    if isinstance(value, dict):
        out = {}
        for k, v in value.items():
            out.update(flatten(v, f"{prefix}.{k}" if prefix else str(k)))
        return out
    return {prefix: value}


def same(a, b):
    if isinstance(a, float) or isinstance(b, float):
        if a is None or b is None:
            return a is b
        return abs(a - b) < 1e-6
    return a == b


# 比對表的分組（報告用的名稱）；鍵的開頭對應到一組
GROUPS = [
    ("thisWeek.days", "本週天數"), ("thisWeek.sets", "本週組數"), ("thisWeek.lower", "本週下肢組數"),
    ("thisWeek.upper", "本週上肢組數"), ("thisWeek.other", "本週其他組數"), ("thisWeek.cardioMinutes", "本週有氧分鐘"),
    ("lastWeek.", "上週同期"),
    ("recent30.sets.", "平衡卡 9 個分類的組數（近 30 天）"), ("recent30.push", "推拉比"), ("recent30.pull", "推拉比"),
    ("recent30.unilateralSessions", "單邊次數"), ("recent30.explosiveSessions", "爆發次數"),
    ("rotation.", "日型（上次日期、幾天前、上次主項、下次主項）"), ("nextDayType", "「下一次」的日型"),
    ("mainLifts.", "主動作的估算 1RM 與 60% 建議重量"),
    ("weekCard.days", "本週卡的天數"), ("weekCard.sets", "本週卡的組數"),
    ("weekCard.calendarWeeks", "日曆的週數"), ("weekCard.calendar.", "日曆顯示的每一天的部位"),
    ("weekCard.rotation.", "本週卡的輪替膠囊"),
    ("weekCard.reminder", "本週卡的提醒（分類和天數）"),
]


def group_of(key):
    for prefix, name in GROUPS:
        if key.startswith(prefix):
            return name
    return key


def compare(script, app, details):
    s, a = flatten(script), flatten(app)
    results = {}
    mismatches = []
    for key in sorted(set(s) | set(a)):
        ok = key in s and key in a and same(s[key], a[key])
        name = group_of(key)
        results.setdefault(name, True)
        results[name] &= ok
        if not ok:
            mismatches.append(key)
    for _, name in GROUPS:
        if name in results:
            print(f"{'一致' if results[name] else '不一致'}\t{name}")
            results.pop(name)
    if details:
        for key in mismatches:
            print(f"  {key}: script={s.get(key, '（沒有）')} app={a.get(key, '（沒有）')}", file=sys.stderr)
    return not mismatches


def check_output(path):
    path = Path(path).resolve()
    if FIXTURES not in path.parents:
        sys.exit(f"輸出只能放在 {FIXTURES} 底下：{path}")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["times", "compare"])
    parser.add_argument("--backup", default=str(FIXTURES / "real_backup.json"))
    parser.add_argument("--tz", default="Asia/Taipei", help="模擬器的時區")
    parser.add_argument("--now", help="ISO 8601，例如 2026-01-05T00:05:00+08:00")
    parser.add_argument("--app", help="App 的 -dumpStats 輸出")
    parser.add_argument("--width", type=float, default=402, help="模擬器的螢幕寬度（pt），iPhone 17 Pro 是 402")
    parser.add_argument("--details", action="store_true")
    args = parser.parse_args()

    tz = ZoneInfo(args.tz)
    data = Data(json.loads(Path(args.backup).read_text()), tz)

    if args.command == "times":
        last = data.local_day(data.sessions[0]["date"])
        noon = datetime(last.year, last.month, last.day, 12, tzinfo=tz) + timedelta(days=1)
        monday = noon.date() + timedelta(days=(7 - noon.weekday()) % 7 or 7)
        times = {"nextDayNoon": noon.isoformat(), "firstMonday": datetime(monday.year, monday.month, monday.day, 0, 5, tzinfo=tz).isoformat()}
        out = check_output(FIXTURES / "times.json")
        out.write_text(json.dumps(times, indent=2))
        print(f"兩個時間點寫到 {out.relative_to(FIXTURES.parent.parent)}")
        return

    now = datetime.fromisoformat(args.now)
    result = compute(data, now, args.width)
    out = check_output(FIXTURES / f"script_{now.strftime('%Y%m%dT%H%M')}.json")
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    app = json.loads(Path(check_output(args.app)).read_text())
    ok = compare(result, app, args.details)
    print("全部一致" if ok else "有不一致")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
