// 生成图标：swift tools/make_icon.swift <输出目录>
// 输出：
//   <dir>/AppIcon.iconset/*.png   交给 iconutil 转成 AppIcon.icns（应用图标）
//   <dir>/icon.tiff               输入法菜单栏图标：16pt，含 @1x(16px) 与 @2x(32px)，黑色+透明背景（模板图）
import AppKit

let glyph = "言"

func render(pixels: Int, points: CGFloat? = nil, _ draw: (CGRect) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: pixels, height: pixels).fill()
    draw(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    // size 决定"点"尺寸：菜单栏图标必须是 16pt，否则会被画得过大或模糊
    let side = points ?? CGFloat(pixels)
    rep.size = NSSize(width: side, height: side)
    return rep
}

/// 把单个汉字居中画进 rect。
func drawGlyph(in rect: CGRect, color: NSColor, scale: CGFloat, weight: NSFont.Weight) {
    let font = NSFont.systemFont(ofSize: rect.height * scale, weight: weight)
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let str = NSAttributedString(string: glyph, attributes: attrs)
    let size = str.size()
    str.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
}

func appIcon(_ r: CGRect) {
    let inset = r.width * 0.06
    let body = r.insetBy(dx: inset, dy: inset)
    let clip = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    clip.addClip()
    NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.52, blue: 0.40, alpha: 1),
               ending: NSColor(calibratedRed: 0.06, green: 0.25, blue: 0.20, alpha: 1))!
        .draw(in: body, angle: -90)
    drawGlyph(in: body, color: NSColor(calibratedRed: 0.96, green: 0.92, blue: 0.80, alpha: 1),
              scale: 0.62, weight: .semibold)
}

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icons")
let iconset = outDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    let rep = render(pixels: px, appIcon)
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: iconset.appendingPathComponent(name + ".png"))
    }
}

// 菜单栏图标：纯黑 + 透明背景，由系统按模板图着色（浅色/深色菜单栏都正常）
func menuGlyph(_ r: CGRect) {
    drawGlyph(in: r, color: .black, scale: 0.92, weight: .bold)
}
let menu1x = render(pixels: 16, points: 16, menuGlyph)
let menu2x = render(pixels: 16, points: 16, menuGlyph)
if let tiff = NSBitmapImageRep.representationOfImageReps(in: [menu1x, menu2x], using: .tiff, properties: [:]) {
    try? tiff.write(to: outDir.appendingPathComponent("icon.tiff"))
} else {
    FileHandle.standardError.write(Data("failed to encode icon.tiff\n".utf8))
    exit(1)
}
print("icons written to \(outDir.path)")
