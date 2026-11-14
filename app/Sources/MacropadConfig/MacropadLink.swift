import CoreBluetooth
import Foundation

// Collegamento Bluetooth con il macropad: protocollo descritto in firmware/src/app_link.h
final class MacropadLink: NSObject, ObservableObject {
    static let serviceUUID = CBUUID(string: "7a0b0001-5d1c-4b8e-9f3a-6d2c1e0a4b10")
    static let ctrlUUID    = CBUUID(string: "7a0b0002-5d1c-4b8e-9f3a-6d2c1e0a4b10")

    enum State: Equatable {
        case bluetoothOff, searching, connecting, connected
        case failed(String)
    }

    @Published private(set) var state: State = .searching
    @Published private(set) var status: DeviceStatus?
    @Published private(set) var pressed: Set<Int> = []
    @Published private(set) var knobTurn: (dir: Int, count: Int) = (0, 0)
    @Published private(set) var buttonDown = false
    @Published private(set) var busy: String?

    var onConfig: ((MacropadConfig) -> Void)?
    var onSaved: ((String?) -> Void)?           // nil = salvato, altrimenti l'errore
    var onEvent: ((DeviceEvent) -> Void)?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var ctrl: CBCharacteristic?
    private var rx = Data()
    private var statusTimer: Timer?
    private var testMode = 0                    // 0 spenta, 1 senza inviare al computer, 2 con le funzioni attive

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    var isConnected: Bool { state == .connected }

    func readConfig()    { request("G", busy: "Lettura dal macropad…") }
    func readDefaults()  { request("F", busy: "Lettura delle predefinite…") }

    func send(_ config: MacropadConfig) {
        guard let p = peripheral, let c = ctrl, isConnected, let json = try? config.json() else { return }
        busy = "Invio al macropad…"
        let chunk = min(p.maximumWriteValueLength(for: .withResponse), 240) - 1
        p.writeValue(Data("B".utf8), for: c, type: .withResponse)
        var i = 0
        while i < json.count {
            p.writeValue(Data("D".utf8) + json.subdata(in: i..<min(i + chunk, json.count)), for: c, type: .withResponse)
            i += chunk
        }
        p.writeValue(Data("E".utf8), for: c, type: .withResponse)
    }

    // modalità prova: rimessa da sola se il collegamento cade e torna
    func setTestMode(_ mode: Int) {
        testMode = mode
        guard isConnected else { return }
        write("M", byte: UInt8(mode))
        restartStatusTimer()
    }

    func refreshStatus() { write("S") }

    // prova senza macropad: gli eventi finti fanno la stessa strada di quelli veri
    func simulate(_ cmd: String, _ value: UInt8) {
        guard !isConnected else { return }
        handle(Data(cmd.utf8) + [value])
    }

    // solo per controllare l'app senza macropad: open "Macropad Config.app" --args -demo 1
    func startDemo(_ events: [(Double, Data)]) {
        state = .connected
        status = DeviceStatus(bat: 74, mv: 3918, usb: false, page: 0, mac: true, test: testMode, fw: "1.1")
        for (t, d) in events {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in self?.handle(d) }
        }
    }

    func reconnect() {
        if let p = peripheral { central.cancelPeripheralConnection(p) }
        peripheral = nil
        ctrl = nil
        find()
    }

    private func request(_ cmd: String, busy text: String) {
        guard let p = peripheral, let c = ctrl, isConnected else { return }
        rx.removeAll()
        busy = text
        p.writeValue(Data(cmd.utf8), for: c, type: .withResponse)
    }

    private func find() {
        guard central.state == .poweredOn else { return }
        if let p = central.retrieveConnectedPeripherals(withServices: [Self.serviceUUID]).first {
            connect(p)
        } else {
            state = .searching
            central.scanForPeripherals(withServices: [Self.serviceUUID])
        }
    }

    private func connect(_ p: CBPeripheral) {
        central.stopScan()
        peripheral = p
        p.delegate = self
        state = .connecting
        central.connect(p)
    }

    private func handle(_ data: Data) {
        guard let type = data.first else { return }
        let body = data.dropFirst()
        switch type {
        case UInt8(ascii: "D"):
            rx.append(body)
        case UInt8(ascii: "E"):
            busy = nil
            if let cfg = try? JSONDecoder().decode(MacropadConfig.self, from: rx) { onConfig?(cfg) }
            rx.removeAll()
        case UInt8(ascii: "K"):
            busy = nil
            onSaved?(nil)
            write("S")
        case UInt8(ascii: "X"):
            busy = nil
            onSaved?(String(decoding: body, as: UTF8.self))
        case UInt8(ascii: "S"):
            status = try? JSONDecoder().decode(DeviceStatus.self, from: body)
        case UInt8(ascii: "P"):
            if let i = body.first { pressed.insert(Int(i)); onEvent?(.key(Int(i), down: true)) }
        case UInt8(ascii: "R"):
            if let i = body.first { pressed.remove(Int(i)); onEvent?(.key(Int(i), down: false)) }
        case UInt8(ascii: "T"):
            if let d = body.first {
                let dir = Int(Int8(bitPattern: d))
                knobTurn = (dir, knobTurn.count + 1)
                onEvent?(.knob(dir))
            }
        case UInt8(ascii: "C"):
            if let d = body.first { buttonDown = d != 0; onEvent?(.button(down: d != 0)) }
        case UInt8(ascii: "N"):
            if let pg = body.first { status?.page = Int(pg); onEvent?(.page(Int(pg))) }
        default:
            break
        }
    }

    private func write(_ cmd: String, byte: UInt8? = nil) {
        guard let p = peripheral, let c = ctrl else { return }
        var d = Data(cmd.utf8)
        if let byte { d.append(byte) }
        p.writeValue(d, for: c, type: .withResponse)
    }

    // stato più spesso durante la prova, per vedere la batteria
    private func restartStatusTimer() {
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: testMode != 0 ? 5 : 30, repeats: true) { [weak self] _ in self?.write("S") }
    }

    private func lost(_ message: String?) {
        statusTimer?.invalidate()
        ctrl = nil
        pressed = []
        buttonDown = false
        busy = nil
        state = message.map { .failed($0) } ?? .searching
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.state != .connected, self.state != .connecting else { return }
            self.peripheral = nil
            self.find()
        }
    }
}

extension MacropadLink: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: find()
        case .unauthorized: state = .failed("L'app non ha il permesso di usare il Bluetooth: Impostazioni di Sistema → Privacy e sicurezza → Bluetooth.")
        default: state = .bluetoothOff
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        lost(nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        lost(nil)
    }
}

extension MacropadLink: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let svc = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            lost("Il macropad non ha il servizio di configurazione: carica il firmware aggiornato.")
            return
        }
        peripheral.discoverCharacteristics([Self.ctrlUUID], for: svc)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let c = service.characteristics?.first(where: { $0.uuid == Self.ctrlUUID }) else { lost(nil); return }
        ctrl = c
        peripheral.setNotifyValue(true, for: c)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            lost("Collegamento rifiutato: \(error.localizedDescription)")
            return
        }
        pressed = []                // via eventuali tasti rimasti dalla simulazione
        buttonDown = false
        state = .connected
        if testMode != 0 { write("M", byte: UInt8(testMode)) }
        write("S")
        readConfig()
        restartStatusTimer()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let v = characteristic.value { handle(v) }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            busy = nil
            onSaved?("Scrittura non riuscita: \(error.localizedDescription)")
        }
    }
}
