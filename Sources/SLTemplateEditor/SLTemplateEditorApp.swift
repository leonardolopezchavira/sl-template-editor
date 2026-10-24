import SwiftUI
import AppKit
import SLTemplateKit

@main
struct SLTemplateEditorApp: App {
    @StateObject private var model = EditorModel()

    init() {
        // Needed when launched from `swift run` rather than from the .app bundle.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("SL Template Editor") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Template") {
                    if let s = model.selectedSlot.flatMap({ model.bank[$0] == nil ? $0 : nil }) ?? model.firstEmptySlot {
                        model.newTemplate(in: s)
                    }
                }
                .keyboardShortcut("n")
                .disabled(model.firstEmptySlot == nil)
                Button("Open…") { model.openFiles() }
                    .keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save Template…") { model.saveCurrent() }
                    .keyboardShortcut("s")
                    .disabled(model.currentTemplate == nil)
                Button("Save Bank…") { model.saveBank() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(model.templateCount == 0)
                Button("Export Template as Hex Text…") { model.exportHexText() }
                    .disabled(model.currentTemplate == nil)
            }
            CommandMenu("Device") {
                Button("Send This Template") { model.sendCurrent() }
                    .keyboardShortcut("u")
                    .disabled(model.currentTemplate == nil)
                Button("Send All Templates…") { model.confirmBulkSend = true }
                    .disabled(model.templateCount == 0)
                Divider()
                Button("Rescan MIDI Devices") { model.midi.refreshEndpoints() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
