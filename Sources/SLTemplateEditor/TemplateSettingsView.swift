import SwiftUI
import SLTemplateKit

struct TemplateSettingsView: View {
    @Binding var template: SLTemplate

    var body: some View {
        Form {
            Section("Template") {
                TextField("Name", text: $template.name, prompt: Text("Up to \(SLTemplate.nameLength) characters"))
                TextField("Manufacturer", text: $template.manufacturer, prompt: Text("Up to \(SLTemplate.manufacturerLength) characters"))
                LabeledContent("Memory slot", value: "\(template.slot + 1) (use Move Up/Down in the list to change)")
                LabeledContent("Format bytes") {
                    let v = template.versionBytes
                    Text(String(format: "%02X %02X", v.0, v.1))
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(0..<4, id: \.self) { n in
                ZoneSection(number: n + 1, zone: zoneBinding(n))
            }

            Section {
                DisclosureGroup("Global bytes 61–418 (preserved exactly; not all are decoded)") {
                    GlobalBytesGrid(bytes: Array(template.globalBytes))
                }
            } footer: {
                Text("These hold keyboard, pad and row-select settings. The editor never changes them unless you edit a zone above, so templates round-trip byte-for-byte.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .tint(Theme.signal)
    }

    private func zoneBinding(_ n: Int) -> Binding<SLZone> {
        Binding(get: { template.zone(n) }, set: { template.setZone(n, $0) })
    }
}

private struct ZoneSection: View {
    let number: Int
    @Binding var zone: SLZone

    var body: some View {
        Section("Keyboard zone \(number)") {
            NumberField("Bottom note", value: $zone.bottomNote, range: 0...127, detail: MIDINoteName.name(zone.bottomNote))
            NumberField("Top note", value: $zone.topNote, range: 0...127, detail: MIDINoteName.name(zone.topNote))
            NumberField("Transpose", value: $zone.transpose, range: -64...63)
            Picker("Channel", selection: $zone.channelGroup) {
                ForEach(SLGroup.allCases) { Text($0 == .own ? "Set below" : "\($0.name) channel").tag($0) }
            }
            if zone.channelGroup == .own {
                NumberField("MIDI channel", value: $zone.channel, range: 1...16)
            }
            Picker("Ports", selection: $zone.portGroup) {
                ForEach(SLGroup.allCases) { Text($0 == .own ? "Set below" : "\($0.name) ports").tag($0) }
            }
            if zone.portGroup == .own {
                PortToggles(ports: $zone.ports)
            }
            Toggle("Aftertouch", isOn: $zone.aftertouch)
            Toggle("Pitch bend (joystick)", isOn: $zone.pitchBend)
            Toggle("Modulation (joystick)", isOn: $zone.modWheel)
        }
    }
}

private struct PortToggles: View {
    @Binding var ports: UInt8
    private let items: [(String, UInt8)] = [("MIDI out 1", 0x01), ("MIDI out 2", 0x02), ("USB port", 0x04), ("USB port B", 0x08), ("USB port C", 0x10)]

    var body: some View {
        ForEach(items, id: \.1) { item in
            Toggle(item.0, isOn: Binding(
                get: { ports & item.1 != 0 },
                set: { on in if on { ports |= item.1 } else { ports &= ~item.1 } }))
        }
    }
}

private struct GlobalBytesGrid: View {
    let bytes: [UInt8]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(stride(from: 0, to: bytes.count, by: 16)), id: \.self) { start in
                HStack(spacing: 10) {
                    Text(String(format: "%3d", start + 61))
                        .foregroundStyle(.tertiary)
                    Text(bytes[start..<min(start + 16, bytes.count)].map { String(format: "%02X", $0) }.joined(separator: " "))
                }
                .font(.system(.caption, design: .monospaced))
            }
        }
        .textSelection(.enabled)
        .padding(.top, 6)
    }
}
