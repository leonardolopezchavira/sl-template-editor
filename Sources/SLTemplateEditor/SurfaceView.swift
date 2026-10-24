import SwiftUI
import AppKit
import SLTemplateKit

/// The template's 90 controls laid out like the ReMOTE SL's panel. In a wide window the
/// left and right sections sit side by side as on the keyboard; in a narrow one they stack.
struct SurfaceView: View {
    let template: SLTemplate
    @Binding var selection: Int
    @State private var showAux = false

    /// Width at which the two halves of the keyboard fit side by side.
    private let sideBySideWidth: CGFloat = 1040
    private let columns = Array(repeating: GridItem(.flexible(minimum: 60), spacing: 4), count: 8)

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= sideBySideWidth
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    TypeLegend()
                    pair(wide,
                         panel("Left section", [.leftUpperButtons, .encoders, .leftLowerButtons, .pots]),
                         panel("Right section", [.sliders, .rightUpperButtons, .rightLowerButtons]))
                    pair(wide,
                         panel("Drum pads", [.drumPads]),
                         panel("Transport", [.transport]))
                    panel("Pedals, joystick and touchpad", [.pedals, .wheels, .touchpad], combined: true)

                    DisclosureGroup(isExpanded: $showAux) {
                        groupGrid(.auxiliary).padding(.top, 10)
                    } label: {
                        Text("Auxiliary slots, used by Automap templates")
                            .font(Theme.heading(15))
                            .foregroundColor(Theme.inkDim)
                    }
                }
                .padding(22)
            }
        }
        .background(Theme.ground)
    }

    @ViewBuilder
    private func pair<A: View, B: View>(_ wide: Bool, _ a: A, _ b: B) -> some View {
        if wide {
            HStack(alignment: .top, spacing: 18) { a; b }
        } else {
            VStack(alignment: .leading, spacing: 22) { a; b }
        }
    }

    private func panel(_ title: String, _ groups: [SLLayout.Group], combined: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.heading(18))
                .foregroundColor(Theme.ink)
            if combined {
                let indices = groups.flatMap { Array($0.range) }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
                    ForEach(indices, id: \.self) { cell($0) }
                }
            } else {
                ForEach(groups) { g in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(g.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.inkDim)
                        groupGrid(g)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.rule, lineWidth: 1))
    }

    private func groupGrid(_ g: SLLayout.Group) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
            ForEach(displayOrder(g), id: \.self) { cell($0) }
        }
    }

    /// Panel order of a group's controls. On the keyboard the transport row ends with
    /// Record, while in the template Loop (77) comes after Record (76).
    private func displayOrder(_ g: SLLayout.Group) -> [Int] {
        g == .transport ? [72, 73, 74, 75, 77, 76] : Array(g.range)
    }

    private func cell(_ index: Int) -> some View {
        ControlCell(index: index, control: template.control(index), isSelected: selection == index)
            .onTapGesture { selection = index }
    }
}

/// One control drawn as the physical part, with its 8-character LCD name and a summary
/// of what it sends underneath, as on the keyboard's panel.
struct ControlCell: View {
    let index: Int
    let control: SLControl
    let isSelected: Bool

    var body: some View {
        let hue = Theme.color(for: control.type)
        let off = control.typeRaw == 0
        VStack(spacing: 6) {
            if let caption = ControlCell.captions[index] {
                Text(caption)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.inkDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            ControlGlyph(kind: ControlKind(index: index), hue: hue, fraction: snapshotFraction, off: off)
                .frame(maxWidth: .infinity)
            Text(control.name.isEmpty ? "—" : control.name)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? Theme.signal : (off ? Theme.off : Theme.ink))
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 3).fill(Theme.raised))
            Text(summary)
                .font(.system(size: 11, weight: .bold).width(.condensed))
                .foregroundColor(hue)
                .lineLimit(1)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isSelected ? Theme.signal : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        .help("\(SLLayout.label(of: index)) — \(summary)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(SLLayout.label(of: index)), \(control.name), \(summary)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Physical labels for controls whose shape alone doesn't say what they are.
    static let captions: [Int: String] = [
        64: "Expression", 65: "Sustain", 66: "Joystick mod", 67: "Joystick pitch",
        68: "Touchpad X1", 69: "Touchpad Y1", 70: "Touchpad X2", 71: "Touchpad Y2",
    ]

    /// Where the snapshot value sits between the low and high values, for drawing knob and fader positions.
    private var snapshotFraction: Double {
        let lo = Double(control.lowValue), hi = Double(control.highValue), v = Double(control.snapshotValue)
        guard hi != lo else { return 0 }
        return min(max((v - min(lo, hi)) / abs(hi - lo), 0), 1)
    }

    private var summary: String {
        guard let type = control.type else { return "Type \(control.typeRaw)" }
        let ch = control.channelGroup == .own ? " ch\(control.channel)" : ""
        switch type {
        case .disabled: return "Off"
        case .cc: return "CC \(control.numberLSB)\(ch)"
        case .nrpn: return "NRPN \(control.numberMSB):\(control.numberLSB)\(ch)"
        case .rpn: return "RPN \(control.numberMSB):\(control.numberLSB)\(ch)"
        case .sysex: return "SysEx"
        case .mmc: return SLMMCCommand(rawValue: control.mmcCommand)?.name ?? "MMC"
        case .note, .noteAlt: return "Note \(MIDINoteName.name(control.noteNumber))\(ch)"
        case .drumNote: return "Drum \(MIDINoteName.name(control.lowValue & 0x7F))\(ch)"
        default: return type.shortName + ch
        }
    }
}
