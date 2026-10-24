import SwiftUI
import SLTemplateKit

struct TemplateEditorView: View {
    @EnvironmentObject var model: EditorModel
    let slot: Int
    let fallback: SLTemplate

    enum Tab: String, CaseIterable, Identifiable {
        case controls = "Controls"
        case settings = "Template settings"
        var id: String { rawValue }
    }
    @State private var tab: Tab = .controls
    @AppStorage("showInspector") private var showInspector = true

    var body: some View {
        let template = model.templateBinding(slot: slot, fallback: fallback)
        VStack(spacing: 0) {
            header(template)
            Rectangle().fill(Theme.rule).frame(height: 1)
            switch tab {
            case .controls:
                HStack(spacing: 0) {
                    SurfaceView(template: template.wrappedValue, selection: $model.selectedControl)
                    if showInspector {
                        Rectangle().fill(Theme.rule).frame(width: 1)
                        ControlInspector(
                            control: model.controlBinding(slot: slot, index: model.selectedControl, fallback: fallback),
                            index: model.selectedControl)
                            .frame(width: 350)
                            .transition(.move(edge: .trailing))
                    }
                }
                .animation(.easeOut(duration: 0.18), value: showInspector)
            case .settings:
                TemplateSettingsView(template: template)
            }
        }
        .background(Theme.ground)
    }

    private func header(_ template: Binding<SLTemplate>) -> some View {
        let t = template.wrappedValue
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                title(t)
                Spacer(minLength: 12)
                controls
            }
            VStack(alignment: .leading, spacing: 12) {
                title(t)
                HStack(spacing: 10) { controls }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(Theme.ground)
    }

    private func title(_ t: SLTemplate) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(t.name.isEmpty ? "Untitled" : t.name)
                .font(Theme.display(30))
                .foregroundColor(Theme.ink)
                .lineLimit(1)
            HStack(spacing: 10) {
                Text("Template \(slot + 1)")
                if !t.manufacturer.isEmpty { Text(t.manufacturer) }
                if model.modifiedSlots.contains(slot) {
                    Text("Edited, not sent yet").foregroundColor(Theme.signal)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Theme.inkDim)
        }
        .layoutPriority(1)
    }

    @ViewBuilder private var controls: some View {
        Picker("", selection: $tab) {
            ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        if tab == .controls {
            Button { showInspector.toggle() } label: {
                Label(showInspector ? "Hide inspector" : "Show inspector", systemImage: "sidebar.right")
            }
            .buttonStyle(OutlineButtonStyle())
            .help("Show or hide the control inspector to make room for the surface")
        }
        Button { model.saveCurrent() } label: { Label("Save…", systemImage: "square.and.arrow.down") }
            .buttonStyle(OutlineButtonStyle())
            .help("Save this template as a .syx file (⌘S)")
        SendTemplateButton(midi: model.midi)
    }
}

/// Sends only the template being edited, to the keyboard's temporary memory.
private struct SendTemplateButton: View {
    @EnvironmentObject var model: EditorModel
    @ObservedObject var midi: MIDIService

    var body: some View {
        Button { model.sendCurrent() } label: {
            Label(midi.isSending ? "Sending…" : "Send This Template", systemImage: "arrow.up.circle.fill")
        }
        .buttonStyle(SignalButtonStyle())
        .disabled(!midi.hasDestination || midi.isSending)
        .help(midi.hasDestination
              ? "Send only this template to the keyboard's temporary memory (⌘U)"
              : "Choose the keyboard as the MIDI output in the toolbar first")
    }
}
