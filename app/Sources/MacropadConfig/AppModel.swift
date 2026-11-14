import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

enum Selection: Hashable {
    case key(Int)
    case knob
}

enum AppMode: Hashable {
    case edit
    case test
}

struct Toast: Equatable {
    let text: String
    let isError: Bool
}

final class AppModel: ObservableObject {
    @Published var config = MacropadConfig.defaults
    @Published private(set) var synced: MacropadConfig?     // ultima configurazione letta dal macropad o inviata
    @Published var pageIndex = 0
    @Published var selection: Selection = .key(0)
    @Published var toast: Toast?
    @Published var deviceConflict: MacropadConfig?          // il macropad ha una configurazione diversa da quella in modifica
    @Published var showSettings = false
    @Published var mode: AppMode = .edit {
        didSet { if mode != oldValue { modeChanged() } }
    }

    let link = MacropadLink()
    let test = TestSession()
    let pad = VirtualPad()
    private var bag: Set<AnyCancellable> = []
    private var edited = false                              // modifiche fatte prima di collegarsi

    init() {
        // per le prove: open "Macropad Config.app" --args -select knob (oppure 0…8) -page 1
        let d = UserDefaults.standard
        if let sel = d.string(forKey: "select") { selection = Int(sel).map { .key($0) } ?? .knob }
        pageIndex = min(max(d.integer(forKey: "page"), 0), config.pages.count - 1)
        if d.string(forKey: "mode") == "test" { mode = .test }
        link.onConfig = { [weak self] cfg in self?.received(cfg) }
        link.onEvent = { [weak self] e in
            guard let self else { return }
            if case .page(let p) = e, p < self.config.pages.count, self.mode == .test || !self.hasUnsentChanges { self.pageIndex = p }
            guard self.mode == .test else { return }
            let p = self.link.status?.page ?? self.pageIndex
            self.test.handle(e, page: p < self.config.pages.count ? self.config.pages[p] : nil,
                             isMac: self.link.status?.mac ?? true, simulated: !self.link.isConnected)
        }
        test.$mode.dropFirst().sink { [weak self] m in
            if self?.mode == .test { self?.link.setTestMode(m) }
        }.store(in: &bag)
        // i controlli fatti in simulazione non valgono per il macropad vero
        link.$state.removeDuplicates().sink { [weak self] s in
            guard let self, s == .connected, self.test.simulated, self.test.started else { return }
            self.test.reset()
            if self.mode == .test { self.show("Macropad collegato: ora la prova usa i tasti veri") }
        }.store(in: &bag)
        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in self?.releaseSimulated() }.store(in: &bag)
        watchKeyboard()
        if mode == .test { modeChanged() }
        if d.bool(forKey: "demo") {
            func ev(_ c: String, _ b: UInt8) -> Data { Data(c.utf8) + [b] }
            var e: [(Double, Data)] = []
            var t = 0.6
            for k in [0, 1, 2, 3, 6] { e.append((t, ev("P", UInt8(k)))); e.append((t + 0.12, ev("R", UInt8(k)))); t += 0.25 }
            for _ in 0..<4 { e.append((t, ev("T", 1))); t += 0.08 }
            t += 1.8
            for _ in 0..<2 { e.append((t, ev("T", 0xFF))); t += 0.08 }
            e.append((t + 0.2, ev("C", 1))); e.append((t + 0.35, ev("C", 0)))
            e.append((t + 0.6, ev("P", 4)))
            link.startDemo(e)
        }
        link.onSaved = { [weak self] error in
            guard let self else { return }
            if let error {
                self.show("Non salvato: \(error)", error: true)
            } else {
                self.synced = self.config
                self.edited = false
                self.show("Inviato: il macropad usa già le nuove funzioni")
            }
        }
    }

    var page: Page {
        get { config.pages[min(pageIndex, config.pages.count - 1)] }
        set { config.pages[min(pageIndex, config.pages.count - 1)] = newValue }
    }

    var hasUnsentChanges: Bool {
        if let synced { return config != synced }
        return edited || config != MacropadConfig.defaults
    }

    func markEdited() { edited = true }

    // ---------- macropad ----------

    // in prova il macropad non manda i tasti al computer (salvo scelta) e l'app segue la sua pagina
    private func modeChanged() {
        releaseSimulated()
        link.setTestMode(mode == .test ? test.mode : 0)
        if mode == .test, let p = link.status?.page, p < config.pages.count { pageIndex = p }
    }

    func send() { link.send(config) }

    // ---------- macropad virtuale: esegue davvero le funzioni sul Mac ----------

    func showPad() { pad.show(self) }

    func padKey(_ i: Int, down: Bool) {
        guard pad.pressed.contains(i) != down else { return }
        pad.press(i, down: down)
        if down { pad.run(page.keys[i], text: test.actionText(page.keys[i], isMac: true)) }
    }

    func padTurn(_ dir: Int) {
        pad.knobTurned(dir)
        let a = dir > 0 ? page.cw : page.ccw
        pad.run(a, text: "Manopola \(dir > 0 ? "↻" : "↺") · " + test.actionText(a, isMac: true))
    }

    // come sul macropad: premere la manopola passa alla pagina dopo
    func padClick() {
        pad.click()
        pageIndex = (pageIndex + 1) % config.pages.count
        pad.note("Pagina \(pageIndex + 1): \(page.name)")
    }

    // ---------- simulazione (prova senza macropad) ----------

    var simulating: Bool { mode == .test && !link.isConnected }

    func simKey(_ i: Int, down: Bool) {
        guard simulating, link.pressed.contains(i) != down else { return }
        link.simulate(down ? "P" : "R", UInt8(i))
    }

    func simTurn(_ dir: Int) {
        guard simulating else { return }
        link.simulate("T", UInt8(bitPattern: Int8(dir)))
    }

    func simButton(down: Bool) {
        guard simulating, link.buttonDown != down else { return }
        link.simulate("C", down ? 1 : 0)
    }

    func simClick() {
        simButton(down: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in self?.simButton(down: false) }
    }

    // niente tasti rimasti giù se la finestra perde il fuoco a metà pressione
    private func releaseSimulated() {
        guard !link.isConnected else { return }
        for i in link.pressed { link.simulate("R", UInt8(i)) }
        if link.buttonDown { link.simulate("C", 0) }
    }

    // tastiera del Mac: 1…9 i tasti, ← → la manopola, spazio il suo pulsante
    private static let digitKeys: [UInt16: Int] = [18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8,
                                                   83: 0, 84: 1, 85: 2, 86: 3, 87: 4, 88: 5, 89: 6, 91: 7, 92: 8]

    private func watchKeyboard() {
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] e in
            guard let self, self.simulating else { return e }
            let down = e.type == .keyDown
            if down {
                guard e.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                      let w = NSApp.keyWindow, w.attachedSheet == nil, !(w.firstResponder is NSText) else { return e }
            }
            if let i = Self.digitKeys[e.keyCode] {
                if !e.isARepeat { self.simKey(i, down: down) }
            } else if e.keyCode == 123 || e.keyCode == 124 {
                if down { self.simTurn(e.keyCode == 124 ? 1 : -1) }
            } else if e.keyCode == 49 {
                if !e.isARepeat { self.simButton(down: down) }
            } else {
                return e
            }
            return nil
        }
    }
    func readFromDevice() { link.readConfig() }

    private func received(_ cfg: MacropadConfig) {
        if hasUnsentChanges && synced == nil && cfg != config {
            deviceConflict = cfg            // modifiche fatte senza macropad: chiedi quale tenere
            return
        }
        use(cfg)
    }

    func use(_ cfg: MacropadConfig) {
        config = cfg
        synced = cfg
        edited = false
        deviceConflict = nil
        pageIndex = min(pageIndex, cfg.pages.count - 1)
    }

    func keepLocal() {
        synced = deviceConflict
        deviceConflict = nil
    }

    func restoreDefaults() {
        let d = MacropadConfig.defaults
        config.pages = d.pages
        config.set = d.set
        pageIndex = 0
        selection = .key(0)
        markEdited()
        show("Predefinite ripristinate: premi Invia per mandarle al macropad")
    }

    // ---------- pagine ----------

    func addPage() {
        guard config.pages.count < MacropadConfig.maxPages else { return }
        config.pages.insert(.empty("PAGINA \(config.pages.count + 1)"), at: pageIndex + 1)
        pageIndex += 1
        selection = .key(0)
        markEdited()
    }

    func duplicatePage(_ i: Int) {
        guard config.pages.count < MacropadConfig.maxPages else { return }
        var p = config.pages[i]
        p.id = UUID()
        p.name = displayText(p.name + "2", max: MacropadConfig.nameMax)
        config.pages.insert(p, at: i + 1)
        pageIndex = i + 1
        markEdited()
    }

    func deletePage(_ i: Int) {
        guard config.pages.count > 1 else { return }
        config.pages.remove(at: i)
        pageIndex = min(pageIndex, config.pages.count - 1)
        markEdited()
    }

    // sposta la pagina i di "by" posizioni (-1 = su, +1 = giù); la selezione la segue
    func movePage(_ i: Int, by d: Int) {
        let j = i + d
        guard config.pages.indices.contains(i), config.pages.indices.contains(j) else { return }
        let moved = config.pages.remove(at: i)
        config.pages.insert(moved, at: j)
        pageIndex = j
        markEdited()
    }

    func movePageToTop(_ i: Int) { movePage(i, by: -i) }

    func movePages(from: IndexSet, to: Int) {
        let current = page.id
        config.pages.move(fromOffsets: from, toOffset: to)
        pageIndex = config.pages.firstIndex { $0.id == current } ?? 0
        markEdited()
    }

    // ---------- file ----------

    func exportFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "macropad_tasti.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let e = JSONEncoder()
            e.outputFormatting = [.prettyPrinted, .sortedKeys]
            try e.encode(config).write(to: url)
            show("Configurazione salvata in \(url.lastPathComponent)")
        } catch {
            show("Salvataggio non riuscito: \(error.localizedDescription)", error: true)
        }
    }

    func importFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let cfg = try JSONDecoder().decode(MacropadConfig.self, from: Data(contentsOf: url))
            guard !cfg.pages.isEmpty, cfg.pages.count <= MacropadConfig.maxPages, cfg.pages.allSatisfy({ $0.keys.count == 9 }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            config = cfg
            pageIndex = 0
            selection = .key(0)
            markEdited()
            show("Caricata \(url.lastPathComponent): premi Invia per mandarla al macropad")
        } catch {
            show("Questo file non è una configurazione del macropad", error: true)
        }
    }

    func show(_ text: String, error: Bool = false) {
        let t = Toast(text: text, isError: error)
        toast = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            if self?.toast == t { self?.toast = nil }
        }
    }
}
