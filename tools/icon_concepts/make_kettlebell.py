#!/usr/bin/env python3
"""壺鈴 icon 的延伸版本（概念 B 的各種變化），各兩種配色。

用法：python3 tools/icon_concepts/make_kettlebell.py
輸出：kettlebell/ 資料夾裡每個版本的 SVG 與 1024×1024 PNG，以及 kettlebell/overview.png（含 60 px 縮圖）。
SVG 轉 PNG 用 render.swift，總覽用 grid.swift（都只用 macOS 內建的 AppKit）。
"""
import json
import math
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "kettlebell"

PALETTES = {
    "graphite": dict(title="石墨橙底", bg="#111214", accent="#FF8A3D", light="#F3F3F4"),
    "midnight": dict(title="午夜藍底", bg="#0B1220", accent="#4C7DF0", light="#E8EDF6"),
}

# 壺鈴的基本形狀：提把（粗線）＋鈴身（圓，底部切平）
CX, CY, R, FLAT = 512, 610, 262, 820
HANDLE = "M 352 470 L 352 350 C 352 214, 672 214, 672 350 L 672 470"
RISE = "M 362 712 L 452 622 L 532 672 L 666 520"
RISE_HEAD = "M 594 516 L 672 512 L 668 590"
ROUND = 'stroke-linecap="round" stroke-linejoin="round" fill="none"'


def mix(a, b, t):
    """a 和 b 兩個 #RRGGBB 顏色依比例 t（0 = a、1 = b）混合"""
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02X}" for x, y in zip(ca, cb))


def body_path(cx=CX, cy=CY, r=R, flat=FLAT):
    half = math.sqrt(r * r - (flat - cy) ** 2)
    return f"M {cx - half:.1f} {flat} A {r} {r} 0 1 1 {cx + half:.1f} {flat} Z"


def kettlebell(handle, body, width=84):
    return (f'<path d="{HANDLE}" stroke="{handle}" stroke-width="{width}" {ROUND}/>'
            f'<path d="{body_path()}" fill="{body}"/>')


def rise(color, width=54):
    return (f'<path d="{RISE}" stroke="{color}" stroke-width="{width}" {ROUND}/>'
            f'<path d="{RISE_HEAD}" stroke="{color}" stroke-width="{width}" {ROUND}/>')


def v_rise(c):
    """原版：鈴身裡挖出一條往右上升的折線"""
    return c["bg"], kettlebell(c["accent"], c["accent"]) + rise(c["bg"])


def v_solid(c):
    """純剪影，沒有任何內部圖案"""
    return c["bg"], kettlebell(c["accent"], c["accent"])


def v_outline(c):
    """線條版：提把和鈴身都只畫外框，裡面一條上升折線"""
    handle = "M 352 410 L 352 350 C 352 214, 672 214, 672 350 L 672 410"
    return c["bg"], (f'<path d="{handle}" stroke="{c["accent"]}" stroke-width="64" {ROUND}/>'
                     f'<path d="{body_path()}" stroke="{c["accent"]}" stroke-width="64" {ROUND}/>'
                     + rise(c["accent"], 48))


def v_check(c):
    """鈴身裡挖出一個打勾：今天練完了"""
    return c["bg"], (kettlebell(c["accent"], c["accent"])
                     + f'<path d="M 400 626 L 478 704 L 632 540" stroke="{c["bg"]}" stroke-width="70" {ROUND}/>')


def v_bars(c):
    """鈴身裡挖出三根由低到高的長條：紀錄在進步"""
    bars = "".join(f'<rect x="{x}" y="{760 - h}" width="70" height="{h}" rx="16" fill="{c["bg"]}"/>'
                   for x, h in [(373, 110), (477, 180), (581, 250)])
    return c["bg"], kettlebell(c["accent"], c["accent"]) + bars


def v_pulse(c):
    """鈴身裡挖出一條橫過去的心跳線"""
    line = "M 230 640 L 410 640 L 452 560 L 516 738 L 568 604 L 598 640 L 800 640"
    return c["bg"], kettlebell(c["accent"], c["accent"]) + f'<path d="{line}" stroke="{c["bg"]}" stroke-width="44" {ROUND}/>'


def v_twotone(c):
    """雙色：淺色提把、亮色鈴身，鈴身裡一條上升折線"""
    return c["bg"], kettlebell(c["light"], c["accent"]) + rise(c["bg"])


def v_inverse(c):
    """反色：整片亮色底，深色壺鈴，折線用底色"""
    return c["accent"], kettlebell(c["bg"], c["bg"]) + rise(c["accent"])


def v_inverse_light(c):
    """反色淺：整片亮色底，白色壺鈴，折線用底色"""
    return c["accent"], kettlebell(c["light"], c["light"]) + rise(c["accent"])


def v_badge(c):
    """純剪影壺鈴，右下角一個打勾的圓形徽章（外圈用底色隔開）"""
    bx, by = 708, 744
    return c["bg"], (kettlebell(c["accent"], c["accent"])
                     + f'<circle cx="{bx}" cy="{by}" r="146" fill="{c["bg"]}"/>'
                     + f'<circle cx="{bx}" cy="{by}" r="114" fill="{c["light"]}"/>'
                     + f'<path d="M {bx - 52} {by + 2} L {bx - 14} {by + 40} L {bx + 54} {by - 34}" '
                       f'stroke="{c["bg"]}" stroke-width="40" {ROUND}/>')


VARIANTS = [
    ("01_rise", "上升折線（原版）", v_rise),
    ("02_solid", "純剪影", v_solid),
    ("03_outline", "線條", v_outline),
    ("04_check", "打勾", v_check),
    ("05_bars", "長條圖", v_bars),
    ("06_pulse", "心跳線", v_pulse),
    ("07_twotone", "雙色", v_twotone),
    ("08_inverse", "反色・深色壺鈴", v_inverse),
    ("09_inverse_light", "反色・白色壺鈴", v_inverse_light),
    ("10_badge", "打勾徽章", v_badge),
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
    manifest.write_text(json.dumps(dict(columns=5, sections=sections), ensure_ascii=False), encoding="utf-8")
    subprocess.run(["swift", str(HERE / "grid.swift"), str(manifest), str(OUT / "overview.png")], check=True)
    manifest.unlink()
    print("done:", len(VARIANTS) * len(PALETTES), "icons")


if __name__ == "__main__":
    main()
