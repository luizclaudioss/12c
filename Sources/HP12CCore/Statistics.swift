import Foundation

public enum Statistics {
    public static func accumulate(state: inout HP12CState, sign: Double) throws {
        let x = state.x
        let y = state.y
        let n = state.storage[1] + sign
        let sx = state.storage[2] + sign * x
        let sx2 = state.storage[3] + sign * x * x
        let sy = state.storage[4] + sign * y
        let sy2 = state.storage[5] + sign * y * y
        let sxy = state.storage[6] + sign * x * y

        guard n.isFinite, sx.isFinite, sx2.isFinite, sy.isFinite, sy2.isFinite, sxy.isFinite else {
            throw CalcError(2)
        }
        state.storage[1] = n
        state.storage[2] = sx
        state.storage[3] = sx2
        state.storage[4] = sy
        state.storage[5] = sy2
        state.storage[6] = sxy
        state.lstx = x
        state.x = n
    }

    public static func mean(state: HP12CState) throws -> (xBar: Double, yBar: Double) {
        let n = state.storage[1]
        guard n != 0 else { throw CalcError(2) }
        return (state.storage[2] / n, state.storage[4] / n)
    }

    public static func stdDev(state: HP12CState) throws -> (sx: Double, sy: Double) {
        let n = state.storage[1]
        guard n > 1 else { throw CalcError(2) }
        let denom = n * (n - 1.0)
        let numX = n * state.storage[3] - state.storage[2] * state.storage[2]
        let numY = n * state.storage[5] - state.storage[4] * state.storage[4]
        guard denom > 0, numX >= -1e-12, numY >= -1e-12 else { throw CalcError(2) }
        return (sqrt(max(0.0, numX) / denom), sqrt(max(0.0, numY) / denom))
    }

    public static func weightedMean(state: HP12CState) throws -> Double {
        let sumW = state.storage[2]
        guard sumW != 0 else { throw CalcError(2) }
        return state.storage[6] / sumW
    }

    private static func linearRegression(state: HP12CState) throws -> (a: Double, b: Double, r: Double) {
        let n = state.storage[1]
        let sumX = state.storage[2]
        let sumX2 = state.storage[3]
        let sumY = state.storage[4]
        let sumY2 = state.storage[5]
        let sumXY = state.storage[6]
        guard n > 0 else { throw CalcError(2) }

        let denomX = n * sumX2 - sumX * sumX
        let denomY = n * sumY2 - sumY * sumY
        guard denomX > 0, denomY > 0 else { throw CalcError(2) }

        let sxy = n * sumXY - sumX * sumY
        let b = sxy / denomX
        let a = (sumY - b * sumX) / n
        let r = sxy / sqrt(denomX * denomY)
        return (a, b, r)
    }

    public static func estimateY(state: HP12CState, xInput: Double) throws -> (yHat: Double, r: Double) {
        let (a, b, r) = try linearRegression(state: state)
        return (a + b * xInput, r)
    }

    public static func estimateX(state: HP12CState, yInput: Double) throws -> (xHat: Double, r: Double) {
        let (a, b, r) = try linearRegression(state: state)
        guard b != 0 else { throw CalcError(2) }
        return ((yInput - a) / b, r)
    }
}
