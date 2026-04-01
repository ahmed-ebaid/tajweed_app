import AppKit

let outputPath = CommandLine.arguments.count > 1
  ? CommandLine.arguments[1]
  : "assets/app_icon/app_icon_1024.png"

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
let green = NSColor(calibratedRed: 0.12, green: 0.67, blue: 0.38, alpha: 1.0)

image.lockFocus()

green.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()

green.setFill()
let background = NSBezierPath(
  roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
  xRadius: 210,
  yRadius: 210
)
background.fill()

let fontNames = [
  "Diwan Kufi",
  "Geeza Pro",
  "Al Bayan",
  "SF Arabic",
  "Arial Unicode MS",
]

let font = fontNames
  .compactMap { NSFont(name: $0, size: 230) }
  .first ?? NSFont.systemFont(ofSize: 230, weight: .medium)

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
paragraph.baseWritingDirection = .rightToLeft

let shadow = NSShadow()
shadow.shadowBlurRadius = 18
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.16)

let attributes: [NSAttributedString.Key: Any] = [
  .font: font,
  .foregroundColor: NSColor.white,
  .paragraphStyle: paragraph,
  .shadow: shadow,
]

let title = "تجويد" as NSString
let textRect = NSRect(x: 120, y: 290, width: 784, height: 420)
title.draw(in: textRect, withAttributes: attributes)

image.unlockFocus()

guard
  let tiffData = image.tiffRepresentation,
  let bitmap = NSBitmapImageRep(data: tiffData),
  let pngData = bitmap.representation(using: .png, properties: [:])
else {
  fputs("Failed to render icon\n", stderr)
  exit(1)
}

try pngData.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
