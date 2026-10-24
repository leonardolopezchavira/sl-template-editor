import Foundation
import CoreMIDI
import SLTemplateKit

/// CoreMIDI wrapper: endpoint discovery, SysEx reception (reassembled across packets)
/// and SysEx transmission with completion callbacks.
final class MIDIService: ObservableObject {
    struct Endpoint: Identifiable, Hashable {
        let id: MIDIUniqueID
        let name: String
        let ref: MIDIEndpointRef
    }

    @Published private(set) var sources: [Endpoint] = []
    @Published private(set) var destinations: [Endpoint] = []
    @Published var sourceID: MIDIUniqueID? { didSet { connectSource() } }
    @Published var destinationID: MIDIUniqueID? {
        didSet {
            if let d = destinations.first(where: { $0.id == destinationID }) {
                UserDefaults.standard.set(d.name, forKey: "destinationName")
            }
        }
    }
    @Published private(set) var status = "Starting MIDI…"
    @Published private(set) var isSending = false
    @Published private(set) var activity = false

    /// Called on the main thread with every complete template received.
    var onTemplate: ((SLTemplate) -> Void)?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var outputPort = MIDIPortRef()
    private var connectedSource: MIDIEndpointRef = 0
    private var assembler = SysExAssembler()   // touched only on the CoreMIDI thread

    init() {
        var err = MIDIClientCreateWithBlock("SL Template Editor" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshEndpoints() }
        }
        guard err == noErr else { status = "Could not start CoreMIDI (error \(err))"; return }
        err = MIDIInputPortCreateWithBlock(client, "SL Template Editor In" as CFString, &inputPort) { [weak self] list, _ in
            self?.receive(list)
        }
        if err != noErr { status = "Could not create MIDI input (error \(err))" }
        err = MIDIOutputPortCreate(client, "SL Template Editor Out" as CFString, &outputPort)
        if err != noErr { status = "Could not create MIDI output (error \(err))" }
        refreshEndpoints()
    }

    var hasDestination: Bool { destinations.contains { $0.id == destinationID } }

    // MARK: endpoints

    func refreshEndpoints() {
        sources = (0..<MIDIGetNumberOfSources()).compactMap { endpoint(MIDIGetSource($0)) }
        destinations = (0..<MIDIGetNumberOfDestinations()).compactMap { endpoint(MIDIGetDestination($0)) }

        if let id = sourceID, sources.contains(where: { $0.id == id }) {
            connectSource()
        } else {
            sourceID = preferred(sources, key: "sourceName")
        }
        if destinationID == nil || !destinations.contains(where: { $0.id == destinationID }) {
            destinationID = preferred(destinations, key: "destinationName")
        }

        if sources.isEmpty && destinations.isEmpty {
            status = "No MIDI devices found. Connect the ReMOTE SL and switch it on."
        } else if let d = destinations.first(where: { $0.id == destinationID }) {
            status = "Ready — sending to \(d.name)"
        } else {
            status = "Choose a MIDI output."
        }
    }

    private func endpoint(_ ref: MIDIEndpointRef) -> Endpoint? {
        guard ref != 0 else { return nil }
        var uid: MIDIUniqueID = 0
        MIDIObjectGetIntegerProperty(ref, kMIDIPropertyUniqueID, &uid)
        var cf: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(ref, kMIDIPropertyDisplayName, &cf)
        let name = (cf?.takeRetainedValue() as String?) ?? "MIDI \(uid)"
        return Endpoint(id: uid, name: name, ref: ref)
    }

    private func preferred(_ list: [Endpoint], key: String) -> MIDIUniqueID? {
        if let saved = UserDefaults.standard.string(forKey: key),
           let e = list.first(where: { $0.name == saved }) { return e.id }
        let hints = ["remote sl", "zero sl", "remote", "sl "]
        for h in hints {
            if let e = list.first(where: { $0.name.lowercased().contains(h) }) { return e.id }
        }
        return list.first?.id
    }

    private func connectSource() {
        if connectedSource != 0 {
            MIDIPortDisconnectSource(inputPort, connectedSource)
            connectedSource = 0
        }
        guard let e = sources.first(where: { $0.id == sourceID }) else { return }
        if MIDIPortConnectSource(inputPort, e.ref, nil) == noErr {
            connectedSource = e.ref
            UserDefaults.standard.set(e.name, forKey: "sourceName")
        }
    }

    // MARK: receive

    private func receive(_ list: UnsafePointer<MIDIPacketList>) {
        let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data) ?? 10
        var finished: [[UInt8]] = []
        for packet in list.unsafeSequence() {
            let length = Int(packet.pointee.length)
            let base = UnsafeRawPointer(packet).advanced(by: dataOffset).assumingMemoryBound(to: UInt8.self)
            for i in 0..<length {
                if let message = assembler.feed(base[i]) { finished.append(message) }
            }
        }
        let started = assembler.isActive
        DispatchQueue.main.async {
            self.activity = started
            for m in finished { self.handle(m) }
        }
    }

    private func handle(_ message: [UInt8]) {
        do {
            let t = try SLTemplate(bytes: message)
            status = "Received “\(t.name)” (template \(t.slot + 1))"
            onTemplate?(t)
        } catch {
            if message.count > 4, Array(message[1...3]) == [0x00, 0x20, 0x29] {
                status = "Received a \(message.count)-byte Novation message that is not a template — ignored."
            }
        }
    }

    // MARK: send

    /// Sends templates one after another, pausing between them like the original editor.
    func send(_ templates: [SLTemplate], gapMilliseconds: Int = 150,
              progress: ((Int) -> Void)? = nil, completion: ((Bool) -> Void)? = nil) {
        guard let dest = destinations.first(where: { $0.id == destinationID }) else {
            status = "No MIDI output selected."
            completion?(false)
            return
        }
        guard !isSending else { completion?(false); return }
        isSending = true
        sendNext(templates, index: 0, to: dest, gap: gapMilliseconds, progress: progress, completion: completion)
    }

    private func sendNext(_ templates: [SLTemplate], index: Int, to dest: Endpoint, gap: Int,
                          progress: ((Int) -> Void)?, completion: ((Bool) -> Void)?) {
        guard index < templates.count else {
            isSending = false
            status = templates.count == 1 ? "Sent “\(templates[0].name)” to \(dest.name)"
                                          : "Sent \(templates.count) templates to \(dest.name)"
            completion?(true)
            return
        }
        progress?(index)
        status = "Sending “\(templates[index].name)”…"
        let ok = SysExRequest.send(templates[index].bytes, to: dest.ref) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(gap)) {
                self?.sendNext(templates, index: index + 1, to: dest, gap: gap, progress: progress, completion: completion)
            }
        }
        if !ok {
            isSending = false
            status = "Sending failed. Check that \(dest.name) is still connected."
            completion?(false)
        }
    }
}

/// Reassembles SysEx messages that may arrive split across many packets.
struct SysExAssembler {
    private var buffer: [UInt8] = []
    private(set) var isActive = false

    mutating func feed(_ b: UInt8) -> [UInt8]? {
        if b == 0xF0 {
            buffer = [b]; isActive = true
            return nil
        }
        guard isActive else { return nil }
        if b >= 0xF8 { return nil }            // real-time messages may interleave
        buffer.append(b)
        if b == 0xF7 {
            isActive = false
            let m = buffer
            buffer = []
            return m
        }
        if b >= 0x80 || buffer.count > 70_000 {  // aborted or runaway message
            isActive = false
            buffer = []
        }
        return nil
    }
}

/// Owns the memory for one asynchronous MIDISendSysex call.
private final class SysExRequest {
    let buffer: UnsafeMutablePointer<UInt8>
    let request: UnsafeMutablePointer<MIDISysexSendRequest>
    let completion: () -> Void

    private init(bytes: [UInt8], destination: MIDIEndpointRef, completion: @escaping () -> Void) {
        buffer = .allocate(capacity: bytes.count)
        buffer.initialize(from: bytes, count: bytes.count)
        request = .allocate(capacity: 1)
        self.completion = completion
        request.initialize(to: MIDISysexSendRequest(
            destination: destination,
            data: UnsafePointer(buffer),
            bytesToSend: UInt32(bytes.count),
            complete: false,
            reserved: (0, 0, 0),
            completionProc: sysexSendCompleted,
            completionRefCon: nil))
    }

    deinit {
        request.deinitialize(count: 1)
        request.deallocate()
        buffer.deallocate()
    }

    /// Returns false if CoreMIDI refused the request.
    static func send(_ bytes: [UInt8], to destination: MIDIEndpointRef, completion: @escaping () -> Void) -> Bool {
        let box = SysExRequest(bytes: bytes, destination: destination, completion: completion)
        let retained = Unmanaged.passRetained(box)
        box.request.pointee.completionRefCon = retained.toOpaque()
        if MIDISendSysex(box.request) != noErr {
            retained.release()
            return false
        }
        return true
    }
}

private func sysexSendCompleted(_ request: UnsafeMutablePointer<MIDISysexSendRequest>) {
    guard let ref = request.pointee.completionRefCon else { return }
    let box = Unmanaged<SysExRequest>.fromOpaque(ref).takeRetainedValue()
    DispatchQueue.main.async { box.completion() }
}
