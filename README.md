<div align="center">

# Macropad C3

**Nine keys. One knob. Zero PCBs.**

An open-source Bluetooth macropad with 9 mechanical keys, a rotary knob and an OLED that labels every key.
You hand-wire it around an ESP32-C3 SuperMini and print it without supports.

[![Firmware & website](https://github.com/Ziocola/macropad-c3/actions/workflows/firmware-and-site.yml/badge.svg)](https://github.com/Ziocola/macropad-c3/actions/workflows/firmware-and-site.yml)
[![Code: MIT](https://img.shields.io/badge/code-MIT-f57a1f)](LICENSE)
[![Hardware: CC BY-NC-SA 4.0](https://img.shields.io/badge/hardware-CC%20BY--NC--SA%204.0-3a3d44)](hardware/LICENSE.md)

### [⚡ Flash it from your browser](https://ziocola.github.io/macropad-c3/) · [🇮🇹 Italiano](README.it.md)

<img src="docs/images/render_front.png" width="640" alt="Macropad C3: black case, nine orange keys, orange knob and OLED window">

</div>

## Features

- **Bluetooth LE keyboard** for macOS and Windows. Each key has its own combo for each OS; hold the knob to switch between them.
- **OLED labels.** The display shows the page name and all 9 labels, and lights up the key you press.
- **Up to 8 pages.** Each page sets its own knob action: volume, scrolling, tabs, zoom or any shortcut. A short press on the knob moves to the next page.
- **Battery powered**: 700 mAh LiPo, USB-C charging, power switch, battery level on screen. The display sleeps after 1 minute and the ESP32 after 15; the knob wakes it.
- **Hand-wired**: off-the-shelf modules and through-hole parts, no PCB.
- **Solid case**: M3 screws into brass heat-set inserts. No supports needed.

## Flash the firmware

The quickest way is the **[web flasher](https://ziocola.github.io/macropad-c3/)**, which needs Chrome or Edge on a computer:

1. Plug the ESP32-C3 SuperMini in with a USB-C **data** cable.
2. Click **Install Macropad C3**, choose the port (usually *USB JTAG/serial debug unit*) and confirm.
3. After about 30 seconds the board restarts. Pair **Macropad C3** in your Bluetooth settings.

If the board isn't found, hold **BOOT**, tap **RESET**, release BOOT and try again.

<details>
<summary>Build it yourself with PlatformIO</summary>

```bash
cd firmware
pio run -t upload        # build and flash
pio device monitor       # see key presses (115200 baud)
```

Every push to `main` builds the firmware with GitHub Actions and publishes it to the web flasher. Tagging a version (`v1.2`) also attaches `-full.bin` (flash at `0x0`) and `-app.bin` (flash at `0x10000`) to a release.
</details>

## Parts

| Part | Qty |
|---|---|
| ESP32-C3 SuperMini | 1 |
| TP4056 USB-C charger with protection (14 × 18 mm) | 1 |
| LiPo 802535, 700 mAh | 1 |
| 0.96" I2C OLED 128×64 (GND VCC SCL SDA) | 1 |
| EC11 encoder with push button, 6 mm knurled shaft cut to 12.5 mm | 1 |
| MX switches, 2 pins (e.g. Kailh Box Brown) | 9 |
| 1N4148 diodes | 9 |
| 1N5819 Schottky diode | 1 |
| 100 kΩ resistors | 2 |
| SS12D00 slide switch | 1 |
| M3 heat-set inserts, 5.7 mm long, 4.6 mm OD | 4 |
| M3 × 12 countersunk screws | 4 |
| M2 × 6 self-tapping screws (display clamp) | 2 |
| Silicone feet, Ø 10 mm | 4 |
| 28 AWG wire, heat-shrink tubing | — |

## Wiring

<img src="docs/images/wiring.png" alt="Wiring diagram drawn with the real modules">

| Function | GPIO |
|---|---|
| Key rows R0 · R1 · R2 | 5 · 6 · 7 |
| Key columns C0 · C1 · C2 | 10 · 20 · 21 |
| OLED SDA · SCL (VCC → 3.3, GND → G) | 8 · 9 |
| Encoder A · B · push (common and S2 → GND) | 3 · 4 · 1 |
| Battery sense, 100k + 100k divider | 0 |

- **Matrix:** column → switch → 1N4148 → row, with the diode's band towards the row. R0 is the row next to the display, C0 is the left column seen from above.
- **Power:** battery to TP4056 B+/B−. Then OUT+ → slide switch → 1N5819 (band towards the board) → **5V**, and OUT− → **G**. Don't use B− as ground.

A vector version is in [`docs/images/wiring.svg`](docs/images/wiring.svg).

## 3D printing

| File | Colour | Notes |
|---|---|---|
| `hardware/stl/macropad_top_shell.stl` | black | upside down, no supports |
| `hardware/stl/macropad_bottom.stl` | black | logo towards the plate |
| `hardware/stl/keycaps_x9.stl`, `knob.stl` | orange | top face on the plate |
| `hardware/stl/oled_clamp.stl` | black | |
| `hardware/stl/test/*.stl` | any | fit tests, print these first |

[`hardware/bambu/Macropad_C3_A1.3mf`](hardware/bambu/Macropad_C3_A1.3mf) is a ready-made Bambu Studio project for the A1 with a 0.4 mm nozzle. It has 4 plates and uses PLA, 0.20 mm layers, 3 walls and 15% gyroid infill.

**Fit tests:** `test_switch`, `test_keycap`, `test_oled`, `test_knob` and `test_insert` are marked with 1–4 dots. Pick the size that fits best on your printer and set it in [`hardware/case/macropad_c3.scad`](hardware/case/macropad_c3.scad), which is fully parametric (OpenSCAD).

**Inserts:** press the four M3 inserts into the shell bosses with a soldering iron at 220–230 °C until they are flush. Then close the case from below with M3 × 12 countersunk screws.

<img src="docs/images/insert_section.png" width="420" alt="Section through a corner: brass insert and M3 screw">

## Customise the keys

- **In the firmware:** the default pages are in [`firmware/src/keymap.h`](firmware/src/keymap.h). Write one line per key, for example `KEY("Copy", PRI, K_C)`, where `PRI` is Cmd on Mac and Ctrl on Windows.
- **Over Bluetooth, no reflashing:** the firmware exposes a BLE service that accepts the whole layout as JSON and stores it in flash. The format is in [`store.cpp`](firmware/src/store.cpp), and [`docs/example_config_fusion.json`](docs/example_config_fusion.json) is an example with an Autodesk Fusion page.
- **macOS app:** [`app/`](app) has **Macropad Config**, a SwiftUI app to edit, reorder and test pages with a live view of the device. Build it with `./build_app.sh` (Xcode required).

## Repository layout

```
firmware/   PlatformIO project (Arduino core, NimBLE, U8g2, ArduinoJson)
app/        macOS configuration app (SwiftUI)
hardware/   OpenSCAD source, STL files, Bambu Studio project
web/        website and web flasher (published to GitHub Pages)
docs/       wiring diagram, renders, example configuration
```

## License

- Code (`firmware/`, `app/`, `web/`): [MIT](LICENSE)
- Hardware (`hardware/`, `docs/`): [CC BY-NC-SA 4.0](hardware/LICENSE.md)

Design: Andrea3DLab
