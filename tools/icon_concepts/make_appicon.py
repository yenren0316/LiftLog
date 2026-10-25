#!/usr/bin/env python3
"""把選定的 icon（啞鈴第 2 版：斜放啞鈴，午夜藍）輸出成 App icon 的三種外觀，寫進 AppIcon.appiconset。

- 一般：午夜藍底，沒有 alpha 通道。
- 深色：透明底，系統會墊上自己的深色背景。
- 單色（Tinted）：透明底、白色的灰階圖，系統依使用者選的顏色上色。

用法：python3 tools/icon_concepts/make_appicon.py
"""
import json
import subprocess
import tempfile
from pathlib import Path

from make_dumbbell import DUMBBELL, PALETTES, place, shapes

HERE = Path(__file__).resolve().parent
ICONSET = HERE.parent.parent / "LiftLog" / "Assets.xcassets" / "AppIcon.appiconset"
COLORS = PALETTES["midnight"]


def svg(body, bg=None):
    background = f'<rect width="1024" height="1024" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
            f'{background}{body}</svg>\n')


def dumbbell(color):
    return place(shapes(DUMBBELL, color), angle=-45, scale=1.08)


VARIANTS = [
    # (檔名, SVG, 外觀, 是否不透明)
    ("AppIcon.png", svg(dumbbell(COLORS["accent"]), COLORS["bg"]), None, True),
    ("AppIcon-Dark.png", svg(dumbbell(COLORS["accent"])), "dark", False),
    ("AppIcon-Tinted.png", svg(dumbbell("#FFFFFF")), "tinted", False),
]


def main():
    images = []
    with tempfile.TemporaryDirectory() as tmp:
        for filename, content, appearance, opaque in VARIANTS:
            source = Path(tmp) / f"{Path(filename).stem}.svg"
            source.write_text(content, encoding="utf-8")
            command = ["swift", str(HERE / "render.swift"), str(source), str(ICONSET / filename), "1024"]
            subprocess.run(command + (["opaque"] if opaque else []), check=True)
            image = dict(filename=filename, idiom="universal", platform="ios", size="1024x1024")
            if appearance:
                image = dict(appearances=[dict(appearance="luminosity", value=appearance)], **image)
            images.append(image)
    contents = dict(images=images, info=dict(author="xcode", version=1))
    (ICONSET / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")
    print("done:", ", ".join(v[0] for v in VARIANTS))


if __name__ == "__main__":
    main()
