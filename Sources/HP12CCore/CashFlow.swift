import Foundation

public enum CashFlow {
    public static func enterCF0(state: inout HP12CState) throws {
        state.storage[0] = state.x
        state.nj[0] = 1
        state.finN = 0
    }

    public static func enterCFj(state: inout HP12CState) throws {
        guard let curN = Numeric.exactInteger(state.finN), curN >= 0 else {
            throw CalcError(6)
        }
        let next = curN + 1
        guard next < state.availableRegisters else {
            throw CalcError(6)
        }
        state.finN = Double(next)
        state.storage[next] = state.x
        state.nj[next] = 1
    }

    public static func enterNj(state: inout HP12CState) throws {
        guard let j = Numeric.exactInteger(state.finN), j >= 0, j < state.availableRegisters else {
            throw CalcError(6)
        }
        guard let count = Numeric.exactInteger(state.x), count >= 1, count <= 99 else {
            throw CalcError(6)
        }
        state.nj[j] = count
    }

    public static func recallCFj(state: inout HP12CState) throws -> Double {
        guard let j = Numeric.exactInteger(state.finN), j >= 0, j < state.availableRegisters else {
            throw CalcError(6)
        }
        let val = state.storage[j]
        state.finN = Double(j - 1)
        return val
    }

    public static func recallNj(state: HP12CState) throws -> Double {
        guard let j = Numeric.exactInteger(state.finN), j >= 0, j < state.availableRegisters else {
            throw CalcError(6)
        }
        return Double(state.nj[j])
    }

    private static func collectFlows(state: HP12CState) throws -> [(amount: Double, count: Int)] {
        guard let nCount = Numeric.exactInteger(state.finN), nCount >= 0, nCount < state.availableRegisters else {
            throw CalcError(6)
        }
        var flows: [(Double, Int)] = [(state.storage[0], 1)]
        if nCount >= 1 {
            for j in 1...nCount {
                flows.append((state.storage[j], max(1, state.nj[j])))
            }
        }
        return flows
    }

    private static func evaluateNPV(flows: [(amount: Double, count: Int)], r: Double) -> Double {
        guard r > -1.0 else { return .nan }
        var sum = flows[0].amount
        var t = 0
        for idx in 1..<flows.count {
            let (cf, nj) = flows[idx]
            for _ in 0..<nj {
                t += 1
                sum += cf * pow(1.0 + r, Double(-t))
            }
        }
        return sum
    }

    private static func evaluateNPVAndDeriv(flows: [(amount: Double, count: Int)], r: Double) -> (f: Double, df: Double) {
        guard r > -1.0 else { return (.nan, .nan) }
        var sum = flows[0].amount
        var deriv = 0.0
        var t = 0
        for idx in 1..<flows.count {
            let (cf, nj) = flows[idx]
            for _ in 0..<nj {
                t += 1
                let disc = pow(1.0 + r, Double(-t))
                sum += cf * disc
                deriv += -Double(t) * cf * disc / (1.0 + r)
            }
        }
        return (sum, deriv)
    }

    public static func npv(state: HP12CState) throws -> Double {
        let ir = state.finI / 100.0
        guard ir > -1.0 else { throw CalcError(5) }
        let flows = try collectFlows(state: state)
        return evaluateNPV(flows: flows, r: ir)
    }

    public static func irr(state: HP12CState, initialGuessPercent: Double?) throws -> Double {
        let flows = try collectFlows(state: state)
        let hasPos = flows.contains { $0.amount > 0 }
        let hasNeg = flows.contains { $0.amount < 0 }
        guard hasPos && hasNeg else {
            throw CalcError(7)
        }

        // 1. Newton from initial guess (default 10%)
        var r = (initialGuessPercent ?? 10.0) / 100.0
        if r > -0.99 && r <= 100.0 {
            for _ in 0..<80 {
                let (fv, dfv) = evaluateNPVAndDeriv(flows: flows, r: r)
                if !fv.isFinite || !dfv.isFinite { break }
                if abs(fv) < 1e-12 {
                    if r > -0.99 && r <= 100.0 {
                        return r * 100.0
                    }
                    break
                }
                if abs(dfv) < 1e-15 { break }
                let step = fv / dfv
                let next = r - step
                if next <= -0.99 || next > 100.0 { break }
                r = next
                if abs(step) <= 1e-12 * max(1.0, abs(r)) {
                    let check = evaluateNPV(flows: flows, r: r)
                    if check.isFinite && abs(check) < 1e-7 && r > -0.99 && r <= 100.0 {
                        return r * 100.0
                    }
                    break
                }
            }
        }

        // 2. Fallback grid + bisection over (-0.99, 100]
        var posGrid: [Double] = [0.0]
        var x = 0.005
        while x < 0.5 { posGrid.append(x); x += 0.005 }
        x = 0.5
        while x < 5.0 { posGrid.append(x); x += 0.05 }
        x = 5.0
        while x <= 100.0 { posGrid.append(x); x += 0.5 }
        if posGrid.last != 100.0 { posGrid.append(100.0) }

        if let root = bisectGrid(grid: posGrid, flows: flows) {
            return root * 100.0
        }

        var negGrid: [Double] = [0.0]
        x = -0.005
        while x > -0.985 { negGrid.append(x); x -= 0.005 }
        negGrid.append(-0.99)

        if let root = bisectGrid(grid: negGrid, flows: flows) {
            return root * 100.0
        }

        throw CalcError(3)
    }

    private static func bisectGrid(grid: [Double], flows: [(amount: Double, count: Int)]) -> Double? {
        var prevX = grid[0]
        var prevY = evaluateNPV(flows: flows, r: prevX)
        if prevY.isFinite && abs(prevY) < 1e-12 { return prevX }
        for idx in 1..<grid.count {
            let curX = grid[idx]
            let curY = evaluateNPV(flows: flows, r: curX)
            if curY.isFinite && abs(curY) < 1e-12 { return curX }
            if prevY.isFinite && curY.isFinite && ((prevY < 0 && curY > 0) || (prevY > 0 && curY < 0)) {
                var a = prevX
                var b = curX
                var fa = prevY
                for _ in 0..<80 {
                    let mid = 0.5 * (a + b)
                    let fm = evaluateNPV(flows: flows, r: mid)
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
}
