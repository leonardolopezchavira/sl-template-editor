import SwiftUI
import AppKit
import SLTemplateKit

struct BankSidebar: View {
    @EnvironmentObject var model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $model.selectedSlot) {
                Section("Keyboard memory · \(model.templateCount)/40") {
                    ForEach(0..<EditorModel.slotCount, id: \.self) { slot in
                        BankRow(slot: slot, template: model.bank[slot], modified: model.modifiedSlots.contains(slot))
                            .tag(slot)
                            .contextMenu { menu(for: slot) }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Theme.ground)

            Rectangle().fill(Theme.rule).frame(height: 1)
            HStack(spacing: 8) {
                Button { model.openFiles() } label: { Label("Open", systemImage: "folder") }
                    .help("Open .syx templates or banks, or .txt hex dumps (⌘O)")
                Button { model.saveBank() } label: { Label("Save Bank", systemImage: "square.and.arrow.down") }
                    .disabled(model.templateCount == 0)
                    .help("Save every template in the list as one .syx bank (⇧⌘S)")
                Spacer()
                Button { model.confirmBulkSend = true } label: { Label("Send All", systemImage: "arrow.up.to.line") }
                    .disabled(model.templateCount == 0 || !model.midi.hasDestination)
                    .help("Send every template to the keyboard")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundColor(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Theme.ground)
    }

    @ViewBuilder
    private func menu(for slot: Int) -> some View {
        if model.bank[slot] == nil {
            Button("New Template Here") { model.newTemplate(in: slot) }
            Button("Open File Into This Slot…") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [EditorModel.sysexType, .plainText, .data]
                if panel.runModal() == .OK, let url = panel.url { model.importFiles([url], intoSlot: slot) }
            }
        } else {
            Button("Send This Template") { model.selectedSlot = slot; model.sendCurrent() }
                .disabled(!model.midi.hasDestination)
            if let target = model.firstEmptySlot {
                Button("Duplicate to Slot \(target + 1)") { model.duplicate(from: slot, to: target) }
            }
            Divider()
            Button("Move Up") { model.move(slot: slot, by: -1) }.disabled(slot == 0)
            Button("Move Down") { model.move(slot: slot, by: 1) }.disabled(slot == EditorModel.slotCount - 1)
            Divider()
            Button("Clear All Controls") { model.clearControls(slot: slot) }
            Button("Remove From List", role: .destructive) { model.clear(slot: slot) }
        }
    }
}

struct BankRow: View {
    let slot: Int
    let template: SLTemplate?
    let modified: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(String(format: "%02d", slot + 1))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(template == nil ? Theme.off : Theme.inkDim)
            if let t = template {
                VStack(alignment: .leading, spacing: 1) {
                    Text(t.name.isEmpty ? "Untitled" : t.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.ink)
                        .lineLimit(1)
                    if !t.manufacturer.isEmpty {
                        Text(t.manufacturer)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.inkDim)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                if modified {
                    Circle().fill(Theme.signal).frame(width: 8, height: 8)
                        .help("Edited since it was received or opened")
                }
            } else {
                Text("Empty")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.off)
                Spacer()
            }
        }
        .padding(.vertical, 1)
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var model: EditorModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("ReMOTE SL Template Editor")
                        .font(Theme.display(44))
                        .foregroundColor(Theme.ink)
                    Text("Edit the templates on a Novation ReMOTE SL or ZeRO SL (MkI) and send them back over USB or MIDI.")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.inkDim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 18) {
                    way("From the keyboard", color: Theme.mmc,
                        "Press Global, use the up arrow until the display shows “Template xx”, then press the button beneath it. The template appears in the list.")
                    way("From files", color: Theme.cc,
                        "Open .syx templates or banks, .txt hex dumps, or the original editor’s FactorySettings.blk. You can also drop files on this window.")
                    way("Edit and send", color: Theme.signal,
                        "Select a control to edit it, then press Send This Template (⌘U). The keyboard keeps it in temporary memory until you press Write.")
                }

                HStack(spacing: 10) {
                    Button("Open Files…") { model.openFiles() }
                        .buttonStyle(SignalButtonStyle())
                        .keyboardShortcut("o")
                    Button("New Template") {
                        if let s = model.selectedSlot ?? model.firstEmptySlot { model.newTemplate(in: s) }
                    }
                    .buttonStyle(OutlineButtonStyle())
                    .disabled(model.firstEmptySlot == nil && model.selectedSlot == nil)
                }
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(48)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.ground)
    }

    private func way(_ title: String, color: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Rectangle().fill(color).frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Theme.heading(19)).foregroundColor(Theme.ink)
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.inkDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
