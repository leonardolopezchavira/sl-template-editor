import Foundation

/// One 41-byte control record. All accessors read/write the raw bytes directly, so any
/// bits this editor does not understand are preserved exactly.
public struct SLControl: Equatable {
    public static let size = 41
    public private(set) var bytes: [UInt8]

    public init(bytes: [UInt8]) {
        precondition(bytes.count == SLControl.size, "control record must be 41 bytes")
        self.bytes = bytes
    }

    /// A disabled control with a blank name.
    public static var blank: SLControl {
        var b = [UInt8](repeating: 0, count: size)
        for i in 0..<8 { b[i] = 0x20 }
        b[12] = 127   // high value 127
        b[18] = 0x05  // USB + MIDI 1
        return SLControl(bytes: b)
    }

    // MARK: helpers

    private func get14(_ i: Int) -> Int { Int(bytes[i] & 0x7F) << 7 | Int(bytes[i + 1] & 0x7F) }
    private mutating func set14(_ i: Int, _ v: Int) {
        let v = min(max(v, 0), 16383)
        bytes[i] = UInt8(v >> 7)
        bytes[i + 1] = UInt8(v & 0x7F)
    }
    private mutating func setBit(_ i: Int, _ mask: UInt8, _ on: Bool) {
        if on { bytes[i] |= mask } else { bytes[i] &= ~mask }
    }

    // MARK: identity

    /// LCD name, up to 8 printable ASCII characters.
    public var name: String {
        get {
            let s = String(bytes[0..<8].map { (0x20...0x7E).contains($0) ? Character(UnicodeScalar($0)) : " " })
            return s.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        }
        set {
            let clean = newValue.unicodeScalars.map { (0x20...0x7E).contains($0.value) ? UInt8($0.value) : 0x3F }
            for i in 0..<8 { bytes[i] = i < clean.count ? clean[i] : 0x20 }
        }
    }

    public var typeRaw: UInt8 {
        get { bytes[8] }
        set {
            bytes[8] = newValue & 0x7F
            if newValue == SLControlType.mmc.rawValue { bytes[15] = 2 }
            else if bytes[15] == 2 { bytes[15] = 0 }
        }
    }
    public var type: SLControlType? { SLControlType(rawValue: bytes[8]) }

    // MARK: values

    /// Low / press value (14-bit). Holds the note for Drum Note controls.
    public var lowValue: Int { get { get14(9) } set { set14(9, newValue) } }
    /// High / release value (14-bit).
    public var highValue: Int { get { get14(11) } set { set14(11, newValue) } }
    /// Value sent on snapshot (14-bit).
    public var snapshotValue: Int { get { get14(20) } set { set14(20, newValue) } }

    /// CC number, NRPN/RPN LSB, or note number.
    public var numberLSB: Int { get { Int(bytes[17]) } set { bytes[17] = UInt8(min(max(newValue, 0), 127)) } }
    /// NRPN / RPN MSB.
    public var numberMSB: Int { get { Int(bytes[16]) } set { bytes[16] = UInt8(min(max(newValue, 0), 127)) } }

    /// Note number. Type 6 (Note On/Off) keeps it in byte 10; other note types use the controller number.
    public var noteNumber: Int {
        get { typeRaw == SLControlType.note.rawValue ? Int(bytes[10]) : numberLSB }
        set {
            let v = UInt8(min(max(newValue, 0), 127))
            if typeRaw == SLControlType.note.rawValue { bytes[10] = v } else { bytes[17] = v }
        }
    }

    /// Note velocity. Type 6 keeps it in byte 12; other note types use the high value.
    public var noteVelocity: Int {
        get { typeRaw == SLControlType.note.rawValue ? Int(bytes[12]) : (highValue & 0x7F) }
        set {
            let v = min(max(newValue, 0), 127)
            if typeRaw == SLControlType.note.rawValue { bytes[12] = UInt8(v) } else { highValue = v }
        }
    }

    public var mmcCommand: UInt8 { get { bytes[10] } set { bytes[10] = newValue & 0x7F } }
    public var mmcDevice: Int { get { Int(bytes[19]) } set { bytes[19] = UInt8(min(max(newValue, 0), 127)) } }

    // MARK: routing

    /// MIDI channel 1–16 (not meaningful for MMC, where byte 19 is the device ID).
    public var channel: Int {
        get { Int(bytes[19] & 0x0F) + 1 }
        set { bytes[19] = (bytes[19] & 0xF0) | UInt8((min(max(newValue, 1), 16) - 1) & 0x0F) }
    }
    public var channelGroup: SLGroup {
        get { SLGroup.from(bits: bytes[19]) }
        set { bytes[19] = (bytes[19] & ~0x60) | newValue.bits }
    }

    public var midiPort1: Bool { get { bytes[18] & 0x01 != 0 } set { setBit(18, 0x01, newValue) } }
    public var midiPort2: Bool { get { bytes[18] & 0x02 != 0 } set { setBit(18, 0x02, newValue) } }
    public var usbPort: Bool { get { bytes[18] & 0x04 != 0 } set { setBit(18, 0x04, newValue) } }
    public var usbPortB: Bool { get { bytes[18] & 0x08 != 0 } set { setBit(18, 0x08, newValue) } }
    public var usbPortC: Bool { get { bytes[18] & 0x10 != 0 } set { setBit(18, 0x10, newValue) } }
    public var portGroup: SLGroup {
        get { SLGroup.from(bits: bytes[18]) }
        set { bytes[18] = (bytes[18] & ~0x60) | newValue.bits }
    }

    // MARK: behaviour

    public var send14Bit: Bool { get { bytes[13] & 0x01 != 0 } set { setBit(13, 0x01, newValue) } }
    public var potPickup: Bool { get { bytes[13] & 0x02 != 0 } set { setBit(13, 0x02, newValue) } }

    public var buttonAction: SLButtonAction {
        get {
            let a = bytes[13]
            if a & 0x10 != 0 { return .step }
            if a & 0x08 != 0 { return .toggle }
            if a & 0x04 != 0 { return .momentary }
            return .normal
        }
        set {
            bytes[13] &= ~0x1C
            switch newValue {
            case .normal: break
            case .momentary: bytes[13] |= 0x04
            case .toggle: bytes[13] |= 0x08
            case .step: bytes[13] |= 0x10
            }
        }
    }

    /// Step size 1–64 for Step buttons.
    public var stepSize: Int {
        get { Int(bytes[22]) + 1 }
        set { bytes[22] = UInt8(min(max(newValue, 1), 64) - 1) }
    }

    public var potCatchup: SLPotCatchup {
        get { SLPotCatchup(rawValue: Int(bytes[14] >> 5) & 3) ?? .jump }
        set { bytes[14] = (bytes[14] & ~0x60) | UInt8(newValue.rawValue << 5) }
    }

    public var displayFormat: UInt8 { get { bytes[15] } set { bytes[15] = newValue & 0x7F } }

    /// Raw flag bytes for advanced users (bits not otherwise exposed).
    public var flagsA: UInt8 { bytes[13] }
    public var flagsB: UInt8 { bytes[14] }

    // MARK: SysEx

    public enum SysExToken: Equatable {
        case byte(UInt8)
        case value
    }

    /// The message between F0 and F7. The 12-byte buffer holds every position, with a
    /// placeholder byte where the control value (DV) goes; byte 27 is the length and
    /// byte 28 the 1-based DV position.
    public var sysexMessage: [SysExToken] {
        get {
            let len = min(Int(bytes[27]), 12)
            let dv = Int(bytes[28])
            guard len > 0 else { return [] }
            return (1...len).map { p -> SysExToken in p == dv ? SysExToken.value : SysExToken.byte(bytes[28 + p]) }
        }
        set {
            let tokens = Array(newValue.prefix(12))
            let oldDV = Int(bytes[28])
            var dv = 0
            for (i, t) in tokens.enumerated() where t == .value && dv == 0 { dv = i + 1 }
            for i in 0..<12 {
                if i < tokens.count {
                    switch tokens[i] {
                    case .byte(let b): bytes[29 + i] = b & 0x7F
                    case .value: if i + 1 != oldDV { bytes[29 + i] = 0 }  // keep the original placeholder
                    }
                } else {
                    bytes[29 + i] = 0
                }
            }
            // Byte 26 is 1 for plain messages; Roland templates store the checksum start (e.g. 4) here.
            bytes[26] = dv > 0 ? max(bytes[26], 1) : 0
            bytes[27] = UInt8(tokens.count)
            bytes[28] = UInt8(dv)
        }
    }

    /// Byte 26: 1 for a plain message, or the position where a Roland checksum starts (e.g. 4).
    public var sysexChecksumStart: Int {
        get { Int(bytes[26]) }
        set { bytes[26] = UInt8(min(max(newValue, 0), 12)) }
    }

    /// SysEx message as editable text, e.g. "41 36 00 23 20 01 0E DV".
    public var sysexText: String {
        sysexMessage.map { t -> String in
            if case .byte(let b) = t { return String(format: "%02X", b) }
            return "DV"
        }.joined(separator: " ")
    }

    /// Parses text such as "F0 41 10 DV F7" (F0/F7 optional). Returns nil if invalid.
    public static func parseSysex(_ text: String) -> [SysExToken]? {
        var tokens: [SysExToken] = []
        for word in text.uppercased().split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" }) {
            if word == "DV" { tokens.append(.value); continue }
            guard let v = UInt8(word, radix: 16) else { return nil }
            if v == 0xF0 || v == 0xF7 { continue }
            guard v < 0x80 else { return nil }
            tokens.append(.byte(v))
        }
        let dvCount = tokens.filter { $0 == .value }.count
        guard dvCount <= 1, !tokens.isEmpty, tokens.count <= 12 else { return nil }
        return tokens
    }
}
