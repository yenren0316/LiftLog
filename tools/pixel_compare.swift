// 比對多張截圖的像素是否完全相同（CHANGE_08 V1：歷程捲到底部後畫面要穩定）。
// 用法：swift tools/pixel_compare.swift --mask-top <像素> a.png b.png c.png …
// 遮掉最上面 <像素> 列（狀態列）後逐一和第一張比較；全部相同時結束碼 0，否則印出差異並結束碼 1。
import AppKit

var args = Array(CommandLine.arguments.dropFirst())
var maskTop = 0
if let i = args.firstIndex(of: "--mask-top"), i + 1 < args.count {
    maskTop = Int(args[i + 1]) ?? 0
    args.removeSubrange(i...(i + 1))
}
guard args.count >= 2 else {
    print("用法：swift pixel_compare.swift --mask-top <像素> a.png b.png …")
    exit(2)
}

func pixels(_ path: String) -> (width: Int, height: Int, data: [UInt8]) {
    guard let image = NSImage(contentsOfFile: path),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("讀不到 \(path)"); exit(2)
    }
    let w = cg.width, h = cg.height
    var data = [UInt8](repeating: 0, count: w * h * 4)
    let context = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (w, h, data)
}

let base = pixels(args[0])
var allSame = true
for path in args.dropFirst() {
    let other = pixels(path)
    guard other.width == base.width, other.height == base.height else {
        print("\(path)：尺寸不同"); allSame = false; continue
    }
    var diff = 0
    var firstRow = -1
    // CGContext 的第 0 列在記憶體的最上面
    for row in maskTop..<base.height {
        let start = row * base.width * 4
        for i in start..<(start + base.width * 4) where base.data[i] != other.data[i] {
            diff += 1
            if firstRow < 0 { firstRow = row }
        }
    }
    let name = (path as NSString).lastPathComponent
    if diff == 0 {
        print("\(name)：相同")
    } else {
        print("\(name)：\(diff) 個位元組不同（第一個在第 \(firstRow) 列）")
        allSame = false
    }
}
print(allSame ? "結果：全部相同" : "結果：有差異")
exit(allSame ? 0 : 1)
