import AppKit

let outputPath = CommandLine.arguments.count > 1
  ? CommandLine.arguments[1]
  : "assets/app_icon/app_icon_1024.png"
let preferredFontName = CommandLine.arguments.count > 2
  ? CommandLine.arguments[2]
  : "Farah"

// Which layer to render:
//   full        - gradient + text, used for iOS and the legacy Android icon
//   background  - gradient only, the adaptive icon's background layer
//   foreground  - text only on transparency, the adaptive icon's foreground
//   monochrome  - like foreground but flat and unshadowed, for themed icons
//
// Android composites the background and foreground layers and then masks the
// result into a device-specific shape, so the two must be rendered separately
// rather than baked into one image.
let layer = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "full"

guard ["full", "background", "foreground", "monochrome"].contains(layer) else {
  fputs("Unknown layer '\(layer)'. Use full, background, foreground or monochrome.\n", stderr)
  exit(1)
}

// Optional seasonal theme used by the iOS alternate icons:
//   default, ramadan, eid_al_fitr, eid_al_adha
let theme = CommandLine.arguments.count > 4 ? CommandLine.arguments[4] : "default"

guard ["default", "ramadan", "eid_al_fitr", "eid_al_adha"].contains(theme) else {
  fputs("Unknown theme '\(theme)'. Use default, ramadan, eid_al_fitr or eid_al_adha.\n", stderr)
  exit(1)
}

let drawsBackground = layer == "full" || layer == "background"
let drawsText = layer != "background"
let drawsShadow = layer == "full" || layer == "foreground"
let drawsDecoration = layer == "full" && theme != "default"

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
let gold = NSColor(calibratedRed: 0.98, green: 0.80, blue: 0.36, alpha: 1.0)

let (gradientTop, gradientBottom): (NSColor, NSColor) = {
  switch theme {
  case "ramadan":
    // Night sky: deep teal fading into midnight blue.
    return (
      NSColor(calibratedRed: 0.06, green: 0.36, blue: 0.40, alpha: 1.0),
      NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.27, alpha: 1.0)
    )
  case "eid_al_adha":
    return (
      NSColor(calibratedRed: 0.10, green: 0.58, blue: 0.42, alpha: 1.0),
      NSColor(calibratedRed: 0.02, green: 0.33, blue: 0.24, alpha: 1.0)
    )
  default:
    return (
      NSColor(calibratedRed: 0.17, green: 0.76, blue: 0.47, alpha: 1.0),
      NSColor(calibratedRed: 0.05, green: 0.52, blue: 0.27, alpha: 1.0)
    )
  }
}()

func drawStar(center: NSPoint, outerRadius: CGFloat, color: NSColor) {
  let innerRadius = outerRadius * 0.42
  let path = NSBezierPath()
  for index in 0..<10 {
    let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
    let angle = CGFloat.pi / 2 + CGFloat(index) * CGFloat.pi / 5
    let point = NSPoint(
      x: center.x + cos(angle) * radius,
      y: center.y + sin(angle) * radius
    )
    if index == 0 { path.move(to: point) } else { path.line(to: point) }
  }
  path.close()
  color.setFill()
  path.fill()
}

func drawCrescent(center: NSPoint, radius: CGFloat, color: NSColor) {
  let outer = NSBezierPath(
    ovalIn: NSRect(
      x: center.x - radius, y: center.y - radius,
      width: radius * 2, height: radius * 2
    )
  )
  let cutRadius = radius * 0.82
  let cutCenter = NSPoint(x: center.x + radius * 0.38, y: center.y + radius * 0.18)
  let cut = NSBezierPath(
    ovalIn: NSRect(
      x: cutCenter.x - cutRadius, y: cutCenter.y - cutRadius,
      width: cutRadius * 2, height: cutRadius * 2
    )
  )
  NSGraphicsContext.saveGraphicsState()
  outer.addClip()
  // Within the outer disc, an even-odd fill of (bounds + inner disc) leaves
  // exactly the crescent without touching the background underneath.
  let crescent = NSBezierPath(rect: outer.bounds)
  crescent.append(cut)
  crescent.windingRule = .evenOdd
  color.setFill()
  crescent.fill()
  NSGraphicsContext.restoreGraphicsState()
}

// Decorations stay above the shared text box (y 214...774) so the wordmark
// is identical across every icon variant.
func drawSeasonalDecoration() {
  switch theme {
  case "ramadan":
    drawCrescent(center: NSPoint(x: 806, y: 872), radius: 86, color: gold)
    drawStar(center: NSPoint(x: 882, y: 900), outerRadius: 22, color: gold)
    for (x, y, r) in [(170.0, 900.0, 14.0), (290.0, 948.0, 9.0), (420.0, 890.0, 11.0), (120.0, 140.0, 9.0), (900.0, 150.0, 12.0)] {
      drawStar(center: NSPoint(x: x, y: y), outerRadius: r, color: gold.withAlphaComponent(0.85))
    }
  case "eid_al_fitr":
    drawCrescent(center: NSPoint(x: 806, y: 872), radius: 80, color: gold)
    for (x, y, r) in [(882.0, 904.0, 22.0), (180.0, 890.0, 24.0), (310.0, 944.0, 14.0), (140.0, 140.0, 16.0), (884.0, 140.0, 16.0)] {
      drawStar(center: NSPoint(x: x, y: y), outerRadius: r, color: gold)
    }
  case "eid_al_adha":
    let border = NSBezierPath(
      roundedRect: NSRect(x: 40, y: 40, width: 944, height: 944),
      xRadius: 200, yRadius: 200
    )
    border.lineWidth = 18
    gold.withAlphaComponent(0.9).setStroke()
    border.stroke()
    drawCrescent(center: NSPoint(x: 512, y: 872), radius: 70, color: gold)
    drawStar(center: NSPoint(x: 578, y: 896), outerRadius: 18, color: gold)
  default:
    break
  }
}

image.lockFocus()

if drawsBackground {
  if let gradient = NSGradient(starting: gradientTop, ending: gradientBottom) {
    gradient.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), angle: 90)
  } else {
    gradientTop.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
  }
}

if drawsDecoration {
  drawSeasonalDecoration()
}

let fontNames = [
  "Diwan Thuluth",
  "DecoType Naskh",
  "Nadeem",
  "Farah",
  "Baghdad",
  "Damascus",
  "Diwan Kufi",
  "KufiStandardGK",
  "Geeza Pro",
  "Al Bayan",
  "Sana",
  "SF Arabic",
  "Arial Unicode MS",
]
let activeFontNames = (preferredFontName.isEmpty == false)
  ? [preferredFontName]
  : fontNames

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
paragraph.baseWritingDirection = .rightToLeft

let shadow = NSShadow()
shadow.shadowBlurRadius = 18
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.16)

let attributes: [NSAttributedString.Key: Any] = drawsShadow
  ? [.paragraphStyle: paragraph, .shadow: shadow]
  : [.paragraphStyle: paragraph]

let title = "تجويد" as NSString

// All layers share one text box. Android's adaptive-icon safe zone is handled
// by the 16% inset that flutter_launcher_icons writes into
// mipmap-anydpi-v26/ic_launcher.xml, so shrinking the text here as well would
// scale it down twice and leave the glyph floating in empty space.
let textRect = NSRect(x: 94, y: 214, width: 836, height: 560)

let maxFontSize: CGFloat = 468
let minFontSize: CGFloat = 120
let step: CGFloat = 4

var chosenFont = NSFont.systemFont(ofSize: 288, weight: .medium)
var chosenBounds = NSRect.zero

var fontSize = maxFontSize
while fontSize >= minFontSize {
  let candidateFont = activeFontNames
    .compactMap { NSFont(name: $0, size: fontSize) }
    .first ?? NSFont.systemFont(ofSize: fontSize, weight: .medium)

  let candidateAttrs: [NSAttributedString.Key: Any] = [
    .font: candidateFont,
    .paragraphStyle: paragraph,
  ]

  let bounds = title.boundingRect(
    with: NSSize(width: textRect.width, height: textRect.height),
    options: [.usesLineFragmentOrigin, .usesFontLeading],
    attributes: candidateAttrs
  )

  if bounds.width <= textRect.width && bounds.height <= textRect.height {
    chosenFont = candidateFont
    chosenBounds = bounds
    break
  }

  fontSize -= step
}

let finalAttributes = attributes.merging([
  .font: chosenFont,
  .foregroundColor: NSColor.white,
]) { _, new in new }

let centeredTextRect = NSRect(
  x: textRect.minX,
  y: textRect.minY + ((textRect.height - chosenBounds.height) / 2),
  width: textRect.width,
  height: chosenBounds.height
)

if drawsText {
  title.draw(in: centeredTextRect, withAttributes: finalAttributes)
}

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
