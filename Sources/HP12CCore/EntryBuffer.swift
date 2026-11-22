import Foundation

public struct EntryBuffer: Equatable, Sendable {
    public private(set) var isActive: Bool = false
    public private(set) var mantissa: String = "0"
    public private(set) var isNegative: Bool = false
    public private(set) var inExponent: Bool = false
    public private(set) var expDigits: String = ""
    public private(set) var expNegative: Bool = false

    public init() {}

    public var hasDot: Bool {
        mantissa.contains(".")
    }

    public var digitCount: Int {
        mantissa.reduce(0) { $1 == "." ? $0 : $0 + 1 }
    }

    public mutating func reset() {
        isActive = false
        mantissa = "0"
        isNegative = false
        inExponent = false
        expDigits = ""
        expNegative = false
    }

    public mutating func beginDigit(_ d: Int) {
        isActive = true
        mantissa = "\(d)"
        isNegative = false
        inExponent = false
        expDigits = ""
        expNegative = false
    }

    public mutating func beginDot() {
        isActive = true
        mantissa = "0."
        isNegative = false
        inExponent = false
        expDigits = ""
        expNegative = false
    }

    public mutating func beginEEX() {
        isActive = true
        mantissa = "1"
        isNegative = false
        inExponent = true
        expDigits = ""
        expNegative = false
    }

    public mutating func appendDigit(_ d: Int) {
        if inExponent {
            if expDigits.count < 2 {
                expDigits.append("\(d)")
            }
        } else {
            if mantissa == "0" {
                mantissa = "\(d)"
            } else if digitCount < 10 {
                mantissa.append("\(d)")
            }
        }
    }

    public mutating func appendDot() {
        guard !inExponent, !hasDot else { return }
        mantissa.append(".")
    }

    public mutating func toggleEEX() {
        guard !inExponent else { return }
        if digitCount <= 7 {
            inExponent = true
        }
    }

    public mutating func toggleSign() {
        if inExponent {
            expNegative.toggle()
        } else {
            isNegative.toggle()
        }
    }

    /// Removes the last typed character. Returns false if entry is completely emptied.
    public mutating func backspace() -> Bool {
        if inExponent {
            if !expDigits.isEmpty {
                expDigits.removeLast()
            } else if expNegative {
                expNegative = false
            } else {
                inExponent = false
            }
            return true
        } else {
            if mantissa.count > 1 {
                mantissa.removeLast()
                return !mantissa.isEmpty
            } else {
                reset()
                return false
            }
        }
    }

    public var numericValue: Double {
        let m = Double(mantissa) ?? 0.0
        let signedM = isNegative ? -m : m
        if inExponent {
            let e = Int(expDigits) ?? 0
            let signedE = expNegative ? -e : e
            let raw = signedM * pow(10.0, Double(signedE))
            return Numeric.normalize(raw)?.value ?? 0.0
        }
        return signedM == 0.0 ? 0.0 : signedM
    }

    public func formatted(european: Bool) -> String {
        let sign = isNegative ? "-" : ""
        if inExponent {
            let mStr = hasDot ? mantissa : mantissa + "."
            let cells = mStr.reduce(0) { $1 == "." ? $0 : $0 + 1 }
            let pad = String(repeating: " ", count: max(0, 7 - cells))
            let eSign = expNegative ? "-" : " "
            let eStr: String
            switch expDigits.count {
            case 0:  eStr = "00"
            case 1:  eStr = "0" + expDigits
            default: eStr = expDigits
            }
            let raw = sign + mStr + pad + eSign + eStr
            return DisplayFormatter.applySeparator(raw, european: european, hasThousandsGrouping: false)
        } else {
            let parts = mantissa.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            let intPart = String(parts[0])
            let grouped = DisplayFormatter.groupThousands(intPart)
            let raw: String
            if hasDot {
                let fracPart = parts.count > 1 ? String(parts[1]) : ""
                raw = sign + grouped + "." + fracPart
            } else {
                raw = sign + grouped + "."
            }
            return DisplayFormatter.applySeparator(raw, european: european, hasThousandsGrouping: true)
        }
    }
}
