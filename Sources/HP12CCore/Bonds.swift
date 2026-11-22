import Foundation

public enum Bonds {
    private struct BondSchedule {
        let e: Int
        let dsc: Int
        let a: Int
        let n: Int
        let coupon: Double

        var accrued: Double {
            (Double(a) / Double(e)) * (coupon / 2.0)
        }

        func cleanPrice(yieldRate y: Double) -> Double {
            let semiY = y / 2.0
            let semiC = coupon / 2.0
            let frac = Double(dsc) / Double(e)
            if n == 1 {
                return (100.0 + semiC) / (1.0 + frac * semiY) - accrued
            }
            let base = 1.0 + semiY
            var pv = 100.0 / pow(base, Double(n - 1) + frac)
            for k in 1...n {
                pv += semiC / pow(base, Double(k - 1) + frac)
            }
            return pv - accrued
        }
    }

    private static func buildSchedule(state: HP12CState) throws -> BondSchedule {
        let settlement = try DateMath.parse(state.y, dmy: state.dmy)
        let maturity = try DateMath.parse(state.x, dmy: state.dmy)
        guard settlement.jdn < maturity.jdn else {
            throw CalcError(8)
        }
        guard state.finPMT >= 0 else {
            throw CalcError(5)
        }

        var step = 1
        var prev = DateMath.subtractMonths(from: maturity, months: 6)
        while prev.jdn > settlement.jdn {
            step += 1
            prev = DateMath.subtractMonths(from: maturity, months: 6 * step)
        }
        let next = step == 1 ? maturity : DateMath.subtractMonths(from: maturity, months: 6 * (step - 1))
        let e = next.jdn - prev.jdn
        let dsc = next.jdn - settlement.jdn
        let a = e - dsc
        guard e > 0 else { throw CalcError(8) }
        return BondSchedule(e: e, dsc: dsc, a: a, n: step, coupon: state.finPMT)
    }

    public static func price(state: HP12CState) throws -> (price: Double, accrued: Double) {
        let schedule = try buildSchedule(state: state)
        let y = state.finI / 100.0
        guard 1.0 + y / 2.0 > 0 else { throw CalcError(5) }
        let clean = schedule.cleanPrice(yieldRate: y)
        return (clean, schedule.accrued)
    }

    public static func ytm(state: HP12CState) throws -> (yieldPercent: Double, accrued: Double) {
        let schedule = try buildSchedule(state: state)
        let target = state.finPV
        guard target > 0 else { throw CalcError(5) }

        var lo = -1.99
        var hi = 2.0
        while schedule.cleanPrice(yieldRate: hi) > target && hi < 200.0 {
            hi *= 2.0
        }
        while schedule.cleanPrice(yieldRate: lo) < target && lo > -1.999999 {
            lo = -2.0 + (lo + 2.0) * 0.1
        }
        let fLo = schedule.cleanPrice(yieldRate: lo) - target
        let fHi = schedule.cleanPrice(yieldRate: hi) - target
        guard fLo.isFinite, fHi.isFinite, fLo >= 0, fHi <= 0 else {
            throw CalcError(5)
        }

        for _ in 0..<90 {
            let mid = 0.5 * (lo + hi)
            let fMid = schedule.cleanPrice(yieldRate: mid) - target
            if abs(fMid) < 1e-12 || abs(hi - lo) <= 1e-12 * max(1.0, abs(mid)) {
                return (mid * 100.0, schedule.accrued)
            }
            if fMid > 0 {
                lo = mid
            } else {
                hi = mid
            }
        }
        return (0.5 * (lo + hi) * 100.0, schedule.accrued)
    }
}
