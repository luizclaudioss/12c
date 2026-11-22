import SwiftUI
import HP12CCore

struct LCDView: View {
    let displayText: String
    let annunciators: Annunciators
    let blinking: Bool
    let isOn: Bool

    private let lcdBg = Color(red: 0xB9 / 255.0, green: 0xC0 / 255.0, blue: 0xA8 / 255.0)
    private let segOn = Color(red: 0x1D / 255.0, green: 0x21 / 255.0, blue: 0x1B / 255.0)
    private let segOff = Color(red: 0x1D / 255.0, green: 0x21 / 255.0, blue: 0x1B / 255.0).opacity(0.06)

    struct CellData {
        var segments: UInt8 = 0 // bits 0..6 = a,b,c,d,e,f,g
        var hasDot: Bool = false
        var hasComma: Bool = false
    }

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if isOn && blinking {
                    TimelineView(.periodic(from: .now, by: 0.4)) { context in
                        let visible = Int(floor(context.date.timeIntervalSinceReferenceDate / 0.4)) % 2 == 0
                        lcdCanvas(showDigits: visible)
                    }
                } else {
                    lcdCanvas(showDigits: isOn)
                }
            }
            .frame(height: 54)

            // Annunciator row
            HStack(spacing: 0) {
                Spacer().frame(width: 22)
                annunciatorLabel("f", active: isOn && annunciators.f)
                Spacer()
                annunciatorLabel("g", active: isOn && annunciators.g)
                Spacer()
                annunciatorLabel("BEGIN", active: isOn && annunciators.begin)
                Spacer()
                annunciatorLabel("D.MY", active: isOn && annunciators.dmy)
                Spacer()
                annunciatorLabel("C", active: isOn && annunciators.compound)
                Spacer()
                annunciatorLabel("PRGM", active: isOn && annunciators.prgm)
                Spacer().frame(width: 14)
            }
            .frame(height: 12)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(lcdBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.black.opacity(0.45), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
        )
    }

    private func lcdCanvas(showDigits: Bool) -> some View {
        GeometryReader { _ in
            Canvas { context, size in
                let parsed = showDigits ? parseCells(displayText) : (signMinus: false, cells: Array(repeating: CellData(), count: 10))

                let totalSlots: CGFloat = 10.65 // 0.65 sign cell + 10 digit cells
                let slotWidth = size.width / totalSlots
                let signWidth = slotWidth * 0.65
                let digitHeight = size.height

                // Sign cell (minus bar only)
                drawSignCell(
                    context: &context,
                    rect: CGRect(x: 0, y: 0, width: signWidth, height: digitHeight),
                    lit: parsed.signMinus,
                    showGhost: isOn
                )

                // 10 seven-segment cells
                for idx in 0..<10 {
                    let x = signWidth + CGFloat(idx) * slotWidth
                    let cellRect = CGRect(x: x, y: 0, width: slotWidth, height: digitHeight)
                    drawDigitCell(
                        context: &context,
                        rect: cellRect,
                        cell: parsed.cells[idx],
                        showGhost: isOn
                    )
                }
            }
        }
    }

    private func annunciatorLabel(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(segOn)
            .opacity(active ? 1.0 : 0.0)
    }

    // MARK: - String to 7-Segment Cell Parsing

    private func parseCells(_ text: String) -> (signMinus: Bool, cells: [CellData]) {
        var cells: [CellData] = []
        var signMinus = false
        var chars = Array(text)

        // Numeric strings use the dedicated sign cell for a leading '-'.
        if chars.first == "-" {
            signMinus = true
            chars.removeFirst()
        }

        for ch in chars {
            if ch == "." {
                if !cells.isEmpty {
                    cells[cells.count - 1].hasDot = true
                } else {
                    cells.append(CellData(segments: 0, hasDot: true, hasComma: false))
                }
            } else if ch == "," {
                if !cells.isEmpty {
                    cells[cells.count - 1].hasDot = true
                    cells[cells.count - 1].hasComma = true
                } else {
                    cells.append(CellData(segments: 0, hasDot: true, hasComma: true))
                }
            } else {
                if cells.count < 10 {
                    cells.append(CellData(segments: segmentMask(for: ch), hasDot: false, hasComma: false))
                }
            }
        }

        while cells.count < 10 {
            cells.append(CellData())
        }
        return (signMinus, Array(cells.prefix(10)))
    }

    // Segments: bit0=a (top), bit1=b (top-right), bit2=c (bottom-right),
    // bit3=d (bottom), bit4=e (bottom-left), bit5=f (top-left), bit6=g (middle)
    private func segmentMask(for ch: Character) -> UInt8 {
        switch ch {
        case "0": return 0b0111111
        case "1": return 0b0000110
        case "2": return 0b1011011
        case "3": return 0b1001111
        case "4": return 0b1100110
        case "5": return 0b1101101
        case "6": return 0b1111101
        case "7": return 0b0000111
        case "8": return 0b1111111
        case "9": return 0b1101111
        case "-": return 0b1000000
        case "E": return 0b1111001
        case "r": return 0b1010000
        case "o": return 0b1011100
        case "P": return 0b1110011
        case "u": return 0b0011100
        case "n": return 0b1010100
        case "i": return 0b0000100
        case "g": return 0b1101111
        default:  return 0
        }
    }

    // MARK: - 7-Segment Geometry Drawing

    private func drawSignCell(context: inout GraphicsContext, rect: CGRect, lit: Bool, showGhost: Bool) {
        let w = rect.width
        let h = rect.height
        let t = max(2.2, w * 0.19)
        let padX = w * 0.14
        let skew: CGFloat = h * 0.08
        let yMid = h * 0.48
        let skewMid = skew * 0.5

        let p = hexHorizontal(x1: rect.minX + padX + skewMid, x2: rect.maxX - padX + skewMid, y: yMid, t: t)
        if lit {
            context.fill(p, with: .color(segOn))
        } else if showGhost {
            context.fill(p, with: .color(segOff))
        }
    }

    private func drawDigitCell(context: inout GraphicsContext, rect: CGRect, cell: CellData, showGhost: Bool) {
        let w = rect.width
        let h = rect.height
        let t = max(2.4, w * 0.13)
        let leftPad = w * 0.12
        let rightPad = w * 0.25 // reserve space for dot/comma
        let topPad = h * 0.08
        let botPad = h * 0.14

        let boxW = w - leftPad - rightPad
        let boxH = h - topPad - botPad
        let skew = boxH * 0.10

        let xL = rect.minX + leftPad
        let xR = xL + boxW
        let yT = rect.minY + topPad
        let yB = yT + boxH
        let yM = (yT + yB) * 0.5

        func sx(_ x: CGFloat, atY y: CGFloat) -> CGFloat {
            let ratio = (yB - y) / max(1, boxH)
            return x + skew * ratio
        }

        let gap = t * 0.24

        // Horizontal segments: a (top), g (mid), d (bottom)
        let segA = hexHorizontal(x1: sx(xL, atY: yT) + gap, x2: sx(xR, atY: yT) - gap, y: yT, t: t)
        let segG = hexHorizontal(x1: sx(xL, atY: yM) + gap, x2: sx(xR, atY: yM) - gap, y: yM, t: t)
        let segD = hexHorizontal(x1: sx(xL, atY: yB) + gap, x2: sx(xR, atY: yB) - gap, y: yB, t: t)

        // Vertical segments: f (top-left), b (top-right), e (bot-left), c (bot-right)
        let segF = slantedVertical(xTop: sx(xL, atY: yT + gap), yTop: yT + gap, xBot: sx(xL, atY: yM - gap), yBot: yM - gap, t: t)
        let segB = slantedVertical(xTop: sx(xR, atY: yT + gap), yTop: yT + gap, xBot: sx(xR, atY: yM - gap), yBot: yM - gap, t: t)
        let segE = slantedVertical(xTop: sx(xL, atY: yM + gap), yTop: yM + gap, xBot: sx(xL, atY: yB - gap), yBot: yB - gap, t: t)
        let segC = slantedVertical(xTop: sx(xR, atY: yM + gap), yTop: yM + gap, xBot: sx(xR, atY: yB - gap), yBot: yB - gap, t: t)

        let segPaths = [segA, segB, segC, segD, segE, segF, segG]
        for bit in 0..<7 {
            let isLit = (cell.segments & (1 << bit)) != 0
            if isLit {
                context.fill(segPaths[bit], with: .color(segOn))
            } else if showGhost {
                context.fill(segPaths[bit], with: .color(segOff))
            }
        }

        // Decimal point & comma tail
        let dotR = t * 0.62
        let dotCenter = CGPoint(x: xR + rightPad * 0.48, y: yB - dotR * 0.35)
        let dotPath = Path(ellipseIn: CGRect(x: dotCenter.x - dotR, y: dotCenter.y - dotR, width: dotR * 2, height: dotR * 2))

        var tailPath = Path()
        tailPath.move(to: CGPoint(x: dotCenter.x + dotR * 0.55, y: dotCenter.y + dotR * 0.2))
        tailPath.addLine(to: CGPoint(x: dotCenter.x - dotR * 0.35, y: dotCenter.y + dotR * 0.2))
        tailPath.addLine(to: CGPoint(x: dotCenter.x - dotR * 1.15, y: dotCenter.y + dotR * 2.5))
        tailPath.addLine(to: CGPoint(x: dotCenter.x - dotR * 0.15, y: dotCenter.y + dotR * 2.5))
        tailPath.closeSubpath()

        if cell.hasDot {
            context.fill(dotPath, with: .color(segOn))
        } else if showGhost {
            context.fill(dotPath, with: .color(segOff))
        }

        if cell.hasComma {
            context.fill(tailPath, with: .color(segOn))
        } else if showGhost {
            context.fill(tailPath, with: .color(segOff))
        }
    }

    private func hexHorizontal(x1: CGFloat, x2: CGFloat, y: CGFloat, t: CGFloat) -> Path {
        let half = t * 0.5
        let tip = min(half * 0.9, max(1.0, (x2 - x1) * 0.15))
        var path = Path()
        path.move(to: CGPoint(x: x1, y: y))
        path.addLine(to: CGPoint(x: x1 + tip, y: y - half))
        path.addLine(to: CGPoint(x: x2 - tip, y: y - half))
        path.addLine(to: CGPoint(x: x2, y: y))
        path.addLine(to: CGPoint(x: x2 - tip, y: y + half))
        path.addLine(to: CGPoint(x: x1 + tip, y: y + half))
        path.closeSubpath()
        return path
    }

    private func slantedVertical(xTop: CGFloat, yTop: CGFloat, xBot: CGFloat, yBot: CGFloat, t: CGFloat) -> Path {
        let half = t * 0.5
        let tip = min(half * 0.9, max(1.0, (yBot - yTop) * 0.18))
        var path = Path()
        path.move(to: CGPoint(x: xTop, y: yTop))
        path.addLine(to: CGPoint(x: xTop + half, y: yTop + tip))
        path.addLine(to: CGPoint(x: xBot + half, y: yBot - tip))
        path.addLine(to: CGPoint(x: xBot, y: yBot))
        path.addLine(to: CGPoint(x: xBot - half, y: yBot - tip))
        path.addLine(to: CGPoint(x: xTop - half, y: yTop + tip))
        path.closeSubpath()
        return path
    }
}
