import SwiftUI

@main
struct MacropadConfigApp: App {
    @StateObject private var model = AppModel()

    init() { NSApplication.shared.setActivationPolicy(.regular) }

    var body: some Scene {
        WindowGroup("Macropad Config") {
            ContentView(link: model.link)
                .environmentObject(model)
                .tint(.orange)
                .preferredColorScheme(.dark)
                .frame(minWidth: 980, minHeight: 640)
        }
        .defaultSize(width: 1180, height: max(760, UserDefaults.standard.double(forKey: "winH")))
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .importExport) {
                Button("Apri configurazione…") { model.importFile() }.keyboardShortcut("o")
                Button("Salva configurazione su file…") { model.exportFile() }.keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandGroup(before: .toolbar) {
                Button("Modifica i tasti") { model.mode = .edit }.keyboardShortcut("1")
                Button("Prova i tasti") { model.mode = .test }.keyboardShortcut("2")
                Divider()
                Button("Pagina precedente") { model.pageIndex = (model.pageIndex + model.config.pages.count - 1) % model.config.pages.count }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                Button("Pagina successiva") { model.pageIndex = (model.pageIndex + 1) % model.config.pages.count }
                    .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                Button("Sposta su la pagina") { model.movePage(model.pageIndex, by: -1) }
                    .keyboardShortcut(.upArrow, modifiers: [.command, .option, .shift])
                    .disabled(model.pageIndex == 0)
                Button("Sposta giù la pagina") { model.movePage(model.pageIndex, by: 1) }
                    .keyboardShortcut(.downArrow, modifiers: [.command, .option, .shift])
                    .disabled(model.pageIndex >= model.config.pages.count - 1)
                Divider()
            }
            CommandMenu("Macropad") {
                Button("Leggi dal macropad") { model.readFromDevice() }.keyboardShortcut("r").disabled(!model.link.isConnected)
                Button("Invia al macropad") { model.send() }.keyboardShortcut(.return).disabled(!model.link.isConnected)
                Button("Mostra il macropad virtuale") { model.showPad() }.keyboardShortcut("m", modifiers: [.command, .shift])
                Divider()
                Button("Impostazioni del macropad…") { model.showSettings = true }.keyboardShortcut(",", modifiers: [.command, .option])
                Button("Ripristina predefinite") { model.restoreDefaults() }
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var link: MacropadLink

    var body: some View {
        NavigationSplitView {
            PagesSidebar(link: link)
                .navigationSplitViewColumnWidth(min: 220, ideal: 236, max: 300)
        } detail: {
            VStack(spacing: 0) {
                ModeBar(simulating: model.simulating)
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        PageSwitcher(locked: model.mode == .test && link.isConnected)
                            .padding(.top, 14)
                        DeviceView(link: link, test: model.test, testing: model.mode == .test, simulating: model.simulating, pad: model.pad)
                        Text(hint)
                            .font(.callout).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                    }
                    .frame(minWidth: 360, maxWidth: .infinity)
                    .background(Stage())
                    Divider()
                    Group {
                        if model.mode == .test { TestPanel(link: link, test: model.test) } else { InspectorView() }
                    }
                    .frame(width: 400)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { StatusBar(link: link) }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { model.showPad() } label: { Label("Macropad virtuale", systemImage: "square.grid.3x3.square") }
                    .help("Macropad virtuale: una finestrella sempre in primo piano che esegue davvero le funzioni nell'app che stai usando")
                Button { model.showSettings = true } label: { Label("Impostazioni", systemImage: "gearshape") }
                    .help("Impostazioni del macropad: verso della manopola, display, batteria")
                Menu {
                    Button("Apri configurazione…") { model.importFile() }
                    Button("Salva configurazione su file…") { model.exportFile() }
                    Divider()
                    Button("Ripristina predefinite") { model.restoreDefaults() }
                } label: { Label("File", systemImage: "doc") }
                Button { model.readFromDevice() } label: { Label("Leggi", systemImage: "arrow.down.circle") }
                    .help("Rileggi la configurazione dal macropad")
                    .disabled(!link.isConnected || link.busy != nil)
                Button { model.send() } label: { Label("Invia al macropad", systemImage: "arrow.up.circle.fill") }
                    .labelStyle(.titleAndIcon)
                    .buttonStyle(.borderedProminent)
                    .help(link.isConnected ? "Manda le funzioni al macropad: si usano subito" : "Collega il macropad per inviare")
                    .disabled(!link.isConnected || link.busy != nil || !model.hasUnsentChanges)
            }
        }
        .overlay(alignment: .top) {
            if let t = model.toast {
                Label(t.text, systemImage: t.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .foregroundStyle(t.isError ? Color.red : Color.primary)
                    .shadow(radius: 6, y: 2)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.toast)
        .sheet(isPresented: $model.showSettings) { DeviceSettingsView() }
        .alert("Il macropad ha una configurazione diversa", isPresented: Binding(
            get: { model.deviceConflict != nil }, set: { if !$0 { model.keepLocal() } })) {
            Button("Usa quella del macropad") { if let c = model.deviceConflict { model.use(c) } }
            Button("Tieni la mia", role: .cancel) { model.keepLocal() }
        } message: {
            Text("Hai fatto modifiche prima di collegarlo. Se tieni la tua, premi poi Invia per mandarla al macropad.")
        }
        .onChange(of: link.status?.page) { _, page in
            if let page, page < model.config.pages.count, model.mode == .test || !model.hasUnsentChanges { model.pageIndex = page }
        }
    }

    private var hint: String {
        if model.simulating { return "Clicca i tasti del disegno oppure premi 1…9 sulla tastiera del Mac. ← → girano la manopola, la barra spaziatrice la preme." }
        if model.mode == .test { return "Premi i tasti veri: qui si illuminano. Clicca un tasto per vedere come è collegato." }
        return "Clicca un tasto o la manopola per cambiarne la funzione."
    }
}

// Le due schermate dell'app, ben in vista sopra a tutto
struct ModeBar: View {
    @EnvironmentObject var model: AppModel
    let simulating: Bool
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 2) {
                tab(.edit, "Modifica i tasti", "slider.horizontal.3", "⌘1")
                tab(.test, "Prova i tasti", "checklist", "⌘2")
            }
            .padding(3)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))

            Text(caption)
                .font(.callout).foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var caption: String {
        switch model.mode {
        case .edit: "Scegli cosa fa ogni tasto e la manopola, pagina per pagina. Poi premi Invia al macropad."
        case .test: simulating
            ? "Macropad non collegato: stai usando la simulazione, con il mouse e la tastiera del Mac."
            : "Premi i tasti sul macropad: l'app controlla che ognuno risponda."
        }
    }

    private func tab(_ m: AppMode, _ title: String, _ icon: String, _ key: String) -> some View {
        let on = model.mode == m
        return Button {
            withAnimation(.snappy(duration: 0.22)) { model.mode = m }
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(on ? Color.capInk : Color.primary.opacity(0.75))
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background {
                    if on {
                        Capsule().fill(Color.orange)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                            .matchedGeometryEffect(id: "pill", in: pill)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("\(title) (\(key))")
    }
}

// Quale pagina stai guardando, con le frecce per passare alle altre
struct PageSwitcher: View {
    @EnvironmentObject var model: AppModel
    let locked: Bool                        // in prova col macropad la pagina è quella del macropad

    var body: some View {
        let n = model.config.pages.count
        HStack(spacing: 14) {
            arrow("chevron.left", "Pagina precedente (⌥⌘↑)") { model.pageIndex = (model.pageIndex + n - 1) % n }
            VStack(spacing: 1) {
                Text(model.page.name.isEmpty ? "senza nome" : model.page.name)
                    .font(.system(size: 15, weight: .semibold))
                Text(locked ? "Pagina \(model.pageIndex + 1) di \(n) · quella attiva sul macropad" : "Pagina \(model.pageIndex + 1) di \(n)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(minWidth: 150)
            arrow("chevron.right", "Pagina successiva (⌥⌘↓)") { model.pageIndex = (model.pageIndex + 1) % n }
        }
    }

    private func arrow(_ icon: String, _ help: String, _ go: @escaping () -> Void) -> some View {
        Button(action: go) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.primary.opacity(0.08)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(locked || model.config.pages.count < 2 ? 0.3 : 1)
        .disabled(locked || model.config.pages.count < 2)
        .help(help)
    }
}

// Piano dietro al macropad: una luce morbida, così il guscio nero si stacca dallo sfondo
struct Stage: View {
    var body: some View {
        ZStack {
            Color(red: 0.135, green: 0.138, blue: 0.150)
            // piano della stampante: una griglia di punti come sul piatto di stampa
            Canvas { ctx, size in
                let step = 22.0
                for x in stride(from: step / 2, to: size.width, by: step) {
                    for y in stride(from: step / 2, to: size.height, by: step) {
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8)),
                                 with: .color(.white.opacity(0.045)))
                    }
                }
            }
            RadialGradient(colors: [Color.white.opacity(0.07), .clear],
                           center: .init(x: 0.5, y: 0.45), startRadius: 20, endRadius: 520)
            RadialGradient(colors: [.clear, Color.black.opacity(0.35)],
                           center: .center, startRadius: 300, endRadius: 900)
        }
    }
}

struct PagesSidebar: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var link: MacropadLink

    var body: some View {
        List {
            Section {
                ForEach(Array(model.config.pages.enumerated()), id: \.element.id) { i, p in
                    PageRow(index: i, page: p, selected: i == model.pageIndex,
                            onDevice: link.isConnected && link.status?.page == i)
                        .contentShape(Rectangle())
                        .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { model.pageIndex = i } }
                        .listRowInsets(EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6))
                        .listRowSeparator(.hidden)
                        .contextMenu {
                            Button("Sposta su") { model.movePage(i, by: -1) }.disabled(i == 0)
                            Button("Sposta giù") { model.movePage(i, by: 1) }.disabled(i == model.config.pages.count - 1)
                            Button("Metti per prima") { model.movePageToTop(i) }.disabled(i == 0)
                            Divider()
                            Button("Duplica") { model.duplicatePage(i) }.disabled(model.config.pages.count >= MacropadConfig.maxPages)
                            Button("Elimina", role: .destructive) { model.deletePage(i) }.disabled(model.config.pages.count <= 1)
                        }
                }
                .onMove { model.movePages(from: $0, to: $1) }
            } header: {
                HStack {
                    Eyebrow("Pagine")
                    Spacer()
                    Text("\(model.config.pages.count)/\(MacropadConfig.maxPages)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                }
                .padding(.bottom, 4)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button { model.addPage() } label: {
                        Label("Nuova pagina", systemImage: "plus")
                            .font(.callout.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.config.pages.count >= MacropadConfig.maxPages)
                    .help("Aggiungi una pagina (al massimo \(MacropadConfig.maxPages))")
                    Button { model.movePage(model.pageIndex, by: -1) } label: { Image(systemName: "arrow.up") }
                        .buttonStyle(.bordered)
                        .disabled(model.pageIndex == 0)
                        .help("Sposta su la pagina selezionata")
                    Button { model.movePage(model.pageIndex, by: 1) } label: { Image(systemName: "arrow.down") }
                        .buttonStyle(.bordered)
                        .disabled(model.pageIndex >= model.config.pages.count - 1)
                        .help("Sposta giù la pagina selezionata")
                    Button { model.deletePage(model.pageIndex) } label: { Image(systemName: "trash") }
                        .buttonStyle(.bordered)
                        .disabled(model.config.pages.count <= 1)
                        .help("Elimina la pagina selezionata")
                }
                Label("Sul macropad passi alla pagina dopo premendo la manopola. Per cambiare l'ordine usa le frecce ↑ ↓ o trascina le pagine, poi premi Invia.", systemImage: "hand.tap")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Theme.sidebar)
        }
    }
}

// Una pagina nell'elenco: il macropad in miniatura con i suoi tasti
struct PageRow: View {
    let index: Int
    let page: Page
    let selected: Bool
    let onDevice: Bool

    var body: some View {
        HStack(spacing: 10) {
            mini
            VStack(alignment: .leading, spacing: 3) {
                Text(page.name.isEmpty ? "senza nome" : page.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(page.name.isEmpty ? .secondary : .primary)
                Text(page.knobLabel.isEmpty ? "manopola libera" : "↻ \(page.knobLabel)")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
                if onDevice {
                    Label("sul macropad", systemImage: "dot.radiowaves.left.and.right")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(Color.testOK)
                }
            }
            Spacer(minLength: 0)
            Text("\(index + 1)")
                .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(selected ? Color.capInk : .secondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(selected ? Color.orange : Color.white.opacity(0.07)))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? Color.orange.opacity(0.13) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(selected ? Color.orange.opacity(0.65) : Color.clear, lineWidth: 1))
    }

    // guscio nero, display e 9 tasti arancioni (spenti quelli senza funzione)
    private var mini: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 1).fill(Color.oledInk.opacity(0.55)).frame(width: 11, height: 4.5)
                Spacer(minLength: 0)
                Circle().fill(Color.orange).frame(width: 6, height: 6)
            }
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { c in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(page.keys[r * 3 + c].kind == .none ? Color.orange.opacity(0.25) : Color.orange)
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.caseLow))
        .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
    }
}

struct StatusBar: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var link: MacropadLink

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 7) {
                Circle().fill(dotColor).frame(width: 8, height: 8)
                    .shadow(color: dotColor.opacity(0.9), radius: 3)
                    .symbolEffect(.pulse, isActive: link.state == .searching)
                Text(stateText).lineLimit(1)
            }
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill(Color.white.opacity(0.05)))
            if link.isConnected, let s = link.status {
                Label(s.usb ? "USB" : "\(s.bat)%", systemImage: s.usb ? "powerplug" : batteryIcon(s.bat))
                Text("Sul macropad: pagina \(s.page + 1) · \(s.mac ? "Mac" : "Windows")")
                Text("firmware \(s.fw)").foregroundStyle(.tertiary)
            }
            if case .failed = link.state {
                Button("Riprova") { link.reconnect() }.controlSize(.small)
            }
            Spacer()
            if let busy = link.busy {
                ProgressView().controlSize(.small)
                Text(busy)
            } else if model.hasUnsentChanges {
                Label("Modifiche non inviate", systemImage: "circle.fill")
                    .foregroundStyle(.orange)
                    .labelStyle(.titleAndIcon)
                    .imageScale(.small)
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Theme.sidebar)
        .overlay(alignment: .top) { Divider() }
    }

    private var dotColor: Color {
        switch link.state {
        case .connected: .green
        case .connecting, .searching: .orange
        case .bluetoothOff, .failed: .red
        }
    }

    private var stateText: String {
        switch link.state {
        case .connected: "Macropad collegato"
        case .connecting: "Collegamento in corso…"
        case .searching: "Cerco il macropad… (deve essere acceso e abbinato al Mac)"
        case .bluetoothOff: "Bluetooth spento"
        case .failed(let m): m
        }
    }

    private func batteryIcon(_ p: Int) -> String {
        p > 80 ? "battery.100" : p > 55 ? "battery.75" : p > 30 ? "battery.50" : p > 10 ? "battery.25" : "battery.0"
    }
}
