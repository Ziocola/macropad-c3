// Collegamento Bluetooth con l'app Macropad Config (servizio a parte, accanto alla tastiera)
//
// Messaggi dall'app (primo byte = comando):
//   'G' configurazione attuale   'F' configurazione predefinita   'S' stato
//   'B' inizio invio, 'D' + pezzo di JSON, 'E' fine invio: salva e applica
//   'M' + modo prova: 0 spenta, 1 prova senza inviare niente al computer, 2 prova con le funzioni attive
// Risposte e avvisi del macropad:
//   'D' + pezzo, 'E' fine JSON   'K' salvato   'X' + errore   'S' + JSON di stato
//   'P'/'R' + n tasto premuto/rilasciato   'T' + verso manopola   'C' + 1/0 pulsante della manopola
//   'N' + pagina attuale
#pragma once
#include <Arduino.h>

class NimBLEServer;

namespace applink {

struct Status { uint8_t battery; uint16_t batteryMv; bool onUsb; uint8_t page; bool isMac; };

enum TestMode : uint8_t { TEST_OFF = 0, TEST_SILENT = 1, TEST_LIVE = 2 };

void attach(NimBLEServer* server);         // chiamata da hid::begin prima di avviare il server
void disconnected(uint16_t handle);        // chiamata da hid quando un computer si scollega
bool poll(const Status& st);               // nel loop; true se è arrivata una nuova configurazione
uint8_t testMode();                        // si spegne da sola se l'app si scollega
void keyEvent(uint8_t index, bool down);
void buttonEvent(bool down);
void knobEvent(int8_t dir);
void pageEvent(uint8_t page);
}
