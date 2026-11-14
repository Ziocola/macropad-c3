// Codici HID dei tasti (posizione fisica, come su una tastiera US/italiana: lettere e numeri coincidono)
#pragma once

// Modificatori
#define CTRL   0x01
#define SHIFT  0x02
#define ALT    0x04      // Option sul Mac
#define GUI    0x08      // Cmd sul Mac, tasto Windows su PC
#define PRI    0x100     // Cmd sul Mac, Ctrl su Windows

// Lettere
#define K_A 0x04
#define K_B 0x05
#define K_C 0x06
#define K_D 0x07
#define K_E 0x08
#define K_F 0x09
#define K_G 0x0A
#define K_H 0x0B
#define K_I 0x0C
#define K_J 0x0D
#define K_K 0x0E
#define K_L 0x0F
#define K_M 0x10
#define K_N 0x11
#define K_O 0x12
#define K_P 0x13
#define K_Q 0x14
#define K_R 0x15
#define K_S 0x16
#define K_T 0x17
#define K_U 0x18
#define K_V 0x19
#define K_W 0x1A
#define K_X 0x1B
#define K_Y 0x1C
#define K_Z 0x1D

// Numeri della fila in alto
#define K_1 0x1E
#define K_2 0x1F
#define K_3 0x20
#define K_4 0x21
#define K_5 0x22
#define K_6 0x23
#define K_7 0x24
#define K_8 0x25
#define K_9 0x26
#define K_0 0x27

#define K_ENTER  0x28
#define K_ESC    0x29
#define K_BSPC   0x2A
#define K_TAB    0x2B
#define K_SPACE  0x2C

#define K_F1  0x3A
#define K_F2  0x3B
#define K_F3  0x3C
#define K_F4  0x3D
#define K_F5  0x3E
#define K_F6  0x3F
#define K_F7  0x40
#define K_F8  0x41
#define K_F9  0x42
#define K_F10 0x43
#define K_F11 0x44
#define K_F12 0x45

#define K_PRTSC  0x46
#define K_HOME   0x4A
#define K_PGUP   0x4B
#define K_DEL    0x4C
#define K_END    0x4D
#define K_PGDN   0x4E
#define K_RIGHT  0x4F
#define K_LEFT   0x50
#define K_DOWN   0x51
#define K_UP     0x52
#define K_KP_MINUS 0x56  // + e - del tastierino: funzionano con qualsiasi layout
#define K_KP_PLUS  0x57

// Tasti multimediali (consumer)
#define M_PLAY     0x00CD
#define M_NEXT     0x00B5
#define M_PREV     0x00B6
#define M_STOP     0x00B7
#define M_MUTE     0x00E2
#define M_VOL_UP   0x00E9
#define M_VOL_DOWN 0x00EA
