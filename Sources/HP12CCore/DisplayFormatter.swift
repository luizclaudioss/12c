import Foundation

public enum DisplayFormatter {
    public static func format(
        state: HP12CState,
        entry: EntryBuffer,
        isRunning: Bool,
        isPausedForPSE: Bool,
        blinking: Bool,
        message: DisplayMessage?,
        dateDisplay: (value: Double, dow: Int)?
    ) -> String {
        guard state.isOn else {
            return ""
        }
        if isRunning && !isPausedForPSE {
            return "running"
        }
        if let message = message {
            return message.text
        }
        if state.prgmMode {
            if state.pc <= 0 || state.pc > state.program.count {
                return "00-"
            }
            return state.program[state.pc - 1].formattedLine(state.pc)
        }
        if let dateInfo = dateDisplay {
            return formatDate(dateInfo.value, dow: dateInfo.dow, european: state.european)
        }
        if entry.isActive {
            return entry.formatted(european: state.european)
        }
        if blinking || abs(state.x) > Numeric.maxValue {
            let raw = (state.x < 0 ? "-" : "") + "9.999999 99"
            return applySeparator(raw, european: state.european, hasThousandsGrouping: false)
        }
        switch state.displayMode {
        case .fix(let k):
            return formatFix(state.x, decimals: k, european: state.european)
        case .sci:
            return formatSci(state.x, european: state.european)
        }
    }

    public static func formatFix(_ v: Double, decimals k: Int, european: Bool) -> String {
        if !v.isFinite {
            return formatSci(v, european: european)
        }
        if v == 0 {
            let raw = k == 0 ? "0" : "0." + String(repeating: "0", count: k)
            return applySeparator(raw, european: european, hasThousandsGrouping: true)
        }
        let neg = v < 0
        let mag = abs(v)
        if mag >= 1e10 {
            return formatSci(v, european: european)
        }

        let intDigits0 = mag < 1.0 ? 1 : max(1, Int(floor(log10(mag))) + 1)
        var d = min(k, max(0, 10 - intDigits0))
        var rounded = Numeric.roundDecimal(mag, scale: d)
        if rounded >= 1e10 || rounded == 0 {
            return formatSci(v, european: european)
        }

        let intDigits1 = rounded < 1.0 ? 1 : max(1, Int(floor(log10(rounded))) + 1)
        if intDigits1 != intDigits0 {
            d = min(k, max(0, 10 - intDigits1))
            rounded = Numeric.roundDecimal(mag, scale: d)
            if rounded >= 1e10 || rounded == 0 {
                return formatSci(v, european: european)
            }
        }

        let formatted = String(format: "%.\(d)f", rounded)
        let parts = formatted.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let intPart = groupThousands(String(parts[0]))
        let raw: String
        if d > 0 && parts.count > 1 {
            raw = (neg ? "-" : "") + intPart + "." + String(parts[1])
        } else {
            raw = (neg ? "-" : "") + intPart
        }
        return applySeparator(raw, european: european, hasThousandsGrouping: true)
    }

    public static func formatSci(_ v: Double, european: Bool) -> String {
        if v == 0 {
            return applySeparator("0.000000 00", european: european, hasThousandsGrouping: false)
        }
        let neg = v < 0
        let mag = abs(v)
        if !mag.isFinite || mag >= 9.9999995e99 {
            let raw = (neg ? "-" : "") + "9.999999 99"
            return applySeparator(raw, european: european, hasThousandsGrouping: false)
        }

        // Parse 10-digit scientific representation, then decimal-round mantissa to 6 decimals
        let s10 = String(format: "%.9e", mag)
        guard let eIdx = s10.firstIndex(of: "e") else {
            return applySeparator("0.000000 00", european: european, hasThousandsGrouping: false)
        }
        let mantissaStr = String(s10[..<eIdx])
        let expPart = String(s10[s10.index(after: eIdx)...])
        var exp = Int(expPart) ?? 0
        guard var mantissaDec = Decimal(string: mantissaStr) else {
            return applySeparator("0.000000 00", european: european, hasThousandsGrouping: false)
        }
        var roundedDec = Decimal()
        NSDecimalRound(&roundedDec, &mantissaDec, 6, .plain)
        var mantissaDouble = NSDecimalNumber(decimal: roundedDec).doubleValue
        if mantissaDouble >= 10.0 {
            mantissaDouble /= 10.0
            exp += 1
        }
        if exp > 99 {
            let raw = (neg ? "-" : "") + "9.999999 99"
            return applySeparator(raw, european: european, hasThousandsGrouping: false)
        }
        if exp < -99 {
            return applySeparator("0.000000 00", european: european, hasThousandsGrouping: false)
        }

        let mStr = String(format: "%.6f", mantissaDouble)
        let expSign = exp < 0 ? "-" : " "
        let expStr = String(format: "%02d", abs(exp))
        let raw = (neg ? "-" : "") + mStr + expSign + expStr
        return applySeparator(raw, european: european, hasThousandsGrouping: false)
    }

    public static func formatDate(_ dateValue: Double, dow: Int, european: Bool) -> String {
        let s = String(format: "%.6f", abs(dateValue))
        let cellCount = s.reduce(0) { $1 == "." ? $0 : $0 + 1 }
        let spaces = String(repeating: " ", count: max(1, 9 - cellCount))
        let raw = s + spaces + "\(dow)"
        return applySeparator(raw, european: european, hasThousandsGrouping: false)
    }

    public static func groupThousands(_ intDigits: String) -> String {
        let chars = Array(intDigits)
        guard chars.count > 3 else { return intDigits }
        var out: [Character] = []
        out.reserveCapacity(chars.count + chars.count / 3)
        for (idx, ch) in chars.reversed().enumerated() {
            if idx > 0 && idx % 3 == 0 {
                out.append(",")
            }
            out.append(ch)
        }
        return String(out.reversed())
    }

    public static func applySeparator(_ s: String, european: Bool, hasThousandsGrouping: Bool) -> String {
        guard european else { return s }
        if !hasThousandsGrouping {
            return s.replacingOccurrences(of: ".", with: ",")
        }
        return String(s.map { ch in
            if ch == "." { return "," }
            if ch == "," { return "." }
            return ch
        })
    }
}
