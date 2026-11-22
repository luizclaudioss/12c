import Foundation

public enum TVM {
    private static func factors(n: Double, ir: Double, compound: Bool) throws -> (A: Double, v: Double, a: Double) {
        guard ir > -1.0 else { throw CalcError(5) }
        let nInt = floor(n)
        let fr = n - nInt
        let A: Double
        if fr != 0 {
            A = compound ? pow(1.0 + ir, fr) : (1.0 + ir * fr)
        } else {
            A = 1.0
        }
        guard A.isFinite, A != 0 else { throw CalcError(5) }
        if ir == 0 {
            return (A, 1.0, nInt)
        }
        let logOnePlusR = log1p(ir)
        let v = exp(-nInt * logOnePlusR)
        let a = -expm1(-nInt * logOnePlusR) / ir
        return (A, v, a)
    }

    public static func solvePV(state: HP12CState) throws -> Double {
        let ir = state.finI / 100.0
        guard ir > -1.0 else { throw CalcError(5) }
        let S = state.begin ? 1.0 : 0.0
        let (A, v, a) = try factors(n: state.finN, ir: ir, compound: state.compound)
        return -((1.0 + ir * S) * state.finPMT * a + state.finFV * v) / A
    }

    public static func solvePMT(state: HP12CState) throws -> Double {
        let ir = state.finI / 100.0
        guard ir > -1.0, state.finN != 0 else { throw CalcError(5) }
        let S = state.begin ? 1.0 : 0.0
        let (A, v, a) = try factors(n: state.finN, ir: ir, compound: state.compound)
        let denom = (1.0 + ir * S) * a
        guard denom != 0, denom.isFinite else { throw CalcError(5) }
        return -(state.finPV * A + state.finFV * v) / denom
    }

    public static func solveFV(state: HP12CState) throws -> Double {
        let ir = state.finI / 100.0
        guard ir > -1.0 else { throw CalcError(5) }
        let S = state.begin ? 1.0 : 0.0
        let (A, v, a) = try factors(n: state.finN, ir: ir, compound: state.compound)
        guard v != 0 else {
            // Overflow if huge n; evaluate sign
            let num = -(state.finPV * A + (1.0 + ir * S) * state.finPMT * a)
            if num == 0 { return 0.0 }
            return num > 0 ? Double.infinity : -Double.infinity
        }
        return -(state.finPV * A + (1.0 + ir * S) * state.finPMT * a) / v
    }

    public static func solveN(state: HP12CState) throws -> Double {
        let ir = state.finI / 100.0
        guard ir > -1.0 else { throw CalcError(5) }
        let S = state.begin ? 1.0 : 0.0
        let pPrime = state.finPMT * (1.0 + ir * S)
        let rawN: Double
        if ir == 0 {
            guard state.finPMT != 0 else { throw CalcError(5) }
            rawN = -(state.finPV + state.finFV) / state.finPMT
        } else {
            let denom = pPrime - state.finFV * ir
            guard denom != 0 else { throw CalcError(5) }
            let ratio = (pPrime + state.finPV * ir) / denom
            guard ratio > 0, ratio.isFinite else { throw CalcError(5) }
            rawN = -log(ratio) / log1p(ir)
        }
        guard rawN.isFinite else { throw CalcError(5) }
        let rounded = rawN.rounded()
        let res = abs(rawN - rounded) < 1e-9 ? rounded : ceil(rawN)
        guard res >= 0 else { throw CalcError(5) }
        return res == 0 ? 0.0 : res
    }

    public static func solveI(state: HP12CState) throws -> Double {
        guard state.finN != 0 else { throw CalcError(5) }
        let pv = state.finPV
        let pmt = state.finPMT
        let fv = state.finFV
        if pv == 0 && pmt == 0 && fv == 0 { throw CalcError(5) }

        let S = state.begin ? 1.0 : 0.0
        let n = state.finN
        let nInt = floor(n)
        let fr = n - nInt

        func f(_ r: Double) -> Double {
            guard r > -1.0 else { return .nan }
            let A: Double
            if fr != 0 {
                A = state.compound ? pow(1.0 + r, fr) : (1.0 + r * fr)
            } else {
                A = 1.0
            }
            if r == 0 {
                return pv * A + pmt * nInt + fv
            }
            let lr = log1p(r)
            let v = exp(-nInt * lr)
            let a = -expm1(-nInt * lr) / r
            return pv * A + (1.0 + r * S) * pmt * a + fv * v
        }

        // 1. Try Newton from 0.1
        var r = 0.1
        for _ in 0..<80 {
            let frVal = f(r)
            if !frVal.isFinite { break }
            if abs(frVal) < 1e-12 {
                if r > -0.999999 && r <= 10.0 {
                    return r * 100.0
                }
                break
            }
            let h = max(1e-7, abs(r) * 1e-7)
            let fp = f(r + h)
            let fm = f(r - h)
            guard fp.isFinite, fm.isFinite else { break }
            let df = (fp - fm) / (2.0 * h)
            if abs(df) < 1e-15 { break }
            let step = frVal / df
            let next = r - step
            if next <= -0.999999 || next > 20.0 { break }
            r = next
            if abs(step) <= 1e-12 * max(1.0, abs(r)) {
                if abs(f(r)) < 1e-7 && r > -0.999999 && r <= 10.0 {
                    return r * 100.0
                }
                break
            }
        }

        // 2. Scan positives from near 0, then negatives
        var posGrid: [Double] = [0.0]
        var x = 1e-6
        while x < 0.01 { posGrid.append(x); x *= 2.0 }
        x = 0.01
        while x < 0.2 { posGrid.append(x); x += 0.002 }
        x = 0.2
        while x < 2.0 { posGrid.append(x); x += 0.02 }
        x = 2.0
        while x <= 10.0 { posGrid.append(x); x += 0.1 }
        if posGrid.last != 10.0 { posGrid.append(10.0) }

        if let root = scanAndBisect(grid: posGrid, f: f) {
            return root * 100.0
        }

        var negGrid: [Double] = [0.0]
        x = -1e-6
        while x > -0.01 { negGrid.append(x); x *= 2.0 }
        x = -0.01
        while x > -0.95 { negGrid.append(x); x -= 0.005 }
        negGrid.append(contentsOf: [-0.96, -0.98, -0.99, -0.995, -0.999, -0.9999, -0.999999])

        if let root = scanAndBisect(grid: negGrid, f: f) {
            return root * 100.0
        }

        throw CalcError(5)
    }

    private static func scanAndBisect(grid: [Double], f: (Double) -> Double) -> Double? {
        guard grid.count >= 2 else { return nil }
        var prevX = grid[0]
        var prevY = f(prevX)
        if prevY.isFinite && abs(prevY) < 1e-12 {
            return prevX
        }
        for i in 1..<grid.count {
            let curX = grid[i]
            let curY = f(curX)
            if curY.isFinite && abs(curY) < 1e-12 {
                return curX
            }
            if prevY.isFinite && curY.isFinite && ((prevY < 0 && curY > 0) || (prevY > 0 && curY < 0)) {
                var a = prevX
                var b = curX
                var fa = prevY
                for _ in 0..<80 {
                    let mid = 0.5 * (a + b)
                    let fm = f(mid)
                    if !fm.isFinite { break }
                    if abs(fm) < 1e-13 || abs(b - a) <= 1e-12 * max(1.0, abs(mid)) {
                        return mid
                    }
                    if (fa < 0 && fm < 0) || (fa > 0 && fm > 0) {
                        a = mid
                        fa = fm
                    } else {
                        b = mid
                    }
                }
                return 0.5 * (a + b)
            }
            prevX = curX
            prevY = curY
        }
        return nil
    }

    public static func amortize(state: inout HP12CState, countDouble: Double) throws -> (interest: Double, principal: Double) {
        guard let count = Numeric.exactInteger(countDouble), count > 0 else {
            throw CalcError(5)
        }
        let ir = state.finI / 100.0
        guard ir > -1.0 else { throw CalcError(5) }

        var sumInt = 0.0
        var sumPrin = 0.0
        let oldN = state.finN

        for k in 1...count {
            let interest: Double
            if state.begin && (oldN + Double(k) == 1.0) {
                interest = 0.0
            } else {
                let rawInt = state.finPV * ir
                let rounded: Double
                switch state.displayMode {
                case .fix(let dec):
                    rounded = Numeric.roundDecimal(rawInt, scale: dec)
                case .sci:
                    rounded = rawInt
                }
                interest = -rounded
            }
            let principal = state.finPMT - interest
            state.finPV = Numeric.normalize(state.finPV + principal)?.value ?? (state.finPV + principal)
            sumInt += interest
            sumPrin += principal
        }
        state.finN = oldN + Double(count)
        return (sumInt == 0 ? 0.0 : sumInt, sumPrin == 0 ? 0.0 : sumPrin)
    }

    public static func simpleInterest(state: HP12CState) throws -> (int360: Double, negPV: Double, int365: Double) {
        let ir = state.finI / 100.0
        let int360 = -state.finPV * ir * state.finN / 360.0
        let negPV = -state.finPV
        let int365 = -state.finPV * ir * state.finN / 365.0
        return (int360 == 0 ? 0.0 : int360, negPV == 0 ? 0.0 : negPV, int365 == 0 ? 0.0 : int365)
    }
}
