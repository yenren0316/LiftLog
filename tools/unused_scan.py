#!/usr/bin/env python3
"""CHANGE_11 §3：找沒有被引用的程式（Periphery 的簡化版，沒有安裝 Periphery 時用）。

列出 App、Shared、小工具三個資料夾裡宣告的型別、函式、屬性和 enum case，
計算名稱在這三個資料夾（不含宣告那一行）出現幾次。0 次的是候選，要逐一人工確認：
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


if __name__ == "__main__":
    main()
