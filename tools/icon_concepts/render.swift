// 用 macOS 內建的 AppKit 把 SVG 轉成 PNG（不需要安裝其他工具）
// 用法：swift render.swift input.svg output.png [size] [opaque]
// opaque：輸出沒有 alpha 通道的 PNG（App icon 的一般外觀要不透明）
import AppKit

let args = CommandLine.arguments
guard args.count >= 3, let image = NSImage(contentsOf: URL(fileURLWithPath: args[1])) else {
    FileHandle.standardError.write("無法讀取 SVG\n".data(using: .utf8)!)
    exit(1)
}
let size = args.count > 3 ? Int(args[3]) ?? 1024 : 1024
let alpha: CGImageAlphaInfo = args.count > 4 && args[4] == "opaque" ? .noneSkipLast : .premultipliedLast
guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue)
else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
guard let output = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, "public.png" as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
