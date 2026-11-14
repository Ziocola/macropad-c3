import AppKit
import ApplicationServices
import SwiftUI

// Macropad virtuale: una finestrella sempre in primo piano che non ruba il fuoco.
// Cliccando i suoi tasti la funzione arriva all'app che stai usando, come col macropad vero.

final class VirtualPad: ObservableObject {
    @Published private(set) var pressed: Set<Int> = []
    @Published private(set) var buttonDown = false
    @Published private(set) var turn = (dir: 0, count: 0)
    @Published private(set) var trusted = AXIsProcessTrusted() || CGPreflightPostEventAccess()
    @Published private(set) var last = ""                   // ultima funzione eseguita, scritta sotto i tasti
    @Published private(set) var lastIsError = false
    private var panel: NSPanel?
    private var trustTimer: Timer?

    // ---------- finestra ----------

    func show(_ model: AppModel) {
        if panel == nil {
            let p = PadPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 520),
                             styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
                             backing: .buffered, defer: false)
            p.title = "Macropad virtuale"
            p.isFloatingPanel = true
            p.level = .floating
            p.hidesOnDeactivate = false
            p.becomesKeyOnlyIfNeeded = true
            p.isReleasedWhenClosed = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let host = FirstClickHostingView(rootView: VirtualPadView(link: model.link, pad: self)
                .environmentObject(model).tint(.orange).preferredColorScheme(.dark))
            p.contentView = host
            p.setFrameAutosaveName("VirtualPad")
            if !p.setFrameUsingName("VirtualPad"), let s = NSScreen.main?.visibleFrame {
                p.setFrameOrigin(NSPoint(x: s.maxX - 330, y: s.maxY - 660))
            }
            p.contentMinSize = NSSize(width: 280, height: 560)
            if p.contentRect(forFrameRect: p.frame).height < 600 {
                let top = p.frame.maxY
                p.setContentSize(NSSize(width: 300, height: 620))
                p.setFrameTopLeftPoint(NSPoint(x: p.frame.minX, y: top))
            }
            panel = p
        }
        panel?.orderFrontRegardless()
        refreshTrust()
        // il permesso si dà nelle Impostazioni di Sistema: ricontrolla finché non arriva
        trustTimer?.invalidate()
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            self.refreshTrust()
            if self.trusted || self.panel?.isVisible != true { t.invalidate() }
        }
    }

    func refreshTrust() {
        let t = AXIsProcessTrusted() || CGPreflightPostEventAccess()
        if t != trusted { trusted = t }
    }

    func askPermission() {
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    // ---------- tasti e manopola ----------

    func press(_ i: Int, down: Bool) {
        if down { pressed.insert(i) } else { pressed.remove(i) }
    }

    func knobTurned(_ dir: Int) { turn = (dir, turn.count + 1) }

    func click() {
        buttonDown = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.buttonDown = false }
    }

    func note(_ text: String, error: Bool = false) {
        last = text
        lastIsError = error
    }

    // ---------- esecuzione sul Mac ----------

    func run(_ a: Action, text: String) {
        let front = NSWorkspace.shared.frontmostApplication
        let mine = front?.processIdentifier == getpid()
        let to = mine || front == nil ? "" : " → \(front?.localizedName ?? "")"
        if a.kind == .none { return note("Nessuna funzione su questo tasto", error: true) }
        refreshTrust()          // si prova comunque: a volte macOS dà il permesso prima di dirlo all'app
        switch a.kind {
        case .key:
            // in Macropad Config una scorciatoia come ⌘W chiuderebbe l'app stessa
            if mine { return note("\(text): prima clicca sulla finestra dell'app dove vuoi provarla", error: true) }
            postCombo(a.mac)
        case .media:
            guard postMedia(a.u ?? 0) else { return note("\(text): non esiste sul Mac", error: true) }
        case .wheel:
            scroll(a.u ?? 0, in: front)
        case .none:
            break
        }
        note(trusted ? text + to : "\(text)\(to) — se non succede niente, manca il permesso", error: !trusted)
    }

    // gli eventi partono in fila con piccole pause: premuto e rilasciato nello stesso istante, il Mac li perde
    private let queue = DispatchQueue(label: "macropad.virtuale.eventi")

    private static let macKeyCode: [Int: UInt16] =
        Dictionary(Keys.fromMacKeyCode.map { ($0.value, $0.key) }, uniquingKeysWith: { a, _ in a })

    private func postCombo(_ c: Combo) {
        guard c.key != 0 || c.mods != 0 else { return }
        let src = CGEventSource(stateID: .hidSystemState)
        // i modificatori vengono premuti davvero, così funzionano anche le scorciatoie di sistema
        var mods: [(UInt16, CGEventFlags)] = []
        if c.mods & Mod.ctrl != 0 { mods.append((59, .maskControl)) }
        if c.mods & Mod.alt != 0 { mods.append((58, .maskAlternate)) }
        if c.mods & Mod.shift != 0 { mods.append((56, .maskShift)) }
        if c.mods & (Mod.gui | Mod.pri) != 0 { mods.append((55, .maskCommand)) }
        var flags: CGEventFlags = []
        var events: [CGEvent] = []
        func post(_ code: UInt16, _ down: Bool, _ f: CGEventFlags) {
            guard let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down) else { return }
            e.flags = f
            events.append(e)
        }
        for (code, f) in mods { flags.insert(f); post(code, true, flags) }
        if let code = Self.macKeyCode[c.key] {
            var f = flags
            if (123...126).contains(code) { f.formUnion([.maskNumericPad, .maskSecondaryFn]) }
            if (0x3A...0x45).contains(c.key) { f.insert(.maskSecondaryFn) }      // tasti F
            post(code, true, f)
            post(code, false, f)
        }
        for (code, f) in mods.reversed() { flags.remove(f); post(code, false, flags) }
        queue.async {
            for e in events { e.post(tap: .cghidEventTap); usleep(12_000) }
        }
    }

    // codici consumer HID del firmware -> tasti speciali del Mac (NX_KEYTYPE_...)
    private static let nxKey: [Int: Int] = [
        0xCD: 16, 0xB5: 17, 0xB6: 18, 0xB3: 19, 0xB4: 20,
        0xE2: 7, 0xE9: 0, 0xEA: 1, 0x6F: 2, 0x70: 3,
    ]

    private func postMedia(_ usage: Int) -> Bool {
        guard let nx = Self.nxKey[usage] else { return false }
        let events = [0xA, 0xB].compactMap { state in      // 0xA premuto, 0xB rilasciato
            NSEvent.otherEvent(with: .systemDefined, location: .zero,
                               modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(state << 8)),
                               timestamp: 0, windowNumber: 0, context: nil, subtype: 8,
                               data1: (nx << 16) | (state << 8), data2: -1)?.cgEvent
        }
        queue.async {
            for e in events { e.post(tap: .cghidEventTap); usleep(30_000) }
        }
        return true
    }

    // la rotella va alla finestra sotto il punto dell'evento: punta alla finestra dell'app in uso,
    // fuori dal macropad virtuale, e rimette subito il puntatore dov'era
    private func scroll(_ n: Int, in app: NSRunningApplication?) {
        guard let e = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1,
                              wheel1: Int32(n * 3), wheel2: 0, wheel3: 0) else { return }
        let back = CGEvent(source: nil)?.location
        if let app, app.processIdentifier != getpid(), let p = scrollPoint(app.processIdentifier) {
            e.location = p
            CGEventSource(stateID: .combinedSessionState)?.localEventsSuppressionInterval = 0
            e.post(tap: .cghidEventTap)
            if let back { CGWarpMouseCursorPosition(back) }
        } else {
            e.post(tap: .cghidEventTap)
        }
    }

    private func scrollPoint(_ pid: pid_t) -> CGPoint? {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        guard let info = list.first(where: { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }),
              let b = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
        let win = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
        guard let panel, let screenH = NSScreen.screens.first?.frame.height else { return CGPoint(x: win.midX, y: win.midY) }
        let f = panel.frame
        let pad = CGRect(x: f.minX, y: screenH - f.maxY, width: f.width, height: f.height)   // in coordinate CG
        // il punto più centrale della finestra non coperto dal macropad virtuale
        let candidates = [CGPoint(x: win.midX, y: win.midY),
                          CGPoint(x: (win.minX + pad.minX) / 2, y: win.midY),
                          CGPoint(x: (pad.maxX + win.maxX) / 2, y: win.midY),
                          CGPoint(x: win.midX, y: (win.minY + pad.minY) / 2),
                          CGPoint(x: win.midX, y: (pad.maxY + win.maxY) / 2)]
        return candidates.first { win.insetBy(dx: 8, dy: 8).contains($0) && !pad.contains($0) }
    }
}

// non prende mai il fuoco: la tastiera resta all'app che stai usando
final class PadPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// il primo clic preme già il tasto, anche se Macropad Config non è in primo piano
final class FirstClickHostingView<V: View>: NSHostingView<V> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

struct VirtualPadView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var link: MacropadLink
    @ObservedObject var pad: VirtualPad

    var body: some View {
        VStack(spacing: 10) {
            if !pad.trusted { permission }
            PageSwitcher(locked: false)
            DeviceView(link: link, test: model.test, testing: false, virtual: true, pad: pad)
                .frame(minHeight: 300)
            Text(pad.last.isEmpty ? "Clicca un tasto mentre usi un'altra app: la funzione arriva lì." : pad.last)
                .font(.callout)
                .foregroundStyle(pad.lastIsError ? Color.orange : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 36)
            Text("Trascina la manopola in tondo per girarla, cliccala per cambiare pagina.")
                .font(.caption).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(minWidth: 280, minHeight: 540)
        .background(Stage())
    }

    private var permission: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Serve un permesso", systemImage: "lock.shield").font(.headline).foregroundStyle(.orange)
            Text("Per premere i tasti al posto tuo, il Mac deve fidarsi dell'app: Impostazioni di Sistema → Privacy e sicurezza → Accessibilità → attiva Macropad Config.")
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(5)
            Text("È già attiva? Selezionala, toglila con − e riaggiungila con +, poi riapri l'app.")
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(3)
            Button("Apri le Impostazioni") { pad.askPermission() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
    }
}
