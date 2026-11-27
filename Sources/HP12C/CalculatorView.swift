import SwiftUI
import HP12CCore

struct CalculatorView: View {
    @ObservedObject var viewModel: CalculatorViewModel

    private let row1: [Key] = [.n, .i, .pv, .pmt, .fv, .chs, .d7, .d8, .d9, .div]
    private let row2: [Key] = [.yx, .recip, .pctT, .dPct, .pct, .eex, .d4, .d5, .d6, .mul]
    private let row3Left: [Key] = [.rs, .sst, .rdown, .swap, .clx]
    private let row3Right: [Key] = [.d1, .d2, .d3, .sub]
    private let row4Left: [Key] = [.on, .f, .g, .sto, .rcl]
    private let row4Right: [Key] = [.d0, .dot, .sigmaPlus, .add]

    private let goldColor = Color(hex: 0xFFAA1D)
    private let blueColor = Color(hex: 0x38D4FF)

    private let baseWidth: CGFloat = 920
    private let baseHeight: CGFloat = 600
    private let cellWidth: CGFloat = 76
    private let colSpacing: CGFloat = 10
    private let keyHeight: CGFloat = 66
    private let goldStripHeight: CGFloat = 20
    private let rowSpacing: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let s = max(0.3, min(geo.size.width / baseWidth, geo.size.height / baseHeight))
            calculatorBody(scale: s)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        .frame(minWidth: 520, idealWidth: baseWidth, maxWidth: .infinity, minHeight: 339, idealHeight: baseHeight, maxHeight: .infinity)
        .background(Color(hex: 0x161616))
        .onAppear {
            viewModel.installKeyboardMonitor()
        }
        .onDisappear {
            viewModel.removeKeyboardMonitor()
        }
        .sheet(isPresented: $viewModel.showingShortcuts) {
            ShortcutsSheet()
        }
    }

    private func calculatorBody(scale s: CGFloat) -> some View {
        VStack(spacing: 0) {
            topAluminumBezel(scale: s)
                .frame(height: 154 * s)

            goldPinLine(scale: s)

            keypadArea(scale: s)
                .padding(.horizontal, 23 * s)
                .padding(.top, 12 * s)
                .padding(.bottom, 18 * s)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0x222222), Color(hex: 0x161616)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(width: baseWidth * s, height: baseHeight * s)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x2E2E2E), Color(hex: 0x151515)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Top Brushed Aluminum Bezel

    private func topAluminumBezel(scale s: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0xCFCCC0),
                    Color(hex: 0xB8B4A7),
                    Color(hex: 0xC6C2B6),
                    Color(hex: 0xA7A396)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 28 * s) {
                // Black LCD bezel on the left ~56%
                ZStack {
                    RoundedRectangle(cornerRadius: 6 * s)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x1A1A1A), Color(hex: 0x0C0C0C)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6 * s)
                                .stroke(Color.black.opacity(0.7), lineWidth: 1 * s)
                        )

                    LCDView(
                        displayText: viewModel.displayText,
                        annunciators: viewModel.annunciators,
                        blinking: viewModel.blinking,
                        isOn: viewModel.isOn,
                        scale: s
                    )
                    .padding(8 * s)
                }
                .frame(width: 510 * s, height: 116 * s)

                // 12C Badge on the right
                VStack(alignment: .leading, spacing: 2 * s) {
                    Text("12C")
                        .font(.system(size: 32 * s, weight: .heavy, design: .default))
                        .foregroundColor(Color(hex: 0x232323))
                    Text("FINANCIAL")
                        .font(.system(size: 13 * s, weight: .bold))
                        .tracking(1.6 * s)
                        .foregroundColor(Color(hex: 0x2B2B2B))
                    Text("CALCULATOR")
                        .font(.system(size: 10.5 * s, weight: .semibold))
                        .tracking(1.4 * s)
                        .foregroundColor(Color(hex: 0x3D3D3D))
                }
                .padding(.horizontal, 14 * s)
                .padding(.vertical, 8 * s)
                .background(
                    RoundedRectangle(cornerRadius: 4 * s)
                        .stroke(Color(hex: 0x4A473E).opacity(0.45), lineWidth: 1 * s)
                )
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 32 * s)
        }
    }

    private func goldPinLine(scale s: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [goldColor.opacity(0.75), goldColor, goldColor.opacity(0.75)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2 * s)
    }

    // MARK: - Keypad

    private func keypadArea(scale s: CGFloat) -> some View {
        VStack(spacing: rowSpacing * s) {
            // Row 1
            HStack(spacing: colSpacing * s) {
                ForEach(row1, id: \.rawValue) { key in
                    keyCell(key, scale: s)
                }
            }

            // Row 2
            HStack(spacing: colSpacing * s) {
                ForEach(row2, id: \.rawValue) { key in
                    keyCell(key, scale: s)
                }
            }

            // CLEAR bracket above SST..CLx + Rows 3 & 4 with tall ENTER
            ZStack(alignment: .topLeading) {
                // Rows 3 and 4 grid
                HStack(alignment: .top, spacing: colSpacing * s) {
                    // Left 5 columns (rows 3 and 4)
                    VStack(spacing: rowSpacing * s) {
                        HStack(spacing: colSpacing * s) {
                            ForEach(row3Left, id: \.rawValue) { key in
                                keyCell(key, scale: s)
                            }
                        }
                        HStack(spacing: colSpacing * s) {
                            ForEach(row4Left, id: \.rawValue) { key in
                                keyCell(key, scale: s)
                            }
                        }
                    }

                    // Column 6: Tall ENTER key spanning rows 3 and 4
                    enterKeyCell(scale: s)

                    // Right 4 columns (rows 3 and 4)
                    VStack(spacing: rowSpacing * s) {
                        HStack(spacing: colSpacing * s) {
                            ForEach(row3Right, id: \.rawValue) { key in
                                keyCell(key, scale: s)
                            }
                        }
                        HStack(spacing: colSpacing * s) {
                            ForEach(row4Right, id: \.rawValue) { key in
                                keyCell(key, scale: s)
                            }
                        }
                    }
                }
                .padding(.top, 14 * s)

                // Gold CLEAR bracket spanning cols 1..4 (SST, R↓, x≷y, CLx)
                clearBracket(scale: s)
                    .offset(x: (cellWidth + colSpacing) * s, y: -2 * s)
            }
        }
        .padding(12 * s)
        .background(
            RoundedRectangle(cornerRadius: 6 * s)
                .stroke(goldColor.opacity(0.65), lineWidth: 1.2 * s)
        )
    }

    private func clearBracket(scale s: CGFloat) -> some View {
        let spanWidth = (cellWidth * 4 + colSpacing * 3) * s
        return ZStack {
            Path { path in
                let yLine: CGFloat = 9 * s
                path.move(to: CGPoint(x: 4 * s, y: 15 * s))
                path.addLine(to: CGPoint(x: 4 * s, y: yLine))
                path.addLine(to: CGPoint(x: spanWidth * 0.5 - 34 * s, y: yLine))
                path.move(to: CGPoint(x: spanWidth * 0.5 + 34 * s, y: yLine))
                path.addLine(to: CGPoint(x: spanWidth - 4 * s, y: yLine))
                path.addLine(to: CGPoint(x: spanWidth - 4 * s, y: 15 * s))
            }
            .stroke(goldColor, lineWidth: 1.8 * s)

            Text("CLEAR")
                .font(.system(size: 13.5 * s, weight: .heavy))
                .tracking(0.8 * s)
                .foregroundColor(goldColor)
                .offset(y: -1 * s)
        }
        .frame(width: spanWidth, height: 18 * s)
    }

    private func keyCell(_ key: Key, scale s: CGFloat) -> some View {
        let w = cellWidth * s
        let h = keyHeight * s
        return VStack(spacing: 2 * s) {
            Text(key.labels.gold ?? "")
                .font(.system(size: 15.5 * s, weight: .heavy))
                .foregroundColor(goldColor)
                .frame(height: goldStripHeight * s)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HPKeyButton(
                key: key,
                isPressed: viewModel.pressedKey == key || viewModel.mousePressedKey == key,
                goldColor: goldColor,
                blueColor: blueColor,
                width: w,
                height: h,
                scale: s,
                onPressChanged: { down in
                    viewModel.mousePressedKey = down ? key : nil
                },
                action: {
                    viewModel.press(key)
                }
            )
            .frame(width: w, height: h)
        }
        .frame(width: w)
    }

    private func enterKeyCell(scale s: CGFloat) -> some View {
        let w = cellWidth * s
        let tallHeight = (keyHeight * 2 + goldStripHeight + rowSpacing + 2) * s
        return VStack(spacing: 2 * s) {
            Text(Key.enter.labels.gold ?? "")
                .font(.system(size: 15.5 * s, weight: .heavy))
                .foregroundColor(goldColor)
                .frame(height: goldStripHeight * s)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HPKeyButton(
                key: .enter,
                isPressed: viewModel.pressedKey == .enter || viewModel.mousePressedKey == .enter,
                goldColor: goldColor,
                blueColor: blueColor,
                width: w,
                height: tallHeight,
                scale: s,
                isEnter: true,
                onPressChanged: { down in
                    viewModel.mousePressedKey = down ? .enter : nil
                },
                action: {
                    viewModel.press(.enter)
                }
            )
            .frame(width: w, height: tallHeight)
        }
        .frame(width: w)
    }
}

private struct HPKeyButton: View {
    let key: Key
    let isPressed: Bool
    let goldColor: Color
    let blueColor: Color
    let width: CGFloat
    let height: CGFloat
    let scale: CGFloat
    var isEnter: Bool = false
    let onPressChanged: (Bool) -> Void
    let action: () -> Void

    private var isGoldKey: Bool { key == .f }
    private var isBlueKey: Bool { key == .g }

    private static let symbolBlueLabels: Set<String> = [
        "12×", "12÷", "√x", "eˣ", "x²", "x≤y", "x=0", "x̂,r", "ŷ,r", "n!", "x̄", "x̄w", "s", "Σ−"
    ]

    var body: some View {
        let s = scale
        ZStack(alignment: .bottom) {
            // Keycap body
            RoundedRectangle(cornerRadius: 5 * s)
                .fill(keyGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 5 * s)
                        .stroke(Color.black.opacity(0.85), lineWidth: 1.2 * s)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4 * s)
                        .stroke(Color.white.opacity(isGoldKey || isBlueKey ? 0.25 : 0.10), lineWidth: 0.8 * s)
                        .padding(1 * s)
                )
                .shadow(color: .black.opacity(0.6), radius: (isPressed ? 0.5 : 2.5) * s, x: 0, y: (isPressed ? 0.5 : 2) * s)

            VStack(spacing: 0) {
                // Primary white/black top face
                ZStack {
                    if isEnter {
                        VStack(spacing: 2 * s) {
                            ForEach(["E", "N", "T", "E", "R"], id: \.self) { letter in
                                Text(letter)
                                    .font(.system(size: 15.5 * s, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    } else {
                        Text(key.labels.primary)
                            .font(.system(size: primaryFontSize * s, weight: primaryFontWeight))
                            .foregroundColor((isGoldKey || isBlueKey) ? Color(hex: 0x151515) : .white)
                            .minimumScaleFactor(0.75)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4 * s)

                // Lower front blue-label bevel strip
                if let blueLabel = key.labels.blue {
                    let isSymbol = Self.symbolBlueLabels.contains(blueLabel)
                    let blueFontSize: CGFloat = (isSymbol ? 17.5 : 16.0) * s
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.62))
                        Text(blueLabel)
                            .font(.system(size: blueFontSize, weight: .heavy))
                            .foregroundColor(blueColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .padding(.horizontal, 2 * s)
                    }
                    .frame(height: 25 * s)
                } else {
                    Spacer().frame(height: 4 * s)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5 * s))

            if isPressed {
                RoundedRectangle(cornerRadius: 5 * s)
                    .fill(Color.black.opacity(0.18))
            }
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.06), value: isPressed)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        onPressChanged(true)
                    }
                }
                .onEnded { value in
                    onPressChanged(false)
                    let pad = 8 * s
                    if value.location.x >= -pad && value.location.x <= width + pad &&
                       value.location.y >= -pad && value.location.y <= height + pad {
                        action()
                    }
                }
        )
    }

    private var primaryFontSize: CGFloat {
        if key.digitValue != nil || key == .dot {
            return 25
        }
        if key == .add || key == .sub || key == .mul || key == .div {
            return 27
        }
        if isGoldKey || isBlueKey {
            return 24
        }
        return 18
    }

    private var primaryFontWeight: Font.Weight {
        (isGoldKey || isBlueKey) ? .heavy : .bold
    }

    private var keyGradient: LinearGradient {
        if isGoldKey {
            return LinearGradient(
                colors: [Color(hex: 0xFFB324), Color(hex: 0xE08400)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        if isBlueKey {
            return LinearGradient(
                colors: [Color(hex: 0x38C0FF), Color(hex: 0x167FD1)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [Color(hex: 0x414141), Color(hex: 0x262626)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
