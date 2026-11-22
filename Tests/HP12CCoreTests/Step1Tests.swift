import Foundation
import Testing
@testable import HP12CCore

@Suite("Step 1: RPN, Math, Display, Errors, Modes")
struct Step1Tests {
    @Test func rpnBasicOperations() {
        let calc = HP12C()
        calc.pressSequence("3 ENTER 4 +")
        #expect(approxEqual(calc.x, 7))

        let calc2 = HP12C()
        calc2.pressSequence("2 ENTER 3 ENTER 4 × +")
        #expect(approxEqual(calc2.x, 14))

        let calc3 = HP12C()
        calc3.pressSequence("4 ENTER ×")
        #expect(approxEqual(calc3.x, 16))

        let calc4 = HP12C()
        calc4.pressSequence("2 ENTER ENTER ENTER × × ×")
        #expect(approxEqual(calc4.x, 16))

        let calc5 = HP12C()
        calc5.pressSequence("9 ENTER CLx 5")
        #expect(approxEqual(calc5.x, 5))
        #expect(approxEqual(calc5.state.y, 9))

        let calc6 = HP12C()
        calc6.pressSequence("5 ENTER 3 −")
        #expect(approxEqual(calc6.x, 2))
        #expect(approxEqual(calc6.state.lstx, 3))
        calc6.pressSequence("g LSTx")
        #expect(approxEqual(calc6.x, 3))
    }

    @Test func stackRollAndSwap() {
        let calc = HP12C()
        calc.pressSequence("1 ENTER 2 ENTER 3 ENTER 4")
        #expect(calc.state.t == 1)
        #expect(calc.state.z == 2)
        #expect(calc.state.y == 3)
        #expect(calc.state.x == 4)

        calc.pressSequence("R↓")
        #expect(calc.state.x == 3)
        #expect(calc.state.y == 2)
        #expect(calc.state.z == 1)
        #expect(calc.state.t == 4)

        calc.pressSequence("x≷y")
        #expect(calc.state.x == 2)
        #expect(calc.state.y == 3)
    }

    @Test func percentages() {
        let calc = HP12C()
        calc.pressSequence("300 ENTER 15 %")
        #expect(approxEqual(calc.x, 45))
        #expect(approxEqual(calc.state.y, 300))
        calc.pressSequence("+")
        #expect(approxEqual(calc.x, 345))

        let calc2 = HP12C()
        calc2.pressSequence("58.5 ENTER 53.25 g Δ%") // Δ% is primary key
        _ = calc2
        let calcDelta = HP12C()
        calcDelta.pressSequence("58.5 ENTER 53.25 Δ%")
        #expect(approxEqual(calcDelta.x, -8.974358974))

        let calcT = HP12C()
        calcT.pressSequence("200 ENTER 50 %T")
        #expect(approxEqual(calcT.x, 25))
    }

    @Test func displayFormatting() {
        let calc = HP12C()
        calc.pressSequence("1234.5 ENTER")
        #expect(calc.displayText == "1.234,50")

        calc.pressSequence("f 4")
        #expect(calc.displayText == "1.234,5000")

        let c2 = HP12C()
        c2.pressSequence("1 EEX 12 ENTER")
        #expect(c2.displayText == "1,000000 12")

        let c3 = HP12C()
        c3.pressSequence("0.0001 ENTER")
        #expect(c3.displayText == "1,000000-04")

        let c4 = HP12C()
        c4.pressSequence("0.5 CHS ENTER")
        #expect(c4.displayText == "-0,50")

        let c5 = HP12C()
        c5.pressSequence("1234.5 ENTER")
        c5.toggleSeparator()
        #expect(c5.displayText == "1,234.50")

        let c6 = HP12C()
        c6.pressSequence("123456 ENTER f .")
        #expect(c6.displayText == "1,234560 05")

        let c7 = HP12C()
        c7.pressSequence("1234")
        #expect(c7.displayText == "1.234,")

        let c8 = HP12C()
        c8.pressSequence("0.05")
        #expect(c8.displayText == "0,05")

        let c9 = HP12C()
        c9.pressSequence("1 EEX 99 ENTER 100 ×")
        #expect(c9.blinking == true)
        #expect(c9.displayText == "9,999999 99")
        #expect(c9.x == 9.999999999e99)
        // Next key clears blinking and executes normally
        c9.pressSequence("CLx")
        #expect(c9.blinking == false)
        #expect(c9.x == 0)

        let c10 = HP12C()
        c10.pressSequence("1.23456 ENTER f RND")
        #expect(approxEqual(c10.x, 1.23))
    }

    @Test func mathAndErrors() {
        let calc = HP12C()
        calc.pressSequence("1 ENTER 0 ÷")
        #expect(calc.displayText == "Error 0")
        // Next key only clears error (is not executed)
        calc.pressSequence("5")
        #expect(calc.displayText == "0,00")
        #expect(calc.x == 0)

        let c2 = HP12C()
        c2.pressSequence("2.5 g n!")
        #expect(c2.displayText == "Error 0")

        let c3 = HP12C()
        c3.pressSequence("5 g n!")
        #expect(approxEqual(c3.x, 120))

        let c4 = HP12C()
        c4.pressSequence("2 CHS ENTER 3 yˣ")
        #expect(approxEqual(c4.x, -8))

        let c5 = HP12C()
        c5.pressSequence("2 CHS ENTER 0.5 yˣ")
        #expect(c5.displayText == "Error 0")

        let c6 = HP12C()
        c6.pressSequence("3.75 CHS g FRAC")
        #expect(approxEqual(c6.x, -0.75))
        c6.pressSequence("g LSTx g INTG")
        #expect(approxEqual(c6.x, -3))

        let c7 = HP12C()
        c7.pressSequence("9 g √x")
        #expect(approxEqual(c7.x, 3))
        c7.pressSequence("g x²")
        #expect(approxEqual(c7.x, 9))
        c7.pressSequence("1 g eˣ g LN")
        #expect(approxEqual(c7.x, 1))
    }

    @Test func storageAndPowerOnOffModifiers() {
        let calc = HP12C()
        calc.pressSequence("10 STO 1 5 STO + 1 RCL 1")
        #expect(approxEqual(calc.x, 15))
        calc.pressSequence("STO . 2 RCL . 2")
        #expect(approxEqual(calc.x, 15))

        calc.pressSequence("STO + 5")
        #expect(calc.displayText == "Error 6")
        calc.press(.clx) // clears error only

        calc.pressSequence("1234.5 f CLEAR PREFIX")
        #expect(calc.displayText == "1234500000")

        // ON + . toggles European/US separator
        let p = HP12C()
        p.pressSequence("1234.5 ENTER ON . ON")
        #expect(p.isOn)
        #expect(p.displayText == "1,234.50")

        // ON + - resets continuous memory with Pr Error (back to default Brazilian/European format)
        p.pressSequence("ON − ON")
        #expect(p.displayText == "Pr Error")
        p.press(.clx)
        #expect(p.displayText == "0,00")
        #expect(p.state.european)
    }
}
