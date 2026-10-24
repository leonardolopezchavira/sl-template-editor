import Foundation

public enum SysExIO {
    /// Splits raw MIDI bytes into complete F0…F7 SysEx messages.
    public static func messages(in bytes: [UInt8]) -> [[UInt8]] {
        var out: [[UInt8]] = []
        var current: [UInt8]? = nil
        for b in bytes {
            if b == 0xF0 {
                current = [b]
            } else if current != nil {
                if b >= 0xF8 { continue }          // real-time bytes may interleave
                current!.append(b)
                if b == 0xF7 { out.append(current!); current = nil }
                else if b >= 0x80 { current = nil } // aborted message
            }
        }
        return out
    }

    /// All valid ReMOTE SL templates found in the data, plus a count of messages that were skipped.
    public static func templates(in data: Data) -> (templates: [SLTemplate], skipped: Int) {
        var ts: [SLTemplate] = []
        var skipped = 0
        for m in messages(in: [UInt8](data)) {
            if let t = try? SLTemplate(bytes: m) { ts.append(t) } else { skipped += 1 }
        }
        return (ts, skipped)
    }

    /// Reads hex text (e.g. the "NovationSLMKIIDefaults" .txt dumps) into bytes.
    public static func bytes(fromHexText text: String) -> [UInt8]? {
        let hex = text.filter { $0.isHexDigit }
        guard hex.count % 2 == 0, !hex.isEmpty else { return nil }
        var out: [UInt8] = []
        out.reserveCapacity(hex.count / 2)
        var i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2)
            guard let v = UInt8(hex[i..<j], radix: 16) else { return nil }
            out.append(v)
            i = j
        }
        return out
    }

    /// Loads a .syx (binary) or .txt (hex) file.
    public static func load(url: URL) throws -> (templates: [SLTemplate], skipped: Int) {
        let data = try Data(contentsOf: url)
        let first = data.first ?? 0
        if first == 0xF0 { return templates(in: data) }
        if let text = String(data: data, encoding: .ascii) ?? String(data: data, encoding: .utf8),
           let b = bytes(fromHexText: text) {
            return templates(in: Data(b))
        }
        return templates(in: data)
    }

    /// Concatenates templates into one .syx bank file.
    public static func bankData(_ templates: [SLTemplate]) -> Data {
        var d = Data()
        for t in templates { d.append(t.data) }
        return d
    }

    /// Hex text in the same style as the "NovationSLMKIIDefaults" dumps (30 bytes per line).
    public static func hexText(_ t: SLTemplate) -> String {
        var lines: [String] = []
        var i = 0
        while i < t.bytes.count {
            let chunk = t.bytes[i..<min(i + 30, t.bytes.count)]
            lines.append(chunk.map { String(format: "%02x", $0) }.joined())
            i += 30
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
