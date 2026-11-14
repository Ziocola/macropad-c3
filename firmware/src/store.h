// Configurazione dei tasti salvata nella memoria del macropad (file /keymap.json)
#pragma once
#include <Arduino.h>
#include "keymap.h"

#define MAX_PAGES  8
#define LABEL_MAX  8                       // caratteri sul display
#define NAME_MAX   8

struct KAction { char label[LABEL_MAX * 2 + 1]; uint8_t kind; Combo mac; Combo win; int16_t media; };
struct KPage   { char name[NAME_MAX * 2 + 1]; KAction keys[9]; char knobLabel[LABEL_MAX * 2 + 1]; KAction cw, ccw; };
struct Settings {
    bool encReverse, oledRotate;
    uint8_t encSteps;
    uint16_t displayOffS;                  // 0 = sempre acceso
    uint16_t sleepMin;                     // 0 = mai
};

namespace store {
extern KPage pages[MAX_PAGES];
extern uint8_t pageCount;
extern Settings settings;

void begin();                              // carica la configurazione salvata, o quella predefinita
String toJson(bool defaults = false);
bool save(const String& json, String& error);
}
