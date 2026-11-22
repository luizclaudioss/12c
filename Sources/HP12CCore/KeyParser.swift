import Foundation

public struct KeyParser: Sendable {
    public enum PendingState: Equatable, Sendable {
        case none
        case f
        case g
        case sto
        case stoDot
        case stoArith(ArithOp)
        case rcl
        case rclDot
        case rclG
        case gto
        case gto1(Int)
        case gtoDot
        case gtoDot1(Int)
    }

    public private(set) var pending: PendingState = .none

    public init() {}

    public mutating func reset() {
        pending = .none
    }

    public mutating func feed(_ key: Key) -> Instruction? {
        switch pending {
        case .none:
            return parsePlain(key)
        case .f:
            return parseF(key)
        case .g:
            return parseG(key)
        case .sto:
            return parseSto(key)
        case .stoDot:
            pending = .none
            if let d = key.digitValue {
                return Instruction(op: .store(10 + d), keycodes: [Key.sto.rawValue, Key.dot.rawValue, d])
            }
            return nil
        case .stoArith(let op):
            pending = .none
            if let d = key.digitValue {
                if d <= 4 {
                    return Instruction(op: .storeArith(op, d), keycodes: [Key.sto.rawValue, op.keycode, d])
                } else {
                    return Instruction(op: .error(6), keycodes: [], isProgrammable: false)
                }
            } else if key == .dot {
                return Instruction(op: .error(6), keycodes: [], isProgrammable: false)
            }
            return nil
        case .rcl:
            return parseRcl(key)
        case .rclDot:
            pending = .none
            if let d = key.digitValue {
                return Instruction(op: .recall(10 + d), keycodes: [Key.rcl.rawValue, Key.dot.rawValue, d])
            }
            return nil
        case .rclG:
            pending = .none
            switch key {
            case .pmt:
                return Instruction(op: .recallCFj, keycodes: [Key.rcl.rawValue, Key.g.rawValue, Key.pmt.rawValue])
            case .fv:
                return Instruction(op: .recallNj, keycodes: [Key.rcl.rawValue, Key.g.rawValue, Key.fv.rawValue])
            case .rs:
                return Instruction(op: .irrWithGuess, keycodes: [Key.rcl.rawValue, Key.g.rawValue, Key.rs.rawValue])
            default:
                return nil
            }
        case .gto:
            if let d = key.digitValue {
                pending = .gto1(d)
                return nil
            } else if key == .dot {
                pending = .gtoDot
                return nil
            }
            pending = .none
            return nil
        case .gto1(let d1):
            pending = .none
            if let d2 = key.digitValue {
                let target = 10 * d1 + d2
                return Instruction(op: .gto(target), keycodes: [Key.g.rawValue, Key.rdown.rawValue, target])
            }
            return nil
        case .gtoDot:
            if let d = key.digitValue {
                pending = .gtoDot1(d)
                return nil
            }
            pending = .none
            return nil
        case .gtoDot1(let d1):
            pending = .none
            if let d2 = key.digitValue {
                let target = 10 * d1 + d2
                return Instruction(op: .gotoLine(target), keycodes: [], isProgrammable: false)
            }
            return nil
        }
    }

    private mutating func parsePlain(_ key: Key) -> Instruction? {
        if let d = key.digitValue {
            return Instruction(op: .digit(d), keycodes: [d])
        }
        switch key {
        case .dot:       return Instruction(op: .dot, keycodes: [key.rawValue])
        case .chs:       return Instruction(op: .chs, keycodes: [key.rawValue])
        case .eex:       return Instruction(op: .eex, keycodes: [key.rawValue])
        case .add:       return Instruction(op: .add, keycodes: [key.rawValue])
        case .sub:       return Instruction(op: .sub, keycodes: [key.rawValue])
        case .mul:       return Instruction(op: .mul, keycodes: [key.rawValue])
        case .div:       return Instruction(op: .div, keycodes: [key.rawValue])
        case .yx:        return Instruction(op: .yx, keycodes: [key.rawValue])
        case .recip:     return Instruction(op: .recip, keycodes: [key.rawValue])
        case .pctT:      return Instruction(op: .pctT, keycodes: [key.rawValue])
        case .dPct:      return Instruction(op: .dPct, keycodes: [key.rawValue])
        case .pct:       return Instruction(op: .pct, keycodes: [key.rawValue])
        case .rs:        return Instruction(op: .rs, keycodes: [key.rawValue])
        case .sst:       return Instruction(op: .sst, keycodes: [key.rawValue], isProgrammable: false)
        case .rdown:     return Instruction(op: .rdown, keycodes: [key.rawValue])
        case .swap:      return Instruction(op: .swap, keycodes: [key.rawValue])
        case .clx:       return Instruction(op: .clx, keycodes: [key.rawValue])
        case .enter:     return Instruction(op: .enter, keycodes: [key.rawValue])
        case .sigmaPlus: return Instruction(op: .sigmaPlus, keycodes: [key.rawValue])
        case .n:         return Instruction(op: .finN, keycodes: [key.rawValue])
        case .i:         return Instruction(op: .finI, keycodes: [key.rawValue])
        case .pv:        return Instruction(op: .finPV, keycodes: [key.rawValue])
        case .pmt:       return Instruction(op: .finPMT, keycodes: [key.rawValue])
        case .fv:        return Instruction(op: .finFV, keycodes: [key.rawValue])
        case .on:        return Instruction(op: .on, keycodes: [key.rawValue], isProgrammable: false)
        case .f:
            pending = .f
            return nil
        case .g:
            pending = .g
            return nil
        case .sto:
            pending = .sto
            return nil
        case .rcl:
            pending = .rcl
            return nil
        default:
            return nil
        }
    }

    private mutating func parseF(_ key: Key) -> Instruction? {
        if key == .f {
            pending = .f
            return nil
        }
        if key == .g {
            pending = .g
            return nil
        }
        pending = .none
        let fCode = Key.f.rawValue
        if let d = key.digitValue {
            return Instruction(op: .fix(d), keycodes: [fCode, d])
        }
        switch key {
        case .n:     return Instruction(op: .amort, keycodes: [fCode, key.rawValue])
        case .i:     return Instruction(op: .int, keycodes: [fCode, key.rawValue])
        case .pv:    return Instruction(op: .npv, keycodes: [fCode, key.rawValue])
        case .pmt:   return Instruction(op: .rnd, keycodes: [fCode, key.rawValue])
        case .fv:    return Instruction(op: .irr, keycodes: [fCode, key.rawValue])
        case .yx:    return Instruction(op: .price, keycodes: [fCode, key.rawValue])
        case .recip: return Instruction(op: .ytm, keycodes: [fCode, key.rawValue])
        case .pctT:  return Instruction(op: .sl, keycodes: [fCode, key.rawValue])
        case .dPct:  return Instruction(op: .soyd, keycodes: [fCode, key.rawValue])
        case .pct:   return Instruction(op: .db, keycodes: [fCode, key.rawValue])
        case .rs:    return Instruction(op: .pr, keycodes: [fCode, key.rawValue], isProgrammable: false)
        case .sst:   return Instruction(op: .clearSigma, keycodes: [fCode, key.rawValue])
        case .rdown: return Instruction(op: .clearPRGM, keycodes: [fCode, key.rawValue], isProgrammable: false)
        case .swap:  return Instruction(op: .clearFIN, keycodes: [fCode, key.rawValue])
        case .clx:   return Instruction(op: .clearREG, keycodes: [fCode, key.rawValue])
        case .enter: return Instruction(op: .clearPREFIX, keycodes: [fCode, key.rawValue], isProgrammable: false)
        case .dot:   return Instruction(op: .sci, keycodes: [fCode, key.rawValue])
        default:     return nil
        }
    }

    private mutating func parseG(_ key: Key) -> Instruction? {
        if key == .g {
            pending = .g
            return nil
        }
        if key == .f {
            pending = .f
            return nil
        }
        pending = .none
        let gCode = Key.g.rawValue
        switch key {
        case .n:         return Instruction(op: .times12, keycodes: [gCode, key.rawValue])
        case .i:         return Instruction(op: .div12, keycodes: [gCode, key.rawValue])
        case .pv:        return Instruction(op: .cf0, keycodes: [gCode, key.rawValue])
        case .pmt:       return Instruction(op: .cfj, keycodes: [gCode, key.rawValue])
        case .fv:        return Instruction(op: .nj, keycodes: [gCode, key.rawValue])
        case .chs:       return Instruction(op: .date, keycodes: [gCode, key.rawValue])
        case .d7:        return Instruction(op: .beg, keycodes: [gCode, key.rawValue])
        case .d8:        return Instruction(op: .end, keycodes: [gCode, key.rawValue])
        case .d9:        return Instruction(op: .mem, keycodes: [gCode, key.rawValue], isProgrammable: false)
        case .yx:        return Instruction(op: .sqrt, keycodes: [gCode, key.rawValue])
        case .recip:     return Instruction(op: .exp, keycodes: [gCode, key.rawValue])
        case .pctT:      return Instruction(op: .ln, keycodes: [gCode, key.rawValue])
        case .dPct:      return Instruction(op: .frac, keycodes: [gCode, key.rawValue])
        case .pct:       return Instruction(op: .intg, keycodes: [gCode, key.rawValue])
        case .eex:       return Instruction(op: .deltaDays, keycodes: [gCode, key.rawValue])
        case .d4:        return Instruction(op: .dmy, keycodes: [gCode, key.rawValue])
        case .d5:        return Instruction(op: .my, keycodes: [gCode, key.rawValue])
        case .d6:        return Instruction(op: .weightedMean, keycodes: [gCode, key.rawValue])
        case .mul:       return Instruction(op: .sq, keycodes: [gCode, key.rawValue])
        case .rs:        return Instruction(op: .pse, keycodes: [gCode, key.rawValue])
        case .sst:       return Instruction(op: .bst, keycodes: [gCode, key.rawValue], isProgrammable: false)
        case .rdown:
            pending = .gto
            return nil
        case .swap:      return Instruction(op: .xLeY, keycodes: [gCode, key.rawValue])
        case .clx:       return Instruction(op: .xEq0, keycodes: [gCode, key.rawValue])
        case .enter:     return Instruction(op: .lstx, keycodes: [gCode, key.rawValue])
        case .d1:        return Instruction(op: .xHatR, keycodes: [gCode, key.rawValue])
        case .d2:        return Instruction(op: .yHatR, keycodes: [gCode, key.rawValue])
        case .d3:        return Instruction(op: .factorial, keycodes: [gCode, key.rawValue])
        case .d0:        return Instruction(op: .mean, keycodes: [gCode, key.rawValue])
        case .dot:       return Instruction(op: .stdDev, keycodes: [gCode, key.rawValue])
        case .sigmaPlus: return Instruction(op: .sigmaMinus, keycodes: [gCode, key.rawValue])
        default:         return nil
        }
    }

    private mutating func parseSto(_ key: Key) -> Instruction? {
        pending = .none
        let sCode = Key.sto.rawValue
        if let d = key.digitValue {
            return Instruction(op: .store(d), keycodes: [sCode, d])
        }
        switch key {
        case .dot:
            pending = .stoDot
            return nil
        case .add:
            pending = .stoArith(.add)
            return nil
        case .sub:
            pending = .stoArith(.sub)
            return nil
        case .mul:
            pending = .stoArith(.mul)
            return nil
        case .div:
            pending = .stoArith(.div)
            return nil
        case .n:   return Instruction(op: .storeFin(.n), keycodes: [sCode, key.rawValue])
        case .i:   return Instruction(op: .storeFin(.i), keycodes: [sCode, key.rawValue])
        case .pv:  return Instruction(op: .storeFin(.pv), keycodes: [sCode, key.rawValue])
        case .pmt: return Instruction(op: .storeFin(.pmt), keycodes: [sCode, key.rawValue])
        case .fv:  return Instruction(op: .storeFin(.fv), keycodes: [sCode, key.rawValue])
        case .eex: return Instruction(op: .toggleCompound, keycodes: [sCode, key.rawValue])
        default:   return nil
        }
    }

    private mutating func parseRcl(_ key: Key) -> Instruction? {
        pending = .none
        let rCode = Key.rcl.rawValue
        if let d = key.digitValue {
            return Instruction(op: .recall(d), keycodes: [rCode, d])
        }
        switch key {
        case .dot:
            pending = .rclDot
            return nil
        case .n:   return Instruction(op: .recallFin(.n), keycodes: [rCode, key.rawValue])
        case .i:   return Instruction(op: .recallFin(.i), keycodes: [rCode, key.rawValue])
        case .pv:  return Instruction(op: .recallFin(.pv), keycodes: [rCode, key.rawValue])
        case .pmt: return Instruction(op: .recallFin(.pmt), keycodes: [rCode, key.rawValue])
        case .fv:  return Instruction(op: .recallFin(.fv), keycodes: [rCode, key.rawValue])
        case .g:
            pending = .rclG
            return nil
        default:   return nil
        }
    }
}
