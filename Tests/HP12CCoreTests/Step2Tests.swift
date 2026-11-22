import Foundation
import Testing
@testable import HP12CCore

@Suite("Step 2: Financial (TVM, AMORT, INT, CashFlow, Bonds, Depreciation)")
struct Step2Tests {
    @Test func tvmCalculations() {
        let calc = HP12C()
        calc.pressSequence("360 n 0.5 i 200000 PV 0 FV PMT")
        #expect(approxEqual(calc.x, -1199.101050))
        #expect(calc.displayText == "-1.199,10")

        let c2 = HP12C()
        c2.pressSequence("10 n 8 i 1000 CHS PV 0 PMT FV")
        #expect(approxEqual(c2.x, 2158.924997))

        let c3 = HP12C()
        c3.pressSequence("200000 PV 1199.10 CHS PMT 360 n 0 FV i")
        #expect(approxEqual(c3.x, 0.5, tol: 1e-5))

        let c4 = HP12C()
        c4.pressSequence("1 i 1000 PV 100 CHS PMT 0 FV n")
        #expect(approxEqual(c4.x, 11))

        let c5 = HP12C()
        c5.pressSequence("5 n 10 i 100 CHS PMT 0 PV FV")
        #expect(approxEqual(c5.x, 610.51))
        c5.pressSequence("g BEG FV")
        #expect(approxEqual(c5.x, 671.561))

        // Odd period C off vs C on
        let c6 = HP12C()
        c6.pressSequence("1.5 n 10 i 100 CHS PV 0 PMT FV")
        #expect(approxEqual(c6.x, 115.50))
        c6.pressSequence("STO EEX FV")
        #expect(c6.annunciators.compound == true)
        #expect(approxEqual(c6.x, 115.368973))
    }

    @Test func storeComputeFlag() {
        let calc = HP12C()
        calc.pressSequence("10 n 5 i 1000 CHS PV 0 PMT FV")
        let firstFV = calc.x
        #expect(approxEqual(firstFV, 1628.894627))
        // Pressing FV again recomputes
        calc.press(.fv)
        #expect(approxEqual(calc.x, firstFV))
        // ENTER clears finComputeFlag so PV stores X instead of computing
        calc.pressSequence("999 ENTER PV")
        #expect(approxEqual(calc.state.finPV, 999))
    }

    @Test func amortization() {
        let calc = HP12C()
        calc.pressSequence("100000 PV 1 i 1100 CHS PMT 0 n")
        calc.pressSequence("1 f AMORT")
        #expect(approxEqual(calc.x, -1000))
        #expect(approxEqual(calc.state.y, -100))
        #expect(approxEqual(calc.state.finPV, 99900))
        #expect(approxEqual(calc.state.finN, 1))

        calc.pressSequence("2 f AMORT")
        #expect(approxEqual(calc.x, -1996.99))
        #expect(approxEqual(calc.state.y, -203.01))
        #expect(approxEqual(calc.state.finPV, 99696.99))
        #expect(approxEqual(calc.state.finN, 3))
    }

    @Test func simpleInterest() {
        let calc = HP12C()
        calc.pressSequence("60 n 7 i 450 CHS PV f INT")
        #expect(approxEqual(calc.x, 5.25))
        #expect(approxEqual(calc.state.y, 450))
        #expect(approxEqual(calc.state.z, 5.178082192))
    }

    @Test func cashFlowsNpvIrr() {
        let c1 = HP12C()
        c1.pressSequence("1000 CHS g CF0 1100 g CFj f IRR")
        #expect(approxEqual(c1.x, 10))

        let c2 = HP12C()
        c2.pressSequence("100 CHS g CF0 60 g CFj 60 g CFj f IRR")
        #expect(approxEqual(c2.x, 13.0662, tol: 1e-3))
        c2.pressSequence("10 i f NPV")
        #expect(approxEqual(c2.x, 4.132231))

        let c3 = HP12C()
        c3.pressSequence("1000 CHS g CF0 300 g CFj 4 g Nj f IRR")
        #expect(approxEqual(c3.x, 7.7138, tol: 1e-3))

        // Recall Nj and CFj (decrements n)
        #expect(approxEqual(c3.state.finN, 1))
        c3.pressSequence("RCL g Nj")
        #expect(approxEqual(c3.x, 4))
        c3.pressSequence("RCL g CFj")
        #expect(approxEqual(c3.x, 300))
        #expect(approxEqual(c3.state.finN, 0))

        // All positive flows -> Error 7
        let c4 = HP12C()
        c4.pressSequence("100 g CF0 50 g CFj f IRR")
        #expect(c4.displayText == "Error 7")
    }

    @Test func bondsPriceAndYtm() {
        let c1 = HP12C()
        c1.pressSequence("6.5 i 5.75 PMT 2.152008 ENTER 11.152017 f PRICE")
        #expect(approxEqual(c1.x, 94.635449, tol: 1e-4))
        #expect(approxEqual(c1.state.y, 1.453297, tol: 1e-6))

        let c2 = HP12C()
        c2.pressSequence("94.635449 PV 5.75 PMT 2.152008 ENTER 11.152017 f YTM")
        #expect(approxEqual(c2.x, 6.5, tol: 1e-4))
    }

    @Test func depreciationMethods() {
        let c1 = HP12C()
        c1.pressSequence("10000 PV 1000 FV 5 n 1 f SL")
        #expect(approxEqual(c1.x, 1800))
        #expect(approxEqual(c1.state.y, 7200))

        let c2 = HP12C()
        c2.pressSequence("10000 PV 1000 FV 5 n 1 f SOYD")
        #expect(approxEqual(c2.x, 3000))
        #expect(approxEqual(c2.state.y, 6000))
        c2.pressSequence("2 f SOYD")
        #expect(approxEqual(c2.x, 2400))
        #expect(approxEqual(c2.state.y, 3600))

        let c3 = HP12C()
        c3.pressSequence("10000 PV 1000 FV 5 n 200 i 1 f DB")
        #expect(approxEqual(c3.x, 4000))
        #expect(approxEqual(c3.state.y, 5000))
        c3.pressSequence("2 f DB")
        #expect(approxEqual(c3.x, 2400))
        #expect(approxEqual(c3.state.y, 2600))
    }
}
