import Foundation

public enum Depreciation {
    private static func validate(state: HP12CState, yearDouble: Double) throws -> (yr: Int, n: Double) {
        guard let yr = Numeric.exactInteger(yearDouble), yr >= 1, state.finN > 0 else {
            throw CalcError(5)
        }
        return (yr, state.finN)
    }

    public static func sl(state: HP12CState, yearDouble: Double) throws -> (dep: Double, remaining: Double) {
        let (yr, n) = try validate(state: state, yearDouble: yearDouble)
        let pv = state.finPV
        let fv = state.finFV
        let annual = (pv - fv) / n
        if Double(yr) > n {
            return (0.0, 0.0)
        }
        let bv = pv - annual * Double(yr)
        return (annual, bv - fv)
    }

    public static func soyd(state: HP12CState, yearDouble: Double) throws -> (dep: Double, remaining: Double) {
        let (yr, n) = try validate(state: state, yearDouble: yearDouble)
        let pv = state.finPV
        let fv = state.finFV
        let denom = n * (n + 1.0) / 2.0
        let maxK = min(yr, Int(floor(n)))
        var bv = pv
        var lastDep = 0.0
        if maxK >= 1 {
            for k in 1...maxK {
                lastDep = (pv - fv) * (n - Double(k) + 1.0) / denom
                bv -= lastDep
            }
        }
        if Double(yr) > n {
            return (0.0, max(0.0, bv - fv))
        }
        return (lastDep, bv - fv)
    }

    public static func db(state: HP12CState, yearDouble: Double) throws -> (dep: Double, remaining: Double) {
        let (yr, n) = try validate(state: state, yearDouble: yearDouble)
        guard state.finI >= 0 else { throw CalcError(5) }
        let pv = state.finPV
        let fv = state.finFV
        let rate = (state.finI / 100.0) / n
        let maxK = min(yr, Int(floor(n)))
        var bv = pv
        var lastDep = 0.0
        if maxK >= 1 {
            for _ in 1...maxK {
                let raw = bv * rate
                let cap = max(0.0, bv - fv)
                lastDep = min(raw, cap)
                bv -= lastDep
            }
        }
        if Double(yr) > n {
            return (0.0, max(0.0, bv - fv))
        }
        return (lastDep, bv - fv)
    }
}
