import Foundation

extension SLTemplate {
    /// Global settings (bytes 61..<419) taken from a "Learn" template dumped by a ReMOTE SL:
    /// four zones on channels 1–4, keyboard on channel 1, standard row-select defaults.
    static let defaultGlobalsHex =
        "000000000000005a290000000000000000000000001900010021000900390011002900310107004700470000030500000700202003007f4007000000414003007f4007000000424003007f4007000000434003007f400700000000000000000000000000000000000000000000000a0a0a0a0a0a0a0a0001004000000000400000"

    /// A brand-new empty template for the given slot.
    public static func newTemplate(name: String = "New Template", slot: Int = 0) -> SLTemplate {
        var b: [UInt8] = SLTemplate.header + [0x09, 0x06, 0x00, UInt8(min(max(slot, 0), 39))]
        b += [UInt8](repeating: 0x20, count: SLTemplate.nameLength + SLTemplate.manufacturerLength)
        var globals = SysExIO.bytes(fromHexText: defaultGlobalsHex) ?? []
        globals += [UInt8](repeating: 0, count: SLTemplate.controlBase - 61 - globals.count)
        b += globals
        for _ in 0..<SLLayout.controlCount { b += SLControl.blank.bytes }
        b += [0x12, 0x34, 0xF7]
        var t = try! SLTemplate(bytes: b)
        t.name = name
        return t
    }
}
