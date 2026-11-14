// ============================================================
// PAGINE PREDEFINITE DEI TASTI
// ============================================================
// Di solito non serve toccare questo file: le funzioni si cambiano dall'app Macropad Config.
// Queste sono le pagine di partenza, usate anche da "Ripristina predefinite".
//
// Ogni pagina ha un nome, 9 tasti (visti da sopra, la prima fila è quella vicina al display)
// e la funzione della manopola. Premi la manopola per passare alla pagina dopo.
//
// Come si scrive un tasto (l'etichetta va sul display: massimo 8 caratteri):
//   KEY("Copia", PRI, K_C)                  stessa combinazione su Mac e Windows; PRI = Cmd sul Mac, Ctrl su Windows
//   OS ("Cerca", GUI, K_SPACE, GUI, K_S)    combinazione Mac, poi combinazione Windows
//   MEDIA("Play", M_PLAY)                   tasto multimediale
//   NONE                                    tasto vuoto
// I modificatori si sommano con |, per esempio PRI | SHIFT. Codici in keycodes.h.
//
// Manopola: KNOB_MEDIA, KNOB_SCROLL oppure KNOB_KEYS(etichetta, orario, antiorario)
#pragma once
#include "keycodes.h"

enum ActKind : uint8_t { A_NONE, A_KEY, A_MEDIA, A_WHEEL };
struct Combo  { uint16_t mods; uint8_t key; };
struct Action { const char* label; ActKind kind; Combo mac; Combo win; uint16_t media; };
struct Knob   { const char* label; Action cw; Action ccw; };
struct Page   { const char* name; Action keys[9]; Knob knob; };

#define NONE                     {"", A_NONE, {0, 0}, {0, 0}, 0}
#define KEY(l, m, k)             {l, A_KEY, {m, k}, {m, k}, 0}
#define OS(l, mm, mk, wm, wk)    {l, A_KEY, {mm, mk}, {wm, wk}, 0}
#define MEDIA(l, u)              {l, A_MEDIA, {0, 0}, {0, 0}, u}
#define WHEEL(n)                 {"", A_WHEEL, {0, 0}, {0, 0}, (uint16_t)(n)}
#define KNOB_MEDIA               {"Volume", MEDIA("", M_VOL_UP), MEDIA("", M_VOL_DOWN)}
#define KNOB_SCROLL              {"Scorri", WHEEL(-1), WHEEL(1)}
#define KNOB_KEYS(l, cw, ccw)    {l, cw, ccw}

static const Page DEFAULT_PAGES[] = {
    {"MEDIA", {
        MEDIA("Prec.", M_PREV),             MEDIA("Play", M_PLAY),             MEDIA("Succ.", M_NEXT),
        MEDIA("Muto", M_MUTE),              KEY("-5 s", 0, K_LEFT),            KEY("+5 s", 0, K_RIGHT),
        OS("Cattura", GUI | SHIFT, K_4, GUI | SHIFT, K_S),
        OS("Blocca", CTRL | GUI, K_Q, GUI, K_L),
        OS("Desktop", 0, K_F11, GUI, K_D),
    }, KNOB_MEDIA},

    {"UFFICIO", {
        KEY("Annulla", PRI, K_Z),           OS("Ripeti", GUI | SHIFT, K_Z, CTRL, K_Y),   KEY("Salva", PRI, K_S),
        KEY("Copia", PRI, K_C),             KEY("Incolla", PRI, K_V),          KEY("Taglia", PRI, K_X),
        OS("Finestre", GUI, K_TAB, ALT, K_TAB),
        OS("Cerca", GUI, K_SPACE, GUI, K_S),
        KEY("Tutto", PRI, K_A),
    }, KNOB_SCROLL},

    {"WEB", {
        OS("Indietro", GUI, K_LEFT, ALT, K_LEFT),
        KEY("Ricarica", PRI, K_R),
        OS("Avanti", GUI, K_RIGHT, ALT, K_RIGHT),
        KEY("Nuova", PRI, K_T),             KEY("Riapri", PRI | SHIFT, K_T),   KEY("Chiudi", PRI, K_W),
        KEY("Indirizz", PRI, K_L),          KEY("Trova", PRI, K_F),
        OS("Intero", CTRL | GUI, K_F, 0, K_F11),
    }, KNOB_KEYS("Schede", KEY("", CTRL, K_TAB), KEY("", CTRL | SHIFT, K_TAB))},

    {"FOTO", {
        KEY("Annulla", PRI, K_Z),           KEY("Ripeti", PRI | SHIFT, K_Z),   KEY("Salva", PRI, K_S),
        KEY("Pennello", 0, K_B),            KEY("Gomma", 0, K_E),              KEY("Sposta", 0, K_V),
        KEY("Mano", 0, K_H),                KEY("Adatta", PRI, K_0),           KEY("100%", PRI, K_1),
    }, KNOB_KEYS("Zoom", KEY("", PRI, K_KP_PLUS), KEY("", PRI, K_KP_MINUS))},
};

static const uint8_t DEFAULT_PAGE_COUNT = sizeof(DEFAULT_PAGES) / sizeof(DEFAULT_PAGES[0]);
