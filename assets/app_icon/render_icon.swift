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

let drawsBackground = layer == "full" || layer == "background"
let drawsText = layer != "background"
let drawsShadow = layer == "full" || layer == "foreground"

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
let gradientTop = NSColor(calibratedRed: 0.17, green: 0.76, blue: 0.47, alpha: 1.0)
let gradientBottom = NSColor(calibratedRed: 0.05, green: 0.52, blue: 0.27, alpha: 1.0)

image.lockFocus()

if drawsBackground {
  if let gradient = NSGradient(starting: gradientTop, ending: gradientBottom) {
    gradient.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024), angle: 90)
  } else {
    gradientTop.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
  }
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
