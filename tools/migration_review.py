#!/usr/bin/env python3
"""用和 App 相同的規則，對 seed.json 預覽 CHANGE_07 的資料遷移，輸出檢查清單。

- assist_review.txt：輔助引體向上在 2026-10-26 以前、重量為正數的組（舊的輔助量）轉成負數（A-1）。
  雙槓撐仍是 assisted 型，不轉換，只列出筆數。
- custom_titles.txt：訓練名稱遷移時視為自訂、保留不動的訓練（C-5）。

App 實際執行時處理的是手機上的資料庫（seed 匯入之後在 App 裡記的紀錄也會一起處理），
規則見 LiftLog/Logic/DataMigrations.swift。
用法：python3 tools/migration_review.py
"""
import json
from collections import defaultdict
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEED = ROOT / "LiftLog" / "Data" / "seed.json"
CUTOFF = "2026-10-26"


def load():
    seed = json.loads(SEED.read_text(encoding="utf-8"))
    names = {e["id"]: e["name"] for e in seed["exercises"]}
    return seed, names


def assist_review(seed, names):
    lines = [
        "# 輔助重量轉負數（CHANGE_07 A-1）",
        f"# 規則：輔助引體向上、那次訓練在 {CUTOFF} 以前、重量為正數 → 改成負數；0（自重）和負數不動。",
        "# 來源：repo 裡的 seed.json。手機上 seed 之後在 App 裡記的紀錄，遷移時也會用同樣的規則處理，",
        "#       實際結果要在手機上確認（遷移前的完整備份在「設定 → 備份與還原 → 自動備份」）。",
        "# 日期\t組數\t原值 (kg)\t轉換後 (kg)",
    ]
    converted = sets_total = 0
    dips = 0
    for entry in sorted(seed["entries"], key=lambda e: e["date"]):
        name = names.get(entry["exerciseId"])
        weight = entry.get("weightKg")
        count = entry.get("sets") or 1
        if name == "雙槓撐" and weight is not None:
            dips += count
        if name != "輔助引體向上" or weight is None or entry["date"][:10] >= CUTOFF:
            continue
        sets_total += count
        if weight > 0:
            converted += count
            lines.append(f"{entry['date'][:10]}\t{count}\t{weight:g}\t{-weight:g}")
    lines.append("")
    lines.append(f"# 合計：輔助引體向上 {sets_total} 組，其中 {converted} 組轉換（其餘是 0 = 自重，不動）。")
    lines.append(f"# 雙槓撐：仍是 assisted 型（輔助重量，越少越好），{dips} 組不轉換。")
    (ROOT / "tools" / "assist_review.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return converted


def auto_title_parts(title):
    """舊的自動名稱：動作名稱用「＋」串起來，或「A＋B 等 N 項」"""
    if not title:
        return []
    head = title
    if " 等 " in title and title.endswith(" 項"):
        head = title.rsplit(" 等 ", 1)[0]
    return [p.strip() for p in head.split("＋")]


def is_legacy_auto(title, exercise_names):
    if not title:
        return True
    parts = auto_title_parts(title)
    return bool(parts) and all(p in exercise_names for p in parts)


def custom_titles(seed, names):
    """seed 的訓練名稱都是匯入時用動作名稱自動產生的；這裡用和 App 相同的判斷列出會被視為自訂的"""
    exercise_names = set()
    for e in seed["exercises"]:
        exercise_names.add(e["name"])
        exercise_names.update(e.get("aliases", []))
    by_day = defaultdict(list)
    for entry in seed["entries"]:
        by_day[entry["date"][:10]].append(names.get(entry["exerciseId"], ""))
    custom = []
    total = 0
    for day, items in sorted(by_day.items()):
        total += 1
        ordered = list(dict.fromkeys(items))
        title = "＋".join(ordered) if len(ordered) <= 3 else "＋".join(ordered[:2]) + f" 等 {len(ordered)} 項"
        if not is_legacy_auto(title, exercise_names):
            custom.append((day, title))
    lines = [
        "# 訓練名稱改成訓練目的（CHANGE_07 C-5）：視為自訂、保留不動的訓練",
        "# 規則：名稱是空的、動作名稱用「＋」串起來、或「A＋B 等 N 項」→ 視為自動名稱，重新產生；其他視為自訂。",
        "# 來源：repo 裡的 seed.json（seed 的名稱都是匯入時自動產生的）。手機上自己改過的名稱會被保留，",
        "#       實際清單要在手機上確認（遷移前的完整備份在「設定 → 備份與還原 → 自動備份」）。",
        "# 日期\t名稱",
    ]
    lines += [f"{day}\t{title}" for day, title in custom]
    lines.append("")
    lines.append(f"# 合計：{total} 次訓練，{len(custom)} 次視為自訂，{total - len(custom)} 次重新產生名稱。")
    (ROOT / "tools" / "custom_titles.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return len(custom)


def main():
    seed, names = load()
    converted = assist_review(seed, names)
    custom = custom_titles(seed, names)
    print(f"assist_review.txt: {converted} 組轉換；custom_titles.txt: {custom} 次自訂")


if __name__ == "__main__":
    main()
