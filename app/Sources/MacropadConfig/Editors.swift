import AppKit
import SwiftUI

// ---------- Pannello a destra: tasto o manopola selezionati ----------

struct InspectorView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                switch model.selection {
                case .key(let i):
                    ActionEditor(title: "Cosa fa",
                                 action: Binding(get: { model.page.keys[i] }, set: { model.page.keys[i] = $0 }),
                                 showLabel: true)
                        .id("\(model.page.id)-\(i)")
                case .knob:
                    KnobEditor()
                        .id("\(model.page.id)-knob")
                }
                pageCard
            }
            .padding(16)
            .animation(.easeOut(duration: 0.15), value: model.selection)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.panel)
    }

    // cosa stai modificando, con un tasto in miniatura
    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                switch model.selection {
                case .key(let i):
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [.orangeHi, .orange], startPoint: .top, endPoint: .bottom))
                    Image(systemName: model.page.keys[i].symbol ?? "\(i + 1).square")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.capInk)
                case .knob:
                    Circle().fill(RadialGradient(colors: [.orangeHi, .orange, .orangeLow], center: .init(x: 0.38, y: 0.32),
                                                 startRadius: 0, endRadius: 30))
                    Image(systemName: "dial.medium.fill").font(.system(size: 19, weight: .semibold)).foregroundStyle(Color.capInk)
                }
            }
            .frame(width: 46, height: 46)
            .shadow(color: .black.opacity(0.5), radius: 3, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                switch model.selection {
                case .key(let i):
                    Eyebrow("Tasto \(i + 1) · fila \(i / 3 + 1), colonna \(i % 3 + 1)")
                    Text(model.page.keys[i].label.isEmpty ? "Senza etichetta" : model.page.keys[i].label)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(model.page.keys[i].label.isEmpty ? .secondary : .primary)
                case .knob:
                    Eyebrow("Manopola")
                    Text(model.page.knobLabel.isEmpty ? "Senza etichetta" : model.page.knobLabel)
                        .font(.system(size: 20, weight: .bold))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }

    private var pageCard: some View {
        Card("Pagina \(model.pageIndex + 1) di \(model.config.pages.count)", icon: "rectangle.stack") {
            WellField(prompt: "Nome della pagina", text: Binding(
                get: { model.page.name },
                set: { model.page.name = displayText($0, max: MacropadConfig.nameMax) }), max: MacropadConfig.nameMax)
            HStack(spacing: 8) {
                OledPreview(text: "\(model.pageIndex + 1)/\(model.config.pages.count) \(model.page.name)")
                Text("in alto sul display").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// ---------- Un'azione: scorciatoia, multimediale, rotella ----------

struct ActionEditor: View {
    let title: String
    @Binding var action: Action
    let showLabel: Bool
    @State private var split = false

    private let kinds: [(ActionKind, String)] = [(.none, "nosign"), (.key, "command"), (.media, "playpause.fill"), (.wheel, "computermouse.fill")]

    var body: some View {
        VStack(spacing: 14) {
            if showLabel {
                Card("Etichetta sul display", icon: "character.cursor.ibeam") {
                    WellField(prompt: "es. Copia", text: Binding(get: { action.label },
                                                                 set: { action.label = displayText($0, max: MacropadConfig.labelMax) }),
                              max: MacropadConfig.labelMax)
                    HStack(spacing: 8) {
                        OledPreview(text: action.label)
                            .frame(width: 92)
                        Text("Lettere e accenti sì, simboli come ⌘ no.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Card(title, icon: "bolt.fill") {
                HStack(spacing: 6) {
                    ForEach(kinds, id: \.0) { k, icon in
                        Tile(icon: icon, title: k.title, selected: action.kind == k) {
                            withAnimation(.easeOut(duration: 0.15)) { setKind(k) }
                        }
                    }
                }
                switch action.kind {
                case .key: shortcut
                case .media: media
                case .wheel: wheel
                case .none:
                    Text("Il tasto non fa niente.").font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { split = !action.sameOnBoth }
    }

    @ViewBuilder private var shortcut: some View {
        Divider().opacity(0.5)
        if split {
            ComboEditor(title: "Sul Mac", combo: Binding(get: { action.mac }, set: { action.mac = $0; autoLabel() }), platform: .mac)
            ComboEditor(title: "Su Windows", combo: Binding(get: { action.win }, set: { action.win = $0 }), platform: .win)
        } else {
            ComboEditor(title: nil, combo: Binding(get: { action.mac },
                                                   set: { action.mac = $0; action.win = $0; autoLabel() }), platform: .both)
        }
        Toggle(isOn: Binding(
            get: { split },
            set: { on in
                withAnimation(.easeOut(duration: 0.15)) { split = on }
                if !on { action.win = action.mac }
            })) {
            Text("Combinazione diversa su Windows").frame(maxWidth: .infinity, alignment: .leading)
        }
            .toggleStyle(.switch)
            .controlSize(.small)
        VStack(spacing: 6) {
            platformRow("apple.logo", "Mac", ComboChips(combo: action.mac, platform: .mac))
            platformRow("pc", "Windows", ComboChips(combo: action.win, platform: .win))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.well))
        if !split {
            Text("⌘ / Ctrl diventa Cmd sul Mac e Ctrl su Windows.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func platformRow<V: View>(_ icon: String, _ name: String, _ chips: V) -> some View {
        HStack {
            Label(name, systemImage: icon).font(.callout).foregroundStyle(.secondary)
            Spacer()
            chips
        }
    }

    private var media: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
            ForEach(Media.all) { m in
                Tile(icon: Media.symbol(m.code), title: Media.tileName(m.code),
                     note: Media.windowsOnly(m.code) ? "solo Windows" : nil, selected: action.u == m.code) {
                    let old = Media.all.first { $0.code == action.u }?.short
                    action.u = m.code
                    if action.label.isEmpty || action.label == old { action.label = m.short }
                }
            }
        }
    }

    @ViewBuilder private var wheel: some View {
        let n = action.u ?? -1
        HStack(spacing: 6) {
            Tile(icon: "chevron.up.2", title: "Su", selected: n > 0) { action.u = abs(n) }
            Tile(icon: "chevron.down.2", title: "Giù", selected: n < 0) { action.u = -abs(n) }
        }
        Stepper(value: Binding(get: { abs(n) }, set: { action.u = (n > 0 ? 1 : -1) * $0 }), in: 1...5) {
            HStack {
                Text("Scatti della rotella")
                Spacer()
                Text("\(abs(n))").font(.body.monospacedDigit().weight(.semibold))
            }
        }
    }

    private func setKind(_ k: ActionKind) {
        action.kind = k
        if k == .media, action.label.isEmpty { action.label = Media.all.first { $0.code == action.u }?.short ?? "" }
    }

    private func autoLabel() {
        guard showLabel, action.label.isEmpty, action.mac.key != 0 else { return }
        action.label = displayText(action.mac.mods == 0 ? Keys.shortName(action.mac.key) : comboText(action.mac, .win),
                                   max: MacropadConfig.labelMax)
    }
}

// ---------- Modificatori + tasto, con registrazione dalla tastiera ----------

struct ComboEditor: View {
    let title: String?
    @Binding var combo: Combo
    let platform: Platform
    @StateObject private var recorder = KeyRecorder()

    private struct ModChip { let symbol: String; let name: String; let mask: Int; let set: Int }

    private var chips: [ModChip] {
        switch platform {
        case .both:
            var c = [ModChip(symbol: "⌘", name: "Cmd / Ctrl", mask: Mod.pri, set: Mod.pri),
                     ModChip(symbol: "⇧", name: "Shift", mask: Mod.shift, set: Mod.shift),
                     ModChip(symbol: "⌥", name: "Option / Alt", mask: Mod.alt, set: Mod.alt),
                     ModChip(symbol: "⌃", name: "Control", mask: Mod.ctrl, set: Mod.ctrl)]
            if combo.mods & Mod.gui != 0 { c.append(ModChip(symbol: "⌘", name: "Cmd / Win", mask: Mod.gui, set: Mod.gui)) }
            return c
        case .mac:
            return [ModChip(symbol: "⌘", name: "Command", mask: Mod.gui | Mod.pri, set: Mod.gui),
                    ModChip(symbol: "⇧", name: "Shift", mask: Mod.shift, set: Mod.shift),
                    ModChip(symbol: "⌥", name: "Option", mask: Mod.alt, set: Mod.alt),
                    ModChip(symbol: "⌃", name: "Control", mask: Mod.ctrl, set: Mod.ctrl)]
        case .win:
            return [ModChip(symbol: "Ctrl", name: "Control", mask: Mod.ctrl | Mod.pri, set: Mod.ctrl),
                    ModChip(symbol: "Shift", name: "Maiuscolo", mask: Mod.shift, set: Mod.shift),
                    ModChip(symbol: "Alt", name: "Alt", mask: Mod.alt, set: Mod.alt),
                    ModChip(symbol: "Win", name: "Windows", mask: Mod.gui, set: Mod.gui)]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Label(title, systemImage: platform == .win ? "pc" : "apple.logo")
                    .font(.callout.weight(.medium)).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(chips, id: \.name) { chip in
                    modKey(chip, on: combo.mods & chip.mask != 0) {
                        let on = combo.mods & chip.mask == 0
                        combo.mods = on ? (combo.mods & ~chip.mask) | chip.set : combo.mods & ~chip.mask
                    }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                Picker("", selection: $combo.key) {
                    Text("Nessun tasto").tag(0)
                    ForEach(Keys.sections, id: \.self) { section in
                        Section(section) {
                            ForEach(Keys.all.filter { $0.section == section }) { Text($0.name).tag($0.code) }
                        }
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                Button {
                    recorder.active ? recorder.stop() : recorder.start(platform) { combo = $0 }
                } label: {
                    Label(recorder.active ? "Premi…" : "Registra", systemImage: recorder.active ? "record.circle.fill" : "record.circle")
                        .symbolEffect(.pulse, isActive: recorder.active)
                }
                .help("Premi la combinazione sulla tastiera del Mac. Cmd+Tab e Cmd+Spazio vanno scelti a mano.")
                .tint(recorder.active ? .red : nil)
                .buttonStyle(.bordered)
            }
        }
    }

    // modificatore disegnato come un tasto: arancione quando è attivo
    private func modKey(_ chip: ModChip, on: Bool, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            VStack(spacing: 1) {
                Text(chip.symbol).font(.system(size: chip.symbol.count > 1 ? 12 : 17, weight: .semibold, design: .rounded))
                Text(chip.name).font(.system(size: 8.5, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7).opacity(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .foregroundStyle(on ? Color.capInk : Color.primary.opacity(0.85))
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(on ? AnyShapeStyle(LinearGradient(colors: [.orangeHi, .orange], startPoint: .top, endPoint: .bottom))
                             : AnyShapeStyle(LinearGradient(colors: [Theme.keyTop, Theme.keyLow], startPoint: .top, endPoint: .bottom)))
                    .shadow(color: .black.opacity(0.55), radius: 0, y: on ? 1 : 2.5))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.white.opacity(on ? 0.25 : 0.09)))
            .offset(y: on ? 1 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(Pressable())
        .help(chip.name)
    }
}

final class KeyRecorder: ObservableObject {
    @Published private(set) var active = false
    private var monitor: Any?

    func start(_ platform: Platform, done: @escaping (Combo) -> Void) {
        stop()
        active = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let key = Keys.fromMacKeyCode[e.keyCode] else { NSSound.beep(); return nil }
            let f = e.modifierFlags
            var mods = 0
            if f.contains(.command) { mods |= platform == .both ? Mod.pri : Mod.gui }
            if f.contains(.control) { mods |= Mod.ctrl }
            if f.contains(.option) { mods |= Mod.alt }
            if f.contains(.shift) { mods |= Mod.shift }
            done(Combo(mods: mods, key: key))
            self?.stop()
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        active = false
    }

    deinit { stop() }
}

// ---------- Manopola ----------

struct KnobEditor: View {
    @EnvironmentObject var model: AppModel
    @State private var custom = false

    var body: some View {
        VStack(spacing: 14) {
            Card("Etichetta sul display", icon: "character.cursor.ibeam") {
                WellField(prompt: "es. Volume", text: Binding(get: { model.page.knobLabel },
                                                              set: { model.page.knobLabel = displayText($0, max: MacropadConfig.labelMax) }),
                          max: MacropadConfig.labelMax)
                OledPreview(text: "Manopola: \(model.page.knobLabel)")
            }
            Card("Girandola", icon: "dial.medium") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(KnobPreset.all) { p in
                        Tile(icon: p.symbol, title: p.tileName, selected: !custom && KnobPreset.matching(model.page)?.name == p.name) {
                            let old = KnobPreset.matching(model.page)?.label
                            model.page.cw = p.cw
                            model.page.ccw = p.ccw
                            if model.page.knobLabel.isEmpty || model.page.knobLabel == old { model.page.knobLabel = p.label }
                            withAnimation(.easeOut(duration: 0.15)) { custom = false }
                        }
                    }
                    Tile(icon: "slider.horizontal.3", title: "A scelta", selected: custom) {
                        withAnimation(.easeOut(duration: 0.15)) { custom = true }
                    }
                }
                Label("Premerla passa alla pagina dopo. Tenerla premuta cambia tra Mac e Windows; 5 secondi cancellano gli abbinamenti Bluetooth.",
                      systemImage: "hand.tap")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if custom {
                ActionEditor(title: "Girando in senso orario ↻", action: Binding(get: { model.page.cw }, set: { model.page.cw = $0 }), showLabel: false)
                ActionEditor(title: "Girando in senso antiorario ↺", action: Binding(get: { model.page.ccw }, set: { model.page.ccw = $0 }), showLabel: false)
            }
        }
        .onAppear { custom = KnobPreset.matching(model.page) == nil }
    }
}

// ---------- Impostazioni del macropad ----------

struct DeviceSettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private let displayChoices = [(15, "15 secondi"), (30, "30 secondi"), (60, "1 minuto"), (120, "2 minuti"),
                                  (300, "5 minuti"), (600, "10 minuti"), (0, "Mai")]
    private let sleepChoices = [(5, "5 minuti"), (10, "10 minuti"), (15, "15 minuti"), (30, "30 minuti"),
                                (60, "1 ora"), (0, "Mai")]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.capInk)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [.orangeHi, .orange], startPoint: .top, endPoint: .bottom)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Impostazioni del macropad").font(.system(size: 17, weight: .bold))
                    Text("Valgono per tutte le pagine.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            ScrollView {
                VStack(spacing: 14) {
                    Card("Manopola", icon: "dial.medium") {
                        row("Inverti il verso di rotazione") { Toggle("", isOn: $model.config.set.rev).toggleStyle(.switch) }
                        row("Impulsi per scatto") {
                            Picker("", selection: $model.config.set.steps) {
                                Text("4 (quasi tutti gli EC11)").tag(4)
                                Text("2").tag(2)
                                Text("1").tag(1)
                            }
                        }
                        note("Se a ogni scatto il volume cambia di due, o solo ogni due scatti, prova un altro valore.")
                    }
                    Card("Display", icon: "rectangle.inset.filled") {
                        row("Display capovolto") { Toggle("", isOn: $model.config.set.rot).toggleStyle(.switch) }
                        row("Spegni dopo") {
                            Picker("", selection: $model.config.set.disp) {
                                ForEach(displayChoices, id: \.0) { Text($0.1).tag($0.0) }
                            }
                        }
                    }
                    Card("Batteria", icon: "battery.75") {
                        row("Sonno profondo dopo") {
                            Picker("", selection: $model.config.set.sleep) {
                                ForEach(sleepChoices, id: \.0) { Text($0.1).tag($0.0) }
                            }
                        }
                        note("Nel sonno profondo consuma quasi niente; si riaccende premendo la manopola.")
                    }
                }
                .padding(.horizontal, 18)
            }

            HStack {
                Label("Arrivano al macropad con Invia.", systemImage: "arrow.up.circle")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Fine") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(18)
        }
        .frame(width: 470, height: 560)
        .background(Theme.panel)
        .tint(.orange)
    }

    private func row<V: View>(_ title: String, @ViewBuilder _ control: () -> V) -> some View {
        HStack {
            Text(title)
            Spacer()
            control().labelsHidden().fixedSize()
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
