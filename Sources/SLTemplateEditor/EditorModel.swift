import SwiftUI
import AppKit
import UniformTypeIdentifiers
import SLTemplateKit

/// App state: a 40-slot bank mirroring the keyboard's memory, the current selection,
/// file import/export and MIDI transfer.
final class EditorModel: ObservableObject {
    static let slotCount = 40

    @Published var bank: [SLTemplate?] = Array(repeating: nil, count: EditorModel.slotCount)
    @Published var selectedSlot: Int?
    @Published var selectedControl: Int = 0
    @Published var modifiedSlots: Set<Int> = []
    @Published var alert: AlertInfo?
    @Published var bankURL: URL?
    @Published var confirmBulkSend = false

    var firstEmptySlot: Int? { bank.firstIndex(where: { $0 == nil }) }
    var templateCount: Int { bank.compactMap { $0 }.count }

    let midi = MIDIService()

    struct AlertInfo: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    init() {
        midi.onTemplate = { [weak self] t in self?.received(t) }
    }

    // MARK: selection and bindings

    var currentTemplate: SLTemplate? {
        guard let s = selectedSlot else { return nil }
        return bank[s]
    }

    func templateBinding(slot: Int, fallback: SLTemplate) -> Binding<SLTemplate> {
        Binding(
            get: { self.bank[slot] ?? fallback },
            set: { newValue in
                guard self.bank[slot] != nil else { return }
                if self.bank[slot] != newValue {
                    self.bank[slot] = newValue
                    self.modifiedSlots.insert(slot)
                }
            })
    }

    func controlBinding(slot: Int, index: Int, fallback: SLTemplate) -> Binding<SLControl> {
        Binding(
            get: { (self.bank[slot] ?? fallback).control(index) },
            set: { newValue in
                guard var t = self.bank[slot] else { return }
                t.setControl(index, newValue)
                if self.bank[slot] != t {
                    self.bank[slot] = t
                    self.modifiedSlots.insert(slot)
                }
            })
    }

    // MARK: bank operations

    func newTemplate(in slot: Int) {
        bank[slot] = SLTemplate.newTemplate(name: "Template \(slot + 1)", slot: slot)
        modifiedSlots.insert(slot)
        selectedSlot = slot
        selectedControl = 0
    }

    func duplicate(from source: Int, to target: Int) {
        guard let t = bank[source] else { return }
        bank[target] = t.duplicate(toSlot: target)
        modifiedSlots.insert(target)
        selectedSlot = target
    }

    func clear(slot: Int) {
        bank[slot] = nil
        modifiedSlots.remove(slot)
    }

    func clearControls(slot: Int) {
        guard let t = bank[slot] else { return }
        bank[slot] = t.clearedCopy(name: t.name)
        modifiedSlots.insert(slot)
    }

    func move(slot: Int, by delta: Int) {
        let target = slot + delta
        guard (0..<EditorModel.slotCount).contains(target) else { return }
        var a = bank[slot], b = bank[target]
        a?.slot = target
        b?.slot = slot
        bank[target] = a
        bank[slot] = b
        modifiedSlots.formUnion([slot, target])
        if selectedSlot == slot { selectedSlot = target }
    }

    private func place(_ t: SLTemplate, preferredSlot: Int? = nil) -> Int {
        var t = t
        let slot = preferredSlot ?? t.slot
        t.slot = slot
        bank[slot] = t
        return slot
    }

    private func received(_ t: SLTemplate) {
        let slot = place(t)
        modifiedSlots.remove(slot)
        selectedSlot = slot
    }

    // MARK: MIDI

    func sendCurrent() {
        guard let t = currentTemplate, let slot = selectedSlot else { return }
        // Like the original editor: a single template goes to the keyboard's temporary memory.
        midi.send([t.forTransfer(toStorage: false)]) { [weak self] ok in
            if ok { self?.modifiedSlots.remove(slot) }
        }
    }

    func sendBank() {
        let templates = bank.compactMap { $0 }
        guard !templates.isEmpty else { return }
        // A bulk send stores each template in the slot it carries, like a keyboard bank dump.
        midi.send(templates.map { $0.forTransfer(toStorage: true) }) { [weak self] ok in
            if ok { self?.modifiedSlots.removeAll() }
        }
    }

    // MARK: files

    static let sysexType = UTType(filenameExtension: "syx") ?? .data

    func openFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [EditorModel.sysexType, .plainText, .data]
        panel.message = "Choose .syx template or bank files, or hex .txt dumps"
        guard panel.runModal() == .OK else { return }
        // Open in name order so "01 - …", "02 - …" fill the list in that order.
        importFiles(panel.urls.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        })
    }

    func importFiles(_ urls: [URL], intoSlot slot: Int? = nil) {
        var loaded = 0, skipped = 0, failures: [String] = [], noRoom: [String] = []
        var lastSlot: Int?
        for url in urls {
            do {
                let (ts, s) = try SysExIO.load(url: url)
                skipped += s
                if ts.isEmpty { failures.append(url.lastPathComponent); continue }
                if ts.count == 1 {
                    // A single template goes to the slot the user picked, otherwise to the first
                    // empty slot: the first file opened lands in slot 1, the next in slot 2, and so on.
                    guard let target = slot ?? firstEmptySlot else { noRoom.append(url.lastPathComponent); continue }
                    lastSlot = place(ts[0], preferredSlot: target)
                    if slot != nil { modifiedSlots.insert(target) }
                } else {
                    // A bank keeps every template in the slot it was saved from.
                    for t in ts { lastSlot = place(t) }
                    bankURL = url
                }
                loaded += ts.count
            } catch {
                failures.append(url.lastPathComponent)
            }
        }
        if let s = lastSlot { selectedSlot = s }
        if !failures.isEmpty || skipped > 0 || !noRoom.isEmpty {
            var msg = "Loaded \(loaded) template\(loaded == 1 ? "" : "s")."
            if !failures.isEmpty { msg += "\nNo ReMOTE SL template found in: \(failures.joined(separator: ", "))." }
            if skipped > 0 { msg += "\nSkipped \(skipped) SysEx message\(skipped == 1 ? "" : "s") that were not SL templates." }
            if !noRoom.isEmpty { msg += "\nAll 40 slots are full, so these were not opened: \(noRoom.joined(separator: ", ")). Remove a template from the list to make room." }
            alert = AlertInfo(title: "Import", message: msg)
        }
    }

    func saveCurrent() {
        guard let t = currentTemplate else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [EditorModel.sysexType]
        panel.nameFieldStringValue = safeFileName(t.name.isEmpty ? "Template \(t.slot + 1)" : t.name) + ".syx"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(t.data, to: url)
    }

    func saveBank() {
        let templates = bank.compactMap { $0 }
        guard !templates.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [EditorModel.sysexType]
        panel.nameFieldStringValue = bankURL?.lastPathComponent ?? "ReMOTE SL Bank.syx"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if write(SysExIO.bankData(templates), to: url) { bankURL = url }
    }

    func exportHexText() {
        guard let t = currentTemplate else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(t.slot + 1).txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(Data(SysExIO.hexText(t).utf8), to: url)
    }

    @discardableResult
    private func write(_ data: Data, to url: URL) -> Bool {
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            alert = AlertInfo(title: "Could not save", message: error.localizedDescription)
            return false
        }
    }

    private func safeFileName(_ s: String) -> String {
        s.components(separatedBy: CharacterSet(charactersIn: "/:\\")).joined(separator: "-")
    }
}
