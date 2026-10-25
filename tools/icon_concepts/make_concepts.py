#!/usr/bin/env python3
"""產生 App icon 的三個概念（A 槓片＋打勾、B 壺鈴＋上升折線、C 推拉轉走四格），各兩種配色。

用法：python3 tools/icon_concepts/make_concepts.py
輸出：每個概念的 SVG 與 1024×1024 PNG，以及 overview.png（含 60 px 縮圖）。
SVG 轉 PNG 用同資料夾的 render.swift，總覽用 overview.swift（都只用 macOS 內建的 AppKit）。
"""
import math
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent

PALETTES = {
    "graphite": dict(bg="#111214", accent="#FF8A3D", light="#F3F3F4"),
    "midnight": dict(bg="#0B1220", accent="#4C7DF0", light="#E8EDF6"),
}


def polar(cx, cy, r, deg):
    a = math.radians(deg)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def concept_a(c):
    """正面的槓片：外環＋中央孔；外環右上留一段缺口，打勾的轉折點接在缺口下緣，長邊從缺口穿出"""
    cx, cy, r, w = 428, 516, 262, 84
    gap_start, gap_end = 35, 285          # 環從右下（30°）順時針畫到右上（285° = -75°）
    a0, a1 = polar(cx, cy, r, gap_start), polar(cx, cy, r, gap_end)
    vertex = a0                           # 打勾的轉折點就是環的下緣端點
    short = (vertex[0] - 100, vertex[1] - 100)
    tip = (vertex[0] + 215, vertex[1] - 420)
    return f"""
  <path d="M {a0[0]:.1f} {a0[1]:.1f} A {r} {r} 0 1 1 {a1[0]:.1f} {a1[1]:.1f}" fill="none" stroke="{c['accent']}"
        stroke-width="{w}" stroke-linecap="round"/>
  <path d="M {short[0]:.1f} {short[1]:.1f} L {vertex[0]:.1f} {vertex[1]:.1f} L {tip[0]:.1f} {tip[1]:.1f}" fill="none"
        stroke="{c['accent']}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>
  <circle cx="{cx}" cy="{cy}" r="80" fill="{c['light']}"/>
  <circle cx="{cx}" cy="{cy}" r="34" fill="{c['bg']}"/>"""


def concept_b(c):
    """壺鈴剪影：提把＋鈴身＋平底；鈴身裡挖出一條往右上升的折線"""
    return f"""
  <path d="M 352 470 L 352 350 C 352 214, 672 214, 672 350 L 672 470" fill="none" stroke="{c['accent']}"
        stroke-width="84" stroke-linecap="round"/>
  <circle cx="512" cy="610" r="262" fill="{c['accent']}"/>
  <rect x="352" y="760" width="320" height="104" rx="30" fill="{c['accent']}"/>
  <path d="M 362 712 L 452 622 L 532 672 L 666 520" fill="none" stroke="{c['bg']}" stroke-width="54"
        stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M 594 516 L 672 512 L 668 590" fill="none" stroke="{c['bg']}" stroke-width="54"
        stroke-linecap="round" stroke-linejoin="round"/>"""


def concept_c(c):
    """四格方塊：推（離開橫桿的箭頭）、拉（回到橫桿的箭頭）、轉（環形箭頭）、走（兩個錯開的腳印）"""
    size, gap, origin = 300, 36, 194
    tiles = []
    cells = [(0, 0, "accent"), (1, 0, "light"), (0, 1, "light"), (1, 1, "accent")]
    for col, row, color in cells:
        x, y = origin + col * (size + gap), origin + row * (size + gap)
        tiles.append(f'<rect x="{x}" y="{y}" width="{size}" height="{size}" rx="64" fill="{c[color]}"/>')

    def at(col, row):
        return origin + col * (size + gap) + size / 2, origin + row * (size + gap) + size / 2

    ink = c["bg"]
    s = 'stroke-linecap="round" stroke-linejoin="round" fill="none"'
    # 推：左邊一條直桿，箭頭往右推出去
    x, y = at(0, 0)
    push = (f'<path d="M {x-92} {y-80} L {x-92} {y+80}" stroke="{ink}" stroke-width="40" {s}/>'
            f'<path d="M {x-40} {y} L {x+86} {y} M {x+30} {y-56} L {x+86} {y} L {x+30} {y+56}" stroke="{ink}" stroke-width="40" {s}/>')
    # 拉：右邊一條直桿，箭頭往右拉回來（箭頭朝向桿子）
    x, y = at(1, 0)
    pull = (f'<path d="M {x+92} {y-80} L {x+92} {y+80}" stroke="{ink}" stroke-width="40" {s}/>'
            f'<path d="M {x-86} {y} L {x+40} {y} M {x-16} {y-56} L {x+40} {y} L {x-16} {y+56}" stroke="{ink}" stroke-width="40" {s}/>')
    # 轉：約 270° 的環形箭頭，箭頭順著行進方向
    x, y = at(0, 1)
    r = 80
    start_deg, end_deg = -50, 220
    a0, a1 = polar(x, y, r, start_deg), polar(x, y, r, end_deg)
    t = math.radians(end_deg)
    direction = (-math.sin(t), math.cos(t))          # 順時針行進的切線方向
    def wing(sign):
        ang = math.atan2(direction[1], direction[0]) + math.pi + sign * math.radians(40)
        return a1[0] + 60 * math.cos(ang), a1[1] + 60 * math.sin(ang)
    w1, w2 = wing(1), wing(-1)
    turn = (f'<path d="M {a0[0]:.1f} {a0[1]:.1f} A {r} {r} 0 1 1 {a1[0]:.1f} {a1[1]:.1f}" stroke="{ink}" stroke-width="40" {s}/>'
            f'<path d="M {w1[0]:.1f} {w1[1]:.1f} L {a1[0]:.1f} {a1[1]:.1f} L {w2[0]:.1f} {w2[1]:.1f}" stroke="{ink}" stroke-width="40" {s}/>')
    # 走：兩個錯開的腳印（橢圓）
    x, y = at(1, 1)
    walk = (f'<ellipse cx="{x-44}" cy="{y+30}" rx="34" ry="62" fill="{ink}"/>'
            f'<ellipse cx="{x+44}" cy="{y-36}" rx="34" ry="62" fill="{ink}"/>')
    return "\n  " + "\n  ".join(tiles + [push, pull, turn, walk])


CONCEPTS = {"A": concept_a, "B": concept_b, "C": concept_c}


def svg(body, bg, transparent=False):
    background = "" if transparent else f'<rect width="1024" height="1024" fill="{bg}"/>'
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
            f'\n  {background}{body}\n</svg>\n')


def render(svg_path, png_path, size=1024):
    subprocess.run(["swift", str(HERE / "render.swift"), str(svg_path), str(png_path), str(size)], check=True)


def main():
    pngs = []
    for name, draw in CONCEPTS.items():
        for pal_name, colors in PALETTES.items():
            stem = f"{name}_{pal_name}"
            (HERE / f"{stem}.svg").write_text(svg(draw(colors), colors["bg"]), encoding="utf-8")
            render(HERE / f"{stem}.svg", HERE / f"{stem}.png")
            pngs.append(stem)

    # 總覽：每個概念兩種配色的大圖（套 iOS 圓角），加上實際 60 px 的縮圖
    subprocess.run(["swift", str(HERE / "overview.swift"), str(HERE), str(HERE / "overview.png")], check=True)
    print("done:", ", ".join(pngs))


if __name__ == "__main__":
    main()
