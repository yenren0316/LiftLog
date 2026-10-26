#!/usr/bin/env python3
"""把選定的 icon（壺鈴第 1 版：鈴身挖出上升折線，午夜藍）輸出成 App icon 的三種外觀，寫進 AppIcon.appiconset。

- 一般：午夜藍底，沒有 alpha 通道。
- 深色：透明底，系統會墊上自己的深色背景。
- 單色（Tinted）：透明底、白色的灰階圖，系統依使用者選的顏色上色。
深色和單色的折線是真的挖空（透明），不是畫上底色。

用法：python3 tools/icon_concepts/make_appicon.py
"""
import json
import subprocess
import tempfile
from pathlib import Path

from make_kettlebell import PALETTES, kettlebell, rise

HERE = Path(__file__).resolve().parent
ICONSET = HERE.parent.parent / "LiftLog" / "Assets.xcassets" / "AppIcon.appiconset"
COLORS = PALETTES["midnight"]


def svg(body, bg=None):
    background = f'<rect width="1024" height="1024" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
            f'{background}{body}</svg>\n')


def icon(color):
    """壺鈴，鈴身裡的上升折線用 mask 挖空"""
    cut = f'<mask id="cut"><rect width="1024" height="1024" fill="#FFFFFF"/>{rise("#000000")}</mask>'
    return f'<defs>{cut}</defs><g mask="url(#cut)">{kettlebell(color, color)}</g>'


VARIANTS = [
    # (檔名, SVG, 外觀, 是否不透明)
    ("AppIcon.png", svg(icon(COLORS["accent"]), COLORS["bg"]), None, True),
    ("AppIcon-Dark.png", svg(icon(COLORS["accent"])), "dark", False),
    ("AppIcon-Tinted.png", svg(icon("#FFFFFF")), "tinted", False),
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
