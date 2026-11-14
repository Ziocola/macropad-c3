// Collegamento con l'app Macropad Config (Bluetooth, servizio a parte accanto alla tastiera)
// e con il configuratore web (cavo USB, righe di testo: vedi in fondo).
//
// Messaggi dall'app (primo byte = comando):
//   'G' configurazione attuale   'F' configurazione predefinita   'S' stato
//   'B' inizio invio, 'D' + pezzo di JSON, 'E' fine invio: salva e applica
//   'M' + modo prova: 0 spenta, 1 prova senza inviare niente al computer, 2 prova con le funzioni attive
// Risposte e avvisi del macropad:
//   'D' + pezzo, 'E' fine JSON   'K' salvato   'X' + errore   'S' + JSON di stato
//   'P'/'R' + n tasto premuto/rilasciato   'T' + verso manopola   'C' + 1/0 pulsante della manopola
//   'N' + pagina attuale
//
// Sulla USB (115200, ma la velocità non conta) ogni messaggio è una riga che inizia con '@':
//   dal computer: "@G" "@F" "@S" "@M0".."@M2" "@B" "@D<pezzo di JSON, max ~200 caratteri>" "@E" "@Q" (fine)
//   dal macropad: "@D..." "@E" "@K" "@X<errore>" "@S{...}" "@A" (pronto per il pezzo dopo, dopo @B e ogni @D)
//                 "@P4" "@R4" "@T1" / "@T-1" "@C1" "@N2"
// Le righe senza '@' sono messaggi di prova e vanno ignorate. Senza richieste per 15 s la USB smette di inviare avvisi.
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
