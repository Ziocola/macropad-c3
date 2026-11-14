import SwiftUI

// Collegamenti della matrice (firmware/src/config.h): fila r -> riga Rr, colonna c -> colonna Cc
enum Wiring {
    static let rowGPIO = [5, 6, 7]
    static let colGPIO = [10, 20, 21]
    static func row(_ i: Int) -> Int { i / 3 }
    static func col(_ i: Int) -> Int { i % 3 }
}

// ---------- Stato della prova ----------

final class TestSession: ObservableObject {
    struct Entry: Identifiable {
        let id = UUID()
        let time: Date
        let icon: String
        var text: String
        let detail: String
        var knobDir = 0
        var knobCount = 0
    }

    @Published var mode = 1                          // 1 = niente al computer, 2 = esegue anche le funzioni
    @Published private(set) var tested: Set<Int> = []
    @Published private(set) var presses = Array(repeating: 0, count: 9)
    @Published private(set) var cw = 0
    @Published private(set) var ccw = 0
    @Published private(set) var clicks = 0
    @Published private(set) var maxTogether = 0
    @Published private(set) var log: [Entry] = []
    @Published private(set) var simulated = false     // eventi finti, dall'app e non dal macropad
    private var down: Set<Int> = []

    static let together = 3
    var knobComplete: Bool { cw > 0 && ccw > 0 && clicks > 0 }
    var total: Int { 9 + 3 + 1 }
    var done: Int { tested.count + (cw > 0 ? 1 : 0) + (ccw > 0 ? 1 : 0) + (clicks > 0 ? 1 : 0) + (maxTogether >= Self.together ? 1 : 0) }
    var started: Bool { !log.isEmpty }

    func reset() {
        tested = []; presses = Array(repeating: 0, count: 9); cw = 0; ccw = 0; clicks = 0
        maxTogether = 0; log = []; down = []
    }

    func handle(_ e: DeviceEvent, page: Page?, isMac: Bool, simulated sim: Bool) {
        if started && sim != simulated { reset() }       // non mischiare prove finte e vere
        simulated = sim
        let now = Date()
        switch e {
        case .key(let i, let isDown):
            if isDown {
                down.insert(i)
                presses[i] += 1
                maxTogether = max(maxTogether, down.count)
                add(Entry(time: now, icon: "keyboard", text: "Tasto \(i + 1) premuto",
                          detail: describe(page?.keys[i], isMac: isMac)))
            } else {
                down.remove(i)
                tested.insert(i)
            }
        case .knob(let dir):
            if dir > 0 { cw += 1 } else { ccw += 1 }
            // gli scatti di fila nello stesso verso diventano una riga sola
            if var last = log.first, last.knobDir == dir, now.timeIntervalSince(last.time) < 1.5 {
                last.knobCount += 1
                last.text = knobText(dir, last.knobCount)
                log[0] = Entry(time: now, icon: last.icon, text: last.text, detail: last.detail, knobDir: dir, knobCount: last.knobCount)
            } else {
                let act = dir > 0 ? page?.cw : page?.ccw
                add(Entry(time: now, icon: dir > 0 ? "arrow.clockwise" : "arrow.counterclockwise", text: knobText(dir, 1),
                          detail: describe(act, isMac: isMac), knobDir: dir, knobCount: 1))
            }
        case .button(let isDown):
            if isDown {
                clicks += 1
                add(Entry(time: now, icon: "smallcircle.filled.circle", text: "Pulsante della manopola premuto",
                          detail: mode == 1 ? "in prova non cambia pagina" : ""))
            }
        case .page(let p):
            add(Entry(time: now, icon: "rectangle.stack", text: "Pagina \(p + 1) sul macropad", detail: ""))
        }
    }

    private func knobText(_ dir: Int, _ n: Int) -> String {
        "Manopola: \(n) \(n == 1 ? "scatto" : "scatti") in senso \(dir > 0 ? "orario" : "antiorario")"
    }

    func actionText(_ a: Action?, isMac: Bool) -> String {
        guard let a else { return "" }
        let what: String
        switch a.kind {
        case .key: what = comboText(isMac ? a.mac : a.win, isMac ? .mac : .win)
        case .media: what = Media.name(a.u ?? 0)
        case .wheel: what = "rotella \((a.u ?? 0) > 0 ? "su" : "giù")"
        case .none: return "nessuna funzione"
        }
        return a.label.isEmpty ? what : "\(a.label) · \(what)"
    }

    private func describe(_ a: Action?, isMac: Bool) -> String {
        guard let a else { return "" }
        if a.kind == .none { return "nessuna funzione" }
        let name = actionText(a, isMac: isMac)
        return simulated ? "\(name) — simulato" : mode == 1 ? "\(name) — non inviato" : "\(name) — inviato al computer"
    }

    private func add(_ e: Entry) {
        log.insert(e, at: 0)
        if log.count > 200 { log.removeLast() }
    }

    // file o colonne che non hanno mai risposto mentre le altre sì: quasi sempre un filo
    var deadRows: [Int] {
        (0..<3).filter { r in
            !(0..<3).contains { tested.contains(r * 3 + $0) } &&
            (0..<3).filter { $0 != r }.allSatisfy { o in (0..<3).contains { tested.contains(o * 3 + $0) } }
        }
    }
    var deadCols: [Int] {
        (0..<3).filter { c in
            !(0..<3).contains { tested.contains($0 * 3 + c) } &&
            (0..<3).filter { $0 != c }.allSatisfy { o in (0..<3).contains { tested.contains($0 * 3 + o) } }
        }
    }
}

// ---------- Pannello della prova ----------

struct TestPanel: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var link: MacropadLink
    @ObservedObject var test: TestSession

    // senza macropad la prova va lo stesso: l'app fa finta di essere il macropad
    private var sim: Bool { !link.isConnected }

    var body: some View {
        ScrollView {
          VStack(spacing: 14) {
            if sim { simSection } else { modeSection }
            progress
            keysSection
            knobSection
            if !sim { batterySection }
            if case .key(let i) = model.selection { keyDetail(i) }
            logSection
            if sim { connectSection }
          }
          .padding(16)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.panel)
    }

    // ---------- simulazione ----------

    @ViewBuilder private var simSection: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Simulazione", systemImage: "cursorarrow.click.2")
                    .font(.headline).foregroundStyle(.orange)
                Text("Il macropad non è collegato, ma puoi provare lo stesso: l'app fa finta di essere il macropad e ti mostra cosa farebbe ogni tasto nella pagina scelta.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 7) {
                    hintRow("premi un tasto (tienine giù tre per la prova dei diodi)") { keyHint("1"); Text("…"); keyHint("9") }
                    hintRow("gira la manopola") { keyHint("←"); keyHint("→") }
                    hintRow("premi la manopola") { keyHint("spazio") }
                    hintRow("oppure clicca i tasti del disegno e trascina la manopola in tondo") {
                        Image(systemName: "computermouse").foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
                Text("Quando colleghi il macropad, la prova riparte da zero con i tasti veri.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Vuoi che succeda davvero qualcosa sul Mac?", systemImage: "sparkles")
                    .font(.headline)
                Text("Qui i tasti vengono solo contati. Il macropad virtuale invece esegue le funzioni: musica e volume, Copia e Incolla, Annulla, zoom… nell'app che stai usando, come il macropad vero.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button { model.showPad() } label: {
                    Label("Apri il macropad virtuale", systemImage: "square.grid.3x3.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.vertical, 2)
        }
    }

    private func hintRow<K: View>(_ text: String, @ViewBuilder keys: () -> K) -> some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 4) { keys() }.frame(width: 84, alignment: .leading)
            Text(text).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func keyHint(_ k: String) -> some View {
        Text(k)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, k.count > 1 ? 6 : 0)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.primary.opacity(0.18)))
    }

    private var connectSection: some View {
        Card("Per provare il macropad vero", icon: "antenna.radiowaves.left.and.right") {
            VStack(alignment: .leading, spacing: 4) {
                Text("1. Carica il firmware 1.1 con Carica_firmware.command (una volta sola).")
                Text("2. Accendi il macropad con l'interruttore.")
                Text("3. La prima volta: Impostazioni di Sistema → Bluetooth → \"Macropad C3\" → Collega.")
                Text("4. Quando in basso compare \"Macropad collegato\", la prova usa i tasti veri.")
            }
            .font(.callout).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // ---------- avanzamento ----------

    private var progress: some View {
        let complete = test.done == test.total
        let color = complete ? Color.testOK : Color.orange
        return Card {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 6)
                    Circle().trim(from: 0, to: Double(test.done) / Double(test.total))
                        .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: color.opacity(0.5), radius: 4)
                    if complete {
                        Image(systemName: "checkmark").font(.system(size: 20, weight: .bold)).foregroundStyle(color)
                    } else {
                        VStack(spacing: -2) {
                            Text("\(test.done)").font(.system(size: 19, weight: .bold, design: .rounded).monospacedDigit())
                            Text("di \(test.total)").font(.system(size: 9.5, weight: .medium)).foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 62, height: 62)
                .animation(.easeOut(duration: 0.25), value: test.done)

                VStack(alignment: .leading, spacing: 4) {
                    Text(complete ? (sim ? "Simulazione completata" : "Tutto funziona") : "Controlli superati")
                        .font(.headline)
                        .foregroundStyle(complete ? Color.testOK : .primary)
                    Text(sim
                         ? (complete
                            ? "Hai visto come funziona: ripetila col macropad vero, è lì che si controllano saldature e diodi."
                            : "Premi ogni tasto, gira la manopola nei due versi e premila: ogni controllo prende la spunta verde.")
                         : complete
                         ? "Tasti, manopola e diodi rispondono come devono."
                         : "Premi ogni tasto, gira la manopola nei due versi e premila. Sul display del macropad compare PROVA.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { withAnimation { test.reset() } } label: { Label("Ricomincia", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(.bordered).controlSize(.small)
                        .disabled(!test.started)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var modeSection: some View {
        Card {
            Toggle(isOn: Binding(get: { test.mode == 2 }, set: { test.mode = $0 ? 2 : 1 })) {
                Text("Esegui anche le funzioni sul computer").frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            Text(test.mode == 2
                 ? "I tasti fanno davvero quello che hai impostato, sull'app in primo piano: attento a scorciatoie come Chiudi o Esci."
                 : "I tasti non mandano niente al computer: puoi premere di tutto senza conseguenze.")
                .font(.caption).foregroundStyle(test.mode == 2 ? Color.orange : .secondary)
            if model.hasUnsentChanges {
                Label("Hai modifiche non inviate: il macropad usa ancora le funzioni di prima.", systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
    }

    // ---------- tasti ----------

    private var keysSection: some View {
        Card("Tasti", icon: "keyboard") {
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(0..<3, id: \.self) { r in
                    GridRow {
                        ForEach(0..<3, id: \.self) { c in keyChip(r * 3 + c) }
                    }
                }
            }
            .padding(.vertical, 4)
            check(test.maxTogether >= TestSession.together,
                  "Tre tasti insieme",
                  test.maxTogether >= TestSession.together
                    ? "Si illuminano solo i tasti premuti: i diodi sono a posto."
                    : sim ? "Tieni premuti insieme 1, 2 e 4 sulla tastiera del Mac."
                    : "Tieni premuti 3 tasti a L (per esempio 1, 2 e 4): deve illuminarsi solo quelli. Se se ne accende anche un quarto, manca un diodo o è in corto.")
            if !sim { wiringWarnings }
        }
    }

    @ViewBuilder private var wiringWarnings: some View {
        ForEach(test.deadRows, id: \.self) { r in
            warning("Nessun tasto della fila \(r + 1) ha risposto",
                    "Se li hai già premuti, controlla il filo della riga R\(r) (GPIO \(Wiring.rowGPIO[r])): collega i tre diodi di quella fila al SuperMini.")
        }
        ForEach(test.deadCols, id: \.self) { c in
            warning("Nessun tasto della colonna \(c + 1) ha risposto",
                    "Se li hai già premuti, controlla il filo della colonna C\(c) (GPIO \(Wiring.colGPIO[c])): collega i tre switch di quella colonna al SuperMini.")
        }
    }

    private func keyChip(_ i: Int) -> some View {
        let ok = test.tested.contains(i)
        let down = link.pressed.contains(i)
        return Button { model.selection = .key(i) } label: {
            HStack(spacing: 6) {
                Image(systemName: ok ? "checkmark.circle.fill" : "circle.dotted")
                    .foregroundStyle(ok ? Color.testOK : .secondary)
                Text("\(i + 1)").font(.body.weight(.semibold).monospacedDigit())
                Spacer(minLength: 0)
                if test.presses[i] > 0 {
                    Text("×\(test.presses[i])").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 7).fill(down ? Color.orange.opacity(0.35) : Color.primary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .strokeBorder(model.selection == .key(i) ? Color.orange : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func keyDetail(_ i: Int) -> some View {
        let r = Wiring.row(i), c = Wiring.col(i)
        return Card("Tasto \(i + 1)", icon: "cable.connector") {
            LabeledContent("In questa pagina", value: test.actionText(model.page.keys[i], isMac: link.status?.mac ?? true))
            LabeledContent("Riga", value: "R\(r) · GPIO \(Wiring.rowGPIO[r])")
            LabeledContent("Colonna", value: "C\(c) · GPIO \(Wiring.colGPIO[c])")
            LabeledContent("Pressioni", value: "\(test.presses[i])")
            if !sim && !test.tested.contains(i) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Se premendolo non succede niente:").font(.callout.weight(.medium))
                    Text("1. Il diodo: la banda nera va verso la riga.\n2. Le saldature sui due piedini dello switch e sul diodo.\n3. Lo switch deve essere inserito fino allo scatto.\n4. Se non funziona tutta la fila o tutta la colonna, è il filo comune.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    // ---------- manopola ----------

    private var knobSection: some View {
        Card("Manopola", icon: "dial.medium") {
            check(test.cw > 0, "Senso orario", test.cw > 0 ? count(test.cw, "scatto", "scatti") : sim ? "Premi → sulla tastiera" : "Girala verso destra")
            check(test.ccw > 0, "Senso antiorario", test.ccw > 0 ? count(test.ccw, "scatto", "scatti") : sim ? "Premi ← sulla tastiera" : "Girala verso sinistra")
            check(test.clicks > 0, "Pulsante", test.clicks > 0 ? count(test.clicks, "pressione", "pressioni") : sim ? "Premi la barra spaziatrice" : "Premila")
            if !sim { knobFixes }
        }
    }

    @ViewBuilder private var knobFixes: some View {
        Text("Ogni scatto deve contare 1, e girando verso destra deve aumentare \"Senso orario\". Se non è così:")
            .font(.caption).foregroundStyle(.secondary)
        HStack {
            Button("Inverti il verso") {
                model.config.set.rev.toggle()
                model.send()
                test.reset()
            }
            .help("Scambia orario e antiorario e lo invia subito al macropad")
            Button("Impulsi per scatto…") { model.showSettings = true }
                .help("Se conta 2 per ogni scatto, o 1 ogni due scatti")
            Spacer()
        }
        .controlSize(.small)
    }

    // ---------- batteria ----------

    private var batterySection: some View {
        Card("Alimentazione", icon: "battery.75") {
            if let s = link.status {
                if s.usb {
                    LabeledContent("Batteria", value: "non letta")
                    Text("L'interruttore è spento: il macropad va col cavo USB. Accendilo per leggere la batteria.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    LabeledContent("Batteria") {
                        Text(s.mv.map { "\((Double($0) / 1000).formatted(.number.precision(.fractionLength(2)))) V · \(s.bat)%" } ?? "\(s.bat)%")
                            .monospacedDigit()
                    }
                    if let mv = s.mv, mv < 3300 || mv > 4300 {
                        warning("Tensione strana",
                                "Una LiPo carica sta fra 3,3 e 4,2 V. Controlla il partitore da 100 kΩ + 100 kΩ verso GPIO 0.")
                    }
                }
            }
        }
    }

    // ---------- registro ----------

    private var logSection: some View {
        Card("Cosa è successo", icon: "list.bullet.rectangle") {
            if test.log.isEmpty {
                Text(sim ? "Ancora niente: premi 1 sulla tastiera o clicca un tasto del disegno." : "Ancora niente: premi un tasto sul macropad.")
                    .foregroundStyle(.secondary)
            }
            ForEach(test.log.prefix(60)) { e in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: e.icon).foregroundStyle(.orange).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(e.text)
                        if !e.detail.isEmpty { Text(e.detail).font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer()
                    Text(e.time, format: .dateTime.hour().minute().second())
                        .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                }
            }
        }
    }

    // ---------- pezzi comuni ----------

    private func count(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }

    private func check(_ ok: Bool, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundStyle(ok ? Color.testOK : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func warning(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
