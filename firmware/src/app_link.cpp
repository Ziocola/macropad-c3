#include "app_link.h"
#include <NimBLEDevice.h>
#include <deque>
#include <string>
#include "store.h"

#define FW_VERSION "1.1"

namespace applink {

const char* SERVICE_UUID = "7a0b0001-5d1c-4b8e-9f3a-6d2c1e0a4b10";
const char* CTRL_UUID    = "7a0b0002-5d1c-4b8e-9f3a-6d2c1e0a4b10";

namespace {

NimBLECharacteristic* ctrl;
SemaphoreHandle_t lock;
std::deque<std::string> inbox;             // messaggi ricevuti, gestiti nel loop
volatile uint16_t peer = BLE_HS_CONN_HANDLE_NONE;   // app collegata e in ascolto
String upload;
bool uploading = false;
volatile uint8_t test = TEST_OFF;

class CtrlCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* c, NimBLEConnInfo& info) override {
        std::string v = c->getValue();
        if (v.empty()) return;
        xSemaphoreTake(lock, portMAX_DELAY);
        if (inbox.size() < 160) inbox.push_back(v);
        xSemaphoreGive(lock);
    }
    void onSubscribe(NimBLECharacteristic*, NimBLEConnInfo& info, uint16_t subValue) override {
        peer = subValue ? info.getConnHandle() : BLE_HS_CONN_HANDLE_NONE;
        if (!subValue) test = TEST_OFF;
    }
};

void send(char type, const uint8_t* data = nullptr, size_t len = 0) {
    if (peer == BLE_HS_CONN_HANDLE_NONE) return;
    uint8_t buf[512];
    buf[0] = type;
    if (len) memcpy(buf + 1, data, len);
    for (int tries = 0; tries < 50 && !ctrl->notify(buf, len + 1, peer); tries++) delay(5);
}

void sendText(char type, const String& s) { send(type, (const uint8_t*)s.c_str(), s.length()); }

void sendJson(const String& json) {
    NimBLEServer* server = NimBLEDevice::getServer();
    size_t mtu = server->getPeerMTU(peer);
    size_t chunk = constrain((int)mtu - 4, 20, 500);
    for (size_t i = 0; i < json.length(); i += chunk)
        send('D', (const uint8_t*)json.c_str() + i, min(chunk, json.length() - i));
    send('E');
}

}  // namespace

void disconnected(uint16_t handle) {
    if (handle != peer) return;
    peer = BLE_HS_CONN_HANDLE_NONE;
    test = TEST_OFF;
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
    bool changed = false;
    while (true) {
        xSemaphoreTake(lock, portMAX_DELAY);
        if (inbox.empty()) { xSemaphoreGive(lock); break; }
        std::string msg = inbox.front();
        inbox.pop_front();
        xSemaphoreGive(lock);

        switch (msg[0]) {
            case 'G': sendJson(store::toJson()); break;
            case 'F': sendJson(store::toJson(true)); break;
            case 'S': {
                char s[128];
                snprintf(s, sizeof(s), "{\"bat\":%d,\"mv\":%d,\"usb\":%s,\"page\":%d,\"mac\":%s,\"test\":%d,\"fw\":\"%s\"}",
                         st.battery, st.batteryMv, st.onUsb ? "true" : "false", st.page, st.isMac ? "true" : "false",
                         test, FW_VERSION);
                sendText('S', s);
                break;
            }
            case 'M':
                test = msg.size() > 1 && msg[1] <= TEST_LIVE ? msg[1] : TEST_OFF;
                break;
            case 'B': upload = ""; uploading = true; break;
            case 'D':
                if (uploading && upload.length() < 24000) upload.concat(msg.c_str() + 1, msg.size() - 1);
                break;
            case 'E': {
                if (!uploading) break;
                uploading = false;
                String err;
                if (store::save(upload, err)) { send('K'); changed = true; }
                else sendText('X', err);
                upload = "";
                break;
            }
        }
    }
    return changed;
}

void keyEvent(uint8_t index, bool down) { uint8_t i = index; send(down ? 'P' : 'R', &i, 1); }
void buttonEvent(bool down) { uint8_t d = down; send('C', &d, 1); }
void knobEvent(int8_t dir) { uint8_t d = (uint8_t)dir; send('T', &d, 1); }
void pageEvent(uint8_t page) { send('N', &page, 1); }

}  // namespace applink
