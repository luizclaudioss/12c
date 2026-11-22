import Foundation

public final class HP12C {
    public private(set) var state: HP12CState
    private var parser = KeyParser()
    private var entry = EntryBuffer()

    public private(set) var isRunning: Bool = false
    private var isPausedForPSE: Bool = false
    public private(set) var blinking: Bool = false
    public private(set) var message: DisplayMessage?

    private var dateDisplay: (value: Double, dow: Int)?
    private enum OffModifier {
        case toggleSeparator
        case resetMemory
    }
    private var offModifier: OffModifier?

    public init(state: HP12CState = HP12CState()) {
        self.state = state
    }

    public var isOn: Bool { state.isOn }
    public var x: Double { state.x }

    public var annunciators: Annunciators {
        Annunciators(
            f: state.isOn && parser.pending == .f,
            g: state.isOn && parser.pending == .g,
            begin: state.isOn && state.begin,
            dmy: state.isOn && state.dmy,
            compound: state.isOn && state.compound,
            prgm: state.isOn && state.prgmMode
        )
    }

    public var displayText: String {
        DisplayFormatter.format(
            state: state,
            entry: entry,
            isRunning: isRunning,
            isPausedForPSE: isPausedForPSE,
            blinking: blinking,
            message: message,
            dateDisplay: dateDisplay
        )
    }

    public func clearInfoMessage() {
        if let msg = message, case .info = msg.kind {
            message = nil
        }
    }

    public func stopRunning() {
        isRunning = false
        isPausedForPSE = false
        finishEntry()
    }

    public func toggleSeparator() {
        state.european.toggle()
    }

    public func resetContinuousMemory() {
        state = HP12CState()
        parser.reset()
        entry.reset()
        isRunning = false
        isPausedForPSE = false
        blinking = false
        message = nil
        dateDisplay = nil
        offModifier = nil
    }

    public func triggerMemoryResetError() {
        resetContinuousMemory()
        message = DisplayMessage(text: "Pr Error", kind: .error)
    }

    public func cancelPrefix() {
        guard state.isOn else { return }
        parser.reset()
        if let msg = message, case .error = msg.kind {
            message = nil
        } else {
            clearInfoMessage()
        }
    }

    public func setX(_ v: Double) {
        guard state.isOn else { return }
        entry.reset()
        parser.reset()
        message = nil
        dateDisplay = nil
        blinking = false
        guard let norm = Numeric.normalize(v) else {
            triggerError(0)
            return
        }
        if state.liftEnabled {
            pushStack()
        }
        state.x = norm.value
        blinking = norm.overflow
        state.liftEnabled = true
        state.finComputeFlag = false
    }

    public func backspace() {
        guard state.isOn, !state.prgmMode, !isRunning else { return }
        if let msg = message, case .error = msg.kind {
            message = nil
            return
        }
        message = nil
        dateDisplay = nil
        blinking = false
        parser.reset()

        if entry.isActive {
            if entry.backspace() {
                state.x = entry.numericValue
            } else {
                state.x = 0
                state.liftEnabled = false
            }
        } else {
            state.x = 0
            state.liftEnabled = false
        }
        state.finComputeFlag = false
    }

    public func press(_ key: Key) {
        if isRunning {
            stopRunning()
            return
        }

        if !state.isOn {
            handleKeyWhileOff(key)
            return
        }

        // Error message swallows the next key press.
        if let msg = message, case .error = msg.kind {
            message = nil
            return
        }

        // Info message, date display, and overflow blink clear on next key press, which still executes.
        clearInfoMessage()
        dateDisplay = nil
        blinking = false

        guard let instr = parser.feed(key) else {
            return
        }

        if state.prgmMode && instr.isProgrammable {
            recordInstruction(instr)
            return
        }

        do {
            _ = try execute(instr, inProgram: false)
        } catch let err as CalcError {
            triggerError(err.code)
        } catch {
            triggerError(0)
        }
    }

    // MARK: - Off State

    private func handleKeyWhileOff(_ key: Key) {
        switch key {
        case .dot:
            offModifier = .toggleSeparator
        case .sub:
            offModifier = .resetMemory
        case .on:
            let mod = offModifier
            offModifier = nil
            parser.reset()
            entry.reset()
            blinking = false
            message = nil
            dateDisplay = nil
            isRunning = false
            isPausedForPSE = false
            state.isOn = true
            switch mod {
            case .toggleSeparator:
                state.european.toggle()
            case .resetMemory:
                resetContinuousMemory()
                message = DisplayMessage(text: "Pr Error", kind: .error)
            case .none:
                break
            }
        default:
            break
        }
    }

    // MARK: - Program Recording & Stepping (completed in §8)

    private func recordInstruction(_ instr: Instruction) {
        guard state.program.count < 99 else {
            triggerError(4)
            return
        }
        let insertIdx = min(max(0, state.pc), state.program.count)
        state.program.insert(instr, at: insertIdx)
        state.pc = insertIdx + 1
        let avail = state.availableRegisters
        for idx in avail..<20 {
            state.storage[idx] = 0
            state.nj[idx] = 1
        }
    }

    public func step() -> StepResult {
        guard isRunning else { return .stopped }
        isPausedForPSE = false

        if state.pc == 0 {
            state.pc = 1
        }
        if state.pc > state.program.count {
            state.pc = 0
            isRunning = false
            return .stopped
        }

        let currentPC = state.pc
        let instr = state.program[currentPC - 1]
        do {
            let outcome = try execute(instr, inProgram: true)
            switch outcome {
            case .normal:
                state.pc = currentPC + 1
                if state.pc > state.program.count {
                    finishEntry()
                    state.pc = 0
                    isRunning = false
                    return .stopped
                }
                return .continue
            case .skipNext:
                state.pc = currentPC + 2
                if state.pc > state.program.count {
                    finishEntry()
                    state.pc = 0
                    isRunning = false
                    return .stopped
                }
                return .continue
            case .jumped(let target):
                state.pc = target
                return .continue
            case .stop:
                finishEntry()
                state.pc = currentPC + 1
                if state.pc > state.program.count {
                    state.pc = 0
                }
                isRunning = false
                return .stopped
            case .haltAtZero:
                finishEntry()
                state.pc = 0
                isRunning = false
                return .stopped
            case .pause:
                state.pc = currentPC + 1
                isPausedForPSE = true
                if state.pc > state.program.count {
                    finishEntry()
                    state.pc = 0
                    isRunning = false
                    isPausedForPSE = false
                    return .stopped
                }
                return .pause
            }
        } catch let err as CalcError {
            triggerError(err.code)
            isRunning = false
            isPausedForPSE = false
            return .stopped
        } catch {
            triggerError(0)
            isRunning = false
            isPausedForPSE = false
            return .stopped
        }
    }

    public func runUntilStopped(maxSteps: Int = 100_000) {
        var steps = 0
        while isRunning && steps < maxSteps {
            let res = step()
            steps += 1
            if res == .stopped {
                break
            }
        }
        if isRunning {
            stopRunning()
        }
    }

    // MARK: - Execution

    private enum ExecOutcome {
        case normal
        case skipNext
        case jumped(Int)
        case stop
        case haltAtZero
        case pause
    }

    private func execute(_ instr: Instruction, inProgram: Bool) throws -> ExecOutcome {
        switch instr.op {
        // Entry operations
        case .digit(let d):
            handleDigitEntry(d)
            state.finComputeFlag = false
            return .normal
        case .dot:
            handleDotEntry()
            state.finComputeFlag = false
            return .normal
        case .eex:
            handleEEXEntry()
            state.finComputeFlag = false
            return .normal
        case .chs:
            handleCHS()
            state.finComputeFlag = false
            return .normal

        default:
            break
        }

        // Any non-entry instruction terminates entry.
        finishEntry()

        // Track financial store/compute rule: TVM keys and mode/display instructions preserve it.
        let keepsFinFlag: Bool
        switch instr.op {
        case .finN, .finI, .finPV, .finPMT, .finFV, .times12, .div12,
             .beg, .end, .toggleCompound, .fix, .sci, .dmy, .my, .clearPREFIX, .mem:
            keepsFinFlag = true
        default:
            keepsFinFlag = false
        }
        let wasFinCompute = state.finComputeFlag
        if !keepsFinFlag {
            state.finComputeFlag = false
        }

        switch instr.op {
        case .digit, .dot, .eex, .chs:
            return .normal

        case .enter:
            pushStack()
            state.liftEnabled = false
            return .normal

        case .clx:
            state.x = 0
            state.liftEnabled = false
            return .normal

        case .swap:
            let tmp = state.x
            state.x = state.y
            state.y = tmp
            state.liftEnabled = true
            return .normal

        case .rdown:
            let oldX = state.x
            state.x = state.y
            state.y = state.z
            state.z = state.t
            state.t = oldX
            state.liftEnabled = true
            return .normal

        case .lstx:
            if state.liftEnabled {
                pushStack()
            }
            state.x = state.lstx
            state.liftEnabled = true
            return .normal

        // Binary arithmetic
        case .add:
            try performBinaryOp { $0 + $1 }
        case .sub:
            try performBinaryOp { $0 - $1 }
        case .mul:
            try performBinaryOp { $0 * $1 }
        case .div:
            try performBinaryOp { y, x in
                guard x != 0 else { throw CalcError(0) }
                return y / x
            }
        case .yx:
            try performBinaryOp { y, x in
                if y == 0 {
                    guard x > 0 else { throw CalcError(0) }
                    return 0.0
                }
                if y < 0 {
                    guard let expInt = Numeric.exactInteger(x) else { throw CalcError(0) }
                    return pow(y, Double(expInt))
                }
                return pow(y, x)
            }

        // Unary math
        case .recip:
            try performUnaryOp { x in
                guard x != 0 else { throw CalcError(0) }
                return 1.0 / x
            }
        case .sqrt:
            try performUnaryOp { x in
                guard x >= 0 else { throw CalcError(0) }
                return Foundation.sqrt(x)
            }
        case .exp:
            try performUnaryOp { x in
                if x > 235 { return Double.infinity } // overflows cleanly to maxValue
                if x < -235 { return 0.0 }
                return Foundation.exp(x)
            }
        case .ln:
            try performUnaryOp { x in
                guard x > 0 else { throw CalcError(0) }
                return Foundation.log(x)
            }
        case .frac:
            try performUnaryOp { x in
                x - x.rounded(.towardZero)
            }
        case .intg:
            try performUnaryOp { x in
                x.rounded(.towardZero)
            }
        case .sq:
            try performUnaryOp { x in
                x * x
            }
        case .factorial:
            try performUnaryOp { x in
                guard let n = Numeric.exactInteger(x), n >= 0 else {
                    throw CalcError(0)
                }
                if n >= 70 {
                    return Double.infinity // triggers overflow clamp to 9.999999999e99
                }
                var prod = 1.0
                if n > 1 {
                    for k in 2...n {
                        prod *= Double(k)
                    }
                }
                return prod
            }
        case .rnd:
            let oldX = state.x
            let rounded: Double
            switch state.displayMode {
            case .fix(let k):
                rounded = Numeric.roundDecimal(oldX, scale: k)
            case .sci:
                rounded = Numeric.roundSignificant(oldX, digits: 7)
            }
            let norm = try normalizeOrError(rounded)
            state.x = norm
            state.liftEnabled = true

        // Percentage functions (Y preserved; no stack drop)
        case .pct:
            let oldX = state.x
            let res = try normalizeOrError(state.y * oldX / 100.0)
            state.lstx = oldX
            state.x = res
            state.liftEnabled = true

        case .dPct:
            let oldX = state.x
            guard state.y != 0 else { throw CalcError(0) }
            let res = try normalizeOrError(((oldX - state.y) / state.y) * 100.0)
            state.lstx = oldX
            state.x = res
            state.liftEnabled = true

        case .pctT:
            let oldX = state.x
            guard state.y != 0 else { throw CalcError(0) }
            let res = try normalizeOrError((oldX / state.y) * 100.0)
            state.lstx = oldX
            state.x = res
            state.liftEnabled = true

        // Display & mode flags
        case .fix(let k):
            state.displayMode = .fix(k)
        case .sci:
            state.displayMode = .sci
        case .beg:
            state.begin = true
        case .end:
            state.begin = false
        case .dmy:
            state.dmy = true
        case .my:
            state.dmy = false
        case .toggleCompound:
            state.compound.toggle()

        // Clears & info
        case .clearSigma:
            for idx in 1...6 {
                state.storage[idx] = 0
            }
            state.x = 0
            state.y = 0
            state.z = 0
            state.t = 0
            state.liftEnabled = false
        case .clearFIN:
            state.finN = 0
            state.finI = 0
            state.finPV = 0
            state.finPMT = 0
            state.finFV = 0
        case .clearREG:
            state.storage = Array(repeating: 0, count: 20)
            state.nj = Array(repeating: 1, count: 20)
            state.finN = 0
            state.finI = 0
            state.finPV = 0
            state.finPMT = 0
            state.finFV = 0
            state.x = 0
            state.y = 0
            state.z = 0
            state.t = 0
            state.lstx = 0
            state.liftEnabled = false
        case .clearPRGM:
            if state.prgmMode {
                state.program.removeAll()
            }
            state.pc = 0
        case .clearPREFIX:
            parser.reset()
            let digits = Numeric.mantissaDigits10(state.x)
            message = DisplayMessage(text: digits, kind: .info(duration: 1.5))
        case .mem:
            let text = String(format: "P-%02d r-%02d", state.allocatedLines, state.availableRegisters)
            message = DisplayMessage(text: text, kind: .info(duration: 1.5))
        case .on:
            parser.reset()
            entry.reset()
            message = nil
            dateDisplay = nil
            blinking = false
            offModifier = nil
            state.isOn = false

        // Storage / Recall
        case .store(let r):
            guard r >= 0 && r < state.availableRegisters else { throw CalcError(6) }
            state.storage[r] = state.x
            state.liftEnabled = true

        case .storeArith(let op, let r):
            guard r >= 0 && r <= 4 && r < state.availableRegisters else { throw CalcError(6) }
            let cur = state.storage[r]
            let raw: Double
            switch op {
            case .add: raw = cur + state.x
            case .sub: raw = cur - state.x
            case .mul: raw = cur * state.x
            case .div:
                guard state.x != 0 else { throw CalcError(0) }
                raw = cur / state.x
            }
            guard let norm = Numeric.normalize(raw) else { throw CalcError(0) }
            if norm.overflow { throw CalcError(1) }
            state.storage[r] = norm.value
            state.liftEnabled = true

        case .storeFin(let reg):
            switch reg {
            case .n: state.finN = state.x
            case .i: state.finI = state.x
            case .pv: state.finPV = state.x
            case .pmt: state.finPMT = state.x
            case .fv: state.finFV = state.x
            }
            state.liftEnabled = true

        case .recall(let r):
            guard r >= 0 && r < state.availableRegisters else { throw CalcError(6) }
            if state.liftEnabled { pushStack() }
            state.x = state.storage[r]
            state.liftEnabled = true

        case .recallFin(let reg):
            if state.liftEnabled { pushStack() }
            switch reg {
            case .n: state.x = state.finN
            case .i: state.x = state.finI
            case .pv: state.x = state.finPV
            case .pmt: state.x = state.finPMT
            case .fv: state.x = state.finFV
            }
            state.liftEnabled = true

        // Financial (Step 2)
        case .finN:
            if wasFinCompute {
                let v = try normalizeOrError(try TVM.solveN(state: state))
                state.finN = v
                state.x = v
            } else {
                state.finN = state.x
            }
            state.finComputeFlag = true
            state.liftEnabled = true

        case .finI:
            if wasFinCompute {
                let v = try normalizeOrError(try TVM.solveI(state: state))
                state.finI = v
                state.x = v
            } else {
                state.finI = state.x
            }
            state.finComputeFlag = true
            state.liftEnabled = true

        case .finPV:
            if wasFinCompute {
                let v = try normalizeOrError(try TVM.solvePV(state: state))
                state.finPV = v
                state.x = v
            } else {
                state.finPV = state.x
            }
            state.finComputeFlag = true
            state.liftEnabled = true

        case .finPMT:
            if wasFinCompute {
                let v = try normalizeOrError(try TVM.solvePMT(state: state))
                state.finPMT = v
                state.x = v
            } else {
                state.finPMT = state.x
            }
            state.finComputeFlag = true
            state.liftEnabled = true

        case .finFV:
            if wasFinCompute {
                let v = try normalizeOrError(try TVM.solveFV(state: state))
                state.finFV = v
                state.x = v
            } else {
                state.finFV = state.x
            }
            state.finComputeFlag = true
            state.liftEnabled = true

        case .times12:
            let v = try normalizeOrError(state.x * 12.0)
            state.x = v
            state.finN = v
            state.finComputeFlag = true
            state.liftEnabled = true

        case .div12:
            let v = try normalizeOrError(state.x / 12.0)
            state.x = v
            state.finI = v
            state.finComputeFlag = true
            state.liftEnabled = true

        case .amort:
            let oldX = state.x
            let oldY = state.y
            let res = try TVM.amortize(state: &state, countDouble: oldX)
            state.lstx = oldX
            state.t = oldY
            state.z = try normalizeOrError(oldX)
            state.y = try normalizeOrError(res.principal)
            state.x = try normalizeOrError(res.interest)
            state.liftEnabled = true

        case .int:
            let res = try TVM.simpleInterest(state: state)
            state.z = try normalizeOrError(res.int365)
            state.y = try normalizeOrError(res.negPV)
            state.x = try normalizeOrError(res.int360)
            state.liftEnabled = true

        case .cf0:
            try CashFlow.enterCF0(state: &state)
            state.liftEnabled = true

        case .cfj:
            try CashFlow.enterCFj(state: &state)
            state.liftEnabled = true

        case .nj:
            try CashFlow.enterNj(state: &state)
            state.liftEnabled = true

        case .recallCFj:
            let v = try CashFlow.recallCFj(state: &state)
            if state.liftEnabled { pushStack() }
            state.x = v
            state.liftEnabled = true

        case .recallNj:
            let v = try CashFlow.recallNj(state: state)
            if state.liftEnabled { pushStack() }
            state.x = v
            state.liftEnabled = true

        case .npv:
            let v = try normalizeOrError(try CashFlow.npv(state: state))
            state.finPV = v
            state.x = v
            state.liftEnabled = true

        case .irr:
            let v = try normalizeOrError(try CashFlow.irr(state: state, initialGuessPercent: nil))
            state.finI = v
            state.x = v
            state.liftEnabled = true

        case .irrWithGuess:
            let v = try normalizeOrError(try CashFlow.irr(state: state, initialGuessPercent: state.x))
            state.finI = v
            state.x = v
            state.liftEnabled = true

        case .price:
            let res = try Bonds.price(state: state)
            state.y = try normalizeOrError(res.accrued)
            state.x = try normalizeOrError(res.price)
            state.liftEnabled = true

        case .ytm:
            let res = try Bonds.ytm(state: state)
            state.y = try normalizeOrError(res.accrued)
            state.x = try normalizeOrError(res.yieldPercent)
            state.liftEnabled = true

        case .sl:
            let oldX = state.x
            let res = try Depreciation.sl(state: state, yearDouble: oldX)
            state.lstx = oldX
            state.y = try normalizeOrError(res.remaining)
            state.x = try normalizeOrError(res.dep)
            state.liftEnabled = true

        case .soyd:
            let oldX = state.x
            let res = try Depreciation.soyd(state: state, yearDouble: oldX)
            state.lstx = oldX
            state.y = try normalizeOrError(res.remaining)
            state.x = try normalizeOrError(res.dep)
            state.liftEnabled = true

        case .db:
            let oldX = state.x
            let res = try Depreciation.db(state: state, yearDouble: oldX)
            state.lstx = oldX
            state.y = try normalizeOrError(res.remaining)
            state.x = try normalizeOrError(res.dep)
            state.liftEnabled = true

        // Calendar & Statistics (Step 3)
        case .date:
            let oldX = state.x
            let res = try DateMath.addDays(dateVal: state.y, days: oldX, dmy: state.dmy)
            state.lstx = oldX
            state.x = res.dateVal
            state.y = state.z
            state.z = state.t
            dateDisplay = (res.dateVal, res.dow)
            state.liftEnabled = true

        case .deltaDays:
            let oldX = state.x
            let res = try DateMath.deltaDays(date1Val: state.y, date2Val: oldX, dmy: state.dmy)
            state.lstx = oldX
            state.x = try normalizeOrError(Double(res.actual))
            state.y = try normalizeOrError(Double(res.days360))
            state.liftEnabled = true

        case .sigmaPlus:
            try Statistics.accumulate(state: &state, sign: 1.0)
            state.liftEnabled = false

        case .sigmaMinus:
            try Statistics.accumulate(state: &state, sign: -1.0)
            state.liftEnabled = false

        case .mean:
            let res = try Statistics.mean(state: state)
            pushStack()
            state.x = try normalizeOrError(res.yBar)
            pushStack()
            state.x = try normalizeOrError(res.xBar)
            state.liftEnabled = true

        case .stdDev:
            let res = try Statistics.stdDev(state: state)
            pushStack()
            state.x = try normalizeOrError(res.sy)
            pushStack()
            state.x = try normalizeOrError(res.sx)
            state.liftEnabled = true

        case .weightedMean:
            let res = try Statistics.weightedMean(state: state)
            pushStack()
            state.x = try normalizeOrError(res)
            state.liftEnabled = true

        case .yHatR:
            let oldX = state.x
            let res = try Statistics.estimateY(state: state, xInput: oldX)
            state.lstx = oldX
            state.t = state.z
            state.z = state.y
            state.y = try normalizeOrError(res.r)
            state.x = try normalizeOrError(res.yHat)
            state.liftEnabled = true

        case .xHatR:
            let oldX = state.x
            let res = try Statistics.estimateX(state: state, yInput: oldX)
            state.lstx = oldX
            state.t = state.z
            state.z = state.y
            state.y = try normalizeOrError(res.r)
            state.x = try normalizeOrError(res.xHat)
            state.liftEnabled = true

        // Programming & flow (Step 4)
        case .pr:
            state.prgmMode.toggle()
            state.pc = 0

        case .rs:
            if inProgram {
                return .stop
            } else {
                isRunning = true
                return .normal
            }

        case .pse:
            if inProgram {
                return .pause
            }
            return .normal

        case .sst:
            if state.prgmMode {
                state.pc += 1
                if state.pc > state.program.count {
                    state.pc = 0
                }
            } else if !inProgram {
                if state.pc == 0 {
                    state.pc = 1
                }
                if state.pc <= state.program.count {
                    let lineNum = state.pc
                    let lineInstr = state.program[lineNum - 1]
                    message = DisplayMessage(text: lineInstr.formattedLine(lineNum), kind: .info(duration: 0.4))
                    isRunning = true
                    _ = step()
                    isRunning = false
                } else {
                    state.pc = 0
                }
            }

        case .bst:
            if state.prgmMode {
                state.pc -= 1
                if state.pc < 0 {
                    state.pc = state.program.count
                }
            } else if !inProgram {
                state.pc -= 1
                if state.pc < 0 {
                    state.pc = state.program.count
                }
                if state.pc == 0 {
                    message = DisplayMessage(text: "00-", kind: .info(duration: 0.6))
                } else {
                    let lineInstr = state.program[state.pc - 1]
                    message = DisplayMessage(text: lineInstr.formattedLine(state.pc), kind: .info(duration: 0.6))
                }
            }

        case .gto(let target):
            if inProgram {
                guard target >= 0 && target <= state.allocatedLines else {
                    throw CalcError(4)
                }
                if target == 0 || target > state.program.count {
                    return .haltAtZero
                }
                return .jumped(target)
            } else {
                guard target >= 0 && target <= state.program.count else {
                    throw CalcError(4)
                }
                state.pc = target
            }

        case .gotoLine(let target):
            guard target >= 0 && target <= state.program.count else {
                throw CalcError(4)
            }
            state.pc = target

        case .xLeY:
            if inProgram {
                return state.x <= state.y ? .normal : .skipNext
            }

        case .xEq0:
            if inProgram {
                return state.x == 0 ? .normal : .skipNext
            }

        case .error(let code):
            throw CalcError(code)
        }

        return .normal
    }

    // MARK: - Helpers

    private func handleDigitEntry(_ d: Int) {
        if !entry.isActive {
            if state.liftEnabled {
                pushStack()
            }
            entry.beginDigit(d)
        } else {
            entry.appendDigit(d)
        }
        state.x = entry.numericValue
    }

    private func handleDotEntry() {
        if !entry.isActive {
            if state.liftEnabled {
                pushStack()
            }
            entry.beginDot()
        } else {
            entry.appendDot()
        }
        state.x = entry.numericValue
    }

    private func handleEEXEntry() {
        if !entry.isActive {
            if state.liftEnabled {
                pushStack()
            }
            entry.beginEEX()
        } else {
            entry.toggleEEX()
        }
        state.x = entry.numericValue
    }

    private func handleCHS() {
        if entry.isActive {
            entry.toggleSign()
            state.x = entry.numericValue
        } else {
            state.x = state.x == 0 ? 0.0 : -state.x
            state.liftEnabled = true
        }
    }

    private func finishEntry() {
        if entry.isActive {
            state.x = entry.numericValue
            entry.reset()
            state.liftEnabled = true
        }
    }

    private func pushStack() {
        state.t = state.z
        state.z = state.y
        state.y = state.x
    }

    private func performBinaryOp(_ op: (Double, Double) throws -> Double) throws {
        let oldX = state.x
        let raw = try op(state.y, oldX)
        let res = try normalizeOrError(raw)
        state.lstx = oldX
        state.x = res
        state.y = state.z
        state.z = state.t
        state.liftEnabled = true
    }

    private func performUnaryOp(_ op: (Double) throws -> Double) throws {
        let oldX = state.x
        let raw = try op(oldX)
        let res = try normalizeOrError(raw)
        state.lstx = oldX
        state.x = res
        state.liftEnabled = true
    }

    private func normalizeOrError(_ v: Double) throws -> Double {
        guard let norm = Numeric.normalize(v) else {
            throw CalcError(0)
        }
        if norm.overflow {
            blinking = true
        }
        return norm.value
    }

    private func triggerError(_ code: Int) {
        parser.reset()
        entry.reset()
        dateDisplay = nil
        blinking = false
        message = DisplayMessage(text: "Error \(code)", kind: .error)
    }
}
