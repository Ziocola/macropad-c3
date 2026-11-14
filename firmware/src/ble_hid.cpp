#include "ble_hid.h"
#include <NimBLEDevice.h>
#include <NimBLEHIDDevice.h>
#include "app_link.h"

namespace {

enum : uint8_t { RID_KEYBOARD = 1, RID_CONSUMER = 2, RID_MOUSE = 3 };

uint8_t reportMap[] = {
    // tastiera: modificatori, riservato, 6 tasti; uscita per i LED
    0x05, 0x01, 0x09, 0x06, 0xA1, 0x01, 0x85, RID_KEYBOARD,
    0x05, 0x07, 0x19, 0xE0, 0x29, 0xE7, 0x15, 0x00, 0x25, 0x01, 0x75, 0x01, 0x95, 0x08, 0x81, 0x02,
    0x95, 0x01, 0x75, 0x08, 0x81, 0x01,
    0x95, 0x05, 0x75, 0x01, 0x05, 0x08, 0x19, 0x01, 0x29, 0x05, 0x91, 0x02,
    0x95, 0x01, 0x75, 0x03, 0x91, 0x01,
    0x95, 0x06, 0x75, 0x08, 0x15, 0x00, 0x25, 0x65, 0x05, 0x07, 0x19, 0x00, 0x29, 0x65, 0x81, 0x00,
    0xC0,
    // tasti multimediali: un codice a 16 bit
    0x05, 0x0C, 0x09, 0x01, 0xA1, 0x01, 0x85, RID_CONSUMER,
    0x15, 0x00, 0x26, 0xFF, 0x03, 0x19, 0x00, 0x2A, 0xFF, 0x03, 0x75, 0x10, 0x95, 0x01, 0x81, 0x00,
    0xC0,
    // mouse: 3 pulsanti, x, y, rotella
    0x05, 0x01, 0x09, 0x02, 0xA1, 0x01, 0x85, RID_MOUSE, 0x09, 0x01, 0xA1, 0x00,
    0x05, 0x09, 0x19, 0x01, 0x29, 0x03, 0x15, 0x00, 0x25, 0x01, 0x95, 0x03, 0x75, 0x01, 0x81, 0x02,
    0x95, 0x01, 0x75, 0x05, 0x81, 0x01,
    0x05, 0x01, 0x09, 0x30, 0x09, 0x31, 0x09, 0x38, 0x15, 0x81, 0x25, 0x7F, 0x75, 0x08, 0x95, 0x03, 0x81, 0x06,
    0xC0, 0xC0,
};

NimBLEHIDDevice* dev;
NimBLECharacteristic* inKeyboard;
NimBLECharacteristic* inConsumer;
NimBLECharacteristic* inMouse;
volatile bool isConnected = false;

class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* s, NimBLEConnInfo& info) override {
        s->updateConnParams(info.getConnHandle(), 6, 12, 0, 300);   // 7.5–15 ms: tasti reattivi
    }
    void onDisconnect(NimBLEServer*, NimBLEConnInfo& info, int) override {
        applink::disconnected(info.getConnHandle());
        isConnected = false;
    }
    void onAuthenticationComplete(NimBLEConnInfo& info) override { isConnected = info.isEncrypted(); }
};

}  // namespace

namespace hid {

void begin(const char* name) {
    NimBLEDevice::init(name);
    NimBLEDevice::setSecurityAuth(true, false, true);              // abbinamento salvato, senza PIN
    NimBLEDevice::setSecurityIOCap(BLE_HS_IO_NO_INPUT_OUTPUT);

    NimBLEServer* server = NimBLEDevice::createServer();
    server->setCallbacks(new ServerCallbacks());
    server->advertiseOnDisconnect(true);

    dev = new NimBLEHIDDevice(server);
    inKeyboard = dev->getInputReport(RID_KEYBOARD);
    dev->getOutputReport(RID_KEYBOARD);
    inConsumer = dev->getInputReport(RID_CONSUMER);
    inMouse    = dev->getInputReport(RID_MOUSE);
    dev->setManufacturer("Andrea3DLab");
    dev->setPnp(0x02, 0xe502, 0xa111, 0x0210);
    dev->setHidInfo(0x00, 0x01);
    dev->setReportMap(reportMap, sizeof(reportMap));
    dev->setBatteryLevel(100);
    applink::attach(server);
    server->start();

    NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
    adv->setAppearance(0x03C1);                                    // tastiera
    adv->addServiceUUID(dev->getHidService()->getUUID());
    adv->setName(name);
    adv->enableScanResponse(true);
    adv->start();
}

bool connected() { return isConnected; }

void keyboard(uint8_t mods, uint8_t key) {
    if (!isConnected) return;
    uint8_t r[8] = {mods, 0, key, 0, 0, 0, 0, 0};
    inKeyboard->setValue(r, sizeof(r));
    inKeyboard->notify();
}

void media(uint16_t usage) {
    if (!isConnected) return;
    uint8_t r[2] = {uint8_t(usage & 0xFF), uint8_t(usage >> 8)};
    inConsumer->setValue(r, sizeof(r));
    inConsumer->notify();
}

void wheel(int8_t steps) {
    if (!isConnected) return;
    uint8_t r[4] = {0, 0, 0, uint8_t(steps)};
    inMouse->setValue(r, sizeof(r));
    inMouse->notify();
    r[3] = 0;
    inMouse->setValue(r, sizeof(r));
    inMouse->notify();
}

void battery(uint8_t percent) { dev->setBatteryLevel(percent, isConnected); }

void forgetDevices() {
    NimBLEServer* server = NimBLEDevice::getServer();
    for (uint16_t h : server->getPeerDevices()) server->disconnect(h);
    NimBLEDevice::deleteAllBonds();
    isConnected = false;
    delay(200);
    NimBLEDevice::getAdvertising()->start();
}

}  // namespace hid
