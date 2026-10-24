import SwiftUI
import CoreMIDI
import UniformTypeIdentifiers
import SLTemplateKit

struct ContentView: View {
    @EnvironmentObject var model: EditorModel

    var body: some View {
        NavigationSplitView {
            BankSidebar()
                .navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 340)
        } detail: {
            if let slot = model.selectedSlot, let t = model.bank[slot] {
                TemplateEditorView(slot: slot, fallback: t)
                    .id(slot)
            } else {
                EmptyStateView()
            }
        }
        .background(Theme.ground)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                MIDIToolbar(midi: model.midi)
            }
        }
        .alert(item: $model.alert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
        .confirmationDialog("Send all \(model.templateCount) templates to the keyboard?",
                            isPresented: $model.confirmBulkSend, titleVisibility: .visible) {
            Button("Send All") { model.sendBank() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Each template goes to the slot number it carries. Test with a single template first, and make sure Memory Protect is off in the keyboard's Global menu if you want them stored.")
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            loadDropped(providers)
            return true
        }
    }

    private func loadDropped(_ providers: [NSItemProvider]) {
        for p in providers {
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                DispatchQueue.main.async { model.importFiles([url]) }
            }
        }
    }
}

// MARK: - Toolbar

struct MIDIToolbar: View {
    @ObservedObject var midi: MIDIService
    @EnvironmentObject var model: EditorModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(midi.activity ? Theme.signal : Theme.off)
                .frame(width: 8, height: 8)
                .help(midi.activity ? "Receiving SysEx…" : "MIDI input idle")
            Text(midi.status)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.inkDim)
                .lineLimit(1)
                .frame(minWidth: 120, maxWidth: 340, alignment: .trailing)
                .layoutPriority(-1)
            Picker("From", selection: $midi.sourceID) {
                Text("No input").tag(MIDIUniqueID?.none)
                ForEach(midi.sources) { e in Text(e.name).tag(Optional(e.id)) }
            }
            .frame(minWidth: 130, idealWidth: 190, maxWidth: 190)
            .help("MIDI input: templates sent from the keyboard arrive here")
            Picker("To", selection: $midi.destinationID) {
                Text("No output").tag(MIDIUniqueID?.none)
                ForEach(midi.destinations) { e in Text(e.name).tag(Optional(e.id)) }
            }
            .frame(minWidth: 130, idealWidth: 190, maxWidth: 190)
            .help("MIDI output: the keyboard's USB or MIDI port")
            Button {
                midi.refreshEndpoints()
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
            }
            .help("Rescan MIDI devices")
            Button {
                model.sendCurrent()
            } label: {
                Label("Send This Template", systemImage: "arrow.up.circle.fill")
            }
            .disabled(model.currentTemplate == nil || !midi.hasDestination || midi.isSending)
            .help("Send the selected template to the keyboard's temporary memory (⌘U)")
        }
    }
}
