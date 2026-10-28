#!/usr/bin/env python3
"""CHANGE_11 §3：找沒有被引用的程式（Periphery 的簡化版，沒有安裝 Periphery 時用）。

列出 App、Shared、小工具三個資料夾裡宣告的型別、函式、屬性和 enum case，
計算名稱在這三個資料夾（不含宣告那一行）出現幾次。0 次的是候選，要逐一人工確認。
名稱相同的宣告會互相掩護（例如兩個型別都有 finish），所以 static 成員另外檢查「型別.名稱」和同一個檔案裡的引用：
- 系統呼叫的（body、makeBody、perform、Codable 的 init(from:)…）不算；
- 小工具、App Intents、即時動態、DEBUG 參數、反射（rawValue、Codable 的鍵）可能用到的只列出，不刪。
用法：python3 tools/unused_scan.py [--tests]   （--tests：只有測試引用的也列出來）
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_DIRS = ["LiftLog", "Shared", "LiftLogWidgets"]
TEST_DIRS = ["LiftLogTests", "LiftLogUITests"]

DECL = re.compile(
    r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:private|fileprivate|internal|public|static|final|nonisolated|override|mutating|"
    r"lazy|weak|@MainActor)\s+)*(?:func|var|let|struct|enum|class|typealias|case)\s+([A-Za-z_]\w*)")
# 系統或協定要求的名稱
SYSTEM = {"body", "makeBody", "perform", "id", "init", "description", "title", "hash", "encode", "decode", "makeUIView",
          "updateUIView", "makeUIGestureRecognizer", "handleUIGestureRecognizerAction", "effectValue", "animatableData",
          "timeline", "placeholder", "getSnapshot", "getTimeline", "snapshot", "widgetBody", "rawValue", "allCases",
          "CodingKeys", "typeDisplayRepresentation", "caseDisplayRepresentations", "displayRepresentation",
          "appShortcuts", "openAppWhenRun", "supportedModes", "main", "shouldRecognizeSimultaneouslyWith",
          "gestureRecognizer", "didMoveToWindow", "sizeThatFits", "layoutSubviews", "intrinsicContentSize",
          "attributes", "ContentState", "persistentModelID", "hashValue"}


def swift_files(dirs):
    for d in dirs:
        yield from (ROOT / d).rglob("*.swift")


def main():
    include_tests = "--tests" in sys.argv
    app = {p: p.read_text().splitlines() for p in swift_files(APP_DIRS)}
    tests = "\n".join(p.read_text() for p in swift_files(TEST_DIRS))
    decls = []
    for path, lines in app.items():
        for n, line in enumerate(lines, 1):
            m = DECL.match(line)
            if m and m.group(1) not in SYSTEM and not line.strip().startswith("//"):
                decls.append((m.group(1), path, n))
    text = {p: "\n".join(l for i, l in enumerate(lines)) for p, lines in app.items()}
    for name, path, n in sorted(decls, key=lambda d: (str(d[1]), d[2])):
        word = re.compile(rf"(?<![A-Za-z0-9_]){re.escape(name)}(?![A-Za-z0-9_])")
        count = sum(len(word.findall(t)) for t in text.values()) - 1
        if count == 0:
            in_tests = bool(word.search(tests))
            if in_tests and not include_tests:
                continue
            note = "（只有測試引用）" if in_tests else ""
            print(f"{path.relative_to(ROOT)}:{n}\t{name}{note}")


STATIC_DECL = re.compile(r"^\s+(?:@\w+\s+)*(?:(?:private|fileprivate|nonisolated|public|internal)\s+)*static\s+(?:func|var|let)\s+(\w+)")
TYPE_DECL = re.compile(r"^(?:(?:nonisolated|private|fileprivate|public|final|@MainActor|@Observable)\s+)*(?:enum|struct|class|extension)\s+(\w+)")


def static_members():
    """static 成員：整個 App 沒有「型別.名稱」、同一個檔案裡也沒有其他引用（含 .名稱、Self.名稱）"""
    files = {p: p.read_text() for p in swift_files(APP_DIRS)}
    everything = "\n".join(files.values())
    print("# static 成員")
    for path, text in sorted(files.items()):
        owner = None
        lines = text.split("\n")
        for n, line in enumerate(lines):
            if m := TYPE_DECL.match(line):
                owner = m.group(1)
            m = STATIC_DECL.match(line)
            if not m or owner is None:
                continue
            name = m.group(1)
            qualified = len(re.findall(rf"\b{owner}\.{name}\b", everything))
            local = sum(len(re.findall(rf"(?<![\w]){name}\b", other)) for i, other in enumerate(lines) if i != n)
            elsewhere = sum(len(re.findall(rf"\.{name}\b", t)) for p, t in files.items() if p != path)
            if qualified == 0 and local == 0 and elsewhere == 0:
                print(f"{path.relative_to(ROOT)}:{n + 1}\t{owner}.{name}")


if __name__ == "__main__":
    main()
    static_members()
