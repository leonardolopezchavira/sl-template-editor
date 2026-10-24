import SwiftUI
import SLTemplateKit

/// What a control physically is on the ReMOTE SL, so it can be drawn as that part.
enum ControlKind {
    case encoder, pot, slider, button, transport(String), pad, pedal, joystickMod, joystickPitch, touchpadX, touchpadY

    init(index: Int) {
        switch SLLayout.group(of: index) {
        case .encoders: self = .encoder
        case .pots: self = .pot
        case .sliders: self = .slider
        case .drumPads: self = .pad
        case .pedals: self = .pedal
        case .wheels: self = index == 66 ? .joystickMod : .joystickPitch
        case .touchpad: self = (index % 2 == 0) ? .touchpadX : .touchpadY
        case .transport:
            let symbols = ["backward.fill", "forward.fill", "stop.fill", "play.fill", "record.circle", "repeat"]
            self = .transport(symbols[index - 72])
        default: self = .button
        }
    }
}

/// Draws the physical control. `hue` is the message-type colour; `fraction` (0…1) is where
/// the snapshot value sits within the control's low…high range.
struct ControlGlyph: View {
    let kind: ControlKind
    let hue: Color
    let fraction: Double
    let off: Bool

    var body: some View {
        switch kind {
        case .encoder: KnobGlyph(hue: hue, fraction: nil, off: off)
        case .pot: KnobGlyph(hue: hue, fraction: fraction, off: off)
        case .slider: FaderGlyph(hue: hue, fraction: fraction, off: off)
        case .button: KeyGlyph(hue: hue, symbol: nil, off: off)
        case .transport(let s): KeyGlyph(hue: hue, symbol: s, off: off)
        case .pad: PadGlyph(hue: hue, off: off)
        case .pedal: PedalGlyph(hue: hue, off: off)
        case .joystickMod: JoystickGlyph(hue: hue, horizontal: false, off: off)
        case .joystickPitch: JoystickGlyph(hue: hue, horizontal: true, off: off)
        case .touchpadX: TouchpadGlyph(hue: hue, horizontal: true, off: off)
        case .touchpadY: TouchpadGlyph(hue: hue, horizontal: false, off: off)
        }
    }
}

// MARK: - Rotary controls

/// Encoders are endless (dashed ring, pointer at the top); pots have a 270° travel arc.
struct KnobGlyph: View {
    let hue: Color
    let fraction: Double?
    let off: Bool
    private let size: CGFloat = 46

    var body: some View {
        let accent = off ? Theme.rule : hue
        ZStack {
            if let f = fraction {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Theme.rule, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(135))
                Circle()
                    .trim(from: 0, to: 0.75 * max(f, 0.001))
                    .stroke(accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(135))
            } else {
                Circle()
                    .stroke(accent, style: StrokeStyle(lineWidth: 2, dash: [2, 3.2]))
            }
            Circle()
                .fill(Theme.raised)
                .overlay(Circle().strokeBorder(off ? Theme.rule : Theme.inkDim, lineWidth: 1))
                .padding(7)
            Capsule()
                .fill(off ? Theme.off : Theme.ink)
                .frame(width: 2.5, height: 9)
                .offset(y: -(size / 2 - 7 - 7))
                .rotationEffect(.degrees(fraction.map { -135 + 270 * $0 } ?? 0))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Fader

struct FaderGlyph: View {
    let hue: Color
    let fraction: Double
    let off: Bool
    private let height: CGFloat = 92
    private let capHeight: CGFloat = 14

    var body: some View {
        let travel = height - capHeight
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(Theme.raised)
                .overlay(Capsule().strokeBorder(Theme.rule, lineWidth: 1))
                .frame(width: 6, height: height)
            Capsule()
                .fill(off ? Theme.rule : hue)
                .frame(width: 6, height: max(capHeight / 2 + travel * fraction, 6))
            RoundedRectangle(cornerRadius: 3)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(off ? Theme.rule : Theme.inkDim, lineWidth: 1))
                .overlay(Rectangle().fill(off ? Theme.off : Theme.ink).frame(height: 2).padding(.horizontal, 4))
                .frame(width: 28, height: capHeight)
                .offset(y: -travel * fraction)
        }
        .frame(width: 34, height: height)
    }
}

// MARK: - Buttons and pads

/// A raised key with a status light in the message-type colour.
struct KeyGlyph: View {
    let hue: Color
    let symbol: String?
    let off: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(off ? Theme.rule : Theme.inkDim, lineWidth: 1))
                .shadow(color: off ? Color.clear : Theme.rule, radius: 0, x: 0, y: 3)
            if let s = symbol {
                Image(systemName: s)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(off ? Theme.off : Theme.ink)
            }
        }
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(off ? Theme.rule : hue)
                .frame(width: 6, height: 6)
                .padding(5)
        }
        .frame(height: 26)
        .frame(maxWidth: 64)
        .padding(.bottom, 3)
    }
}

/// A square rubber drum pad.
struct PadGlyph: View {
    let hue: Color
    let off: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(Theme.raised)
            .overlay(RoundedRectangle(cornerRadius: 9).fill(off ? Color.clear : hue.opacity(0.16)).padding(7))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(off ? Theme.rule : hue, lineWidth: 2))
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 58)
    }
}

// MARK: - Pedals, wheels, touchpad

struct PedalGlyph: View {
    let hue: Color
    let off: Bool

    var body: some View {
        PedalShape()
            .fill(Theme.raised)
            .overlay(PedalShape().stroke(off ? Theme.rule : Theme.inkDim, lineWidth: 1))
            .overlay(alignment: .bottom) {
                Capsule().fill(off ? Theme.rule : hue).frame(width: 18, height: 3).padding(.bottom, 7)
            }
            .frame(width: 34, height: 52)
    }
}

private struct PedalShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.18, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.18, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// The pitch/mod joystick seen from above: a round gate with the stick in the centre.
/// The coloured line shows the axis this control uses (pitch bend left–right, mod up–down).
struct JoystickGlyph: View {
    let hue: Color
    let horizontal: Bool
    let off: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.raised)
                .overlay(Circle().strokeBorder(off ? Theme.rule : Theme.inkDim, lineWidth: 1))
            Rectangle()
                .fill(Theme.rule)
                .frame(width: horizontal ? 2 : nil, height: horizontal ? nil : 2)
                .padding(9)
            Rectangle()
                .fill(off ? Theme.rule : hue)
                .frame(width: horizontal ? nil : 3, height: horizontal ? 3 : nil)
                .padding(9)
            Circle()
                .fill(Theme.ground)
                .overlay(Circle().strokeBorder(off ? Theme.off : Theme.ink, lineWidth: 2))
                .frame(width: 16, height: 16)
        }
        .frame(width: 52, height: 52)
    }
}

/// The X/Y touchpad; the coloured line shows which axis this control sends.
struct TouchpadGlyph: View {
    let hue: Color
    let horizontal: Bool
    let off: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.raised)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(off ? Theme.rule : Theme.inkDim, lineWidth: 1))
            Rectangle()
                .fill(off ? Theme.rule : hue)
                .frame(width: horizontal ? nil : 2, height: horizontal ? 2 : nil)
                .padding(8)
        }
        .frame(width: 52, height: 52)
    }
}
