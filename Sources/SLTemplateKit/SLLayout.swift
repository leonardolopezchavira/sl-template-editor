import Foundation

/// Physical layout of the ReMOTE SL / ZeRO SL (MkI) and the order of the 90 control records.
public enum SLLayout {
    public static let controlCount = 90

    public enum Group: String, CaseIterable, Identifiable {
        case encoders = "Encoders"
        case pots = "Pots"
        case sliders = "Sliders"
        case leftUpperButtons = "Left Upper Buttons"
        case leftLowerButtons = "Left Lower Buttons"
        case rightUpperButtons = "Right Upper Buttons"
        case rightLowerButtons = "Right Lower Buttons"
        case drumPads = "Drum Pads"
        case pedals = "Pedals"
        case wheels = "Joystick"
        case touchpad = "Touchpad"
        case transport = "Transport"
        case auxiliary = "Auxiliary (Automap)"

        public var id: String { rawValue }

        public var range: ClosedRange<Int> {
            switch self {
            case .encoders: return 0...7
            case .pots: return 8...15
            case .sliders: return 16...23
            case .leftUpperButtons: return 24...31
            case .leftLowerButtons: return 32...39
            case .rightUpperButtons: return 40...47
            case .rightLowerButtons: return 48...55
            case .drumPads: return 56...63
            case .pedals: return 64...65
            case .wheels: return 66...67
            case .touchpad: return 68...71
            case .transport: return 72...77
            case .auxiliary: return 78...89
            }
        }

        public var isButtonRow: Bool {
            switch self {
            case .leftUpperButtons, .leftLowerButtons, .rightUpperButtons, .rightLowerButtons, .transport, .auxiliary:
                return true
            default:
                return false
            }
        }

        public var isContinuous: Bool {
            switch self {
            case .encoders, .pots, .sliders, .pedals, .wheels, .touchpad: return true
            default: return false
            }
        }
    }

    public static func group(of index: Int) -> Group {
        Group.allCases.first { $0.range.contains(index) } ?? .auxiliary
    }

    public static func label(of index: Int) -> String {
        let g = group(of: index)
        let n = index - g.range.lowerBound + 1
        switch g {
        case .encoders: return "Encoder \(n)"
        case .pots: return "Pot \(n)"
        case .sliders: return "Slider \(n)"
        case .leftUpperButtons: return "Left Upper \(n)"
        case .leftLowerButtons: return "Left Lower \(n)"
        case .rightUpperButtons: return "Right Upper \(n)"
        case .rightLowerButtons: return "Right Lower \(n)"
        case .drumPads: return "Drum Pad \(n)"
        case .pedals: return n == 1 ? "Expression Pedal" : "Sustain Pedal"
        case .wheels: return n == 1 ? "Joystick Mod" : "Joystick Pitch Bend"
        case .touchpad: return ["Touchpad X1", "Touchpad Y1", "Touchpad X2", "Touchpad Y2"][n - 1]
        case .transport: return ["Rewind", "Forward", "Stop", "Play", "Record", "Loop"][n - 1]
        case .auxiliary: return "Aux \(n)"
        }
    }
}

public enum SLControlType: UInt8, CaseIterable, Identifiable {
    case disabled = 0, cc, nrpn, rpn, sysex, mmc, note, noteAlt, bankSelect, programChange, pitchBend, drumNote, aftertouch

    public var id: UInt8 { rawValue }

    public var name: String {
        switch self {
        case .disabled: return "Disabled"
        case .cc: return "CC"
        case .nrpn: return "NRPN"
        case .rpn: return "RPN"
        case .sysex: return "SysEx"
        case .mmc: return "MMC"
        case .note: return "Note On/Off"
        case .noteAlt: return "Note On/Off (alt)"
        case .bankSelect: return "Bank Select"
        case .programChange: return "Program Change"
        case .pitchBend: return "Pitch Bend"
        case .drumNote: return "Drum Note"
        case .aftertouch: return "Aftertouch"
        }
    }

    public var shortName: String {
        switch self {
        case .disabled: return "—"
        case .noteAlt, .note: return "Note"
        case .bankSelect: return "Bank"
        case .programChange: return "PrgCh"
        case .pitchBend: return "PB"
        case .drumNote: return "Drum"
        case .aftertouch: return "AT"
        default: return name
        }
    }
}

public enum SLDisplayFormat {
    /// Known values recovered from the original editor's UI handlers.
    public static let known: [(UInt8, String)] = [
        (0, "0 to 127"), (1, "-64 to 63"), (3, "On/Off"), (6, "REL1"), (7, "REL2"), (17, "APOT"),
    ]
    public static func name(_ v: UInt8) -> String {
        if v == 2 { return "MMC" }
        return known.first { $0.0 == v }?.1 ?? "Other (\(v))"
    }
}

public enum SLButtonAction: Int, CaseIterable, Identifiable {
    case normal = 0, momentary, toggle, step
    public var id: Int { rawValue }
    public var name: String { ["Normal", "Momentary", "Toggle", "Step"][rawValue] }
}

public enum SLPotCatchup: Int, CaseIterable, Identifiable {
    case jump = 0, pickup, template, global
    public var id: Int { rawValue }
    public var name: String { ["Jump", "Pickup", "Template", "Global"][rawValue] }
}

/// Channel / port group as stored in bytes 18 and 19 of a control record.
public enum SLGroup: Int, CaseIterable, Identifiable {
    case common = 0, own = 1, keyboard = 2
    public var id: Int { rawValue }
    public var name: String { ["Common", "This control", "Keyboard"][rawValue] }

    static func from(bits: UInt8) -> SLGroup {
        if bits & 0x40 != 0 { return .common }
        if bits & 0x20 != 0 { return .keyboard }
        return .own
    }
    var bits: UInt8 {
        switch self {
        case .common: return 0x40
        case .own: return 0x00
        case .keyboard: return 0x20
        }
    }
}

public enum SLMMCCommand: UInt8, CaseIterable, Identifiable {
    case stop = 1, play, deferredPlay, forward, rewind, record, recordExit, recordPause, pause, eject, chase, errorReset, mmcReset
    public var id: UInt8 { rawValue }
    public var name: String {
        ["Stop", "Play", "Def. Play", "Forward", "Rewind", "Record", "Record Exit", "Record Pause",
         "Pause", "Eject", "Chase", "Err. Reset", "MMC Reset"][Int(rawValue) - 1]
    }
}

public enum MIDINoteName {
    static let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    /// Uses the original editor's convention (note 0 = C-2).
    public static func name(_ n: Int) -> String {
        guard (0...127).contains(n) else { return "" }
        return "\(names[n % 12])\(n / 12 - 2)"
    }
}
