import Foundation

/// Represents every physical key on the HP 12C keyboard.
/// The raw value corresponds to the standard HP 12C two-digit keycode (single digit for 0–9).
public enum Key: Int, CaseIterable, Codable, Sendable {
    // Row 1
    case n = 11
    case i = 12
    case pv = 13
    case pmt = 14
    case fv = 15
    case chs = 16
    case d7 = 7
    case d8 = 8
    case d9 = 9
    case div = 10

    // Row 2
    case yx = 21
    case recip = 22
    case pctT = 23
    case dPct = 24
    case pct = 25
    case eex = 26
    case d4 = 4
    case d5 = 5
    case d6 = 6
    case mul = 20

    // Row 3
    case rs = 31
    case sst = 32
    case rdown = 33
    case swap = 34
    case clx = 35
    case enter = 36
    case d1 = 1
    case d2 = 2
    case d3 = 3
    case sub = 30

    // Row 4
    case on = 41
    case f = 42
    case g = 43
    case sto = 44
    case rcl = 45
    case d0 = 0
    case dot = 48
    case sigmaPlus = 49
    case add = 40

    public var digitValue: Int? {
        switch self {
        case .d0: return 0
        case .d1: return 1
        case .d2: return 2
        case .d3: return 3
        case .d4: return 4
        case .d5: return 5
        case .d6: return 6
        case .d7: return 7
        case .d8: return 8
        case .d9: return 9
        default: return nil
        }
    }

    public static func digit(_ d: Int) -> Key? {
        switch d {
        case 0: return .d0
        case 1: return .d1
        case 2: return .d2
        case 3: return .d3
        case 4: return .d4
        case 5: return .d5
        case 6: return .d6
        case 7: return .d7
        case 8: return .d8
        case 9: return .d9
        default: return nil
        }
    }

    public struct Labels {
        public let primary: String
        public let gold: String?
        public let blue: String?
    }

    public var labels: Labels {
        switch self {
        case .n:         return Labels(primary: "n", gold: "AMORT", blue: "12×")
        case .i:         return Labels(primary: "i", gold: "INT", blue: "12÷")
        case .pv:        return Labels(primary: "PV", gold: "NPV", blue: "CFo")
        case .pmt:       return Labels(primary: "PMT", gold: "RND", blue: "CFj")
        case .fv:        return Labels(primary: "FV", gold: "IRR", blue: "Nj")
        case .chs:       return Labels(primary: "CHS", gold: nil, blue: "DATE")
        case .d7:        return Labels(primary: "7", gold: nil, blue: "BEG")
        case .d8:        return Labels(primary: "8", gold: nil, blue: "END")
        case .d9:        return Labels(primary: "9", gold: nil, blue: "MEM")
        case .div:       return Labels(primary: "÷", gold: nil, blue: nil)

        case .yx:        return Labels(primary: "yˣ", gold: "PRICE", blue: "√x")
        case .recip:     return Labels(primary: "1/x", gold: "YTM", blue: "eˣ")
        case .pctT:      return Labels(primary: "%T", gold: "SL", blue: "LN")
        case .dPct:      return Labels(primary: "Δ%", gold: "SOYD", blue: "FRAC")
        case .pct:       return Labels(primary: "%", gold: "DB", blue: "INTG")
        case .eex:       return Labels(primary: "EEX", gold: nil, blue: "ΔDYS")
        case .d4:        return Labels(primary: "4", gold: nil, blue: "D.MY")
        case .d5:        return Labels(primary: "5", gold: nil, blue: "M.DY")
        case .d6:        return Labels(primary: "6", gold: nil, blue: "x̄w")
        case .mul:       return Labels(primary: "×", gold: nil, blue: "x²")

        case .rs:        return Labels(primary: "R/S", gold: "P/R", blue: "PSE")
        case .sst:       return Labels(primary: "SST", gold: "Σ", blue: "BST")
        case .rdown:     return Labels(primary: "R↓", gold: "PRGM", blue: "GTO")
        case .swap:      return Labels(primary: "x≷y", gold: "FIN", blue: "x≤y")
        case .clx:       return Labels(primary: "CLx", gold: "REG", blue: "x=0")
        case .enter:     return Labels(primary: "ENTER", gold: "PREFIX", blue: "LSTx")
        case .d1:        return Labels(primary: "1", gold: nil, blue: "x̂,r")
        case .d2:        return Labels(primary: "2", gold: nil, blue: "ŷ,r")
        case .d3:        return Labels(primary: "3", gold: nil, blue: "n!")
        case .sub:       return Labels(primary: "−", gold: nil, blue: nil)

        case .on:        return Labels(primary: "ON", gold: nil, blue: nil)
        case .f:         return Labels(primary: "f", gold: nil, blue: nil)
        case .g:         return Labels(primary: "g", gold: nil, blue: nil)
        case .sto:       return Labels(primary: "STO", gold: nil, blue: nil)
        case .rcl:       return Labels(primary: "RCL", gold: nil, blue: nil)
        case .d0:        return Labels(primary: "0", gold: nil, blue: "x̄")
        case .dot:       return Labels(primary: "·", gold: nil, blue: "s")
        case .sigmaPlus: return Labels(primary: "Σ+", gold: nil, blue: "Σ−")
        case .add:       return Labels(primary: "+", gold: nil, blue: nil)
        }
    }
}
