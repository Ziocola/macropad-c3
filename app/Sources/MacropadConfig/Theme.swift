import SwiftUI

// Stile dell'app: scuro come il guscio del macropad, con l'arancione dei tasti come colore d'accento

enum Theme {
    static let panel      = Color(red: 0.112, green: 0.114, blue: 0.124)
    static let sidebar    = Color(red: 0.090, green: 0.092, blue: 0.100)
    static let card       = Color.white.opacity(0.045)
    static let cardStroke = Color.white.opacity(0.075)
    static let well       = Color.black.opacity(0.28)         // campi di testo e zone incassate
    static let keyTop     = Color(red: 0.235, green: 0.238, blue: 0.255)
    static let keyLow     = Color(red: 0.165, green: 0.168, blue: 0.182)
}

// ---------- Riquadro con titolo ----------

struct Card<Content: View>: View {
    let title: String?
    let icon: String?
    let content: Content

    init(_ title: String? = nil, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(spacing: 6) {
                    if let icon { Image(systemName: icon).foregroundStyle(Color.orange) }
                    Eyebrow(title)
                }
                .font(.system(size: 10.5, weight: .semibold))
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.cardStroke))
    }
}

// titoletto maiuscolo e spaziato
struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.9)
            .foregroundStyle(.secondary)
    }
}

// ---------- Tessera cliccabile: icona + nome ----------

struct Tile: View {
    let icon: String
    let title: String
    var note: String? = nil
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(height: 20)
                Text(title)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let note {
                    Text(note).font(.system(size: 9.5)).opacity(0.6).lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: note == nil ? 56 : 64)
            .foregroundStyle(selected ? Color.capInk : Color.primary.opacity(0.82))
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? AnyShapeStyle(LinearGradient(colors: [.orangeHi, .orange], startPoint: .top, endPoint: .bottom))
                                   : AnyShapeStyle(Color.white.opacity(0.05))))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(selected ? Color.white.opacity(0.25) : Color.white.opacity(0.07)))
            .shadow(color: selected ? Color.orange.opacity(0.35) : .clear, radius: 6, y: 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(Pressable())
    }
}

struct Pressable: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// ---------- Tasti della tastiera, per mostrare le combinazioni ----------

struct KeyChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.primary.opacity(0.9))
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 21)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.keyTop, Theme.keyLow], startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.5), radius: 0, y: 1.5))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.white.opacity(0.10)))
    }
}

struct ComboChips: View {
    let combo: Combo
    let platform: Platform
    var body: some View {
        let parts = comboParts(combo, platform)
        HStack(spacing: 3) {
            if parts.isEmpty {
                Text("nessuna").font(.callout).foregroundStyle(.tertiary)
            }
            ForEach(Array(parts.enumerated()), id: \.offset) { _, p in KeyChip(text: p) }
        }
    }
}

func comboParts(_ c: Combo, _ p: Platform) -> [String] {
    var parts: [String] = []
    let m = c.mods
    switch p {
    case .mac:
        if m & Mod.ctrl != 0 { parts.append("⌃") }
        if m & Mod.alt != 0 { parts.append("⌥") }
        if m & Mod.shift != 0 { parts.append("⇧") }
        if m & (Mod.gui | Mod.pri) != 0 { parts.append("⌘") }
    case .win, .both:
        if m & (Mod.ctrl | Mod.pri) != 0 { parts.append("Ctrl") }
        if m & Mod.gui != 0 { parts.append("Win") }
        if m & Mod.alt != 0 { parts.append("Alt") }
        if m & Mod.shift != 0 { parts.append("Shift") }
    }
    if c.key != 0 { parts.append(Keys.shortName(c.key)) }
    return parts
}

// ---------- Anteprima di una riga del display del macropad ----------

struct OledPreview: View {
    let text: String
    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.oledInk)
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.black))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.white.opacity(0.10)))
    }
}

// campo di testo incassato, con il contatore dei caratteri
struct WellField: View {
    let prompt: String
    @Binding var text: String
    let max: Int

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $text, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
            Text("\(text.count)/\(max)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(text.count >= max ? Color.orange : .secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.well))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.white.opacity(0.07)))
    }
}

// ---------- Icone delle funzioni ----------

extension Action {
    // icona da disegnare sul tasto, se ne esiste una adatta
    var symbol: String? {
        switch kind {
        case .media: return Media.symbol(u ?? 0)
        case .wheel: return (u ?? 0) > 0 ? "chevron.up.2" : "chevron.down.2"
        case .key: return shortcutSymbol(mac)
        case .none: return nil
        }
    }
}

private func shortcutSymbol(_ c: Combo) -> String? {
    // ⌘ vale sia GUI che "⌘ / Ctrl"
    var m = c.mods & (Mod.ctrl | Mod.shift | Mod.alt)
    if c.mods & (Mod.gui | Mod.pri) != 0 { m |= Mod.gui }
    let cmd = Mod.gui, sh = Mod.shift, ctl = Mod.ctrl
    let table: [Int: [Int: String]] = [
        0: [0x05: "paintbrush.pointed.fill", 0x08: "eraser.fill", 0x19: "arrow.up.and.down.and.arrow.left.and.right",
            0x0B: "hand.raised.fill", 0x44: "menubar.dock.rectangle", 0x50: "arrow.left", 0x4F: "arrow.right",
            0x52: "arrow.up", 0x51: "arrow.down", 0x28: "return", 0x29: "escape", 0x2C: "space", 0x2A: "delete.left"],
        cmd: [0x1D: "arrow.uturn.backward", 0x16: "square.and.arrow.down", 0x06: "doc.on.doc", 0x19: "doc.on.clipboard",
              0x1B: "scissors", 0x2B: "rectangle.on.rectangle", 0x2C: "magnifyingglass", 0x04: "rectangle.dashed",
              0x50: "chevron.backward", 0x4F: "chevron.forward", 0x15: "arrow.clockwise", 0x17: "plus.square.on.square",
              0x1A: "xmark.square", 0x0F: "link", 0x09: "text.magnifyingglass", 0x27: "arrow.down.right.and.arrow.up.left",
              0x1E: "1.magnifyingglass", 0x57: "plus.magnifyingglass", 0x56: "minus.magnifyingglass",
              0x14: "power", 0x0D: "person", 0x11: "doc.badge.plus", 0x12: "folder", 0x13: "printer"],
        cmd | sh: [0x1D: "arrow.uturn.forward", 0x17: "arrow.counterclockwise.square", 0x21: "camera.viewfinder",
                   0x20: "camera.viewfinder", 0x22: "camera.viewfinder"],
        cmd | ctl: [0x14: "lock.fill", 0x09: "arrow.up.left.and.arrow.down.right"],
        ctl: [0x2B: "arrow.right.square", 0x52: "rectangle.3.group"],
        ctl | sh: [0x2B: "arrow.left.square"],
    ]
    return table[m]?[c.key]
}

extension Media {
    static func symbol(_ code: Int) -> String {
        switch code {
        case 0xCD: "playpause.fill"
        case 0xB5: "forward.end.fill"
        case 0xB6: "backward.end.fill"
        case 0xB7: "stop.fill"
        case 0xB3: "forward.fill"
        case 0xB4: "backward.fill"
        case 0xE2: "speaker.slash.fill"
        case 0xE9: "speaker.wave.3.fill"
        case 0xEA: "speaker.wave.1.fill"
        case 0x6F: "sun.max.fill"
        case 0x70: "sun.min.fill"
        case 0x192: "plus.forwardslash.minus"
        case 0x18A: "envelope.fill"
        case 0x223: "house.fill"
        default: "music.note"
        }
    }

    // nome breve per le tessere
    static func tileName(_ code: Int) -> String {
        switch code {
        case 0xCD: "Play / Pausa"
        case 0xB5: "Successivo"
        case 0xB6: "Precedente"
        case 0xB3: "Avanti"
        case 0xB4: "Riavvolgi"
        case 0xE9: "Volume +"
        case 0xEA: "Volume −"
        case 0x6F: "Luce +"
        case 0x70: "Luce −"
        case 0x192: "Calcolatrice"
        case 0x18A: "Posta"
        case 0x223: "Home"
        default: all.first { $0.code == code }?.short ?? "?"
        }
    }

    static func windowsOnly(_ code: Int) -> Bool { [0x192, 0x18A, 0x223, 0xB7].contains(code) }
}

extension KnobPreset {
    var symbol: String {
        switch name {
        case "Volume": "speaker.wave.2.fill"
        case "Scorrimento (rotella)": "arrow.up.and.down"
        case "Schede del browser": "square.on.square"
        case "Zoom": "plus.magnifyingglass"
        case "Frecce su e giù": "arrow.up.arrow.down"
        case "Frecce destra e sinistra": "arrow.left.arrow.right"
        case "Luminosità": "sun.max.fill"
        case "Annulla e ripeti": "clock.arrow.circlepath"
        default: "dial.medium"
        }
    }

    var tileName: String {
        switch name {
        case "Scorrimento (rotella)": "Scorrimento"
        case "Schede del browser": "Schede"
        case "Frecce su e giù": "Frecce ↑↓"
        case "Frecce destra e sinistra": "Frecce ←→"
        case "Annulla e ripeti": "Annulla/Ripeti"
        default: name
        }
    }
}
