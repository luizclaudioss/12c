import Foundation

public enum Numeric {
    public static let maxValue: Double = 9.999999999e99
    public static let minNonZero: Double = 1e-99

    /// Normalizes a computed result to 10 significant digits, clamping overflow and zeroing underflow.
    /// Returns nil only when `v` is NaN.
    public static func normalize(_ v: Double) -> (value: Double, overflow: Bool)? {
        if v.isNaN { return nil }
        if v == 0 { return (0.0, false) }
        if v.isInfinite || abs(v) > 1e101 {
            return (v > 0 ? maxValue : -maxValue, true)
        }
        let s = String(format: "%.9e", v)
        guard let rounded = Double(s) else { return nil }
        if abs(rounded) > maxValue {
            return (rounded > 0 ? maxValue : -maxValue, true)
        }
        if abs(rounded) < minNonZero {
            return (0.0, false)
        }
        return (rounded == 0 ? 0.0 : rounded, false)
    }

    /// Rounds a Double to `scale` decimal places using decimal half-away-from-zero rounding.
    public static func roundDecimal(_ v: Double, scale: Int) -> Double {
        if v == 0 || v.isNaN || v.isInfinite { return v == 0 ? 0.0 : v }
        let s = String(format: "%.9e", v)
        guard var dec = Decimal(string: s) else { return v }
        var result = Decimal()
        NSDecimalRound(&result, &dec, scale, .plain)
        let d = NSDecimalNumber(decimal: result).doubleValue
        return d == 0 ? 0.0 : d
    }

    /// Rounds `v` to `digits` significant figures (for SCI display/RND, digits = 7 gives 6 decimal places).
    public static func roundSignificant(_ v: Double, digits: Int) -> Double {
        if v == 0 || v.isNaN || v.isInfinite { return v == 0 ? 0.0 : v }
        let s = String(format: "%.\(digits - 1)e", v)
        let d = Double(s) ?? v
        return d == 0 ? 0.0 : d
    }

    /// Returns the 10-digit mantissa string of `v` with no sign or punctuation (used by f CLEAR PREFIX).
    public static func mantissaDigits10(_ v: Double) -> String {
        if v == 0 || !v.isFinite {
            return "0000000000"
        }
        let s = String(format: "%.9e", abs(v))
        guard let eIdx = s.firstIndex(of: "e") else { return "0000000000" }
        let mantissa = String(s[..<eIdx]).replacingOccurrences(of: ".", with: "")
        if mantissa.count >= 10 {
            return String(mantissa.prefix(10))
        }
        return mantissa + String(repeating: "0", count: 10 - mantissa.count)
    }

    /// Checks whether `v` is an exact integer (within Double integer range).
    public static func exactInteger(_ v: Double) -> Int? {
        guard v.isFinite, v >= Double(Int.min), v <= Double(Int.max) else { return nil }
        if v.rounded(.towardZero) == v {
            return Int(v)
        }
        return nil
    }
}
