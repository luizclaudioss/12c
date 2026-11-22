import Foundation
import Testing
@testable import HP12CCore

@Suite("Step 4 & 5: Programming and Persistence")
struct Step4And5Tests {
    @Test func simpleProgramRun() {
        let calc = HP12C()
        calc.pressSequence("f P/R f CLEAR PRGM 2 × f P/R")
        #expect(!calc.annunciators.prgm)

        calc.pressSequence("5 R/S")
        #expect(calc.isRunning)
        calc.runUntilStopped()
        #expect(!calc.isRunning)
        #expect(approxEqual(calc.x, 10))
        #expect(calc.state.pc == 0)
    }

    @Test func countdownProgramAndExplicitGto00Halt() {
        let calc = HP12C()
        calc.pressSequence("f P/R f CLEAR PRGM 1 − g x=0 g GTO 06 g GTO 01 f P/R")
        #expect(calc.state.program.count == 5)

        calc.pressSequence("3 R/S")
        calc.runUntilStopped()
        #expect(!calc.isRunning)
        #expect(approxEqual(calc.x, 0))
        #expect(calc.state.pc == 0)

        // Explicit g GTO 00 halts at pc = 0 without executing trailing lines
        let calc0 = HP12C()
        calc0.pressSequence("f P/R f CLEAR PRGM 1 + g GTO 00 9 9 + f P/R")
        calc0.pressSequence("5 R/S")
        calc0.runUntilStopped()
        #expect(!calc0.isRunning)
        #expect(approxEqual(calc0.x, 6))
        #expect(calc0.state.pc == 0)
    }

    @Test func prgmDisplayFormattingAndMemoryAllocation() {
        let calc = HP12C()
        calc.pressSequence("g MEM")
        #expect(calc.displayText == "P-08 r-20")

        calc.pressSequence("f P/R f CLEAR PRGM")
        #expect(calc.displayText == "00-")

        calc.pressSequence("STO + 1")
        #expect(calc.displayText == "01-44 40 1")

        calc.pressSequence("g GTO 01")
        #expect(calc.displayText == "02-43,33 01")

        calc.pressSequence("RCL g CFj")
        #expect(calc.displayText == "03-45,43 14")

        calc.pressSequence("f n")
        #expect(calc.displayText == "04-  42 11")

        // Add 5 more lines -> 9 total -> P-15 r-19
        calc.pressSequence("1 2 3 4 5")
        #expect(calc.state.program.count == 9)
        calc.pressSequence("g MEM")
        #expect(calc.displayText == "P-15 r-19")
    }

    @Test func programCapacityAndRegisterLoss() {
        let calc = HP12C()
        // Pre-populate R.9 (index 19)
        calc.pressSequence("77 STO . 9")
        #expect(approxEqual(calc.state.storage[19], 77))

        calc.pressSequence("f P/R f CLEAR PRGM")
        for _ in 0..<99 {
            calc.press(.d1)
        }
        #expect(calc.state.program.count == 99)
        #expect(calc.state.availableRegisters == 7)
        #expect(calc.state.storage[19] == 0)

        // 100th insert -> Error 4
        calc.press(.d1)
        #expect(calc.displayText == "Error 4")
        calc.press(.clx) // clears error

        // Exit PRGM mode, try STO . 9 -> Error 6
        calc.pressSequence("f P/R 5 STO . 9")
        #expect(calc.displayText == "Error 6")
    }

    @Test func sstBstAndConditionalInProgram() {
        let calc = HP12C()
        calc.pressSequence("f P/R f CLEAR PRGM 5 ENTER 3 g x≤y g GTO 06 10 + R/S f P/R")
        // Verify SST in run mode steps and shows info message
        calc.press(.sst)
        #expect(calc.displayText == "01-      5")
        calc.press(.clx) // executes CLx after clearing info message; wait: let's test runUntilStopped cleanly
        let c2 = HP12C()
        // Program: 10 g x<=y (if X <= Y execute next, else skip): line1=5, line2=ENTER, line3=3, line4=x<=y, line5=gto 08, line6=9, line7=+, line8=R/S
        // Here X=3, Y=5 => 3 <= 5 is true => executes line 5 (GTO 08) => stops with X=3
        c2.pressSequence("f P/R f CLEAR PRGM 5 ENTER 3 g x≤y g GTO 08 9 + R/S f P/R R/S")
        c2.runUntilStopped()
        #expect(approxEqual(c2.x, 3))

        // GTO out of bounds (> allocatedLines) in program -> Error 4
        let c3 = HP12C()
        c3.pressSequence("f P/R f CLEAR PRGM g GTO 20 f P/R R/S")
        c3.runUntilStopped()
        #expect(c3.displayText == "Error 4")
        #expect(!c3.isRunning)

        // PSE returns .pause and shows X, then resumes cleanly
        let c4 = HP12C()
        c4.pressSequence("f P/R f CLEAR PRGM 4 2 g PSE 1 + f P/R")
        c4.press(.rs)
        #expect(c4.step() == .continue)
        #expect(c4.step() == .continue)
        #expect(c4.step() == .pause)
        #expect(c4.displayText == "42.00")
        #expect(c4.step() == .continue)
        #expect(c4.step() == .stopped)
        #expect(approxEqual(c4.x, 43))

        // STO arithmetic (-, *, /, overflow Error 1) & RCL g R/S (IRR with guess)
        let c5 = HP12C()
        c5.pressSequence("100 STO 0 25 STO - 0 2 STO × 0 3 STO ÷ 0 RCL 0")
        #expect(approxEqual(c5.x, 50))
        c5.pressSequence("1 EEX 99 STO 1 10 STO × 1")
        #expect(c5.displayText == "Error 1")
        c5.press(.clx)
        #expect(approxEqual(c5.state.storage[1], 1e99))

        let c6 = HP12C()
        c6.pressSequence("100 CHS g CF0 60 g CFj 60 g CFj 15 RCL g R/S")
        #expect(approxEqual(c6.x, 13.0662, tol: 1e-3))
    }

    @Test func statePersistenceRoundTrip() throws {
        let calc = HP12C()
        calc.pressSequence("1000 CHS PV 5 i 10 n 0 PMT FV")
        calc.pressSequence("42 STO . 3")
        calc.pressSequence("g BEG g D.MY STO EEX f 4")
        calc.pressSequence("f P/R f CLEAR PRGM 2 × g GTO 00 f P/R")
        calc.toggleSeparator()

        let data = try JSONEncoder().encode(calc.state)
        let decoded = try JSONDecoder().decode(HP12CState.self, from: data)
        #expect(decoded == calc.state)

        let restored = HP12C(state: decoded)
        #expect(restored.annunciators.begin)
        #expect(restored.annunciators.dmy)
        #expect(restored.annunciators.compound)
        #expect(restored.state.european)
        #expect(restored.state.program.count == 3)
        #expect(approxEqual(restored.state.storage[13], 42))
    }
}
