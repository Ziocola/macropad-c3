// Impostazioni hardware e tempi. I collegamenti sono quelli di schema/schema_cablaggio.png.
#pragma once

#define DEVICE_NAME   "Macropad C3"

// Matrice 3x3: colonna -> switch -> diodo (banda verso la riga) -> riga
static const uint8_t ROW_PINS[3] = {5, 6, 7};     // R0 = fila vicina al display
static const uint8_t COL_PINS[3] = {10, 20, 21};  // C0 = colonna di sinistra

// Encoder EC11: A, B e pulsante; il comune C e S2 vanno a GND
#define ENC_A_PIN     3
#define ENC_B_PIN     4
#define ENC_BTN_PIN   1      // anche il pin che risveglia dal sonno profondo
// Verso della manopola, impulsi per scatto, rotazione del display e tempi di spegnimento
// si cambiano dall'app Macropad Config; questi sono i valori di partenza.
#define ENC_REVERSE   0      // 1 se girando in senso orario il volume scende
#define ENC_STEPS     4      // impulsi per scatto: 4 per quasi tutti gli EC11, prova 2 se salta scatti

// OLED 0.96" SSD1306 128x64 in I2C
#define OLED_SDA_PIN  8
#define OLED_SCL_PIN  9
#define OLED_ROTATE   0      // 1 se il display appare capovolto

// Lettura batteria: partitore 100k + 100k -> GPIO0
#define BAT_PIN       0
#define BAT_DIVIDER   2.0f

// Tempi (millisecondi)
#define DEBOUNCE_MS        6
#define HOLD_OS_MS       600     // tieni premuta la manopola: cambio Mac/Windows
#define HOLD_PAIR_MS    5000     // tienila ancora: nuovo abbinamento Bluetooth
#define DISPLAY_OFF_S   60       // display spento dopo 1 minuto fermo
#define SLEEP_MIN       15       // sonno profondo dopo 15 minuti fermo (0 = mai)
#define BAT_READ_MS     30000UL

