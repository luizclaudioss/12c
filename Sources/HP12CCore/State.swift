import Foundation

public enum DisplayMode: Codable, Equatable, Sendable {
    case fix(Int)
    case sci
}

public struct Annunciators: Equatable, Sendable {
    public var f: Bool = false
    public var g: Bool = false
    public var begin: Bool = false
    public var dmy: Bool = false
    public var compound: Bool = false
    public var prgm: Bool = false

    public init(
        f: Bool = false,
        g: Bool = false,
        begin: Bool = false,
        dmy: Bool = false,
        compound: Bool = false,
        prgm: Bool = false
    ) {
        self.f = f
        self.g = g
        self.begin = begin
        self.dmy = dmy
        self.compound = compound
        self.prgm = prgm
    }
}

public enum DisplayMessageKind: Equatable, Sendable {
    case error
    case info(duration: Double)
}

public struct DisplayMessage: Equatable, Sendable {
    public var text: String
    public var kind: DisplayMessageKind

    public init(text: String, kind: DisplayMessageKind) {
        self.text = text
        self.kind = kind
    }
}

public enum StepResult: Equatable, Sendable {
    case `continue`
    case pause
    case stopped
}

public struct CalcError: Error, Equatable, Sendable {
    public let code: Int
    public init(_ code: Int) {
        self.code = code
    }
}

public struct HP12CState: Codable, Equatable, Sendable {
    public var x: Double = 0
    public var y: Double = 0
    public var z: Double = 0
    public var t: Double = 0
    public var lstx: Double = 0

    public var storage: [Double] = Array(repeating: 0, count: 20)
    public var nj: [Int] = Array(repeating: 1, count: 20)

    public var finN: Double = 0
    public var finI: Double = 0
    public var finPV: Double = 0
    public var finPMT: Double = 0
    public var finFV: Double = 0

    public var begin: Bool = false
    public var dmy: Bool = false
    public var compound: Bool = false
    public var european: Bool = false
    public var displayMode: DisplayMode = .fix(2)

    public var program: [Instruction] = []
    public var pc: Int = 0
    public var prgmMode: Bool = false

    public var liftEnabled: Bool = true
    public var finComputeFlag: Bool = false
    public var isOn: Bool = true

    public init() {}

    public var regsLost: Int {
        if program.count <= 8 { return 0 }
        return (program.count - 8 + 6) / 7
    }

    public var availableRegisters: Int {
        20 - regsLost
    }

    public var allocatedLines: Int {
        8 + 7 * regsLost
    }
}
