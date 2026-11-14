// Macropad cablato — ESP32-C3 SuperMini
// 9 tasti a matrice, encoder con pulsante, OLED 128x64, tastiera Bluetooth.
// Le funzioni dei tasti si cambiano dall'app Macropad Config (pagine di partenza in keymap.h).
// Pin e tempi: config.h.
#include <Arduino.h>
#include <Preferences.h>
#include <U8g2lib.h>
#include <Wire.h>
#include <driver/gpio.h>
#include <esp_sleep.h>
#include "app_link.h"
#include "ble_hid.h"
#include "config.h"
#include "store.h"

U8G2_SSD1306_128X64_NONAME_F_HW_I2C oled(U8G2_R0, U8X8_PIN_NONE, OLED_SCL_PIN, OLED_SDA_PIN);
Preferences prefs;

uint8_t page = 0;
bool isMac = true;
uint8_t batPct = 100;
uint16_t batMv = 0;
bool onUsb = false;
uint8_t testMode = applink::TEST_OFF;   // prova dei tasti dall'app

uint32_t lastActivity = 0;
bool displayOn = true;
bool dirty = true;
String note;                  // messaggio temporaneo in basso
uint32_t noteUntil = 0;

// ---------- matrice ----------
bool keyState[9], keyRaw[9];
uint32_t keyChanged[9];

void scanMatrix(bool out[9]) {
    for (uint8_t r = 0; r < 3; r++) {
        digitalWrite(ROW_PINS[r], LOW);
        delayMicroseconds(5);
        for (uint8_t c = 0; c < 3; c++) out[r * 3 + c] = digitalRead(COL_PINS[c]) == LOW;
        digitalWrite(ROW_PINS[r], HIGH);
    }
}

// ---------- encoder ----------
volatile int16_t encCount = 0;
volatile uint8_t encState = 0;
static const DRAM_ATTR int8_t ENC_TABLE[16] = {0, -1, 1, 0, 1, 0, 0, -1, -1, 0, 0, 1, 0, 1, -1, 0};

void IRAM_ATTR encISR() {
    encState = ((encState << 2) | (digitalRead(ENC_A_PIN) << 1) | digitalRead(ENC_B_PIN)) & 0x0F;
    encCount += ENC_TABLE[encState];
}

// pulsante della manopola
bool btnDown = false, btnRaw = false, btnIgnore = false;
uint32_t btnChanged = 0, btnSince = 0;

// ---------- azioni ----------
Combo combo(const KAction& a) {
    Combo c = isMac ? a.mac : a.win;
    if (c.mods & PRI) c.mods = (c.mods & 0xFF) | (isMac ? GUI : CTRL);
    return c;
}

void press(const KAction& a) {
    switch (a.kind) {
        case A_KEY:   { Combo c = combo(a); hid::keyboard(c.mods, c.key); break; }
        case A_MEDIA: hid::media(a.media); break;
        case A_WHEEL: hid::wheel((int8_t)a.media); break;
        default: break;
    }
}

void release(const KAction& a) {
    if (a.kind == A_KEY) hid::keyboard(0, 0);
    if (a.kind == A_MEDIA) hid::media(0);
}

void tap(const KAction& a) {
    press(a);
    delay(8);
    release(a);
}

void showNote(const String& s, uint32_t ms = 1500) {
    note = s;
    noteUntil = millis() + ms;
    dirty = true;
}

void savePrefs() {
    prefs.putUChar("page", page);
    prefs.putBool("mac", isMac);
}

// ---------- batteria ----------
void readBattery() {
    uint32_t mv = 0;
    for (int i = 0; i < 16; i++) mv += analogReadMilliVolts(BAT_PIN);
    float v = mv / 16.0f * BAT_DIVIDER / 1000.0f;
    batMv = v * 1000;
    onUsb = v < 2.5f;                       // interruttore spento e cavo collegato all'ESP32
    static const float V[] = {3.30, 3.40, 3.50, 3.60, 3.70, 3.80, 3.90, 4.00, 4.10, 4.20};
    static const uint8_t P[] = {0, 4, 10, 23, 42, 56, 68, 79, 90, 100};
    uint8_t p = 0;
    if (v >= V[9]) p = 100;
    else for (int i = 0; i < 9; i++) if (v >= V[i] && v < V[i + 1]) p = P[i] + (v - V[i]) / (V[i + 1] - V[i]) * (P[i + 1] - P[i]);
    if (p != batPct) dirty = true;
    batPct = p;
    if (!onUsb) hid::battery(batPct);
}

// ---------- display ----------
void draw() {
    const KPage& pg = store::pages[page];
    oled.clearBuffer();

    // intestazione: pagina, modalità, Bluetooth, batteria
    oled.setFont(u8g2_font_6x10_tf);
    oled.enableUTF8Print();
    oled.setCursor(0, 8);
    if (testMode) oled.print("PROVA");
    else { oled.print(page + 1); oled.print('/'); oled.print(store::pageCount); oled.print(' '); oled.print(pg.name); }
    oled.setFont(u8g2_font_5x8_tf);
    oled.drawRBox(74, 0, 17, 9, 2);       // dopo "8/8 " e il nome di 8 caratteri
    oled.setDrawColor(0);
    oled.drawStr(76, 8, isMac ? "MAC" : "WIN");
    oled.setDrawColor(1);
    if (onUsb) oled.drawStr(105, 8, "USB");
    else {
        oled.drawFrame(104, 1, 20, 8);
        oled.drawBox(124, 3, 2, 4);
        oled.drawBox(106, 3, (batPct * 16 + 50) / 100, 4);
    }
    if (!hid::connected() && (millis() / 500) % 2) oled.drawStr(95, 8, "*");

    // griglia 3x3
    for (uint8_t i = 0; i < 9; i++) {
        int x = (i % 3) * 43, y = 12 + (i / 3) * 14;
        const char* l = pg.keys[i].label;
        if (keyState[i]) oled.drawRBox(x, y, 42, 13, 2);
        else if (l[0]) oled.drawRFrame(x, y, 42, 13, 2);
        oled.setDrawColor(keyState[i] ? 0 : 1);
        oled.drawUTF8(x + (42 - oled.getUTF8Width(l)) / 2, y + 10, l);
        oled.setDrawColor(1);
    }

    // riga in basso: messaggio, stato Bluetooth o funzione della manopola
    String bottom;
    if (millis() < noteUntil) bottom = note;
    else if (testMode == applink::TEST_SILENT) bottom = "Prova: niente al computer";
    else if (testMode == applink::TEST_LIVE) bottom = "Prova: funzioni attive";
    else if (!hid::connected()) bottom = "Bluetooth: in attesa";
    else bottom = String("Manopola: ") + pg.knobLabel;
    oled.drawUTF8((128 - oled.getUTF8Width(bottom.c_str())) / 2, 63, bottom.c_str());

    oled.sendBuffer();
    dirty = false;
}

void applySettings() {
    oled.setDisplayRotation(store::settings.oledRotate ? U8G2_R2 : U8G2_R0);
    if (page >= store::pageCount) page = 0;
    dirty = true;
}

void wake() {
    lastActivity = millis();
    if (!displayOn) { oled.setPowerSave(0); displayOn = true; dirty = true; }
}

void goToSleep() {
    oled.clearBuffer();
    oled.setFont(u8g2_font_6x10_tf);
    oled.drawStr(46, 30, "Spento");
    oled.setFont(u8g2_font_5x8_tf);
    oled.drawStr(22, 46, "premi la manopola");
    oled.sendBuffer();
    delay(1500);
    oled.setPowerSave(1);
    hid::keyboard(0, 0);
    gpio_pullup_en((gpio_num_t)ENC_BTN_PIN);
    gpio_pulldown_dis((gpio_num_t)ENC_BTN_PIN);
    esp_deep_sleep_enable_gpio_wakeup(1ULL << ENC_BTN_PIN, ESP_GPIO_WAKEUP_GPIO_LOW);
    esp_deep_sleep_start();
}

// ---------- avvio ----------
void setup() {
    Serial.setRxBufferSize(1024);           // configuratore web via USB: righe fino a ~200 caratteri
    Serial.setTxBufferSize(1024);
    Serial.begin(115200);
    Serial.setTxTimeoutMs(0);               // senza nessuno in ascolto sulla USB non si aspetta mai
    for (uint8_t r = 0; r < 3; r++) { pinMode(ROW_PINS[r], OUTPUT); digitalWrite(ROW_PINS[r], HIGH); }
    for (uint8_t c = 0; c < 3; c++) pinMode(COL_PINS[c], INPUT_PULLUP);
    pinMode(ENC_A_PIN, INPUT_PULLUP);
    pinMode(ENC_B_PIN, INPUT_PULLUP);
    pinMode(ENC_BTN_PIN, INPUT_PULLUP);
    encState = (digitalRead(ENC_A_PIN) << 1) | digitalRead(ENC_B_PIN);
    attachInterrupt(ENC_A_PIN, encISR, CHANGE);
    attachInterrupt(ENC_B_PIN, encISR, CHANGE);
    btnIgnore = digitalRead(ENC_BTN_PIN) == LOW;      // risveglio: ignora la pressione che ha acceso

    store::begin();
    prefs.begin("macropad");
    page = prefs.getUChar("page", 0) % store::pageCount;
    isMac = prefs.getBool("mac", true);

    oled.setBusClock(400000);
    oled.begin();
    applySettings();
    analogSetPinAttenuation(BAT_PIN, ADC_11db);

    hid::begin(DEVICE_NAME);
    readBattery();
    lastActivity = millis();
    Serial.println("Macropad pronto");
}

// ---------- ciclo ----------
void loop() {
    uint32_t now = millis();
    // richieste dall'app di configurazione
    if (applink::poll({batPct, batMv, onUsb, page, isMac})) {
        for (uint8_t i = 0; i < 9; i++) if (keyState[i]) hid::keyboard(0, 0);
        applySettings();
        showNote("Configurazione salvata");
        wake();
    }
    if (applink::testMode() != testMode) {
        testMode = applink::testMode();
        hid::keyboard(0, 0);
        hid::media(0);
        wake();
        dirty = true;
    }
    bool silent = testMode == applink::TEST_SILENT;     // in prova i tasti non arrivano al computer
    const KPage& pg = store::pages[page];

    // tasti, con antirimbalzo
    bool raw[9];
    scanMatrix(raw);
    for (uint8_t i = 0; i < 9; i++) {
        if (raw[i] != keyRaw[i]) { keyRaw[i] = raw[i]; keyChanged[i] = now; }
        if (keyRaw[i] != keyState[i] && now - keyChanged[i] >= DEBOUNCE_MS) {
            keyState[i] = keyRaw[i];
            Serial.printf("Tasto R%d C%d %s\n", i / 3, i % 3, keyState[i] ? "premuto" : "rilasciato");
            if (!silent) { if (keyState[i]) press(pg.keys[i]); else release(pg.keys[i]); }
            applink::keyEvent(i, keyState[i]);
            wake();
            dirty = true;
        }
    }

    // rotazione della manopola
    noInterrupts();
    int16_t steps = encCount / store::settings.encSteps;
    encCount -= steps * store::settings.encSteps;
    interrupts();
    if (store::settings.encReverse) steps = -steps;
    while (steps != 0) {
        if (!silent) tap(steps > 0 ? pg.cw : pg.ccw);
        applink::knobEvent(steps > 0 ? 1 : -1);
        steps += steps > 0 ? -1 : 1;
        wake();
    }

    // pulsante della manopola: breve = pagina dopo, lungo = Mac/Windows, lunghissimo = nuovo abbinamento
    bool b = digitalRead(ENC_BTN_PIN) == LOW;
    if (b != btnRaw) { btnRaw = b; btnChanged = now; }
    if (btnRaw != btnDown && now - btnChanged >= 20) {
        btnDown = btnRaw;
        wake();
        if (!btnIgnore) applink::buttonEvent(btnDown);
        if (btnDown) btnSince = now;
        else if (btnIgnore) btnIgnore = false;
        else if (testMode) {}                            // in prova la pressione si vede solo nell'app
        else {
            uint32_t held = now - btnSince;
            if (held >= HOLD_PAIR_MS) {
                hid::forgetDevices();
                showNote("Abbinamenti cancellati", 3000);
            } else if (held >= HOLD_OS_MS) {
                isMac = !isMac;
                savePrefs();
                showNote(isMac ? "Modalita Mac" : "Modalita Windows");
            } else {
                page = (page + 1) % store::pageCount;
                savePrefs();
                applink::pageEvent(page);
                noteUntil = 0;
            }
            dirty = true;
        }
    }
    if (btnDown && !btnIgnore && !testMode) {
        uint32_t held = now - btnSince;
        const char* hint = held >= HOLD_PAIR_MS ? "Rilascia: nuovo abbinam."
                         : held >= HOLD_OS_MS   ? (isMac ? "Rilascia: Windows" : "Rilascia: Mac")
                         : nullptr;
        if (hint && note != hint) showNote(hint, 200);
        if (hint) noteUntil = now + 200;
    }

    // batteria e stato
    static uint32_t lastBat = 0, lastTick = 0;
    static bool wasConnected = false;
    if (now - lastBat >= BAT_READ_MS) { lastBat = now; readBattery(); }
    if (hid::connected() != wasConnected) { wasConnected = hid::connected(); dirty = true; }
    if (now - lastTick >= 500) { lastTick = now; if (!hid::connected() || millis() < noteUntil + 500) dirty = true; }

    // risparmio energetico
    // ora rilevata adesso: wake() può aver segnato lastActivity dopo "now", e la sottrazione andrebbe sotto zero
    uint32_t idle = millis() - lastActivity;
    uint32_t dispOff = store::settings.displayOffS * 1000UL, sleepAfter = store::settings.sleepMin * 60000UL;
    if (testMode) { lastActivity = millis(); idle = 0; }  // durante la prova resta acceso
    if (displayOn && dispOff && idle >= dispOff) { oled.setPowerSave(1); displayOn = false; }
    if (sleepAfter && idle >= sleepAfter && !btnDown) goToSleep();

    if (displayOn && dirty) draw();
    delay(1);
}
