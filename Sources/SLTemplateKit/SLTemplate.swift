import Foundation

public enum SLTemplateError: Error, LocalizedError {
    case wrongSize(Int)
    case notSLTemplate
    case badStructure(String)

    public var errorDescription: String? {
        switch self {
        case .wrongSize(let n): return "A ReMOTE SL template is 4112 bytes; this message is \(n) bytes."
        case .notSLTemplate: return "This SysEx message is not a Novation ReMOTE SL template."
        case .badStructure(let s): return "Template structure is invalid: \(s)"
        }
    }
}

/// A complete 4112-byte ReMOTE SL template SysEx message.
/// The raw bytes are the source of truth; typed accessors edit them in place.
public struct SLTemplate: Equatable, Identifiable {
    public static let size = 4112
    public static let controlBase = 419
    /// Novation SysEx prefix for ReMOTE SL templates. Byte 7 (the transfer mode) follows it.
    public static let prefix: [UInt8] = [0xF0, 0x00, 0x20, 0x29, 0x02, 0x03, 0x7F]
    /// Header used for new templates: prefix, transfer mode 0, then byte 8 = 0.
    public static let header: [UInt8] = prefix + [0x00, 0x00]

    public let id = UUID()
    public private(set) var bytes: [UInt8]

    public static func == (a: SLTemplate, b: SLTemplate) -> Bool { a.bytes == b.bytes }

    public init(bytes: [UInt8]) throws {
        guard bytes.count == SLTemplate.size else { throw SLTemplateError.wrongSize(bytes.count) }
        // Byte 7 is 0 in single-template files made for uploading and 1 in keyboard dumps and banks.
        guard Array(bytes[0..<7]) == SLTemplate.prefix, bytes[7] <= 1, bytes[8] == 0,
              bytes[SLTemplate.size - 1] == 0xF7 else {
            throw SLTemplateError.notSLTemplate
        }
        if bytes[1..<(SLTemplate.size - 1)].contains(where: { $0 >= 0x80 }) {
            throw SLTemplateError.badStructure("contains non-7-bit data")
        }
        var b = bytes
        // Same repair the original editor performs ("NUMCMN" / "PGCNSIZE").
        b[68] = 0x5A
        b[69] = 0x29
        self.bytes = b
    }

    public init(data: Data) throws { try self.init(bytes: [UInt8](data)) }

    public var data: Data { Data(bytes) }

    // MARK: header

    /// Memory slot 0–39 the template belongs to.
    public var slot: Int {
        get { Int(bytes[12]) }
        set { bytes[12] = UInt8(min(max(newValue, 0), 39)) }
    }

    public var versionBytes: (UInt8, UInt8) { (bytes[9], bytes[10]) }

    /// Header byte 7. 0 = single template for the keyboard's temporary (edit) memory, as the
    /// original editor sends it; 1 = template stored to its slot, as in bulk dumps.
    public var isStorageDump: Bool {
        get { bytes[7] == 1 }
        set { bytes[7] = newValue ? 1 : 0 }
    }

    /// A copy with the transfer mode set for sending.
    public func forTransfer(toStorage: Bool) -> SLTemplate {
        var t = self
        t.isStorageDump = toStorage
        return t
    }

    // MARK: names

    private func text(_ range: Range<Int>) -> String {
        let s = String(bytes[range].map { (0x20...0x7E).contains($0) ? Character(UnicodeScalar($0)) : " " })
        return s.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
    }
    private mutating func setText(_ range: Range<Int>, _ value: String) {
        let clean = value.unicodeScalars.map { (0x20...0x7E).contains($0.value) ? UInt8($0.value) : 0x3F }
        for (k, i) in range.enumerated() { bytes[i] = k < clean.count ? clean[k] : 0x20 }
    }

    public static let nameLength = 35
    public static let manufacturerLength = 13

    public var name: String {
        get { text(13..<48) }
        set { setText(13..<48, newValue) }
    }
    public var manufacturer: String {
        get { text(48..<61) }
        set { setText(48..<61, newValue) }
    }

    // MARK: controls

    public func control(_ index: Int) -> SLControl {
        let o = SLTemplate.controlBase + index * SLControl.size
        return SLControl(bytes: Array(bytes[o..<(o + SLControl.size)]))
    }

    public mutating func setControl(_ index: Int, _ c: SLControl) {
        let o = SLTemplate.controlBase + index * SLControl.size
        bytes.replaceSubrange(o..<(o + SLControl.size), with: c.bytes)
    }

    public var controls: [SLControl] { (0..<SLLayout.controlCount).map(control) }

    // MARK: keyboard zones

    public func zone(_ n: Int) -> SLZone { SLZone(bytes: Array(bytes[(111 + n * 10)..<(121 + n * 10)])) }
    public mutating func setZone(_ n: Int, _ z: SLZone) {
        bytes.replaceSubrange((111 + n * 10)..<(121 + n * 10), with: z.bytes)
    }

    // MARK: raw global section

    /// Bytes 61..<419 — template-wide settings, exposed raw for advanced editing.
    public var globalBytes: ArraySlice<UInt8> { bytes[61..<SLTemplate.controlBase] }
    public mutating func setGlobalByte(_ offset: Int, _ value: UInt8) {
        guard (61..<SLTemplate.controlBase).contains(offset), offset != 68, offset != 69 else { return }
        bytes[offset] = value & 0x7F
    }

    // MARK: derived templates

    /// A copy of this template with every control disabled and blank, keeping all global settings.
    public func clearedCopy(name: String) -> SLTemplate {
        var t = self
        for i in 0..<SLLayout.controlCount { t.setControl(i, .blank) }
        t.name = name
        return t
    }

    /// The same template with fresh identity (for duplicating into another slot).
    public func duplicate(toSlot slot: Int) -> SLTemplate {
        var t = try! SLTemplate(bytes: bytes)
        t.slot = slot
        return t
    }
}

/// One of the four template keyboard zones (10 bytes).
public struct SLZone: Equatable {
    public private(set) var bytes: [UInt8]
    init(bytes: [UInt8]) { self.bytes = bytes }

    public var channel: Int {
        get { Int(bytes[0] & 0x0F) + 1 }
        set { bytes[0] = (bytes[0] & 0xF0) | UInt8((min(max(newValue, 1), 16) - 1) & 0x0F) }
    }
    public var channelGroup: SLGroup {
        get { SLGroup.from(bits: bytes[0]) }
        set { bytes[0] = (bytes[0] & ~0x60) | newValue.bits }
    }
    public var ports: UInt8 { get { bytes[1] & 0x1F } set { bytes[1] = (bytes[1] & 0x60) | (newValue & 0x1F) } }
    public var portGroup: SLGroup {
        get { SLGroup.from(bits: bytes[1]) }
        set { bytes[1] = (bytes[1] & ~0x60) | newValue.bits }
    }
    public var bottomNote: Int { get { Int(bytes[3]) } set { bytes[3] = UInt8(min(max(newValue, 0), 127)) } }
    public var topNote: Int { get { Int(bytes[4]) } set { bytes[4] = UInt8(min(max(newValue, 0), 127)) } }
    public var transpose: Int { get { Int(bytes[5]) - 64 } set { bytes[5] = UInt8(min(max(newValue, -64), 63) + 64) } }
    public var aftertouch: Bool { get { bytes[6] & 0x01 != 0 } set { flag(0x01, newValue) } }
    public var pitchBend: Bool { get { bytes[6] & 0x02 != 0 } set { flag(0x02, newValue) } }
    public var modWheel: Bool { get { bytes[6] & 0x04 != 0 } set { flag(0x04, newValue) } }
    /// Byte +2, preserved raw.
    public var velocityRaw: UInt8 { get { bytes[2] } set { bytes[2] = newValue & 0x7F } }

    private mutating func flag(_ m: UInt8, _ on: Bool) { if on { bytes[6] |= m } else { bytes[6] &= ~m } }
}
