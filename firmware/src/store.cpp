#include "store.h"
#include <ArduinoJson.h>
#include <LittleFS.h>
#include "config.h"

namespace store {

KPage pages[MAX_PAGES];
uint8_t pageCount = 0;
Settings settings;

namespace {

const char* PATH = "/keymap.json";
KPage tmpPages[MAX_PAGES];

// copia una stringa UTF-8 tenendo al massimo maxChars caratteri
void copyText(char* dst, size_t size, const char* src, uint8_t maxChars) {
    size_t i = 0;
    uint8_t chars = 0;
    while (src && src[i] && i < size - 1) {
        if ((src[i] & 0xC0) != 0x80 && chars++ == maxChars) break;
        dst[i] = src[i];
        i++;
    }
    while (i > 0 && (dst[i - 1] & 0xC0) == 0xC0) i--;   // non tagliare a metà un carattere
    dst[i] = 0;
}

void fromDefault(KAction& k, const Action& a) {
    copyText(k.label, sizeof(k.label), a.label, LABEL_MAX);
    k.kind = a.kind; k.mac = a.mac; k.win = a.win;
    k.media = a.kind == A_WHEEL ? (int16_t)(int8_t)a.media : (int16_t)a.media;
}

void loadDefaults(KPage* out, uint8_t& count, Settings& set) {
    count = DEFAULT_PAGE_COUNT;
    for (uint8_t p = 0; p < count; p++) {
        const Page& d = DEFAULT_PAGES[p];
        copyText(out[p].name, sizeof(out[p].name), d.name, NAME_MAX);
        for (uint8_t i = 0; i < 9; i++) fromDefault(out[p].keys[i], d.keys[i]);
        copyText(out[p].knobLabel, sizeof(out[p].knobLabel), d.knob.label, LABEL_MAX);
        fromDefault(out[p].cw, d.knob.cw);
        fromDefault(out[p].ccw, d.knob.ccw);
    }
    set = {ENC_REVERSE != 0, OLED_ROTATE != 0, ENC_STEPS, DISPLAY_OFF_S, SLEEP_MIN};
}

void actionToJson(JsonObject o, const KAction& a, bool withLabel) {
    if (withLabel) o["l"] = a.label;
    o["t"] = a.kind;
    if (a.kind == A_KEY) {
        JsonArray m = o["m"].to<JsonArray>(); m.add(a.mac.mods); m.add(a.mac.key);
        JsonArray w = o["w"].to<JsonArray>(); w.add(a.win.mods); w.add(a.win.key);
    } else if (a.kind != A_NONE) o["u"] = a.media;
}

bool actionFromJson(JsonObjectConst o, KAction& a, String& err) {
    copyText(a.label, sizeof(a.label), o["l"] | "", LABEL_MAX);
    a.kind = o["t"] | 0;
    a.mac = {0, 0}; a.win = {0, 0}; a.media = 0;
    switch (a.kind) {
        case A_NONE: return true;
        case A_KEY:
            a.mac = {uint16_t(o["m"][0] | 0), uint8_t(o["m"][1] | 0)};
            a.win = {uint16_t(o["w"][0] | 0), uint8_t(o["w"][1] | 0)};
            if (a.mac.key > 0x65 || a.win.key > 0x65 || (a.mac.mods | a.win.mods) > 0x1FF) { err = "codice tasto non valido"; return false; }
            return true;
        case A_MEDIA:
            a.media = o["u"] | 0;
            if (a.media <= 0 || a.media > 0x3FF) { err = "tasto multimediale non valido"; return false; }
            return true;
        case A_WHEEL:
            a.media = o["u"] | 0;
            if (a.media == 0 || a.media < -10 || a.media > 10) { err = "rotella non valida"; return false; }
            return true;
    }
    err = "tipo di azione sconosciuto";
    return false;
}

bool parse(const String& json, KPage* out, uint8_t& count, Settings& set, String& err) {
    JsonDocument doc;
    if (deserializeJson(doc, json)) { err = "JSON non leggibile"; return false; }
    JsonArrayConst arr = doc["pages"];
    if (arr.isNull() || arr.size() < 1 || arr.size() > MAX_PAGES) { err = "servono da 1 a 8 pagine"; return false; }
    count = 0;
    for (JsonObjectConst p : arr) {
        KPage& pg = out[count];
        copyText(pg.name, sizeof(pg.name), p["n"] | "", NAME_MAX);
        JsonArrayConst keys = p["k"];
        if (keys.size() != 9) { err = "ogni pagina deve avere 9 tasti"; return false; }
        for (uint8_t i = 0; i < 9; i++) if (!actionFromJson(keys[i], pg.keys[i], err)) return false;
        copyText(pg.knobLabel, sizeof(pg.knobLabel), p["kl"] | "", LABEL_MAX);
        if (!actionFromJson(p["cw"], pg.cw, err) || !actionFromJson(p["ccw"], pg.ccw, err)) return false;
        count++;
    }
    JsonObjectConst s = doc["set"];
    set.encReverse  = s["rev"] | (ENC_REVERSE != 0);
    set.oledRotate  = s["rot"] | (OLED_ROTATE != 0);
    set.encSteps    = constrain(int(s["steps"] | ENC_STEPS), 1, 4);
    set.displayOffS = constrain(int(s["disp"] | DISPLAY_OFF_S), 0, 3600);
    set.sleepMin    = constrain(int(s["sleep"] | SLEEP_MIN), 0, 240);
    return true;
}

}  // namespace

void begin() {
    loadDefaults(pages, pageCount, settings);
    if (!LittleFS.begin(true)) return;
    File f = LittleFS.open(PATH, "r");
    if (!f) return;
    String json = f.readString();
    f.close();
    uint8_t count;
    Settings set;
    String err;
    if (parse(json, tmpPages, count, set, err)) {
        memcpy(pages, tmpPages, sizeof(KPage) * count);
        pageCount = count;
        settings = set;
    }
}

String toJson(bool defaults) {
    KPage* src = pages;
    uint8_t count = pageCount;
    Settings set = settings;
    if (defaults) { loadDefaults(tmpPages, count, set); src = tmpPages; }

    JsonDocument doc;
    doc["v"] = 1;
    JsonObject s = doc["set"].to<JsonObject>();
    s["rev"] = set.encReverse; s["rot"] = set.oledRotate; s["steps"] = set.encSteps;
    s["disp"] = set.displayOffS; s["sleep"] = set.sleepMin;
    JsonArray arr = doc["pages"].to<JsonArray>();
    for (uint8_t p = 0; p < count; p++) {
        JsonObject o = arr.add<JsonObject>();
        o["n"] = src[p].name;
        JsonArray keys = o["k"].to<JsonArray>();
        for (uint8_t i = 0; i < 9; i++) actionToJson(keys.add<JsonObject>(), src[p].keys[i], true);
        o["kl"] = src[p].knobLabel;
        actionToJson(o["cw"].to<JsonObject>(), src[p].cw, false);
        actionToJson(o["ccw"].to<JsonObject>(), src[p].ccw, false);
    }
    String out;
    serializeJson(doc, out);
    return out;
}

bool save(const String& json, String& err) {
    uint8_t count;
    Settings set;
    if (!parse(json, tmpPages, count, set, err)) return false;
    File f = LittleFS.open(PATH, "w");
    if (!f) { err = "memoria non disponibile"; return false; }
    f.print(json);
    f.close();
    memcpy(pages, tmpPages, sizeof(KPage) * count);
    pageCount = count;
    settings = set;
    return true;
}

}  // namespace store
