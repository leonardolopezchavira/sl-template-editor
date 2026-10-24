import SwiftUI
import SLTemplateKit

/// Ultra-high-contrast palette: true black ground, white ink, one signal colour for
/// selection and the primary action, and a saturated hue per MIDI message type so a
/// template can be read at a glance. Every text colour is at least 7:1 against black (WCAG AAA).
enum Theme {
    static let ground = Color.black
    static let raised = Color(white: 0.085)                       // control faces, fields
    static let rule = Color(white: 0.32)                          // outlines and dividers
    static let ink = Color.white
    static let inkDim = Color(white: 0.74)                        // ≈ 11:1
    static let off = Color(white: 0.60)                           // disabled controls, ≈ 7.4:1
    static let signal = Color(red: 1.0, green: 0.902, blue: 0.0)  // #FFE600

    static let cc = Color(red: 0.0, green: 0.878, blue: 1.0)       // #00E0FF
    static let nrpn = Color(red: 1.0, green: 0.361, blue: 0.851)   // #FF5CD9
    static let note = Color(red: 1.0, green: 0.620, blue: 0.110)   // #FF9E1C
    static let mmc = Color(red: 0.549, green: 1.0, blue: 0.349)    // #8CFF59
    static let sysex = Color(red: 0.702, green: 0.580, blue: 1.0)  // #B394FF

    static func color(for type: SLControlType?) -> Color {
        switch type {
        case .cc?: return cc
        case .nrpn?, .rpn?: return nrpn
        case .note?, .noteAlt?, .drumNote?: return note
        case .mmc?: return mmc
        case .sysex?: return sysex
        case .pitchBend?, .aftertouch?, .programChange?, .bankSelect?: return ink
        case .disabled?, nil: return off
        }
    }

    static let legend: [(String, Color)] = [
        ("CC", cc), ("NRPN / RPN", nrpn), ("Note / Drum", note), ("MMC", mmc),
        ("SysEx", sysex), ("Pitch bend, aftertouch, program", ink), ("Off", off),
    ]

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .black).width(.condensed) }
    static func heading(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy).width(.condensed) }
}

/// Primary action: signal yellow with black text, so it stays legible (≈ 17:1).
struct SignalButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(isEnabled ? .black : Theme.off)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEnabled ? Theme.signal.opacity(configuration.isPressed ? 0.72 : 1) : Theme.raised))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isEnabled ? Color.clear : Theme.rule))
    }
}

/// Secondary action: white outline on black.
struct OutlineButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isEnabled ? Theme.ink : Theme.off)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(configuration.isPressed ? Theme.raised : Theme.ground))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isEnabled ? Theme.inkDim : Theme.rule))
    }
}

/// Explains the type colours used on the control surface.
struct TypeLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            ForEach(Theme.legend, id: \.0) { item in
                HStack(spacing: 6) {
                    Rectangle().fill(item.1).frame(width: 10, height: 10)
                    Text(item.0).font(.system(size: 11, weight: .medium)).foregroundColor(Theme.inkDim)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Colour key for message types")
    }
}
