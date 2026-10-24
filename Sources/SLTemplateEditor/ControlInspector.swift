import SwiftUI
import SLTemplateKit

struct ControlInspector: View {
    @Binding var control: SLControl
    let index: Int

    @State private var sysexDraft = ""
    @State private var sysexError: String?

    private var group: SLLayout.Group { SLLayout.group(of: index) }
    private var type: SLControlType? { control.type }
    private var valueMax: Int { control.send14Bit ? 16383 : 127 }

    var body: some View {
        Form {
            Section {
                LabeledContent("Control", value: SLLayout.label(of: index))
                TextField("LCD name", text: $control.name, prompt: Text("8 characters"))
                Picker("Type", selection: $control.typeRaw) {
                    ForEach(SLControlType.allCases) { Text($0.name).tag($0.rawValue) }
                    if type == nil { Text("Unknown (\(control.typeRaw))").tag(control.typeRaw) }
                }
            } header: {
                HStack(spacing: 8) {
                    Rectangle().fill(Theme.color(for: type)).frame(width: 4, height: 18)
                    Text(SLLayout.label(of: index))
                        .font(Theme.heading(18))
                        .foregroundColor(Theme.ink)
                }
                .textCase(nil)
            }

            if type != .disabled {
                messageSection
                if type != .mmc { rangeSection }
                behaviourSection
                routingSection
            }

            Section {
                DisclosureGroup("Raw bytes") {
                    Text(control.bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Theme.ground)
        .tint(Theme.signal)
        .onAppear { sysexDraft = control.sysexText }
        .onChange(of: index) { _ in sysexDraft = control.sysexText; sysexError = nil }
    }

    // MARK: sections

    @ViewBuilder private var messageSection: some View {
        Section("Message") {
            switch type ?? .disabled {
            case .cc:
                NumberField("CC number", value: $control.numberLSB, range: 0...127)
            case .nrpn, .rpn:
                NumberField("\(type == .nrpn ? "NRPN" : "RPN") MSB", value: $control.numberMSB, range: 0...127)
                NumberField("\(type == .nrpn ? "NRPN" : "RPN") LSB", value: $control.numberLSB, range: 0...127)
            case .note, .noteAlt:
                NumberField("Note", value: $control.noteNumber, range: 0...127,
                            detail: MIDINoteName.name(control.noteNumber))
                NumberField("Velocity", value: $control.noteVelocity, range: 0...127)
            case .drumNote:
                NumberField("Note", value: $control.lowValue, range: 0...127,
                            detail: MIDINoteName.name(control.lowValue))
            case .mmc:
                Picker("Command", selection: $control.mmcCommand) {
                    ForEach(SLMMCCommand.allCases) { Text($0.name).tag($0.rawValue) }
                    if SLMMCCommand(rawValue: control.mmcCommand) == nil {
                        Text("Other (\(control.mmcCommand))").tag(control.mmcCommand)
                    }
                }
                NumberField("Device ID", value: $control.mmcDevice, range: 0...127,
                            detail: control.mmcDevice == 127 ? "all" : nil)
            case .sysex:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Message in hex, bytes separated by spaces. Use DV for the control value. F0/F7 are added automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. 41 10 42 12 DV", text: $sysexDraft)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit(applySysex)
                    HStack {
                        if let e = sysexError {
                            Text(e).font(.caption).foregroundColor(Theme.nrpn)
                        } else {
                            Text("Up to 12 bytes including DV").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Set", action: applySysex)
                            .disabled(sysexDraft == control.sysexText)
                    }
                    if control.sysexChecksumStart > 1 {
                        NumberField("Roland checksum from byte", value: $control.sysexChecksumStart, range: 1...12)
                    }
                }
            default:
                Text("\(type?.name ?? "This type") uses the control's range and channel.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var rangeSection: some View {
        Section("Values") {
            if group.isButtonRow || group == .drumPads {
                if type != .drumNote {
                    NumberField("Press / min value", value: $control.lowValue, range: 0...valueMax)
                }
                NumberField("Release / max value", value: $control.highValue, range: 0...valueMax)
            } else {
                NumberField("Low value", value: $control.lowValue, range: 0...valueMax)
                NumberField("High value", value: $control.highValue, range: 0...valueMax)
            }
            Picker("Display", selection: $control.displayFormat) {
                ForEach(SLDisplayFormat.known, id: \.0) { Text($0.1).tag($0.0) }
                if !SLDisplayFormat.known.contains(where: { $0.0 == control.displayFormat }) {
                    Text(SLDisplayFormat.name(control.displayFormat)).tag(control.displayFormat)
                }
            }
            NumberField("Snapshot value", value: $control.snapshotValue, range: 0...valueMax)
        }
    }

    @ViewBuilder private var behaviourSection: some View {
        Section("Behaviour") {
            if group.isButtonRow {
                Picker("Button type", selection: $control.buttonAction) {
                    ForEach(SLButtonAction.allCases) { Text($0.name).tag($0) }
                }
                if control.buttonAction == .step {
                    NumberField("Step size", value: $control.stepSize, range: 1...64)
                }
            }
            if group.isContinuous {
                Picker("Pot strategy", selection: $control.potCatchup) {
                    ForEach(SLPotCatchup.allCases) { Text($0.name).tag($0) }
                }
                Toggle("Pot pickup on this control", isOn: $control.potPickup)
            }
            if type == .cc || type == .nrpn || type == .rpn {
                Toggle("Send 14-bit values (0–16383)", isOn: $control.send14Bit)
            }
        }
    }

    @ViewBuilder private var routingSection: some View {
        Section("MIDI routing") {
            if type != .mmc {
                Picker("Channel", selection: $control.channelGroup) {
                    ForEach(SLGroup.allCases) { Text($0 == .own ? "Set below" : "\($0.name) channel").tag($0) }
                }
                if control.channelGroup == .own {
                    NumberField("MIDI channel", value: $control.channel, range: 1...16)
                }
            }
            Picker("Ports", selection: $control.portGroup) {
                ForEach(SLGroup.allCases) { Text($0 == .own ? "Set below" : "\($0.name) ports").tag($0) }
            }
            if control.portGroup == .own {
                Toggle("USB port", isOn: $control.usbPort)
                Toggle("USB port B", isOn: $control.usbPortB)
                Toggle("USB port C", isOn: $control.usbPortC)
                Toggle("MIDI out 1", isOn: $control.midiPort1)
                Toggle("MIDI out 2", isOn: $control.midiPort2)
            }
        }
    }

    private func applySysex() {
        guard let tokens = SLControl.parseSysex(sysexDraft) else {
            sysexError = "Use 2-digit hex bytes below 80, at most 12 positions including one DV."
            return
        }
        control.sysexMessage = tokens
        sysexDraft = control.sysexText
        sysexError = nil
    }
}

/// Labelled integer field with a stepper, clamped to a range.
struct NumberField: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var detail: String? = nil

    init(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, detail: String? = nil) {
        self.title = title
        self._value = value
        self.range = range
        self.detail = detail
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                if let detail = detail {
                    Text(detail).font(.system(size: 11, weight: .semibold)).foregroundColor(Theme.inkDim)
                }
                TextField("", value: Binding(
                    get: { value },
                    set: { value = min(max($0, range.lowerBound), range.upperBound) }),
                    format: .number)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 64)
                    .labelsHidden()
                Stepper("", value: $value, in: range)
                    .labelsHidden()
            }
        }
    }
}
