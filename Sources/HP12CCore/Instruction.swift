import Foundation

public enum ArithOp: String, Codable, Equatable, Sendable {
    case add, sub, mul, div

    public var keycode: Int {
        switch self {
        case .add: return Key.add.rawValue
        case .sub: return Key.sub.rawValue
        case .mul: return Key.mul.rawValue
        case .div: return Key.div.rawValue
        }
    }
}

public enum FinReg: String, Codable, Equatable, Sendable {
    case n, i, pv, pmt, fv

    public var keycode: Int {
        switch self {
        case .n: return Key.n.rawValue
        case .i: return Key.i.rawValue
        case .pv: return Key.pv.rawValue
        case .pmt: return Key.pmt.rawValue
        case .fv: return Key.fv.rawValue
        }
    }
}

public enum Op: Codable, Equatable, Sendable {
    // Entry
    case digit(Int)
    case dot
    case chs
    case eex

    // Stack & arithmetic
    case add, sub, mul, div
    case enter
    case clx
    case swap
    case rdown
    case lstx

    // Math & percentage
    case yx
    case recip
    case sqrt
    case exp
    case ln
    case frac
    case intg
    case sq
    case factorial
    case pct
    case dPct
    case pctT
    case rnd

    // Financial
    case finN, finI, finPV, finPMT, finFV
    case amort
    case int
    case npv
    case irr
    case irrWithGuess
    case price
    case ytm
    case sl
    case soyd
    case db
    case times12
    case div12
    case cf0
    case cfj
    case nj
    case recallCFj
    case recallNj

    // Modes
    case fix(Int)
    case sci
    case beg
    case end
    case dmy
    case my
    case toggleCompound

    // Clear & info
    case clearSigma
    case clearPRGM
    case clearFIN
    case clearREG
    case clearPREFIX
    case mem
    case on

    // Calendar & statistics
    case date
    case deltaDays
    case sigmaPlus
    case sigmaMinus
    case mean
    case stdDev
    case weightedMean
    case xHatR
    case yHatR

    // Storage / Recall
    case store(Int)
    case storeArith(ArithOp, Int)
    case storeFin(FinReg)
    case recall(Int)
    case recallFin(FinReg)

    // Programming
    case rs
    case pr
    case pse
    case sst
    case bst
    case gto(Int)
    case gotoLine(Int)
    case xLeY
    case xEq0

    // Direct error (e.g. STO + 5)
    case error(Int)
}

public struct Instruction: Codable, Equatable, Sendable {
    public let op: Op
    public let keycodes: [Int]
    public let isProgrammable: Bool

    public init(op: Op, keycodes: [Int], isProgrammable: Bool = true) {
        self.op = op
        self.keycodes = keycodes
        self.isProgrammable = isProgrammable
    }

    /// Formats the instruction for a program line (`nn-` + keycodes right-aligned in 7 LCD cells).
    public func formattedLine(_ lineNumber: Int) -> String {
        let prefix = String(format: "%02d-", lineNumber)
        let tokens = displayTokens
        let body: String
        switch tokens.count {
        case 0:
            body = ""
        case 1:
            body = tokens[0]
        case 2:
            body = "\(tokens[0]) \(tokens[1])"
        default:
            if tokens[2].count >= 2 {
                body = "\(tokens[0]),\(tokens[1]) \(tokens[2])"
            } else {
                body = "\(tokens[0]) \(tokens[1]) \(tokens[2])"
            }
        }
        let cellCount = body.reduce(0) { $1 == "," ? $0 : $0 + 1 }
        let padding = max(0, 7 - cellCount)
        return prefix + String(repeating: " ", count: padding) + body
    }

    private var displayTokens: [String] {
        switch op {
        case .gto(let nn):
            return ["43", "33", String(format: "%02d", nn)]
        case .store(let r) where r >= 10:
            return ["44", "48", "\(r - 10)"]
        case .recall(let r) where r >= 10:
            return ["45", "48", "\(r - 10)"]
        default:
            return keycodes.map { String($0) }
        }
    }
}
