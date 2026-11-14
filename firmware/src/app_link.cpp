#include "app_link.h"
#include <NimBLEDevice.h>
#include <deque>
#include <string>
#include "store.h"

#define FW_VERSION "1.2"

namespace applink {

const char* SERVICE_UUID = "7a0b0001-5d1c-4b8e-9f3a-6d2c1e0a4b10";
const char* CTRL_UUID    = "7a0b0002-5d1c-4b8e-9f3a-6d2c1e0a4b10";

namespace {

enum Src : uint8_t { SRC_BLE, SRC_USB };
struct Msg { Src src; std::string data; };

NimBLECharacteristic* ctrl;
SemaphoreHandle_t lock;
std::deque<Msg> inbox;                     // messaggi ricevuti, gestiti nel loop
volatile uint16_t peer = BLE_HS_CONN_HANDLE_NONE;   // app collegata via Bluetooth e in ascolto
String upload;
bool uploading = false;
volatile uint8_t test = TEST_OFF;
Src testFrom = SRC_BLE;                    // chi ha acceso la prova: si spegne quando se ne va

// ---------- USB ----------
bool usbHost = false;                      // il configuratore web è collegato al cavo
uint32_t usbLastRx = 0;
const uint32_t USB_TIMEOUT_MS = 15000;     // il configuratore chiede lo stato ogni 5 s
std::string usbLine;

class CtrlCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* c, NimBLEConnInfo& info) override {
        std::string v = c->getValue();
        if (v.empty()) return;
        xSemaphoreTake(lock, portMAX_DELAY);
        if (inbox.size() < 160) inbox.push_back({SRC_BLE, v});
        xSemaphoreGive(lock);
    }
    void onSubscribe(NimBLECharacteristic*, NimBLEConnInfo& info, uint16_t subValue) override {
        peer = subValue ? info.getConnHandle() : BLE_HS_CONN_HANDLE_NONE;
        if (!subValue && testFrom == SRC_BLE) test = TEST_OFF;
    }
};

// sulla USB ogni messaggio è una riga: '@' + tipo + contenuto in testo.
// I valori di un byte (tasto, verso, pagina...) diventano numeri: "@P4", "@T-1".
void sendUsb(char type, const uint8_t* data, size_t len) {
    char head[2] = {'@', type};
    Serial.write((const uint8_t*)head, 2);
    if (len) {
        if (type == 'P' || type == 'R' || type == 'C' || type == 'N') Serial.print(data[0]);
        else if (type == 'T') Serial.print((int)(int8_t)data[0]);
        else Serial.write(data, len);
    }
    Serial.write('\n');
}

void sendBle(char type, const uint8_t* data, size_t len) {
    if (peer == BLE_HS_CONN_HANDLE_NONE) return;
    uint8_t buf[512];
    buf[0] = type;
    if (len) memcpy(buf + 1, data, len);
    for (int tries = 0; tries < 50 && !ctrl->notify(buf, len + 1, peer); tries++) delay(5);
}

void send(Src to, char type, const uint8_t* data = nullptr, size_t len = 0) {
    if (to == SRC_USB) sendUsb(type, data, len);
    else sendBle(type, data, len);
}

// avvisi: a tutti quelli in ascolto
void broadcast(char type, const uint8_t* data = nullptr, size_t len = 0) {
    sendBle(type, data, len);
    if (usbHost) sendUsb(type, data, len);
}

void sendText(Src to, char type, const String& s) { send(to, type, (const uint8_t*)s.c_str(), s.length()); }

void sendJson(Src to, const String& json) {
    size_t chunk = 200;
    if (to == SRC_BLE) {
        size_t mtu = NimBLEDevice::getServer()->getPeerMTU(peer);
        chunk = constrain((int)mtu - 4, 20, 500);
    }
    for (size_t i = 0; i < json.length(); i += chunk)
        send(to, 'D', (const uint8_t*)json.c_str() + i, min(chunk, json.length() - i));
    send(to, 'E');
}

// righe dal cavo USB: "@G", "@M1", "@D{...pezzo...}", ecc. Le altre righe si ignorano.
void readUsb() {
    while (Serial.available()) {
        int c = Serial.read();
        if (c < 0) break;
        if (c == '\r') continue;
        if (c != '\n') {
            if (usbLine.size() < 1024) usbLine.push_back((char)c);
            continue;
        }
        if (usbLine.size() >= 2 && usbLine[0] == '@') {
            char type = usbLine[1];
            if (type == 'Q') {                                       // il configuratore si scollega
                usbHost = false;
                if (testFrom == SRC_USB) test = TEST_OFF;
            } else {
                std::string msg(1, type);
                if (type == 'M') msg.push_back((char)(usbLine.size() > 2 ? usbLine[2] - '0' : 0));
                else msg.append(usbLine, 2, std::string::npos);
                usbHost = true;
                usbLastRx = millis();
                xSemaphoreTake(lock, portMAX_DELAY);
                if (inbox.size() < 160) inbox.push_back({SRC_USB, msg});
                xSemaphoreGive(lock);
            }
        }
        usbLine.clear();
    }
    if (usbHost && millis() - usbLastRx > USB_TIMEOUT_MS) {          // pagina chiusa o cavo staccato
        usbHost = false;
        if (testFrom == SRC_USB) test = TEST_OFF;
    }
}

}  // namespace

void disconnected(uint16_t handle) {
    if (handle != peer) return;
    peer = BLE_HS_CONN_HANDLE_NONE;
    if (testFrom == SRC_BLE) test = TEST_OFF;
}

uint8_t testMode() { return test; }

void attach(NimBLEServer* server) {
    lock = xSemaphoreCreateMutex();
    NimBLEService* svc = server->createService(SERVICE_UUID);
    ctrl = svc->createCharacteristic(CTRL_UUID, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_ENC | NIMBLE_PROPERTY::NOTIFY);
    ctrl->setCallbacks(new CtrlCallbacks());
    NimBLEDevice::getAdvertising()->addServiceUUID(SERVICE_UUID);
}

bool poll(const Status& st) {
    readUsb();
    bool changed = false;
    while (true) {
        xSemaphoreTake(lock, portMAX_DELAY);
        if (inbox.empty()) { xSemaphoreGive(lock); break; }
        Msg m = inbox.front();
        inbox.pop_front();
        xSemaphoreGive(lock);
        const std::string& msg = m.data;

        switch (msg[0]) {
            case 'G': sendJson(m.src, store::toJson()); break;
            case 'F': sendJson(m.src, store::toJson(true)); break;
            case 'S': {
                char s[160];
                snprintf(s, sizeof(s), "{\"bat\":%d,\"mv\":%d,\"usb\":%s,\"page\":%d,\"mac\":%s,\"test\":%d,\"fw\":\"%s\"}",
                         st.battery, st.batteryMv, st.onUsb ? "true" : "false", st.page, st.isMac ? "true" : "false",
                         test, FW_VERSION);
                sendText(m.src, 'S', s);
                break;
            }
            case 'M':
                test = msg.size() > 1 && msg[1] <= TEST_LIVE ? msg[1] : TEST_OFF;
                testFrom = m.src;
                break;
            case 'B':
                upload = ""; uploading = true;
                if (m.src == SRC_USB) send(m.src, 'A');                  // sulla USB: pronto per il pezzo dopo
                break;
            case 'D':
                if (uploading && upload.length() < 24000) upload.concat(msg.c_str() + 1, msg.size() - 1);
                if (m.src == SRC_USB) send(m.src, 'A');
                break;
            case 'E': {
                if (!uploading) break;
                uploading = false;
                String err;
                if (store::save(upload, err)) { send(m.src, 'K'); changed = true; }
                else sendText(m.src, 'X', err);
                upload = "";
                break;
            }
        }
    }
    return changed;
}

void keyEvent(uint8_t index, bool down) { uint8_t i = index; broadcast(down ? 'P' : 'R', &i, 1); }
void buttonEvent(bool down) { uint8_t d = down; broadcast('C', &d, 1); }
void knobEvent(int8_t dir) { uint8_t d = (uint8_t)dir; broadcast('T', &d, 1); }
void pageEvent(uint8_t page) { broadcast('N', &page, 1); }

}  // namespace applink
