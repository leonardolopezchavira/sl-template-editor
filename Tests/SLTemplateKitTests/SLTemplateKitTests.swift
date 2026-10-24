import XCTest
@testable import SLTemplateKit

/// Most tests use Novation's factory templates when they sit in the folder that contains this
/// package: ReMOTESLZeroEditor.app/Contents/Resources/FactorySettings.blk (40 templates) and
/// NovationSLMKIIDefaults/*.txt dumps. They are not distributed with this repository, so those
/// tests skip when the files are absent.
final class SLTemplateKitTests: XCTestCase {
    static let projectFolder: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // SLTemplateKitTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // SLTemplateEditor (package)
        .deletingLastPathComponent()   // the folder that contains the package

    func allTemplates() throws -> [SLTemplate] {
        var out: [SLTemplate] = []
        let blk = Self.projectFolder.appendingPathComponent("ReMOTESLZeroEditor.app/Contents/Resources/FactorySettings.blk")
        if FileManager.default.fileExists(atPath: blk.path) {
            out += try SysExIO.load(url: blk).templates
        }
        let dumps = Self.projectFolder.appendingPathComponent("NovationSLMKIIDefaults")
        if let files = try? FileManager.default.contentsOfDirectory(at: dumps, includingPropertiesForKeys: nil) {
            for f in files where f.pathExtension == "txt" {
                out += try SysExIO.load(url: f).templates
            }
        }
        if out.isEmpty { throw XCTSkip("No template fixtures found next to the package.") }
        return out
    }

    func testFactoryBankHas40Templates() throws {
        let blk = Self.projectFolder.appendingPathComponent("ReMOTESLZeroEditor.app/Contents/Resources/FactorySettings.blk")
        guard FileManager.default.fileExists(atPath: blk.path) else { throw XCTSkip("FactorySettings.blk not found") }
        let r = try SysExIO.load(url: blk)
        XCTAssertEqual(r.templates.count, 40)
        XCTAssertEqual(r.skipped, 0)
        XCTAssertEqual(r.templates.map(\.slot), Array(0..<40))
    }

    func testRoundTripIsByteExact() throws {
        for t in try allTemplates() {
            var copy = try SLTemplate(bytes: t.bytes)
            // Rewriting every control through the typed API must not change a single byte.
            for i in 0..<SLLayout.controlCount {
                var c = copy.control(i)
                c.name = c.name
                c.channel = c.channel
                c.channelGroup = c.channelGroup
                c.portGroup = c.portGroup
                c.lowValue = c.lowValue
                c.highValue = c.highValue
                c.snapshotValue = c.snapshotValue
                c.buttonAction = c.buttonAction
                c.potCatchup = c.potCatchup
                if (1...12).contains(c.bytes[27]), c.bytes[28] > 0 { c.sysexMessage = c.sysexMessage }
                copy.setControl(i, c)
            }
            for n in 0..<4 {
                var z = copy.zone(n)
                z.transpose = z.transpose
                copy.setZone(n, z)
            }
            XCTAssertEqual(copy.bytes, t.bytes, "round trip changed “\(t.name)”")
        }
    }

    /// The ready-made templates shipped in this repository's Templates/ folder load and
    /// re-encode byte-for-byte. Runs everywhere (no Novation files needed).
    func testBundledTemplatesRoundTrip() throws {
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Templates")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        let syx = files.filter { $0.pathExtension == "syx" }
        guard !syx.isEmpty else { throw XCTSkip("No Templates/ folder next to the package.") }
        for f in syx {
            let r = try SysExIO.load(url: f)
            XCTAssertEqual(r.templates.count, 1, f.lastPathComponent)
            XCTAssertEqual(r.skipped, 0, f.lastPathComponent)
            if let t = r.templates.first {
                XCTAssertEqual(t.bytes, [UInt8](try Data(contentsOf: f)), f.lastPathComponent)
            }
        }
    }

    func testCCNamesMatchCCNumbers() throws {
        var checked = 0
        for t in try allTemplates() {
            for c in t.controls where c.type == .cc && c.name.hasPrefix("CC# ") {
                XCTAssertEqual(Int(c.name.dropFirst(4).trimmingCharacters(in: .whitespaces)), c.numberLSB)
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 0)
    }

    func testTransportIsMMC() throws {
        let stations = try allTemplates().first { $0.name == "Stations" }
        guard let t = stations else { throw XCTSkip("Stations template not present") }
        XCTAssertEqual(t.control(72).type, .mmc)
        XCTAssertEqual(SLMMCCommand(rawValue: t.control(72).mmcCommand), .rewind)
        XCTAssertEqual(SLMMCCommand(rawValue: t.control(75).mmcCommand), .play)
    }

    func testNewTemplateIsValid() throws {
        let t = SLTemplate.newTemplate(name: "Test", slot: 5)
        XCTAssertEqual(t.bytes.count, 4112)
        XCTAssertEqual(t.slot, 5)
        XCTAssertEqual(t.name, "Test")
        XCTAssertEqual(Array(t.bytes.suffix(3)), [0x12, 0x34, 0xF7])
        XCTAssertNoThrow(try SLTemplate(bytes: t.bytes))
        XCTAssertFalse(t.bytes.dropFirst().dropLast().contains { $0 >= 0x80 })
    }

    func testAcceptsBothTransferModes() throws {
        var b = SLTemplate.newTemplate().bytes
        b[7] = 0
        XCTAssertFalse(try SLTemplate(bytes: b).isStorageDump)
        b[7] = 1
        XCTAssertTrue(try SLTemplate(bytes: b).isStorageDump)
        b[7] = 2
        XCTAssertThrowsError(try SLTemplate(bytes: b))
        XCTAssertEqual(SLTemplate.newTemplate().forTransfer(toStorage: true).bytes[7], 1)
    }

    func testEditingFields() {
        var c = SLControl.blank
        c.name = "Cutoff"
        c.typeRaw = SLControlType.cc.rawValue
        c.numberLSB = 74
        c.channel = 10
        c.channelGroup = .own
        c.buttonAction = .toggle
        c.potCatchup = .pickup
        XCTAssertEqual(c.name, "Cutoff")
        XCTAssertEqual(Array(c.bytes[0..<8]), Array("Cutoff  ".utf8))
        XCTAssertEqual(c.bytes[17], 74)
        XCTAssertEqual(c.bytes[19] & 0x0F, 9)
        XCTAssertEqual(c.bytes[13] & 0x1C, 0x08)
        XCTAssertEqual(c.bytes[14] & 0x60, 0x20)

        c.typeRaw = SLControlType.sysex.rawValue
        c.sysexMessage = SLControl.parseSysex("F0 41 36 00 23 20 01 0E DV F7")!
        XCTAssertEqual(c.sysexText, "41 36 00 23 20 01 0E DV")
        XCTAssertEqual(c.bytes[26], 1)
        XCTAssertEqual(c.bytes[27], 8)
        XCTAssertEqual(c.bytes[28], 8)
        XCTAssertEqual(Array(c.bytes[29..<36]), [0x41, 0x36, 0x00, 0x23, 0x20, 0x01, 0x0E])
        XCTAssertNil(SLControl.parseSysex("90 DV"))      // status byte not allowed
        XCTAssertNil(SLControl.parseSysex("01 DV DV"))   // only one DV
        XCTAssertNil(SLControl.parseSysex("00 01 02 03 04 05 06 07 08 09 0A 0B DV"))  // 13 positions
    }
}
