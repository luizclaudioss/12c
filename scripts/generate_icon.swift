#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

guard CommandLine.arguments.count >= 2 else {
    fputs("Uso: generate_icon.swift <caminho-saida.icns>\n", stderr)
    exit(1)
}

let outputICNSPath = CommandLine.arguments[1]
let fm = FileManager.default
let tempDir = fm.temporaryDirectory.appendingPathComponent("hp12c_icon_\(UUID().uuidString)")
let iconsetDir = tempDir.appendingPathComponent("AppIcon.iconset")

try fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: tempDir) }

func color(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
    let r = CGFloat((hex >> 16) & 0xFF) / 255.0
    let g = CGFloat((hex >> 8) & 0xFF) / 255.0
    let b = CGFloat(hex & 0xFF) / 255.0
    return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
}

func drawSquirclePath(in rect: CGRect, radius: CGFloat) -> CGPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).cgPathCompatible
}

extension NSBezierPath {
    var cgPathCompatible: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo, .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        return path
    }
}

func renderIcon(size px: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(
        data: nil,
        width: px,
        height: px,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        fatalError("Failed to create CGContext")
    }

    let s = CGFloat(px) / 1024.0
    ctx.scaleBy(x: s, y: s)

    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    // Note: AppKit flipped=false has origin (0,0) at bottom-left, y upward.
    let bodyRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let cornerRadius: CGFloat = 185
    let bodyPath = drawSquirclePath(in: bodyRect, radius: cornerRadius)

    // Drop shadow behind squircle body
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor.black.withAlphaComponent(0.55).cgColor)
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0x1C1C1C).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Clip everything inside the calculator squircle body
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()

    // Main dark charcoal body gradient
    let bodyGrad = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0x2B2B2B).cgColor, color(0x141414).cgColor] as CFArray,
        locations: [0.0, 1.0]
    )!
    ctx.drawLinearGradient(
        bodyGrad,
        start: CGPoint(x: 512, y: 924),
        end: CGPoint(x: 512, y: 100),
        options: []
    )

    // Top brushed silver / champagne aluminum band (top 34% of body)
    let bandY: CGFloat = 640
    let bandRect = CGRect(x: 100, y: bandY, width: 824, height: 284)
    ctx.saveGState()
    ctx.clip(to: bandRect)
    let bandGrad = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            color(0xD3D0C4).cgColor,
            color(0xBDB9AC).cgColor,
            color(0xCAC6B9).cgColor,
            color(0xA6A295).cgColor
        ] as CFArray,
        locations: [0.0, 0.45, 0.72, 1.0]
    )!
    ctx.drawLinearGradient(
        bandGrad,
        start: CGPoint(x: 100, y: 924),
        end: CGPoint(x: 924, y: bandY),
        options: []
    )
    ctx.restoreGState()

    // Gold separator line below aluminum band
    ctx.setFillColor(color(0xD9A740).cgColor)
    ctx.fill(CGRect(x: 100, y: bandY - 7, width: 824, height: 7))

    // Recessed LCD Bezel on left of top band
    let bezelRect = CGRect(x: 148, y: 678, width: 472, height: 186)
    let bezelPath = drawSquirclePath(in: bezelRect, radius: 22)
    ctx.addPath(bezelPath)
    ctx.setFillColor(color(0x111111).cgColor)
    ctx.fillPath()

    // Sage-green LCD panel
    let lcdRect = CGRect(x: 168, y: 698, width: 432, height: 146)
    let lcdPath = drawSquirclePath(in: lcdRect, radius: 14)
    ctx.addPath(lcdPath)
    ctx.setFillColor(color(0xB9C0A8).cgColor)
    ctx.fillPath()

    // Subtle LCD border
    ctx.addPath(lcdPath)
    ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.45).cgColor)
    ctx.setLineWidth(3)
    ctx.strokePath()

    // LCD text "12.345,67"
    let lcdParagraph = NSMutableParagraphStyle()
    lcdParagraph.alignment = .left
    let lcdAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 68, weight: .bold),
        .foregroundColor: color(0x1D211B),
        .paragraphStyle: lcdParagraph
    ]
    let lcdStr = NSAttributedString(string: "12.345,67", attributes: lcdAttrs)
    let lcdBounds = lcdStr.boundingRect(with: CGSize(width: 404, height: 120), options: [.usesLineFragmentOrigin])
    lcdStr.draw(in: CGRect(
        x: 186,
        y: lcdRect.midY - lcdBounds.height * 0.48,
        width: 400,
        height: lcdBounds.height + 10
    ))

    // "12C" badge centered on the right of top band
    let badgeStyle = NSMutableParagraphStyle()
    badgeStyle.alignment = .center
    let badgeAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 70, weight: .heavy),
        .foregroundColor: color(0x202020),
        .paragraphStyle: badgeStyle
    ]
    NSAttributedString(string: "12C", attributes: badgeAttrs)
        .draw(in: CGRect(x: 636, y: 748, width: 256, height: 86))

    let finAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 21, weight: .bold),
        .foregroundColor: color(0x323232),
        .kern: 1.5,
        .paragraphStyle: badgeStyle
    ]
    NSAttributedString(string: "FINANCIAL", attributes: finAttrs)
        .draw(in: CGRect(x: 636, y: 706, width: 256, height: 30))

    // Keypad outer gold frame
    let keypadFrameRect = CGRect(x: 146, y: 148, width: 732, height: 448)
    let keypadFramePath = drawSquirclePath(in: keypadFrameRect, radius: 24)
    ctx.addPath(keypadFramePath)
    ctx.setStrokeColor(color(0xD9A740, alpha: 0.55).cgColor)
    ctx.setLineWidth(4)
    ctx.strokePath()

    // Helper to draw a stylized HP 12C key
    func drawKey(
        rect: CGRect,
        bgTop: UInt32 = 0x454545,
        bgBot: UInt32 = 0x262626,
        topGoldText: String? = nil,
        label: String,
        labelColor: UInt32 = 0xFFFFFF,
        blueFront: Bool = true,
        fontSize: CGFloat = 34,
        verticalEnter: Bool = false
    ) {
        if let gold = topGoldText {
            let gStyle = NSMutableParagraphStyle()
            gStyle.alignment = .center
            let gAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 19, weight: .bold),
                .foregroundColor: color(0xD9A740),
                .paragraphStyle: gStyle
            ]
            NSAttributedString(string: gold, attributes: gAttrs)
                .draw(in: CGRect(x: rect.minX - 4, y: rect.maxY + 4, width: rect.width + 8, height: 24))
        }

        let kPath = drawSquirclePath(in: rect, radius: 14)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 6, color: NSColor.black.withAlphaComponent(0.65).cgColor)
        ctx.addPath(kPath)
        ctx.setFillColor(color(bgBot).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(kPath)
        ctx.clip()

        let kGrad = CGGradient(
            colorsSpace: colorSpace,
            colors: [color(bgTop).cgColor, color(bgBot).cgColor] as CFArray,
            locations: [0.0, 1.0]
        )!
        ctx.drawLinearGradient(
            kGrad,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end: CGPoint(x: rect.midX, y: rect.minY),
            options: []
        )

        if blueFront {
            let bevelH = min(22.0, rect.height * 0.24)
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
            ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: bevelH))
            ctx.setFillColor(color(0x5DA3E0).cgColor)
            ctx.fill(CGRect(x: rect.minX + 18, y: rect.minY + bevelH * 0.32, width: rect.width - 36, height: 6))
        }

        ctx.restoreGState()

        ctx.addPath(kPath)
        ctx.setStrokeColor(NSColor.black.withAlphaComponent(0.85).cgColor)
        ctx.setLineWidth(3)
        ctx.strokePath()

        let pStyle = NSMutableParagraphStyle()
        pStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: color(labelColor),
            .paragraphStyle: pStyle
        ]
        if verticalEnter {
            let letters = ["E", "N", "T", "E", "R"]
            let stepH = (rect.height - 46) / CGFloat(letters.count)
            for (idx, ch) in letters.enumerated() {
                let yPos = rect.maxY - 22 - CGFloat(idx + 1) * stepH
                NSAttributedString(string: ch, attributes: attrs)
                    .draw(in: CGRect(x: rect.minX, y: yPos, width: rect.width, height: stepH))
            }
        } else {
            let str = NSAttributedString(string: label, attributes: attrs)
            let b = str.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin])
            let yOffset: CGFloat = blueFront ? 8 : 0
            str.draw(in: CGRect(
                x: rect.minX,
                y: rect.midY - b.height * 0.5 + yOffset,
                width: rect.width,
                height: b.height + 6
            ))
        }
    }

    // Stylized 5-column x 3-row keypad grid inside frame
    let cols = 5
    let keyW: CGFloat = 114
    let gapX: CGFloat = 20
    let startX: CGFloat = 176

    // Row 1 (Financial keys: n, i, PV, PMT, FV)
    let row1Labels: [(String, String)] = [
        ("AMORT", "n"),
        ("INT", "i"),
        ("NPV", "PV"),
        ("RND", "PMT"),
        ("IRR", "FV")
    ]
    for (c, item) in row1Labels.enumerated() {
        let x = startX + CGFloat(c) * (keyW + gapX)
        drawKey(
            rect: CGRect(x: x, y: 446, width: keyW, height: 104),
            topGoldText: item.0,
            label: item.1,
            blueFront: true,
            fontSize: 34
        )
    }

    // Row 2 (CHS, 7, 8, 9, ENTER top-to-bottom span)
    let row2Specs: [(String?, String, CGFloat)] = [
        (nil, "CHS", 30),
        (nil, "7", 40),
        (nil, "8", 40),
        (nil, "9", 40)
    ]
    for (c, spec) in row2Specs.enumerated() {
        let x = startX + CGFloat(c) * (keyW + gapX)
        drawKey(
            rect: CGRect(x: x, y: 312, width: keyW, height: 104),
            topGoldText: spec.0,
            label: spec.1,
            blueFront: true,
            fontSize: spec.2
        )
    }

    // Row 3 (f gold, g blue, STO, RCL)
    let x0 = startX
    let x1 = startX + (keyW + gapX)
    let x2 = startX + 2 * (keyW + gapX)
    let x3 = startX + 3 * (keyW + gapX)
    let x4 = startX + 4 * (keyW + gapX)

    drawKey(
        rect: CGRect(x: x0, y: 176, width: keyW, height: 104),
        bgTop: 0xECB23B,
        bgBot: 0xC68C1C,
        label: "f",
        labelColor: 0x151515,
        blueFront: false,
        fontSize: 44
    )
    drawKey(
        rect: CGRect(x: x1, y: 176, width: keyW, height: 104),
        bgTop: 0x5CA4E4,
        bgBot: 0x3576B5,
        label: "g",
        labelColor: 0x151515,
        blueFront: false,
        fontSize: 44
    )
    drawKey(
        rect: CGRect(x: x2, y: 176, width: keyW, height: 104),
        label: "STO",
        blueFront: false,
        fontSize: 30
    )
    drawKey(
        rect: CGRect(x: x3, y: 176, width: keyW, height: 104),
        label: "RCL",
        blueFront: false,
        fontSize: 30
    )

    // Tall ENTER key spanning rows 2 and 3 in rightmost column
    drawKey(
        rect: CGRect(x: x4, y: 176, width: keyW, height: 240),
        topGoldText: "PREFIX",
        label: "ENTER",
        blueFront: true,
        fontSize: 28,
        verticalEnter: true
    )
    _ = cols

    ctx.restoreGState()

    // Subtle gold-tinted outer rim highlight on squircle
    ctx.addPath(bodyPath)
    ctx.setStrokeColor(color(0xD9A740, alpha: 0.45).cgColor)
    ctx.setLineWidth(6)
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()

    guard let cgImage = ctx.makeImage() else {
        fatalError("Failed to create CGImage")
    }
    return cgImage
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, px) in sizes {
    let cgImg = renderIcon(size: px)
    let rep = NSBitmapImageRep(cgImage: cgImg)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode PNG for \(filename)")
    }
    try pngData.write(to: iconsetDir.appendingPathComponent(filename))
}

let outURL = URL(fileURLWithPath: outputICNSPath)
try fm.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
if fm.fileExists(atPath: outURL.path) {
    try fm.removeItem(at: outURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", outURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    fputs("iconutil falhou com status \(process.terminationStatus)\n", stderr)
    exit(process.terminationStatus)
}
