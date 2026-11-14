// Tastiera Bluetooth (HID su BLE): tastiera, tasti multimediali e rotella del mouse
#pragma once
#include <Arduino.h>

namespace hid {
void begin(const char* name);
bool connected();
void keyboard(uint8_t mods, uint8_t key);   // key = 0 per rilasciare tutto
void media(uint16_t usage);                 // usage = 0 per rilasciare
void wheel(int8_t steps);
void battery(uint8_t percent);
void forgetDevices();                       // cancella gli abbinamenti e torna visibile
}
