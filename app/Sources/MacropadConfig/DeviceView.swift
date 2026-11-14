import SwiftUI

// Il macropad visto da sopra, in millimetri come nel modello OpenSCAD (case/macropad_cablato.scad)
enum Geo {
    static let W = 72.0, D = 105.0, corner = 9.0
    static let pitch = 19.05, keyX0 = W / 2 - 19.05, keyY0 = 13.0, cap = 17.0
    static let knob = CGPoint(x: 57, y: 84), knobD = 17.0
    static let window = CGRect(x: 26 - 11.4, y: 85.5 - 6.2, width: 22.8, height: 12.4)   // area visibile del display

    // tasto n: fila 0 = quella vicina al display, colonna 0 = sinistra
    static func keyCenter(_ i: Int) -> CGPoint {
        CGPoint(x: keyX0 + Double(i % 3) * pitch, y: keyY0 + Double(2 - i / 3) * pitch)
    }
}

// Colori del macropad stampato: guscio nero, tasti e manopola arancioni
extension Color {
    static let caseTop    = Color(red: 0.155, green: 0.158, blue: 0.170)
    static let caseLow    = Color(red: 0.095, green: 0.097, blue: 0.105)
    static let orange     = Color(red: 0.965, green: 0.478, blue: 0.122)
    static let orangeHi   = Color(red: 1.000, green: 0.600, blue: 0.260)
    static let orangeLow  = Color(red: 0.820, green: 0.370, blue: 0.070)
    static let capInk     = Color(red: 0.140, green: 0.075, blue: 0.030)
    static let oledInk    = Color(red: 0.80, green: 0.90, blue: 1.0)
    static let testOK     = Color(red: 0.20, green: 0.78, blue: 0.42)
}

struct DeviceView: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject var link: MacropadLink
    @ObservedObject var test: TestSession
    let testing: Bool
    var simulating = false                          // prova senza macropad: tasti e manopola si usano col mouse
    var virtual = false                             // macropad virtuale: i tasti eseguono le funzioni sul Mac
    @ObservedObject var pad: VirtualPad
    @State private var knobAngle = 0.0
    @State private var dragAngle: Double?           // trascinamento della manopola in simulazione
    @State private var dragTurn = 0.0
    @State private var dragged = false
    @State private var mouseKey: Int?               // tasto tenuto giù col mouse in simulazione

    var body: some View {
        GeometryReader { geo in
            let s = min((geo.size.width - 48) / Geo.W, (geo.size.height - 48) / Geo.D)
            let origin = CGPoint(x: (geo.size.width - Geo.W * s) / 2, y: (geo.size.height - Geo.D * s) / 2)
            // da millimetri (y verso il retro) a punti sullo schermo
            let pt = { (p: CGPoint) in CGPoint(x: origin.x + p.x * s, y: origin.y + (Geo.D - p.y) * s) }

            ZStack(alignment: .topLeading) {
                caseShape(s)
                    .frame(width: Geo.W * s, height: Geo.D * s)
                    .position(x: origin.x + Geo.W * s / 2, y: origin.y + Geo.D * s / 2)

                let w = Geo.window
                OledView(page: model.page, pageIndex: model.pageIndex, pageCount: model.config.pages.count,
                         isMac: link.status?.mac ?? true, battery: link.status?.bat, usb: link.status?.usb ?? false,
                         pressed: pressedKeys, testMode: testing ? (simulating ? 3 : test.mode) : 0)
                    .frame(width: w.width * s, height: w.height * s)
                    .padding(1.4 * s)
                    .background(
                        RoundedRectangle(cornerRadius: 1.4 * s)
                            .fill(Color.black)
                            .overlay(RoundedRectangle(cornerRadius: 1.4 * s)
                                .fill(LinearGradient(colors: [.white.opacity(0.07), .clear], startPoint: .topLeading, endPoint: .center)))
                            .overlay(RoundedRectangle(cornerRadius: 1.4 * s).strokeBorder(Color.white.opacity(0.10), lineWidth: 1)))
                    .position(pt(CGPoint(x: w.midX, y: w.midY)))

                knob(s, center: pt(Geo.knob))
                    .position(pt(Geo.knob))

                if interactive {
                    turnButton(-1, s).position(pt(CGPoint(x: Geo.knob.x - 6.5, y: 67.5)))
                    turnButton(1, s).position(pt(CGPoint(x: Geo.knob.x + 6.5, y: 67.5)))
                }

                ForEach(0..<9, id: \.self) { i in
                    keycap(i, s)
                        .position(pt(Geo.keyCenter(i)))
                }
            }
            .coordinateSpace(name: "device")
        }
        .onChange(of: link.knobTurn.count) {
            if !virtual { withAnimation(.easeOut(duration: 0.15)) { knobAngle += Double(link.knobTurn.dir) * 18 } }
        }
        .onChange(of: pad.turn.count) {
            if virtual { withAnimation(.easeOut(duration: 0.15)) { knobAngle += Double(pad.turn.dir) * 18 } }
        }
    }

    // ---------- da dove arrivano le pressioni ----------

    private var interactive: Bool { simulating || virtual }
    private var pressedKeys: Set<Int> { virtual ? pad.pressed : link.pressed }
    private var knobDown: Bool { virtual ? pad.buttonDown : link.buttonDown }

    private func press(_ i: Int, _ down: Bool) {
        if virtual { model.padKey(i, down: down) } else { model.simKey(i, down: down) }
    }
    private func turn(_ dir: Int) { if virtual { model.padTurn(dir) } else { model.simTurn(dir) } }
    private func click() { if virtual { model.padClick() } else { model.simClick() } }

    // guscio nero opaco, con il bordo appena illuminato
    private func caseShape(_ s: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: Geo.corner * s, style: .continuous)
        return shape
            .fill(LinearGradient(colors: [.caseTop, .caseLow], startPoint: .top, endPoint: .bottom))
            .overlay(shape.fill(RadialGradient(colors: [.white.opacity(0.05), .clear], center: .init(x: 0.3, y: 0.1),
                                               startRadius: 0, endRadius: 60 * s)))
            .background(Ellipse().fill(Color.black.opacity(0.45)).blur(radius: 18)
                .frame(width: Geo.W * s * 1.05, height: 16 * s).offset(y: Geo.D * s / 2 + 2 * s))
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.22), .white.opacity(0.04)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 1.2))
            .overlay(shape.inset(by: 1.2 * s).strokeBorder(Color.black.opacity(0.35), lineWidth: 0.6 * s))
            .shadow(color: .black.opacity(0.45), radius: 22, y: 14)
    }

    private func keycap(_ i: Int, _ s: Double) -> some View {
        let a = model.page.keys[i]
        let selected = !virtual && model.selection == .key(i)
        let down = pressedKeys.contains(i)
        let shape = RoundedRectangle(cornerRadius: 2 * s, style: .continuous)
        let top = RoundedRectangle(cornerRadius: 1.6 * s, style: .continuous)
        let face = ZStack {
            // fianco del tasto, più scuro, che si vede sotto la superficie
            shape.fill(LinearGradient(colors: [.orange, .orangeLow, Color(red: 0.62, green: 0.27, blue: 0.05)],
                                      startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(down ? 0.25 : 0.6), radius: down ? 1 : 3.5, y: down ? 0.6 : 2.8)
            // superficie leggermente concava
            top.fill(LinearGradient(colors: down ? [.orange, .orangeLow] : [.orangeHi, .orange],
                                    startPoint: .top, endPoint: .bottom))
                .overlay(top.fill(RadialGradient(colors: [.white.opacity(down ? 0.04 : 0.16), .clear],
                                                 center: .init(x: 0.5, y: 0.25), startRadius: 0, endRadius: 9 * s)))
                .overlay(top.strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.0)],
                                                         startPoint: .top, endPoint: .bottom), lineWidth: 0.8))
                .padding(.horizontal, 1.3 * s)
                .padding(.top, 0.9 * s)
                .padding(.bottom, (down ? 1.6 : 2.4) * s)
            if testing {
                VStack(spacing: 0.3 * s) {
                    Text("\(i + 1)").font(.system(size: 4.6 * s, weight: .bold, design: .rounded))
                    Text("R\(i / 3) · C\(i % 3)").font(.system(size: 2.2 * s, weight: .medium, design: .monospaced))
                        .opacity(0.6)
                }
            } else {
                VStack(spacing: 0.5 * s) {
                    if let sym = a.symbol {
                        Image(systemName: sym)
                            .font(.system(size: 3.6 * s, weight: .semibold))
                            .frame(height: 4.2 * s)
                    }
                    Text(a.label.isEmpty ? (a.kind == .none ? "—" : " ") : a.label)
                        .font(.system(size: (a.symbol == nil ? 3.4 : 2.9) * s, weight: .bold))
                        .opacity(a.kind == .none ? 0.4 : 1)
                    if a.symbol == nil, summary(a) != a.label, !summary(a).isEmpty {
                        Text(summary(a))
                            .font(.system(size: 2.2 * s, weight: .medium))
                            .opacity(0.6)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, 1.8 * s)
                .offset(y: (down ? -0.4 : -0.8) * s)
            }
        }
        .foregroundStyle(Color.capInk)
        .frame(width: Geo.cap * s, height: Geo.cap * s)
        .overlay(alignment: .topTrailing) {
            if testing && test.tested.contains(i) { okBadge(s).offset(x: 1.4 * s, y: -1.4 * s) }
        }
        .overlay(shape.strokeBorder(Color.white, lineWidth: selected ? 2.5 : 0).padding(-3.5))
        .scaleEffect(down ? 0.97 : 1)
        .offset(y: down ? 0.5 * s : 0)
        .animation(.easeOut(duration: 0.08), value: down)
        .contentShape(Rectangle())
        return Group {
            if interactive {
                // tenuto premuto col mouse come un tasto vero
                face.gesture(DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if mouseKey != i { mouseKey = i; select(.key(i)); press(i, true) }
                    }
                    .onEnded { _ in
                        if mouseKey == i {
                            press(i, false)
                        } else {                    // clic senza movimento: premuto e rilasciato
                            select(.key(i))
                            press(i, true)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { press(i, false) }
                        }
                        mouseKey = nil
                    })
            } else {
                Button { model.selection = .key(i) } label: { face }.buttonStyle(.plain)
            }
        }
        .help(virtual ? "\(a.label.isEmpty ? "Tasto \(i + 1)" : a.label): clicca per eseguirlo nell'app in uso"
              : simulating ? "Tasto \(i + 1): clicca per premerlo, oppure premi \(i + 1) sulla tastiera"
              : testing ? "Tasto \(i + 1): riga R\(i / 3), colonna C\(i % 3)" : "Tasto \(i + 1): fila \(i / 3 + 1), colonna \(i % 3 + 1)")
    }

    private func knob(_ s: Double, center: CGPoint) -> some View {
        let d = Geo.knobD * s
        let selected = !virtual && model.selection == .knob
        let down = knobDown
        let face = ZStack {
            // bordo zigrinato
            Circle().fill(LinearGradient(colors: [.orange, .orangeLow], startPoint: .top, endPoint: .bottom))
            Circle().inset(by: 0.8 * s)
                .stroke(Color.black.opacity(0.24),
                        style: StrokeStyle(lineWidth: 1.5 * s, dash: [0.4 * s, Double.pi * (d - 1.6 * s) / 40 - 0.4 * s],
                                           dashPhase: knobAngle / 360 * Double.pi * (d - 1.6 * s)))
            // faccia superiore, staccata dal bordo da un'ombra sottile
            Circle().inset(by: 1.45 * s).fill(Color.black.opacity(0.28))
            Circle().inset(by: 1.7 * s)
                .fill(RadialGradient(colors: down ? [.orange, .orangeLow] : [.orangeHi, .orange, .orangeLow],
                                     center: .init(x: 0.4, y: 0.3), startRadius: 0, endRadius: d * 0.55))
            Circle().inset(by: 1.7 * s).strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                                                    startPoint: .top, endPoint: .center), lineWidth: 0.8)
            Capsule().fill(Color.capInk.opacity(0.85))
                .frame(width: 0.9 * s, height: 3.0 * s)
                .offset(y: -d / 2 + 3.6 * s)
                .rotationEffect(.degrees(knobAngle))
            Text(testing ? "\(test.cw) ↻   \(test.ccw) ↺" : model.page.knobLabel)
                .font(.system(size: 2.6 * s, weight: .bold, design: testing ? .monospaced : .default))
                .foregroundStyle(Color.capInk.opacity(0.8))
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: d * 0.7)
                .offset(y: 2.2 * s)
        }
        .frame(width: d, height: d)
        .scaleEffect(down ? 0.95 : 1)
        .animation(.easeOut(duration: 0.08), value: down)
        .background(Circle().fill(Color.black.opacity(0.55)).blur(radius: 4).offset(y: 3.5))
        .overlay(Circle().strokeBorder(Color.white, lineWidth: selected ? 2.5 : 0).padding(-3.5))
        .overlay(alignment: .topTrailing) {
            if testing && test.knobComplete { okBadge(s).offset(x: 0.6 * s, y: -0.6 * s) }
        }
        .contentShape(Circle())
        return Group {
            if interactive {
                face.gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("device"))
                    .onChanged { dragKnob($0, center: center, d) }.onEnded { _ in
                    if !dragged { select(.knob); click() }
                    dragged = false; dragAngle = nil; dragTurn = 0
                })
            } else {
                Button { model.selection = .knob } label: { face }.buttonStyle(.plain)
            }
        }
        .help(virtual ? "Manopola: trascinala in tondo per girarla, cliccala per passare alla pagina dopo"
              : simulating ? "Manopola: trascinala in tondo per girarla, cliccala per premerla"
              : testing ? "Manopola: girala nei due versi e premila" : "Manopola: girarla fa la funzione della pagina, premerla cambia pagina")
    }

    // trascinando in tondo: ogni 18° uno scatto, come l'encoder vero (20 scatti al giro)
    private func dragKnob(_ v: DragGesture.Value, center: CGPoint, _ d: Double) {
        if hypot(v.translation.width, v.translation.height) > 3 { dragged = true }
        let dx = v.location.x - center.x, dy = v.location.y - center.y
        guard dragged, hypot(dx, dy) > d * 0.12 else { return }
        let a = atan2(dy, dx) * 180 / .pi            // y verso il basso: l'angolo cresce in senso orario
        if let last = dragAngle {
            var delta = a - last
            if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
            dragTurn += delta
            while dragTurn >= 18 { turn(1); dragTurn -= 18 }
            while dragTurn <= -18 { turn(-1); dragTurn += 18 }
        }
        dragAngle = a
    }

    private func turnButton(_ dir: Int, _ s: Double) -> some View {
        Button { turn(dir) } label: {
            Image(systemName: dir > 0 ? "arrow.clockwise" : "arrow.counterclockwise")
                .font(.system(size: 2.6 * s, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.85))
                .frame(width: 6 * s, height: 6 * s)
                .background(Circle().fill(Color.white.opacity(0.10)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .help(dir > 0 ? "Gira la manopola in senso orario (o premi →)" : "Gira la manopola in senso antiorario (o premi ←)")
    }

    // il macropad virtuale non tocca la selezione della finestra principale
    private func select(_ sel: Selection) { if !virtual { model.selection = sel } }

    private func okBadge(_ s: Double) -> some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 4.2 * s, weight: .bold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color.testOK)
            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            .transition(.scale.combined(with: .opacity))
    }

    private func summary(_ a: Action) -> String {
        switch a.kind {
        case .key: a.sameOnBoth ? comboText(a.mac, .mac) : comboText(a.mac, .mac) + " · " + comboText(a.win, .win)
        case .media: (Media.all.first { $0.code == a.u }?.short).map { $0 == a.label ? "♪" : "♪ " + $0 } ?? "♪"
        case .wheel: (a.u ?? 0) > 0 ? "Rotella ↑" : "Rotella ↓"
        case .none: ""
        }
    }
}

// Riproduce lo schermo del macropad (128 × 64 punti), come lo disegna firmware/src/main.cpp
struct OledView: View {
    let page: Page
    let pageIndex: Int
    let pageCount: Int
    let isMac: Bool
    let battery: Int?
    let usb: Bool
    let pressed: Set<Int>
    let testMode: Int

    var body: some View {
        Canvas { ctx, size in
            let k = size.width / 128
            func text(_ s: String, _ x: Double, _ y: Double, size: Double, center: Bool = false, color: Color = .oledInk) {
                let t = ctx.resolve(Text(s).font(.system(size: size * k, design: .monospaced)).foregroundColor(color))
                ctx.draw(t, at: CGPoint(x: x * k, y: y * k), anchor: center ? .bottom : .bottomLeading)
            }
            text(testMode != 0 ? "PROVA" : "\(pageIndex + 1)/\(pageCount) \(page.name)", 0, 9.5, size: 9)
            ctx.fill(Path(roundedRect: CGRect(x: 74 * k, y: 0, width: 17 * k, height: 9 * k), cornerRadius: 2 * k), with: .color(.oledInk))
            text(isMac ? "MAC" : "WIN", 82.5, 8.8, size: 7, center: true, color: .black)
            if usb {
                text("USB", 105, 8.8, size: 7)
            } else {
                ctx.stroke(Path(CGRect(x: 104 * k, y: 1 * k, width: 20 * k, height: 8 * k)), with: .color(.oledInk), lineWidth: k)
                ctx.fill(Path(CGRect(x: 124 * k, y: 3 * k, width: 2 * k, height: 4 * k)), with: .color(.oledInk))
                ctx.fill(Path(CGRect(x: 106 * k, y: 3 * k, width: Double((battery ?? 100) * 16 + 50) / 100 * k, height: 4 * k)),
                         with: .color(.oledInk))
            }

            for i in 0..<9 {
                let r = CGRect(x: Double(i % 3) * 43 * k, y: (12 + Double(i / 3) * 14) * k, width: 42 * k, height: 13 * k)
                let l = page.keys[i].label
                if pressed.contains(i) {
                    ctx.fill(Path(roundedRect: r, cornerRadius: 2 * k), with: .color(.oledInk))
                } else if !l.isEmpty {
                    ctx.stroke(Path(roundedRect: r.insetBy(dx: 0.5 * k, dy: 0.5 * k), cornerRadius: 2 * k), with: .color(.oledInk), lineWidth: k)
                }
                text(l, r.midX / k, r.maxY / k - 2.5, size: 7.5, center: true, color: pressed.contains(i) ? .black : .oledInk)
            }
            let bottom = testMode == 1 ? "Prova: niente al computer" : testMode == 2 ? "Prova: funzioni attive"
                : testMode == 3 ? "Simulazione sul Mac" : "Manopola: \(page.knobLabel)"
            text(bottom, 64, 64, size: 7.5, center: true)
        }
    }
}
