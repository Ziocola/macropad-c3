import Foundation

// Stesso formato JSON del firmware (firmware/src/store.cpp)

enum Mod {
    static let ctrl = 0x01, shift = 0x02, alt = 0x04, gui = 0x08
    static let pri = 0x100          // Cmd sul Mac, Ctrl su Windows
}

enum ActionKind: Int, CaseIterable, Identifiable {
    case none = 0, key = 1, media = 2, wheel = 3
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .key: "Scorciatoia"
        case .media: "Multimediale"
        case .wheel: "Rotella"
        case .none: "Nessuna"
        }
    }
}

struct Combo: Equatable {
    var mods: Int
    var key: Int
}

struct Action: Codable, Equatable {
    var label: String = ""
    var t: Int = 0
    var m: [Int]? = nil
    var w: [Int]? = nil
    var u: Int? = nil

    enum CodingKeys: String, CodingKey { case label = "l", t, m, w, u }

    init(label: String = "", kind: ActionKind = .none) {
        self.label = label
        self.kind = kind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        t = try c.decodeIfPresent(Int.self, forKey: .t) ?? 0
        m = try c.decodeIfPresent([Int].self, forKey: .m)
        w = try c.decodeIfPresent([Int].self, forKey: .w)
        u = try c.decodeIfPresent(Int.self, forKey: .u)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(label, forKey: .label)
        try c.encode(t, forKey: .t)
        switch kind {
        case .key:
            try c.encode([mac.mods, mac.key], forKey: .m)
            try c.encode([win.mods, win.key], forKey: .w)
        case .media, .wheel:
            try c.encode(u ?? 0, forKey: .u)
        case .none:
            break
        }
    }

    var kind: ActionKind {
        get { ActionKind(rawValue: t) ?? .none }
        set {
            t = newValue.rawValue
            switch newValue {
            case .key: if m == nil { m = [Mod.pri, 0]; w = [Mod.pri, 0] }
            case .media: if (u ?? 0) <= 0 { u = Media.all[0].code }
            case .wheel: if u == nil || u == 0 || abs(u!) > 10 { u = -1 }
            case .none: break
            }
        }
    }

    var mac: Combo {
        get { Combo(mods: m?.first ?? 0, key: m?.dropFirst().first ?? 0) }
        set { m = [newValue.mods, newValue.key] }
    }
    var win: Combo {
        get { Combo(mods: w?.first ?? 0, key: w?.dropFirst().first ?? 0) }
        set { w = [newValue.mods, newValue.key] }
    }
    var sameOnBoth: Bool { mac == win }

    // per confrontare le azioni della manopola con i modelli, senza etichetta
    var behaviour: Action { var a = self; a.label = ""; if kind != .key { a.m = nil; a.w = nil }; if kind == .key || kind == .none { a.u = nil }; return a }

    static func key(_ mods: Int, _ key: Int) -> Action {
        var a = Action(kind: .key); a.mac = Combo(mods: mods, key: key); a.win = a.mac; return a
    }
    static func media(_ code: Int) -> Action { var a = Action(kind: .media); a.u = code; return a }
    static func wheel(_ n: Int) -> Action { var a = Action(kind: .wheel); a.u = n; return a }
}

struct Page: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var keys: [Action]
    var knobLabel: String
    var cw: Action
    var ccw: Action

    enum CodingKeys: String, CodingKey { case name = "n", keys = "k", knobLabel = "kl", cw, ccw }

    static func empty(_ name: String) -> Page {
        Page(name: name, keys: Array(repeating: Action(), count: 9), knobLabel: "Volume",
             cw: .media(0xE9), ccw: .media(0xEA))
    }
}

struct DeviceSettings: Codable, Equatable {
    var rev: Bool
    var rot: Bool
    var steps: Int
    var disp: Int
    var sleep: Int
}

struct MacropadConfig: Codable, Equatable {
    var v: Int = 1
    var set: DeviceSettings
    var pages: [Page]

    static let maxPages = 8
    static let labelMax = 8
    static let nameMax = 8

    static let defaults: MacropadConfig =
        try! JSONDecoder().decode(MacropadConfig.self, from: Data(defaultConfigJSON.utf8))

    func json() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return try e.encode(self)
    }
}

// Il display del macropad ha solo i caratteri latini (accenti compresi): niente emoji o simboli come ⌘
func displayText(_ s: String, max: Int) -> String {
    let ok = s.unicodeScalars.filter { $0.value >= 0x20 && $0.value <= 0xFF && $0.value != 0x7F }
    return String(String.UnicodeScalarView(ok).prefix(max))
}

// ---------- Tasti ----------

struct KeyInfo: Identifiable {
    let code: Int
    let name: String
    let section: String
    var id: Int { code }
}

enum Keys {
    static let all: [KeyInfo] = {
        var k: [KeyInfo] = []
        for (i, c) in "ABCDEFGHIJKLMNOPQRSTUVWXYZ".enumerated() { k.append(KeyInfo(code: 0x04 + i, name: String(c), section: "Lettere")) }
        for (i, c) in "1234567890".enumerated() { k.append(KeyInfo(code: 0x1E + i, name: String(c), section: "Numeri")) }
        for i in 1...12 { k.append(KeyInfo(code: 0x39 + i, name: "F\(i)", section: "Tasti funzione")) }
        let nav: [(Int, String)] = [(0x52, "Freccia su"), (0x51, "Freccia giù"), (0x50, "Freccia sinistra"), (0x4F, "Freccia destra"),
                                   (0x4A, "Inizio (Home)"), (0x4D, "Fine (End)"), (0x4B, "Pagina su"), (0x4E, "Pagina giù")]
        let edit: [(Int, String)] = [(0x28, "Invio"), (0x29, "Esc"), (0x2B, "Tab"), (0x2C, "Spazio"),
                                    (0x2A, "Cancella ⌫"), (0x4C, "Canc avanti ⌦"), (0x49, "Ins"), (0x46, "Stamp (PrintScreen)")]
        let sym: [(Int, String)] = [(0x2D, "' ?"), (0x2E, "ì ^"), (0x2F, "è é"), (0x30, "+ *"), (0x31, "ù §"), (0x33, "ò ç"),
                                   (0x34, "à °"), (0x35, "\\ |"), (0x36, ", ;"), (0x37, ". :"), (0x38, "- _"), (0x64, "< >")]
        let pad: [(Int, String)] = [(0x57, "+ tastierino"), (0x56, "− tastierino"), (0x55, "× tastierino"), (0x54, "÷ tastierino"),
                                   (0x58, "Invio tastierino"), (0x63, ", tastierino")] +
                                   (0...9).map { ($0 == 0 ? 0x62 : 0x58 + $0, "\($0) tastierino") }
        for (c, n) in nav { k.append(KeyInfo(code: c, name: n, section: "Frecce e pagine")) }
        for (c, n) in edit { k.append(KeyInfo(code: c, name: n, section: "Scrittura")) }
        for (c, n) in sym { k.append(KeyInfo(code: c, name: n, section: "Simboli (tastiera italiana)")) }
        for (c, n) in pad { k.append(KeyInfo(code: c, name: n, section: "Tastierino numerico")) }
        return k
    }()
    static let sections: [String] = {
        var s: [String] = []
        for k in all where !s.contains(k.section) { s.append(k.section) }
        return s
    }()
    static func name(_ code: Int) -> String {
        if code == 0 { return "—" }
        return all.first { $0.code == code }?.name ?? String(format: "0x%02X", code)
    }
    static func shortName(_ code: Int) -> String {
        switch code {
        case 0x52: "↑"; case 0x51: "↓"; case 0x50: "←"; case 0x4F: "→"
        case 0x2C: "Spazio"; case 0x57: "+"; case 0x56: "−"
        default: name(code)
        }
    }

    // codici tasto del Mac (kVK_...) -> codici HID, per "Registra"
    static let fromMacKeyCode: [UInt16: Int] = [
        0: 0x04, 11: 0x05, 8: 0x06, 2: 0x07, 14: 0x08, 3: 0x09, 5: 0x0A, 4: 0x0B, 34: 0x0C, 38: 0x0D, 40: 0x0E, 37: 0x0F,
        46: 0x10, 45: 0x11, 31: 0x12, 35: 0x13, 12: 0x14, 15: 0x15, 1: 0x16, 17: 0x17, 32: 0x18, 9: 0x19, 13: 0x1A,
        7: 0x1B, 16: 0x1C, 6: 0x1D,
        18: 0x1E, 19: 0x1F, 20: 0x20, 21: 0x21, 23: 0x22, 22: 0x23, 26: 0x24, 28: 0x25, 25: 0x26, 29: 0x27,
        36: 0x28, 53: 0x29, 51: 0x2A, 48: 0x2B, 49: 0x2C, 27: 0x2D, 24: 0x2E, 33: 0x2F, 30: 0x30, 42: 0x31,
        41: 0x33, 39: 0x34, 50: 0x35, 43: 0x36, 47: 0x37, 44: 0x38, 10: 0x64,
        122: 0x3A, 120: 0x3B, 99: 0x3C, 118: 0x3D, 96: 0x3E, 97: 0x3F, 98: 0x40, 100: 0x41, 101: 0x42, 109: 0x43,
        103: 0x44, 111: 0x45,
        115: 0x4A, 116: 0x4B, 117: 0x4C, 119: 0x4D, 121: 0x4E, 124: 0x4F, 123: 0x50, 125: 0x51, 126: 0x52,
        75: 0x54, 67: 0x55, 78: 0x56, 69: 0x57, 76: 0x58, 83: 0x59, 84: 0x5A, 85: 0x5B, 86: 0x5C, 87: 0x5D,
        88: 0x5E, 89: 0x5F, 91: 0x60, 92: 0x61, 82: 0x62, 65: 0x63,
    ]
}

enum Platform { case both, mac, win }

func comboText(_ c: Combo, _ p: Platform) -> String {
    if c.key == 0 && c.mods == 0 { return "—" }
    var parts: [String] = []
    let m = c.mods
    switch p {
    case .mac:
        if m & Mod.ctrl != 0 { parts.append("⌃") }
        if m & Mod.alt != 0 { parts.append("⌥") }
        if m & Mod.shift != 0 { parts.append("⇧") }
        if m & (Mod.gui | Mod.pri) != 0 { parts.append("⌘") }
        return parts.joined() + (c.key != 0 ? Keys.shortName(c.key) : "")
    case .win, .both:
        if m & (Mod.ctrl | Mod.pri) != 0 { parts.append("Ctrl") }
        if m & Mod.gui != 0 { parts.append("Win") }
        if m & Mod.alt != 0 { parts.append("Alt") }
        if m & Mod.shift != 0 { parts.append("Shift") }
        if c.key != 0 { parts.append(Keys.shortName(c.key)) }
        return parts.joined(separator: "+")
    }
}

// ---------- Tasti multimediali ----------

struct MediaInfo: Identifiable {
    let code: Int
    let name: String
    let short: String
    var id: Int { code }
}

enum Media {
    static let all: [MediaInfo] = [
        MediaInfo(code: 0xCD, name: "Play / Pausa", short: "Play"),
        MediaInfo(code: 0xB5, name: "Brano successivo", short: "Succ."),
        MediaInfo(code: 0xB6, name: "Brano precedente", short: "Prec."),
        MediaInfo(code: 0xB7, name: "Stop", short: "Stop"),
        MediaInfo(code: 0xB3, name: "Avanti veloce", short: "Avanti"),
        MediaInfo(code: 0xB4, name: "Riavvolgi", short: "Riavv."),
        MediaInfo(code: 0xE2, name: "Muto", short: "Muto"),
        MediaInfo(code: 0xE9, name: "Volume su", short: "Vol +"),
        MediaInfo(code: 0xEA, name: "Volume giù", short: "Vol -"),
        MediaInfo(code: 0x6F, name: "Luminosità su", short: "Luce +"),
        MediaInfo(code: 0x70, name: "Luminosità giù", short: "Luce -"),
        MediaInfo(code: 0x192, name: "Calcolatrice (Windows)", short: "Calcolo"),
        MediaInfo(code: 0x18A, name: "Posta (Windows)", short: "Posta"),
        MediaInfo(code: 0x223, name: "Pagina iniziale del browser", short: "Home"),
    ]
    static func name(_ code: Int) -> String { all.first { $0.code == code }?.name ?? String(format: "Codice 0x%03X", code) }
}

// ---------- Modelli per la manopola ----------

struct KnobPreset: Identifiable {
    let name: String
    let label: String
    let cw: Action
    let ccw: Action
    var id: String { name }

    static let all: [KnobPreset] = [
        KnobPreset(name: "Volume", label: "Volume", cw: .media(0xE9), ccw: .media(0xEA)),
        KnobPreset(name: "Scorrimento (rotella)", label: "Scorri", cw: .wheel(-1), ccw: .wheel(1)),
        KnobPreset(name: "Schede del browser", label: "Schede", cw: .key(Mod.ctrl, 0x2B), ccw: .key(Mod.ctrl | Mod.shift, 0x2B)),
        KnobPreset(name: "Zoom", label: "Zoom", cw: .key(Mod.pri, 0x57), ccw: .key(Mod.pri, 0x56)),
        KnobPreset(name: "Frecce su e giù", label: "Frecce", cw: .key(0, 0x51), ccw: .key(0, 0x52)),
        KnobPreset(name: "Frecce destra e sinistra", label: "Frecce", cw: .key(0, 0x4F), ccw: .key(0, 0x50)),
        KnobPreset(name: "Luminosità", label: "Luce", cw: .media(0x6F), ccw: .media(0x70)),
        KnobPreset(name: "Annulla e ripeti", label: "Storia", cw: .key(Mod.pri | Mod.shift, 0x1D), ccw: .key(Mod.pri, 0x1D)),
    ]

    static func matching(_ p: Page) -> KnobPreset? {
        all.first { $0.cw.behaviour == p.cw.behaviour && $0.ccw.behaviour == p.ccw.behaviour }
    }
}

struct DeviceStatus: Decodable, Equatable {
    var bat: Int
    var mv: Int?            // tensione della batteria in mV (firmware 1.1)
    var usb: Bool
    var page: Int
    var mac: Bool
    var test: Int?
    var fw: String
}

// Avvisi in tempo reale dal macropad
enum DeviceEvent {
    case key(Int, down: Bool)
    case knob(Int)          // +1 orario, -1 antiorario
    case button(down: Bool)
    case page(Int)
}
