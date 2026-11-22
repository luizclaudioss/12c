import Foundation
import AppKit
import Combine
import HP12CCore

@MainActor
final class CalculatorViewModel: ObservableObject {
    let engine: HP12C

    @Published private(set) var displayText: String
    @Published private(set) var annunciators: Annunciators
    @Published private(set) var blinking: Bool
    @Published private(set) var isOn: Bool
    @Published var pressedKey: Key?
    @Published var mousePressedKey: Key?
    @Published var showingShortcuts: Bool = false

    private var runTask: Task<Void, Never>?
    private var infoTimerTask: Task<Void, Never>?
    private var flashKeyTask: Task<Void, Never>?
    private var keyMonitor: Any?

    private static var stateURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("HP12C/state.json")
    }

    init() {
        let url = Self.stateURL
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(HP12CState.self, from: data)
                self.engine = HP12C(state: decoded)
            } catch {
                let fresh = HP12C()
                fresh.triggerMemoryResetError()
                self.engine = fresh
            }
        } else {
            self.engine = HP12C()
        }

        self.displayText = engine.displayText
        self.annunciators = engine.annunciators
        self.blinking = engine.blinking
        self.isOn = engine.isOn
    }

    func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.showingShortcuts {
                if event.keyCode == 53 {
                    Task { @MainActor in self.showingShortcuts = false }
                    return nil
                }
                return event
            }
            if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
                return event
            }
            if self.handleKeyDown(event) {
                return nil
            }
            return event
        }
    }

    func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        // Return / Keypad Enter
        if event.keyCode == 36 || event.keyCode == 76 {
            triggerKeyFromKeyboard(.enter)
            return true
        }
        // Backspace / Forward Delete
        if event.keyCode == 51 || event.keyCode == 117 {
            backspace()
            return true
        }
        // Escape -> cancel prefix
        if event.keyCode == 53 {
            cancelPrefix()
            return true
        }

        guard let chars = event.charactersIgnoringModifiers?.lowercased(), let ch = chars.first else {
            return false
        }

        // Also check unshifted/shifted characters from event.characters (e.g. % ^ + *)
        let actualChar = event.characters?.first
        if let actualChar {
            switch actualChar {
            case "+": triggerKeyFromKeyboard(.add); return true
            case "*": triggerKeyFromKeyboard(.mul); return true
            case "%": triggerKeyFromKeyboard(.pct); return true
            case "^": triggerKeyFromKeyboard(.yx); return true
            default: break
            }
        }

        let mapped: Key?
        switch ch {
        case "0": mapped = .d0
        case "1": mapped = .d1
        case "2": mapped = .d2
        case "3": mapped = .d3
        case "4": mapped = .d4
        case "5": mapped = .d5
        case "6": mapped = .d6
        case "7": mapped = .d7
        case "8": mapped = .d8
        case "9": mapped = .d9
        case ".", ",": mapped = .dot
        case "+": mapped = .add
        case "-": mapped = .sub
        case "*": mapped = .mul
        case "/": mapped = .div
        case "f": mapped = .f
        case "g": mapped = .g
        case "s": mapped = .sto
        case "r": mapped = .rcl
        case "n": mapped = .n
        case "i": mapped = .i
        case "p": mapped = .pv
        case "m": mapped = .pmt
        case "v": mapped = .fv
        case "c": mapped = .chs
        case "e": mapped = .eex
        case "x": mapped = .swap
        case "d": mapped = .rdown
        case " ": mapped = .rs
        case "o": mapped = .on
        case "%": mapped = .pct
        case "^": mapped = .yx
        default: mapped = nil
        }

        if let key = mapped {
            triggerKeyFromKeyboard(key)
            return true
        }
        return false
    }

    private func triggerKeyFromKeyboard(_ key: Key) {
        pressedKey = key
        flashKeyTask?.cancel()
        flashKeyTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 90_000_000)
            if !Task.isCancelled {
                self?.pressedKey = nil
            }
        }
        press(key)
    }

    func press(_ key: Key) {
        infoTimerTask?.cancel()
        infoTimerTask = nil

        if engine.isRunning {
            engine.stopRunning()
            runTask?.cancel()
            runTask = nil
            syncUI()
            saveState()
            return
        }

        engine.press(key)
        syncUI()
        saveState()

        if engine.isRunning {
            startRunLoop()
        } else if let msg = engine.message, case .info(let duration) = msg.kind {
            infoTimerTask = Task { [weak self] in
                let ns = UInt64(max(0.05, duration) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: ns)
                guard let self, !Task.isCancelled else { return }
                self.engine.clearInfoMessage()
                self.syncUI()
            }
        }
    }

    func backspace() {
        infoTimerTask?.cancel()
        infoTimerTask = nil
        if engine.isRunning { return }
        engine.backspace()
        syncUI()
        saveState()
    }

    func cancelPrefix() {
        infoTimerTask?.cancel()
        infoTimerTask = nil
        if engine.isRunning {
            engine.stopRunning()
            runTask?.cancel()
            runTask = nil
        } else {
            engine.cancelPrefix()
        }
        syncUI()
    }

    func toggleSeparator() {
        engine.toggleSeparator()
        syncUI()
        saveState()
    }

    func resetContinuousMemory() {
        runTask?.cancel()
        runTask = nil
        infoTimerTask?.cancel()
        infoTimerTask = nil
        engine.triggerMemoryResetError()
        syncUI()
        saveState()
    }

    func copyXString() -> String {
        let v = engine.x == 0 ? 0.0 : engine.x
        let s = String(format: "%.10g", v)
        return engine.state.european ? s.replacingOccurrences(of: ".", with: ",") : s
    }

    func pasteFromString(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let noSpaces = trimmed.replacingOccurrences(of: " ", with: "")
        let parsed: Double?
        if let direct = Double(noSpaces) {
            parsed = direct
        } else if engine.state.european {
            let clean = noSpaces.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            parsed = Double(clean)
        } else if noSpaces.contains(",") && !noSpaces.contains(".") {
            let parts = noSpaces.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count == 2 && parts[1].count != 3 {
                parsed = Double(noSpaces.replacingOccurrences(of: ",", with: "."))
            } else {
                parsed = Double(noSpaces.replacingOccurrences(of: ",", with: ""))
            }
        } else {
            parsed = Double(noSpaces.replacingOccurrences(of: ",", with: ""))
        }

        if let val = parsed, val.isFinite {
            engine.setX(val)
            syncUI()
            saveState()
        }
    }

    private func startRunLoop() {
        runTask?.cancel()
        runTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.engine.isRunning {
                var steps = 0
                var hitPause = false
                while steps < 500 && self.engine.isRunning && !Task.isCancelled {
                    let res = self.engine.step()
                    steps += 1
                    if res == .pause {
                        hitPause = true
                        break
                    }
                    if res == .stopped {
                        break
                    }
                }
                self.syncUI()
                if hitPause {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled || !self.engine.isRunning { break }
                } else if self.engine.isRunning {
                    await Task.yield()
                }
            }
            self.syncUI()
            self.saveState()
        }
    }

    func syncUI() {
        displayText = engine.displayText
        annunciators = engine.annunciators
        blinking = engine.blinking
        isOn = engine.isOn
    }

    func saveState() {
        let url = Self.stateURL
        let dir = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(engine.state)
            try data.write(to: url, options: .atomic)
        } catch {
            // Non-fatal persistence write failure
        }
    }
}
