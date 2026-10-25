// 把六張概念圖排成一張總覽：左邊 300 px 大圖（套 iOS 圓角），右邊是實際 60 px 的縮圖
// 用法：swift overview.swift <資料夾> <輸出.png>
import AppKit

let dir = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let concepts = ["A", "B", "C"], palettes = ["graphite", "midnight"]
let big: CGFloat = 300, small: CGFloat = 60, pad: CGFloat = 40, labelHeight: CGFloat = 44
let width = pad + 2 * (big + pad) + 2 * (small + pad)
let height = pad + CGFloat(concepts.count) * (big + labelHeight + pad)

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

let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 26), .foregroundColor: NSColor.white]
for (row, concept) in concepts.enumerated() {
    // AppKit 的座標原點在左下
    let top = height - pad - CGFloat(row) * (big + labelHeight + pad)
    ("概念 \(concept)" as NSString).draw(at: NSPoint(x: pad, y: top - 32), withAttributes: attributes)
    for (col, palette) in palettes.enumerated() {
        guard let image = NSImage(contentsOf: dir.appendingPathComponent("\(concept)_\(palette).png")) else { continue }
        let y = top - labelHeight - big
        draw(image, in: NSRect(x: pad + CGFloat(col) * (big + pad), y: y, width: big, height: big))
        draw(image, in: NSRect(x: pad + 2 * (big + pad) + CGFloat(col) * (small + pad), y: y, width: small, height: small))
    }
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: output)
