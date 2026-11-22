import Foundation
import Testing
@testable import HP12CCore

@Suite("Step 3: Calendar Dates and Statistics")
struct Step3Tests {
    @Test func dateCalculations() {
        let c1 = HP12C()
        c1.pressSequence("5.142004 ENTER 120 g DATE")
        #expect(approxEqual(c1.x, 9.112004, tol: 1e-7))
        #expect(c1.displayText == "9,112004  6")
        // Next key clears date display format
        c1.press(.clx)
        #expect(c1.displayText == "0,00")

        let c2 = HP12C()
        c2.pressSequence("1.012020 ENTER 3.012020 g ΔDYS")
        #expect(approxEqual(c2.x, 60))
        #expect(approxEqual(c2.state.y, 60))

        let c3 = HP12C()
        c3.pressSequence("1.312020 ENTER 3.312020 g ΔDYS")
        #expect(approxEqual(c3.x, 60))
        #expect(approxEqual(c3.state.y, 60))

        let c4 = HP12C()
        c4.pressSequence("2.302020 ENTER 1 g DATE")
        #expect(c4.displayText == "Error 8")

        // D.MY mode
        let c5 = HP12C()
        c5.pressSequence("g D.MY 14.052004 ENTER 120 g DATE")
        #expect(c5.annunciators.dmy == true)
        #expect(approxEqual(c5.x, 11.092004, tol: 1e-7))
        #expect(c5.displayText == "11,092004 6")
    }

    @Test func statisticsAndRegression() {
        let calc = HP12C()
        // Empty stats -> Error 2
        calc.pressSequence("g x̄")
        #expect(calc.displayText == "Error 2")
        calc.press(.clx) // clear error

        // Pairs (y ENTER x Σ+): (2,1), (4,2), (6,3)
        calc.pressSequence("2 ENTER 1 Σ+ 4 ENTER 2 Σ+ 6 ENTER 3 Σ+")
        #expect(approxEqual(calc.state.storage[1], 3))

        calc.pressSequence("g x̄")
        #expect(approxEqual(calc.x, 2))
        #expect(approxEqual(calc.state.y, 4))

        calc.pressSequence("g s")
        #expect(approxEqual(calc.x, 1))
        #expect(approxEqual(calc.state.y, 2))

        calc.pressSequence("4 g ŷ,r")
        #expect(approxEqual(calc.x, 8))
        #expect(approxEqual(calc.state.y, 1))

        calc.pressSequence("8 g x̂,r")
        #expect(approxEqual(calc.x, 4))
        #expect(approxEqual(calc.state.y, 1))

        // Weighted mean: x = [10, 20], w = [1, 3] => (10+60)/4 = 17.5 (remember Σ+ takes y=Y, x=X; x̄w = R6/R2 = Σxy / Σx)
        let cw = HP12C()
        cw.pressSequence("10 ENTER 1 Σ+ 20 ENTER 3 Σ+ g x̄w")
        #expect(approxEqual(cw.x, 17.5))

        // Σ− removal
        calc.pressSequence("6 ENTER 3 g Σ−")
        #expect(approxEqual(calc.state.storage[1], 2))
        calc.pressSequence("g x̄")
        #expect(approxEqual(calc.x, 1.5))
    }
}
