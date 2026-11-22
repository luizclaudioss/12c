import Foundation
import Testing
@testable import HP12CCore

func keys(_ s: String) -> [Key] {
    var result: [Key] = []
    let tokens = s.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    for token in tokens {
        if token == "CLEAR" {
            continue
        }
        if let mapped = singleTokenKey(token) {
            result.append(mapped)
            continue
        }
        // Check if token is digits and dots (e.g. "1000", "58.5", ".2", "06")
        if !token.isEmpty && token.allSatisfy({ ($0 >= "0" && $0 <= "9") || $0 == "." }) {
            for ch in token {
                if ch == "." {
                    result.append(.dot)
                } else if let d = Int(String(ch)), let k = Key.digit(d) {
                    result.append(k)
                }
            }
            continue
        }
        fatalError("Unknown key token in test helper: '\(token)'")
    }
    return result
}

private func singleTokenKey(_ token: String) -> Key? {
    switch token {
    case "n": return .n
    case "i": return .i
    case "PV": return .pv
    case "PMT": return .pmt
    case "FV": return .fv
    case "CHS": return .chs
    case "/", "÷": return .div
    case "yˣ", "y^x", "^": return .yx
    case "1/x": return .recip
    case "%T": return .pctT
    case "Δ%": return .dPct
    case "%": return .pct
    case "EEX": return .eex
    case "*", "×": return .mul
    case "R/S": return .rs
    case "SST": return .sst
    case "R↓": return .rdown
    case "x≷y", "x<->y": return .swap
    case "CLx": return .clx
    case "ENTER": return .enter
    case "-", "−": return .sub
    case "ON": return .on
    case "f": return .f
    case "g": return .g
    case "STO": return .sto
    case "RCL": return .rcl
    case ".": return .dot
    case "Σ+": return .sigmaPlus
    case "+": return .add

    // Alternate gold/blue labels accepted as direct key tokens (after f or g prefix)
    case "AMORT", "12×", "12x": return .n
    case "INT", "12÷": return .i
    case "NPV", "CF₀", "CF0": return .pv
    case "RND", "CFⱼ", "CFj": return .pmt
    case "IRR", "Nⱼ", "Nj": return .fv
    case "DATE": return .chs
    case "BEG": return .d7
    case "END": return .d8
    case "MEM": return .d9
    case "PRICE", "√x": return .yx
    case "YTM", "eˣ": return .recip
    case "SL", "LN": return .pctT
    case "SOYD", "FRAC": return .dPct
    case "DB", "INTG": return .pct
    case "ΔDYS": return .eex
    case "D.MY": return .d4
    case "M.DY": return .d5
    case "x̄w": return .d6
    case "x²": return .mul
    case "P/R", "PSE": return .rs
    case "Σ", "BST": return .sst
    case "PRGM", "GTO": return .rdown
    case "FIN", "x≤y": return .swap
    case "REG", "x=0": return .clx
    case "PREFIX", "LSTx": return .enter
    case "x̂,r": return .d1
    case "ŷ,r", "yHat,r": return .d2
    case "n!": return .d3
    case "x̄": return .d0
    case "s": return .dot
    case "Σ−", "Σ-": return .sigmaPlus
    default: return nil
    }
}

extension HP12C {
    func pressSequence(_ s: String) {
        for k in keys(s) {
            press(k)
        }
    }
}

func approxEqual(_ a: Double, _ b: Double, tol: Double = 1e-6) -> Bool {
    abs(a - b) <= tol
}
