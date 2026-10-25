#!/usr/bin/env python3
"""啞鈴（和槓鈴）icon 的各種版本，各兩種配色。

用法：python3 tools/icon_concepts/make_dumbbell.py
輸出：dumbbell/ 資料夾裡每個版本的 SVG 與 1024×1024 PNG，以及 dumbbell/overview.png（含 60 px 縮圖）。
SVG 轉 PNG 用 render.swift，總覽用 grid.swift（都只用 macOS 內建的 AppKit）。
"""
import json
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "dumbbell"

PALETTES = {
    "graphite": dict(title="石墨橙底", bg="#111214", accent="#FF8A3D", light="#F3F3F4"),
    "midnight": dict(title="午夜藍底", bg="#0B1220", accent="#4C7DF0", light="#E8EDF6"),
}
ROUND = 'stroke-linecap="round" stroke-linejoin="round" fill="none"'

# 啞鈴全部由圓角矩形組成，以 (0, 0) 為中心水平擺放：(部位, x, y, 寬, 高, 圓角)；畫的順序由下往上
DUMBBELL = [
    ("handle", -160, -32, 320, 64, 16),
    ("stub", 290, -36, 46, 72, 16), ("stub", -336, -36, 46, 72, 16),
    ("outer", 230, -118, 76, 236, 26), ("outer", -306, -118, 76, 236, 26),
    ("inner", 150, -170, 92, 340, 34), ("inner", -242, -170, 92, 340, 34),
]
CHUNKY = [
    ("handle", -150, -44, 300, 88, 24),
    ("inner", 120, -190, 180, 380, 70), ("inner", -300, -190, 180, 380, 70),
]
BARBELL = [
    ("handle", -430, -22, 860, 44, 22),
    ("stub", 340, -30, 90, 60, 18), ("stub", -430, -30, 90, 60, 18),
    ("outer", 296, -150, 44, 300, 16), ("outer", -340, -150, 44, 300, 16),
    ("inner", 236, -220, 64, 440, 22), ("inner", -300, -220, 64, 440, 22),
    ("stub", 206, -48, 34, 96, 10), ("stub", -240, -48, 34, 96, 10),
]


def shapes(parts, fill, stroke=None, width=0):
    """fill 可以是單一顏色或 {部位: 顏色}；stroke 用在線條版與交叉時的外框"""
    out = []
    for kind, x, y, w, h, rx in parts:
        color = fill[kind] if isinstance(fill, dict) else fill
        line = f' stroke="{stroke}" stroke-width="{width}" stroke-linejoin="round"' if stroke else ""
        out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{color}"{line}/>')
    return "".join(out)


def place(body, angle=0, scale=1.0, x=512, y=512):
    return f'<g transform="translate({x} {y}) rotate({angle}) scale({scale})">{body}</g>'


def check(cx, cy, c, r=114):
    """右下角的打勾徽章，外圈用底色和主圖隔開"""
    return (f'<circle cx="{cx}" cy="{cy}" r="{r + 32}" fill="{c["bg"]}"/>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{c["light"]}"/>'
            f'<path d="M {cx - 52} {cy + 2} L {cx - 14} {cy + 40} L {cx + 54} {cy - 34}" '
            f'stroke="{c["bg"]}" stroke-width="40" {ROUND}/>')


def v_flat(c):
    """水平擺放的啞鈴"""
    return c["bg"], place(shapes(DUMBBELL, c["accent"]), scale=1.12)


def v_diagonal(c):
    """斜放 45°，比較能填滿方形"""
    return c["bg"], place(shapes(DUMBBELL, c["accent"]), angle=-45, scale=1.08)


def v_chunky(c):
    """粗短的啞鈴：每邊只有一片大鈴片，縮小後仍然很粗"""
    return c["bg"], place(shapes(CHUNKY, c["accent"]), angle=-45, scale=1.08)


def v_outline(c):
    """線條版：每個部位只畫外框"""
    return c["bg"], place(shapes(DUMBBELL, c["bg"], stroke=c["accent"], width=34), angle=-45, scale=1.0)


def v_twotone(c):
    """雙色：亮色鈴片、淺色握把"""
    fill = dict(handle=c["light"], stub=c["accent"], outer=c["accent"], inner=c["accent"])
    return c["bg"], place(shapes(DUMBBELL, fill), angle=-45, scale=1.08)


def v_rise(c):
    """下方一支水平啞鈴，上方一條往右上升的折線"""
    line = (f'<path d="M 236 470 L 396 330 L 520 410 L 764 196" stroke="{c["light"]}" stroke-width="56" {ROUND}/>'
            f'<path d="M 668 196 L 768 192 L 764 292" stroke="{c["light"]}" stroke-width="56" {ROUND}/>')
    return c["bg"], line + place(shapes(DUMBBELL, c["accent"]), scale=0.9, y=700)


def v_badge(c):
    """斜放啞鈴，右下角一個打勾徽章"""
    return c["bg"], place(shapes(DUMBBELL, c["accent"]), angle=-45, scale=1.0, x=480, y=480) + check(744, 744, c)


def v_disc(c):
    """亮色圓章，啞鈴用底色挖空"""
    return c["bg"], (f'<circle cx="512" cy="512" r="372" fill="{c["accent"]}"/>'
                     + place(shapes(DUMBBELL, c["bg"]), angle=-45, scale=0.86))


def v_inverse(c):
    """反色：整片亮色底，深色啞鈴"""
    return c["accent"], place(shapes(DUMBBELL, c["bg"]), angle=-45, scale=1.08)


def v_inverse_light(c):
    """反色淺：整片亮色底，白色啞鈴"""
    return c["accent"], place(shapes(DUMBBELL, c["light"]), angle=-45, scale=1.08)


def v_card(c):
    """紀錄卡：淺色卡片上一支啞鈴，下面三行紀錄"""
    lines = "".join(f'<rect x="352" y="{y}" width="{w}" height="40" rx="20" fill="{c["bg"]}" opacity="0.28"/>'
                    for y, w in [(590, 320), (666, 320), (742, 200)])
    return c["bg"], (f'<rect x="236" y="176" width="552" height="672" rx="88" fill="{c["light"]}"/>'
                     + place(shapes(DUMBBELL, c["accent"]), scale=0.66, y=410) + lines)


def v_barbell(c):
    """槓鈴：長槓兩端各兩片槓片"""
    return c["bg"], place(shapes(BARBELL, c["accent"]), scale=0.96)


VARIANTS = [
    ("01_flat", "水平啞鈴", v_flat),
    ("02_diagonal", "斜放啞鈴", v_diagonal),
    ("03_chunky", "粗短啞鈴", v_chunky),
    ("04_outline", "線條", v_outline),
    ("05_twotone", "雙色", v_twotone),
    ("06_rise", "啞鈴＋上升折線", v_rise),
    ("07_badge", "打勾徽章", v_badge),
    ("08_disc", "圓章", v_disc),
    ("09_inverse", "反色・深色", v_inverse),
    ("10_inverse_light", "反色・白色", v_inverse_light),
    ("11_card", "紀錄卡", v_card),
    ("12_barbell", "槓鈴", v_barbell),
]


def svg(body, bg):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">\n'
            f'  <rect width="1024" height="1024" fill="{bg}"/>\n  {body}\n</svg>\n')


def main():
    OUT.mkdir(exist_ok=True)
    sections = []
    for pal_name, colors in PALETTES.items():
        items = []
        for key, label, draw in VARIANTS:
            bg, body = draw(colors)
            stem = f"{key}_{pal_name}"
            (OUT / f"{stem}.svg").write_text(svg(body, bg), encoding="utf-8")
            subprocess.run(["swift", str(HERE / "render.swift"), str(OUT / f"{stem}.svg"), str(OUT / f"{stem}.png")],
                           check=True)
            items.append(dict(path=str(OUT / f"{stem}.png"), label=f"{int(key[:2])} {label}", short=str(int(key[:2]))))
        sections.append(dict(title=colors["title"], items=items))
    manifest = OUT / "manifest.json"
    manifest.write_text(json.dumps(dict(columns=6, sections=sections), ensure_ascii=False), encoding="utf-8")
    subprocess.run(["swift", str(HERE / "grid.swift"), str(manifest), str(OUT / "overview.png")], check=True)
    manifest.unlink()
    print("done:", len(VARIANTS) * len(PALETTES), "icons")


if __name__ == "__main__":
    main()
