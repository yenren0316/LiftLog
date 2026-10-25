// 把多個 icon 排成總覽：每種配色一段，上面是 200 px 大圖（套 iOS 圓角）＋名稱，下面一排是實際 60 px 的縮圖
// 用法：swift grid.swift manifest.json 輸出.png
// manifest：{"columns": 5, "sections": [{"title": "...", "items": [{"path": "...", "label": "...", "short": "1"}]}]}
import AppKit

struct Manifest: Decodable {
    struct Item: Decodable { var path: String; var label: String; var short: String }
    struct Section: Decodable { var title: String; var items: [Item] }
    var columns: Int
    var sections: [Section]
}

let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let big: CGFloat = 200, small: CGFloat = 60, pad: CGFloat = 40, gap: CGFloat = 36
let titleHeight: CGFloat = 56, labelHeight: CGFloat = 40, stripHeight: CGFloat = small + 64
let columns = CGFloat(manifest.columns)
let width = 2 * pad + columns * big + (columns - 1) * gap

func rows(_ section: Manifest.Section) -> CGFloat { CGFloat((section.items.count + manifest.columns - 1) / manifest.columns) }
func sectionHeight(_ section: Manifest.Section) -> CGFloat {
    titleHeight + rows(section) * (big + labelHeight) + (rows(section) - 1) * gap / 2 + stripHeight + pad
}
let height = pad + manifest.sections.map(sectionHeight).reduce(0, +)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width), pixelsHigh: Int(height), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()

func draw(_ image: NSImage, in rect: NSRect) {
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.2237, yRadius: rect.width * 0.2237).addClip()
    image.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
}

func text(_ string: String, size: CGFloat, bold: Bool = false, color: NSColor = .white) -> NSAttributedString {
    NSAttributedString(string: string, attributes: [
        .font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
        .foregroundColor: color,
    ])
}

// AppKit 的座標原點在左下，所以從上往下算 top
var top = height - pad
for section in manifest.sections {
    text(section.title, size: 30, bold: true).draw(at: NSPoint(x: pad, y: top - 36))
    top -= titleHeight
    for (index, item) in section.items.enumerated() {
        guard let image = NSImage(contentsOf: URL(fileURLWithPath: item.path)) else { continue }
        let col = CGFloat(index % manifest.columns), row = CGFloat(index / manifest.columns)
        let x = pad + col * (big + gap)
        let y = top - row * (big + labelHeight + gap / 2) - big
        draw(image, in: NSRect(x: x, y: y, width: big, height: big))
        text(item.label, size: 20, color: NSColor(white: 0.85, alpha: 1)).draw(at: NSPoint(x: x, y: y - 30))
    }
    top -= rows(section) * (big + labelHeight) + (rows(section) - 1) * gap / 2
    // 60 px 縮圖：大約是主畫面上的大小
    let stripGap = (width - 2 * pad - CGFloat(section.items.count) * small) / CGFloat(max(section.items.count - 1, 1))
    for (index, item) in section.items.enumerated() {
        guard let image = NSImage(contentsOf: URL(fileURLWithPath: item.path)) else { continue }
        let x = pad + CGFloat(index) * (small + stripGap)
        draw(image, in: NSRect(x: x, y: top - 8 - small, width: small, height: small))
        let label = text(item.short, size: 16, color: NSColor(white: 0.7, alpha: 1))
        label.draw(at: NSPoint(x: x + (small - label.size().width) / 2, y: top - 8 - small - 26))
    }
    top -= stripHeight + pad
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: output)
