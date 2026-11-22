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

    private let goldColor = Color(red: 0xD9 / 255.0, green: 0xA7 / 255.0, blue: 0x40 / 255.0)
    private let blueColor = Color(red: 0x5D / 255.0, green: 0xA3 / 255.0, blue: 0xE0 / 255.0)

    private let cellWidth: CGFloat = 76
    private let colSpacing: CGFloat = 10
    private let keyHeight: CGFloat = 54
    private let goldStripHeight: CGFloat = 15
    private let rowSpacing: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            topAluminumBezel
                .frame(height: 152)

            goldPinLine

            keypadArea
                .padding(.horizontal, 26)
                .padding(.top, 14)
                .padding(.bottom, 22)
                .background(
                    LinearGradient(
                        colors: [Color(hex: 0x222222), Color(hex: 0x161616)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .frame(width: 920)
        .background(
            LinearGradient(
                colors: [Color(hex: 0x2E2E2E), Color(hex: 0x151515)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.6), radius: 14, x: 0, y: 6)
        .padding(10)
        .background(Color(hex: 0x101010))
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

    // MARK: - Top Brushed Aluminum Bezel

    private var topAluminumBezel: some View {
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

            HStack(spacing: 28) {
                // Black LCD bezel on the left ~56%
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x1A1A1A), Color(hex: 0x0C0C0C)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.black.opacity(0.7), lineWidth: 1)
                        )

                    LCDView(
                        displayText: viewModel.displayText,
                        annunciators: viewModel.annunciators,
                        blinking: viewModel.blinking,
                        isOn: viewModel.isOn
                    )
                    .padding(12)
                }
                .frame(width: 495, height: 112)

                // HP 12C Badge on the right
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: 0x1E2630))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                        Text("hp")
                            .font(.system(size: 25, weight: .bold, design: .rounded).italic())
                            .foregroundColor(Color(hex: 0xE6E4DC))
                            .offset(y: -1)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("12C")
                            .font(.system(size: 32, weight: .heavy, design: .default))
                            .foregroundColor(Color(hex: 0x232323))
                        Text("FINANCIAL")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1.6)
                            .foregroundColor(Color(hex: 0x2B2B2B))
                        Text("CALCULATOR")
                            .font(.system(size: 10.5, weight: .semibold))
                            .tracking(1.4)
                            .foregroundColor(Color(hex: 0x3D3D3D))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(hex: 0x4A473E).opacity(0.45), lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 32)
        }
    }

    private var goldPinLine: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [goldColor.opacity(0.65), goldColor, goldColor.opacity(0.65)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
    }

    // MARK: - Keypad

    private var keypadArea: some View {
        VStack(spacing: rowSpacing) {
            // Row 1
            HStack(spacing: colSpacing) {
                ForEach(row1, id: \.rawValue) { key in
                    keyCell(key)
                }
            }

            // Row 2
            HStack(spacing: colSpacing) {
                ForEach(row2, id: \.rawValue) { key in
                    keyCell(key)
                }
            }

            // CLEAR bracket above SST..CLx + Rows 3 & 4 with tall ENTER
            ZStack(alignment: .topLeading) {
                // Rows 3 and 4 grid
                HStack(alignment: .top, spacing: colSpacing) {
                    // Left 5 columns (rows 3 and 4)
                    VStack(spacing: rowSpacing) {
                        HStack(spacing: colSpacing) {
                            ForEach(row3Left, id: \.rawValue) { key in
                                keyCell(key)
                            }
                        }
                        HStack(spacing: colSpacing) {
                            ForEach(row4Left, id: \.rawValue) { key in
                                keyCell(key)
                            }
                        }
                    }

                    // Column 6: Tall ENTER key spanning rows 3 and 4
                    enterKeyCell

                    // Right 4 columns (rows 3 and 4)
                    VStack(spacing: rowSpacing) {
                        HStack(spacing: colSpacing) {
                            ForEach(row3Right, id: \.rawValue) { key in
                                keyCell(key)
                            }
                        }
                        HStack(spacing: colSpacing) {
                            ForEach(row4Right, id: \.rawValue) { key in
                                keyCell(key)
                            }
                        }
                    }
                }
                .padding(.top, 10) // room for CLEAR bracket

                // Gold CLEAR bracket spanning cols 1..4 (SST, R↓, x≷y, CLx)
                clearBracket
                    .offset(x: cellWidth + colSpacing, y: -2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(goldColor.opacity(0.45), lineWidth: 1)
        )
    }

    private var clearBracket: some View {
        let spanWidth = cellWidth * 4 + colSpacing * 3
        return ZStack {
            Path { path in
                let yLine: CGFloat = 7
                path.move(to: CGPoint(x: 4, y: 12))
                path.addLine(to: CGPoint(x: 4, y: yLine))
                path.addLine(to: CGPoint(x: spanWidth * 0.5 - 26, y: yLine))
                path.move(to: CGPoint(x: spanWidth * 0.5 + 26, y: yLine))
                path.addLine(to: CGPoint(x: spanWidth - 4, y: yLine))
                path.addLine(to: CGPoint(x: spanWidth - 4, y: 12))
            }
            .stroke(goldColor, lineWidth: 1.2)

            Text("CLEAR")
                .font(.system(size: 9.5, weight: .bold))
                .tracking(0.8)
                .foregroundColor(goldColor)
                .offset(y: -1)
        }
        .frame(width: spanWidth, height: 14)
    }

    private func keyCell(_ key: Key) -> some View {
        VStack(spacing: 2) {
            Text(key.labels.gold ?? "")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(goldColor)
                .frame(height: goldStripHeight)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HPKeyButton(
                key: key,
                isPressed: viewModel.pressedKey == key || viewModel.mousePressedKey == key,
                goldColor: goldColor,
                blueColor: blueColor,
                height: keyHeight,
                onPressChanged: { down in
                    viewModel.mousePressedKey = down ? key : nil
                },
                action: {
                    viewModel.press(key)
                }
            )
            .frame(width: cellWidth, height: keyHeight)
        }
        .frame(width: cellWidth)
    }

    private var enterKeyCell: some View {
        let tallHeight = keyHeight * 2 + goldStripHeight + rowSpacing + 2
        return VStack(spacing: 2) {
            Text(Key.enter.labels.gold ?? "")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(goldColor)
                .frame(height: goldStripHeight)

            HPKeyButton(
                key: .enter,
                isPressed: viewModel.pressedKey == .enter || viewModel.mousePressedKey == .enter,
                goldColor: goldColor,
                blueColor: blueColor,
                height: tallHeight,
                isEnter: true,
                onPressChanged: { down in
                    viewModel.mousePressedKey = down ? .enter : nil
                },
                action: {
                    viewModel.press(.enter)
                }
            )
            .frame(width: cellWidth, height: tallHeight)
        }
        .frame(width: cellWidth)
    }
}

private struct HPKeyButton: View {
    let key: Key
    let isPressed: Bool
    let goldColor: Color
    let blueColor: Color
    let height: CGFloat
    var isEnter: Bool = false
    let onPressChanged: (Bool) -> Void
    let action: () -> Void

    private var isGoldKey: Bool { key == .f }
    private var isBlueKey: Bool { key == .g }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Keycap body
            RoundedRectangle(cornerRadius: 5)
                .fill(keyGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.black.opacity(0.85), lineWidth: 1.2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(isGoldKey || isBlueKey ? 0.25 : 0.10), lineWidth: 0.8)
                        .padding(1)
                )
                .shadow(color: .black.opacity(0.6), radius: isPressed ? 0.5 : 2.5, x: 0, y: isPressed ? 0.5 : 2)

            VStack(spacing: 0) {
                // Primary white/black top face
                ZStack {
                    if isEnter {
                        VStack(spacing: 2) {
                            ForEach(["E", "N", "T", "E", "R"], id: \.self) { letter in
                                Text(letter)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    } else {
                        Text(key.labels.primary)
                            .font(.system(size: primaryFontSize, weight: .semibold))
                            .foregroundColor((isGoldKey || isBlueKey) ? Color(hex: 0x151515) : .white)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4)

                // Lower front blue-label bevel strip
                if let blueLabel = key.labels.blue {
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.32))
                        Text(blueLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(blueColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(height: 16)
                } else {
                    Spacer().frame(height: 4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))

            if isPressed {
                RoundedRectangle(cornerRadius: 5)
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
                    if value.location.x >= -8 && value.location.x <= 84 &&
                       value.location.y >= -8 && value.location.y <= height + 8 {
                        action()
                    }
                }
        )
    }

    private var primaryFontSize: CGFloat {
        if key.digitValue != nil || key == .dot {
            return 18
        }
        if key == .add || key == .sub || key == .mul || key == .div {
            return 19
        }
        if isGoldKey || isBlueKey {
            return 17
        }
        return 14
    }

    private var keyGradient: LinearGradient {
        if isGoldKey {
            return LinearGradient(
                colors: [Color(hex: 0xE6AD36), Color(hex: 0xC68C1C)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        if isBlueKey {
            return LinearGradient(
                colors: [Color(hex: 0x58A0E0), Color(hex: 0x3576B5)],
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
