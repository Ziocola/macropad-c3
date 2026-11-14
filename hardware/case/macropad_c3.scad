// ============================================================
// Macropad 3x3 + encoder EC11 + OLED 0.96" I2C — versione CABLATA (senza PCB), forma "Slab"
// ESP32-C3 SuperMini · TP4056 Type-C mini 14x18 · LiPo 802535 700 mAh · SS12D00 · switch MX box marroni, 2 pin
// Piano piatto alto 25 mm, pareti rastremate, fascia di base in un secondo colore,
// tasti quasi a filo (keycap piatti che sporgono 2 mm), manopola sottile Ø 17.
// Modello parametrico OpenSCAD — unità: mm.  x = destra, y = verso il retro, z = alto.
// ============================================================

comp = ""; mat = ""; mode = "a";
part = "assembly"; // [assembly, top, bottom, keycap, keycaps9, knob, clamp, test_keycap, test_switch, test_oled, test_knob, test_insert, chk_top, chk_bot, chk_fit, chk_comp]

$fn = 48;

// ---------- Involucro ----------
W        = 72;
D        = 105;
Hf       = 25;      // altezza del piano (piatto)
r_out    = 9;       // raggio degli angoli in pianta
taper    = 1.5;     // rientro delle pareti dal fondo al piano (rastremazione ~3.4°)
wall     = 2.4;
chamfer  = 1.2;     // smusso del bordo superiore
t_top    = 2.0;
t_bot    = 2.4;
z_join   = 5.0;     // altezza della fascia di base (secondo colore)
fit      = 0.25;
seam_chamfer   = 0.5;
bottom_chamfer = 0.8;

function off(z) = -taper * z / Hf;                 // profilo rastremato
module outline(o = 0) offset(o) rrect([W, D], r_out);
module slice(z, o = 0) translate([0, 0, z]) linear_extrude(0.01) outline(off(z) + o);

// ---------- Tasti (switch MX con stelo "box", 2 pin, montaggio a piastra) ----------
pitch     = 19.05;
sw_hole   = 14.1;
sw_pocket = 16.0;
t_sw      = 1.5;
sw_flange = [15.58, 15.53];   // misurato: ingombro massimo visto dall'alto
sw_h      = 14.80;            // misurato: dal fondo della parte bianca alla cima del box, senza pin
sw_below  = 5.0;              // fondo dello switch sotto la faccia della piastra (standard MX)
sw_top    = sw_h - sw_below;  // cima del box sopra la piastra, a riposo: 9.8
key_x0    = W/2 - pitch;
key_v0    = 13;
key_end_v = key_v0 + 2*pitch + pitch/2 + 1.5;

// ---------- Keycap piatti, quasi a filo ----------
cap       = 17.0;
cap_t     = 2.4;
cap_stem  = 3.0;       // lo stelo entra nel box; il keycap si appoggia sulla cima del box
cap_gap   = 0.4;
cap_out   = 2.0;       // sporgenza a riposo
travel    = 4.0;
cap_well  = cap + 2*cap_gap;
sw_recess = sw_top + cap_t - cap_out;                  // 10.2
well_d    = cap_t - cap_out + travel + 0.6;            // 5.0
t_key     = sw_recess + t_sw;

// ---------- OLED 0.96" I2C (pin GND VCC SCL SDA, connettore sul retro) ----------
oled_c          = [26, 84];                          // centro del PCB
oled_size       = [24.70, 26.08];                    // misurato: PCB (x lungo la fila di pin, y dai pin al cavetto)
oled_pcb        = oled_size + [1.6, 1.0];            // sede con gioco, tarata su stampe di prova (x 25.60 con +1.0: stretta)
oled_pcb_t      = 1.2;
oled_stack      = 3.33;                              // misurato: PCB + vetro
oled_comp_h     = 4.5 - oled_stack;                  // misurato: componenti sul retro
oled_glass_m    = [24.70, 16.56];                    // misurato: vetro
oled_glass      = [oled_size.x, oled_glass_m.y] + [1.4, 0.8];   // incasso del vetro nel piano
oled_glass_dy   = oled_size.y/2 - 5.01 - oled_glass_m.y/2;   // vetro a 5.01 dal bordo lato pin
oled_glass_t    = oled_stack - oled_pcb_t;           // vetro + biadesivo
oled_glass_sink = 0.8;
oled_win        = [22.8, 12.4];                      // area accesa 21.74 x 10.86 + margine
oled_win_off    = oled_glass_dy + 1.8;               // l'area accesa è spostata verso i pin
oled_hdr_x      = -1.3;                              // fila di pin leggermente a sinistra (vista da sopra)
oled_fpc_w      = 17;
oled_back       = t_top - oled_glass_sink + oled_glass_t + oled_pcb_t;
oled_boss_dx    = oled_pcb.x/2 + 1.2 + 3;
clamp_t         = 3.0;                               // barretta: scavo di 1.6 per i componenti sul retro

// ---------- Encoder EC11 (albero 12.5 mm) e manopola sottile ----------
enc_c     = [57, 84];
enc_hole  = 7.3;
enc_shaft = 12.5;      // albero dalla faccia di montaggio: quello comprato è 17.2, va accorciato di 4.7
knob_bore = 5.9;       // foro per albero zigrinato 6 mm (a pressione): scegli il valore con test_knob
enc_bush  = 7;         // boccola filettata M7
knob_d    = 17;
knob_z    = 0.8;       // manopola sollevata sul piano
knob_skirt = enc_bush - t_top - knob_z + 0.6;                 // incavo per dado e boccola: 4.8
knob_h    = enc_shaft - t_top + 0.3 - knob_z + 1.0;           // 11.0

// ---------- Fondo: batteria e schede affiancate ----------
bat     = [25, 35 + 4.5, 8];        // 802535 disposta lungo y, protezione verso il davanti
bat_in  = [bat.x + 1, bat.y + 1];
bat_x0  = 33.5;
bat_y1  = D + off(t_bot) - wall - 0.3;
bat_y0  = bat_y1 - bat_in.y;

ledge    = 3.8;                     // schede rialzate: le USB-C stanno sopra la fascia di base
esp_pcb  = [18.0, 22.52, 1.0];
esp_over = 1.6;
esp_cx   = 22;                      // USB verso il retro
tp_pcb   = [14.0, 18.0, 1.0];
tp_over  = 2.4;
tp_cy    = 68;                      // USB verso il fianco sinistro
usb_shell = [8.94, 3.16];
usb_plug  = [11.4, 6.0];
usb_hole  = [9.8, 4.0];
usb_web   = 0.6;
usb_zc    = t_bot + ledge + 1.0 + usb_shell.y/2;      // centro delle USB-C
function wall_in(z) = wall - off(z);                  // distanza della faccia interna dal bordo esterno a z=0

// ---------- Interruttore SS12D00 (parete destra) ----------
ss_body   = [8.6, 3.6, 3.5];
ss_y      = 66;
ss_z      = 9;
ss_slot   = [4.6, 2.2];
ss_pocket = [11, 6.5];
ss_thin   = 1.2;
ss_rise   = 1.7;       // il fondo dell'incasso sale di tanto verso l'interno (45°)

bosses = [[6, 6], [W-6, 6], [6.5, D-6.5], [W-6.5, D-6.5]];   // vicino agli angoli: lontano dagli switch

// ---------- Inserti filettati in ottone M3 (a caldo) nelle 4 torrette del guscio ----------
// Misure per inserti tipo "M3 x 5,7 x 4,6" (Ruthex, CNC Kitchen e simili): foro 4.0, lunghi 5.7.
// Per altri inserti: insert_hole = foro consigliato dal venditore, insert_len = lunghezza. Scegli il foro con test_insert.
insert_hole = 4.0;
insert_len  = 5.7;
insert_d    = insert_hole + 4.0;     // torretta attorno all'inserto: 2 mm di parete
boss_d      = 6.5;                   // torretta sopra l'inserto
screw_free  = 3.4;                   // foro passante per la vite M3
screw_reach = 9.0;                   // la vite M3 x 12 svasata arriva a z = 12: foro libero fino a z_join + 9
feet   = [[14, 14], [W-14, 14], [14, D-14], [W-14, D-14]];
logo_y = 56;
font   = "Liberation Sans:style=Bold";

// ============================================================
// Utilità
// ============================================================
module P() translate([0, 0, Hf]) children();
module rrect(s, r) { translate([r, r]) offset(r) square([s.x - 2*r, s.y - 2*r]); }
module rsq(s, r)   { offset(r) square([s.x - 2*r, s.y - 2*r], center = true); }
function keypos(i, j) = [key_x0 + i*pitch, key_v0 + j*pitch];

module outer() hull() {
    slice(z_join, -seam_chamfer);
    slice(z_join + seam_chamfer);
    slice(Hf - chamfer);
    slice(Hf - 0.01, -chamfer);
}
module inner_solid(o = 0) hull() {
    slice(-1, -wall + o);
    slice(Hf - t_top, -wall + o);
}

// ============================================================
// Guscio superiore
// ============================================================
module key_block() intersection() {
    inner_solid(0.01);
    translate([-50, -50, Hf - t_key]) cube([W + 100, key_end_v + 50, t_key]);
}

module key_cut(hole = sw_hole) {
    translate([0, 0, -well_d]) linear_extrude(well_d + 1) rsq([cap_well, cap_well], 1.8);
    hull() {
        translate([0, 0, -well_d - 0.01]) linear_extrude(0.01) rsq([cap_well, cap_well], 1.8);
        translate([0, 0, -well_d - (cap_well - sw_pocket)/2]) linear_extrude(0.01) rsq([sw_pocket, sw_pocket], 0.6);
    }
    translate([0, 0, -sw_recess]) linear_extrude(sw_recess - well_d + 0.01) rsq([sw_pocket, sw_pocket], 0.6);
    cube([hole, hole, 40], center = true);
    hull() {
        translate([0, 0, -0.5]) linear_extrude(0.01) rsq([cap_well, cap_well], 1.8);
        linear_extrude(0.5) rsq([cap_well + 1.0, cap_well + 1.0], 2.3);
    }
}

// sede del display (sistema locale: centro del PCB, z = 0 sulla faccia del piano)
module oled_mounts() translate([0, 0, -t_top]) {
    fd = oled_back - t_top - 0.3;
    translate([0, 0, -fd]) linear_extrude(fd + 1) difference() {           // +1: si fonde con il piano
        square(oled_pcb + [2.4, 2.4], center = true);
        square(oled_pcb, center = true);
        translate([-oled_fpc_w/2, -oled_pcb.y/2 - 2]) square([oled_fpc_w, 3]);
    }
    for (s = [-1, 1]) translate([s*oled_boss_dx, 0, -(oled_back - t_top - 0.2)])
        cylinder(d = 6, h = oled_back - t_top - 0.2 + 1);
}
module oled_cut() {
    translate([0, oled_glass_dy, -t_top - 1]) linear_extrude(1 + oled_glass_sink) square(oled_glass, center = true);
    translate([0, oled_win_off, 0]) {
        linear_extrude(10, center = true) rsq(oled_win, 1.2);
        hull() {
            translate([0, 0, -0.5]) linear_extrude(0.01) rsq(oled_win, 1.2);
            linear_extrude(1) rsq(oled_win + [2.2, 2.2], 2.3);
        }
    }
    for (s = [-1, 1]) translate([s*oled_boss_dx, 0, -oled_back - 1]) cylinder(d = 1.8, h = oled_back + 1 - 0.8);
}

// interruttore sulla parete destra (sistema locale: parete interna a x = 0, verso l'interno -x)
module ss_frame() translate([W - wall_in(ss_z + 3), 0, 0]) mirror([1, 0, 0]) children();
module ss_holder() ss_frame() difference() {
    union() {
        translate([-0.01, ss_y - ss_body.x/2 - 1.8, ss_z - ss_body.y/2 - 2]) cube([ss_body.z + 0.1, ss_body.x + 3.6, ss_body.y + 4]);
        // raccordo a 45° sopra la cornice: capovolto si stampa senza sbalzo
        hull() {
            translate([-1, ss_y - ss_body.x/2 - 1.8, ss_z + ss_body.y/2 + 2 - 0.01]) cube([ss_body.z + 1.1, ss_body.x + 3.6, 0.01]);
            translate([-1, ss_y - ss_body.x/2 - 1.8, ss_z + ss_body.y/2 + 2 - 0.01]) cube([0.01, ss_body.x + 3.6, ss_body.z + 1.1]);
        }
    }
    translate([-0.1,  ss_y - ss_body.x/2 - 0.1, ss_z - ss_body.y/2 - 0.1]) cube([10, ss_body.x + 0.2, ss_body.y + 0.2]);
}

// apertura USB-C (sistema locale: asse lungo +z, z = 0 sulla faccia esterna)
module usb_cut() {
    translate([0, 0, -wall - 2]) linear_extrude(wall + 3) rsq(usb_hole, usb_hole.y/2 - 0.01);
    translate([0, 0, -(wall - usb_web)]) linear_extrude(wall - usb_web + 1) rsq(usb_plug, 2.4);
    translate([0, 0, -0.4]) hull() {
        linear_extrude(0.01) rsq(usb_plug, 2.4);
        translate([0, 0, 0.41]) linear_extrude(0.01) rsq(usb_plug + [0.8, 0.8], 2.8);
    }
}
module back_usb()  translate([esp_cx, D + off(usb_zc), usb_zc]) rotate([-90, 0, 0]) children();
module left_usb()  translate([-off(usb_zc), tp_cy, usb_zc]) rotate([0, -90, 0]) rotate([0, 0, 90]) children();
module wall_text(txt) linear_extrude(1.2) text(txt, size = 2.6, font = font, halign = "center", valign = "center");

// foro per l'inserto (sistema locale: z = 0 sulla faccia d'appoggio della torretta, foro verso +z)
module insert_hole_cut() {
    translate([0, 0, -1]) cylinder(d = insert_hole, h = insert_len + 0.6 + 1);
    translate([0, 0, -0.01]) cylinder(d1 = insert_hole + 0.8, d2 = insert_hole, h = 0.4);   // invito
    cylinder(d = screw_free, h = screw_reach);                                              // spazio per la punta della vite
    translate([0, 0, insert_len + 0.6 - 0.01]) cylinder(d1 = insert_hole, d2 = screw_free, h = (insert_hole - screw_free)/2 + 0.01);
}

module top_shell() difference() {
    union() {
        difference() { outer(); inner_solid(); }
        key_block();
        intersection() {
            outer();
            difference() {
                for (p = bosses) translate([p.x, p.y, z_join]) {
                    cylinder(d = insert_d, h = insert_len + 1.0);
                    translate([0, 0, insert_len + 1.0 - 0.01])                  // raccordo a 45°: capovolto si stampa senza supporti
                        cylinder(d1 = insert_d, d2 = boss_d, h = (insert_d - boss_d)/2 + 0.01);
                    cylinder(d = boss_d, h = 40);
                }
                P() for (i = [0:2], j = [0:2]) translate([each keypos(i, j), -sw_recess - t_sw - 20])   // spazio per gli switch
                    linear_extrude(20 - 0.01) rsq([sw_hole + 0.5, sw_hole + 0.5], 0.5);
            }
        }
        P() translate([oled_c.x, oled_c.y, 0]) oled_mounts();
        ss_holder();
    }
    for (p = bosses) translate([p.x, p.y, z_join]) insert_hole_cut();
    P() for (i = [0:2], j = [0:2]) translate([each keypos(i, j), 0]) key_cut();
    P() translate([oled_c.x, oled_c.y, 0]) oled_cut();
    P() translate([enc_c.x, enc_c.y, 0]) {
        cylinder(d = enc_hole, h = 10, center = true);                       // piano liscio sotto la manopola, nessun incasso
    }
    back_usb() usb_cut();
    left_usb() usb_cut();
    translate([esp_cx, D + off(usb_zc + 7) - 0.6, usb_zc + 7]) rotate([90, 0, 180]) wall_text("USB");
    translate([-off(usb_zc + 7) + 0.6, tp_cy, usb_zc + 7]) rotate([90, 0, -90]) wall_text("CARICA");
    // interruttore: incasso esterno (fondo inclinato a 45°, stampabile capovolto) + feritoia
    ss_frame() {
        hull() {
            translate([-wall - 1, ss_y, ss_z]) rotate([0, 90, 0]) linear_extrude(wall + 1 - ss_thin - ss_rise) rsq([ss_pocket.y, ss_pocket.x], 1.5);
            translate([-ss_thin - 0.01, ss_y, ss_z + ss_rise/2]) rotate([0, 90, 0]) linear_extrude(0.01) rsq([ss_pocket.y - ss_rise, ss_pocket.x], 1.5);
        }
        translate([-wall - 1, ss_y - ss_slot.x/2, ss_z - ss_slot.y/2]) cube([wall + 2, ss_slot.x, ss_slot.y]);
    }
}

// ============================================================
// Fondo (fascia di base): vani per batteria, ESP32 e TP4056
// ============================================================
// alloggio scheda nel sistema locale: faccia interna della parete a y = 0, USB verso +y
module board_pocket(pcb, over) {
    yb = -over - 0.1;
    yf = yb - pcb.y;
    w  = pcb.x + 0.4;
    h  = ledge + pcb.z + 1.0;
    difference() {
        translate([-w/2 - 1.2, yf - 1.5, 0]) cube([w + 2.4, -yf + 1.5 - 0.3, h]);
        translate([-w/2, yf - 0.3, ledge]) cube([w, yb - yf + 0.4, 10]);
        translate([-usb_shell.x/2 - 0.6, yb, ledge + pcb.z]) cube([usb_shell.x + 1.2, 10, 10]);
        translate([-w/2, yf + 2.5, -1]) cube([w, pcb.y - 5, ledge + 1.01]);     // appoggio alle estremità
        translate([0, yf - 2, 0]) hull() {                                      // passaggio fili sotto, tetto a 45°
            translate([-3, 0, -1]) cube([6, 3, ledge - 3.5 + 1]);
            translate([-0.01, 0, -1]) cube([0.02, 3, ledge - 0.5 + 1]);
        }
    }
}
module esp_frame() translate([esp_cx, D - wall_in(usb_zc), 0]) children();
module tp_frame()  translate([wall_in(usb_zc), tp_cy, 0]) rotate([0, 0, 90]) children();

module bat_bay() translate([bat_x0, bat_y0, 0]) difference() {
    translate([-1.2, -1.2, 0]) cube([bat_in.x + 2.4, bat_in.y + 1.2, 3]);
    translate([0, 0, -1]) cube([bat_in.x, bat_in.y + 1, 10]);
    translate([3, -2, -1]) cube([bat_in.x - 6, 3, 10]);                       // uscita fili davanti
}

module base_lip() difference() {             // bordino davanti e sui fianchi che centra il guscio
    lip_in = -wall - fit - 1.2;
    lip_z1 = z_join - 0.5;
    lip_z0 = lip_z1 - (-wall + 0.4 - lip_in);  // attacco alla parete con sottosquadro a 45°: niente sbalzi
    union() {
        hull() { slice(lip_z1, -wall - fit); slice(z_join + 2.5, -wall - fit); }
        hull() { slice(lip_z0, -wall + 0.4); slice(z_join - 0.01, -wall + 0.4); }
    }
    hull() { slice(lip_z0 - 0.01, -wall + 0.41); slice(lip_z1, lip_in); }
    hull() { slice(lip_z1, lip_in); slice(z_join + 3, lip_in); }
    translate([-1, 52, -1]) cube([W + 2, D, 20]);
    for (p = bosses) translate([p.x, p.y, -1]) cylinder(d = insert_d + 2*fit + 0.6, h = 20);
}

module bottom() difference() {
    union() {
        difference() {
            hull() {
                slice(0, -bottom_chamfer);
                slice(bottom_chamfer);
                slice(z_join - seam_chamfer);
                slice(z_join - 0.01, -seam_chamfer);
            }
            hull() { slice(t_bot, -wall); slice(z_join + 1, -wall); }
        }
        base_lip();
        translate([0, 0, t_bot - 0.01]) {
            bat_bay();
            esp_frame() board_pocket(esp_pcb, esp_over);
            tp_frame() board_pocket(tp_pcb, tp_over);
        }
        for (p = bosses) translate([p.x, p.y, 0]) cylinder(d = insert_d, h = z_join);   // appoggio delle torrette
    }
    for (p = bosses) translate([p.x, p.y, 0]) {
        translate([0, 0, -1]) cylinder(d = 3.4, h = 20);
        translate([0, 0, -0.01]) cylinder(d1 = 6.6, d2 = 3.2, h = 1.7);
    }
    for (p = feet) translate([p.x, p.y, -0.01]) difference() {                  // segno dei piedini: anello, niente ponti
        cylinder(d = 10.5, h = 0.41);
        translate([0, 0, -1]) cylinder(d = 9.0, h = 3);
    }
    translate([W/2, logo_y, 0]) engrave() mirror([1, 0, 0])
        resize([46, 0], auto = true) import("logo_andrea3dlab.svg", center = true, $fn = 8);   // curve SVG: 8 segmenti bastano a 46 mm
    translate([W/2, logo_y - 25, 0]) engrave() mirror([1, 0, 0])
        text("MACROPAD C3", size = 6, font = font, halign = "center", valign = "center");
}

// incisione sul lato del piatto a gradini da 0.2 rientranti a 45°: nessun ponte sopra le lettere
module engrave(depth = 0.6, step = 0.2) for (k = [0 : round(depth/step) - 1])
    translate([0, 0, k*step - 0.01]) linear_extrude(step + 0.02) offset(delta = -k*step) children();

// ============================================================
// Parti piccole
// ============================================================
cap_slot  = 1.35;      // larghezza dei bracci della croce nel keycap
module keycap(slot = cap_slot, stem = cap_stem) {
    hull() {
        linear_extrude(cap_t - 0.6) rsq([cap, cap], 2.0);
        translate([0, 0, cap_t - 0.01]) linear_extrude(0.01) rsq([cap - 1.2, cap - 1.2], 1.4);
    }
    // stelo liscio, senza alette: entra nel box dello switch e il keycap si appoggia sulla sua cima
    difference() {
        translate([0, 0, -stem]) cylinder(d = 5.5, h = stem + 0.01);
        translate([0, 0, -stem - 0.01]) {
            translate([-4.15/2, -slot/2, 0]) cube([4.15, slot, stem + 0.4]);
            translate([-slot/2, -4.15/2, 0]) cube([slot, 4.15, stem + 0.4]);
        }
    }
}

// manopola sottile: copre dado e boccola, zigrinatura fine, tacca sul bordo superiore
module knob(bore = knob_bore) {
    d = knob_d; h = knob_h;
    difference() {
        union() {
            cylinder(d = d, h = h - 1.0, $fn = 72);
            translate([0, 0, h - 1.0]) cylinder(d1 = d, d2 = d - 2, h = 1.0, $fn = 72);
        }
        for (i = [0:39]) rotate(i*9) translate([d/2 + 0.2, 0, 1.2]) cylinder(d = 0.9, h = h - 2.6, $fn = 10);
        translate([0, 0, -0.01]) cylinder(d = 12.6, h = knob_skirt);          // dado M7 + boccola
        translate([0, 0, knob_skirt - 0.01]) {                                // albero zigrinato 6 mm: foro tondo a pressione
            cylinder(d = bore, h = h - knob_skirt - 1.0, $fn = 48);
            cylinder(d1 = bore + 0.8, d2 = bore, h = 0.6, $fn = 48);          // invito
        }
        translate([-0.45, d/2 - 4.2, h - 0.5]) cube([0.9, 3.2, 1]);
    }
}

module clamp() difference() {
    L = 2*oled_boss_dx + 5;
    translate([-L/2, -3.5, 0]) cube([L, 7, clamp_t]);
    for (s = [-1, 1]) translate([s*oled_boss_dx, 0, -1]) cylinder(d = 2.3, h = clamp_t + 2);
    translate([-(oled_size.x/2 - 1.5), -4, clamp_t - 1.6]) cube([oled_size.x - 3, 8, 2]);   // preme solo sui bordi del PCB
}

// prova del display: pezzo di piano con finestra, sede e torrette (si stampa capovolto, come il guscio)
module test_oled() difference() {
    union() {
        translate([-oled_boss_dx - 5, -oled_pcb.y/2 - 3, -t_top]) cube([2*oled_boss_dx + 10, oled_pcb.y + 6, t_top]);
        oled_mounts();
    }
    oled_cut();
}

// prova dei keycap: 4 varianti di croce e stelo, numerate da 1 a 4 con puntini sotto
test_caps = [[1.15, 3.0], [1.25, 3.0], [1.15, 2.2], [1.25, 2.2]];
module test_keycap() for (k = [0:3]) translate([k*21, 0, cap_t]) rotate([180, 0, 0]) difference() {
    keycap(test_caps[k][0], test_caps[k][1]);
    for (n = [0:k]) translate([-6 + n*2, -6, -0.01]) cylinder(d = 1.2, h = 0.6, $fn = 16);
}

// prova del foro della manopola: 4 anelli con foro 5.7 · 5.8 · 5.9 · 6.0, numerati da 1 a 4 con puntini
test_bores = [5.7, 5.8, 5.9, 6.0];
module test_knob() for (k = [0:3]) translate([k*14, 0, 0]) difference() {
    cylinder(d = 11, h = 6, $fn = 48);
    translate([0, 0, -0.01]) cylinder(d = test_bores[k], h = 7, $fn = 48);
    for (n = [0:k]) translate([-3 + n*2, 4.3, 5.5]) cylinder(d = 1.0, h = 1, $fn = 12);
}

// prova degli inserti: 3 torrette con fori 3.8 / 4.0 / 4.2 (1–3 puntini), stampate in piedi come nel guscio capovolto
test_inserts = [3.8, 4.0, 4.2];
module test_insert() for (k = [0:2]) translate([k*13, 0, 0]) difference() {
    union() {
        translate([-5.5, -5.5, 0]) cube([11, 11, 2]);
        cylinder(d = test_inserts[k] + 4.0, h = insert_len + 3);
    }
    translate([0, 0, insert_len + 3]) mirror([0, 0, 1]) {
        translate([0, 0, -1]) cylinder(d = test_inserts[k], h = insert_len + 0.6 + 1);
        translate([0, 0, -0.01]) cylinder(d1 = test_inserts[k] + 0.8, d2 = test_inserts[k], h = 0.4);
        cylinder(d = screw_free, h = insert_len + 3 + 1);
    }
    for (n = [0:k]) translate([-2 + n*2, -4.9, 1.5]) cylinder(d = 1.0, h = 1, $fn = 12);
}

module test_switch() {
    holes = [13.9, 14.0, 14.1, 14.2];
    difference() {
        translate([-pitch/2 - 2, -pitch/2 - 2, -t_key]) cube([4*pitch + 4, pitch + 4, t_key]);
        for (i = [0:3]) translate([i*pitch, 0, 0]) {
            key_cut(holes[i]);
            translate([0, pitch/2 + 0.4, -0.6]) linear_extrude(1) text(str(holes[i]), size = 1.4, font = font, halign = "center", valign = "center");
        }
    }
}

// ============================================================
// Ingombri dei componenti (verifiche di collisione)
// ============================================================
module switches_dummy(above = true) P() for (i = [0:2], j = [0:2]) translate([each keypos(i, j), -sw_recess]) {
    translate([-6.95, -6.95, -5]) cube([13.9, 13.9, 5 - t_sw - 0.05]);
    translate([-6.95, -6.95, -10]) cube([13.9, 13.9, 5]);
    if (above) translate([-7.8, -7.8, 0.05]) cube([15.6, 15.6, 6.6]);
}
module keycaps_placed(pressed = 0) P() for (i = [0:2], j = [0:2])
    translate([each keypos(i, j), cap_out - cap_t - pressed]) keycap();
module oled_dummy() P() translate([oled_c.x, oled_c.y, 0]) {
    translate([-oled_glass_m.x/2, oled_glass_dy - oled_glass_m.y/2, -t_top + oled_glass_sink - oled_glass_t]) cube([oled_glass_m.x, oled_glass_m.y, oled_glass_t - 0.02]);
    translate([-oled_size.x/2, -oled_size.y/2, -oled_back]) cube([oled_size.x, oled_size.y, oled_pcb_t - 0.02]);
    translate([-(oled_size.x/2 - 1.6), -oled_size.y/2 + 1, -oled_back - oled_comp_h]) cube([oled_size.x - 3.2, oled_size.y - 2, oled_comp_h]);
    translate([oled_hdr_x - 5.5, oled_size.y/2 - 4, -oled_back - 8.5]) cube([11, 3, 8.5]);
}
module enc_dummy() P() translate([enc_c.x, enc_c.y, -t_top - 0.02]) {
    translate([-6.2, -6.6, -6.5]) cube([12.4, 13.2, 6.5]);
    translate([-6.2, -6.6, -10.5]) cube([12.4, 13.2, 4]);
}
module board_dummy(pcb, over, comp_h) {          // sistema locale della scheda
    yb = -over - 0.1;
    z0 = t_bot + ledge + 0.05;
    translate([-pcb.x/2, yb - pcb.y + 0.05, z0]) cube([pcb.x, pcb.y - 0.1, pcb.z]);
    translate([-pcb.x/2 + 0.5, yb - pcb.y + 1, z0 + pcb.z]) cube([pcb.x - 1, pcb.y - 2, comp_h]);
    translate([-usb_shell.x/2, yb - 7.3 + over, z0 + pcb.z]) cube([usb_shell.x, 7.3 - 0.05, usb_shell.y]);
}
module esp_dummy() esp_frame() board_dummy(esp_pcb, esp_over, 2.0);
module tp_dummy()  tp_frame() board_dummy(tp_pcb, tp_over, 1.6);
module bat_dummy() translate([bat_x0 + 0.5, bat_y0 + 0.5, t_bot + 0.05]) cube(bat);
module ss_dummy() ss_frame() {
    translate([0.05, ss_y - ss_body.x/2, ss_z - ss_body.y/2]) cube([ss_body.z, ss_body.x, ss_body.y]);
    translate([ss_body.z, ss_y - 2.6, ss_z - 0.3]) cube([4, 5.2, 0.6]);
    translate([-3 + 0.05, ss_y - 0.75, ss_z - 0.75]) cube([3, 1.5, 1.5]);
}
module clamp_placed() P() translate([oled_c.x, oled_c.y, -oled_back - clamp_t - 0.02]) clamp();
module knob_placed() P() translate([enc_c.x, enc_c.y, 0]) {
    translate([0, 0, -t_top]) cylinder(d = 6, h = enc_shaft);
    translate([0, 0, knob_z]) knob();
}
module all_dummies() { switches_dummy(); oled_dummy(); enc_dummy(); esp_dummy(); tp_dummy(); bat_dummy(); ss_dummy(); }

// ============================================================
// Modelli dettagliati dei componenti (solo visualizzazione)
// Ogni modello è diviso per materiale: mat = "pcb", "nero", "metallo", "oro", ...
// ============================================================
module pin_ring(n, pitch_p, y) for (k = [0:n-1]) translate([k*pitch_p - (n-1)*pitch_p/2, y, 0]) children();

// ESP32-C3 SuperMini — PCB 18 x 22.52, origine: bordo USB del PCB a y = 0, sotto del PCB a z = 0
module esp_model(mat) {
    L = esp_pcb.y; Wd = esp_pcb.x;
    if (mat == "pcb") difference() {
        translate([-Wd/2, -L, 0]) cube([Wd, L, 1.0]);
        for (s = [-1, 1]) for (k = [0:7]) translate([s*(Wd/2 - 1.3), -2.2 - k*2.54, -1]) cylinder(d = 1.0, h = 3, $fn = 12);
    }
    if (mat == "oro") for (s = [-1, 1]) for (k = [0:7]) translate([s*(Wd/2 - 1.3), -2.2 - k*2.54, -0.05]) difference() {
        cylinder(d = 1.7, h = 1.1, $fn = 16); translate([0, 0, -1]) cylinder(d = 1.0, h = 3, $fn = 12);
    }
    if (mat == "metallo") {
        translate([-usb_shell.x/2, -7.3 + esp_over, 1.0]) rsq_box([usb_shell.x, 7.3, usb_shell.y], 1.2);
        translate([-2.6, -12.2, 1.0]) cube([5.2, 5.2, 0.85]);                // ESP32-C3
    }
    if (mat == "nero") {
        translate([-1.6, -L + 1.0, 1.0]) cube([3.2, 6.6, 1.2]);              // antenna ceramica
        for (x = [-5, 5]) translate([x - 1.5, -17.6, 1.0]) cube([3, 2, 1.4]);   // BOOT / RST
        translate([-4, -8.6, 1.0]) cube([2, 1.2, 1.0]);                      // regolatore
    }
    if (mat == "bianco") for (x = [-5, 5]) translate([x - 0.6, -17.1, 2.4]) cube([1.2, 1.0, 0.6]);
}
module rsq_box(s, r) translate([s.x/2, 0, s.z/2]) rotate([-90, 0, 0]) linear_extrude(s.y) rsq([s.x, s.z], min(r, s.z/2 - 0.01));

// TP4056 Type-C mini 14 x 18 — stessa convenzione dell'ESP
module tp_model(mat) {
    L = tp_pcb.y; Wd = tp_pcb.x;
    if (mat == "pcb") translate([-Wd/2, -L, 0]) cube([Wd, L, 1.0]);
    if (mat == "metallo") {
        translate([-usb_shell.x/2, -7.3 + tp_over, 1.0]) rsq_box([usb_shell.x, 7.3, usb_shell.y], 1.2);
        for (x = [-4.5, -1.5, 1.5, 4.5]) translate([x - 1, -L + 0.4, 1.0]) cube([2, 2.2, 0.15]);   // piazzole OUT+ B+ B- OUT-
    }
    if (mat == "nero") {
        translate([-2.0, -11.6, 1.0]) cube([4.0, 5.0, 1.5]);                 // TP4056
        translate([2.6, -15.2, 1.0]) cube([3, 3, 1.0]);                      // DW01 + 8205A
        translate([-5.6, -15.2, 1.0]) cube([3, 3, 1.0]);
    }
    if (mat == "rosso") translate([-5.2, -6.2, 1.0]) cube([1.6, 0.8, 0.6]);
    if (mat == "blu")   translate([3.6, -6.2, 1.0]) cube([1.6, 0.8, 0.6]);
}

// LiPo 802535 + protezione — origine all'angolo, protezione verso y = 0
module bat_model(mat) {
    if (mat == "metallo") translate([0, 4.5, 0]) minkowski() { translate([0.8, 0.8, 0.8]) cube([bat.x - 1.6, bat.y - 4.5 - 1.6, bat.z - 1.6]); sphere(r = 0.8, $fn = 10); }
    if (mat == "giallo") translate([0.3, 0, 0.5]) cube([bat.x - 0.6, 4.6, bat.z - 1.0]);
    if (mat == "bianco") translate([4, 12, bat.z - 0.04]) cube([bat.x - 8, 16, 0.08]);
    if (mat == "rosso") translate([bat.x/2 + 1.2, -6, bat.z/2]) rotate([-90, 0, 0]) cylinder(d = 1.1, h = 6.2, $fn = 10);
    if (mat == "nero")  translate([bat.x/2 - 1.2, -6, bat.z/2]) rotate([-90, 0, 0]) cylinder(d = 1.1, h = 6.2, $fn = 10);
}

// OLED 0.96" — origine al centro del PCB, sotto del PCB a z = 0
module oled_model(mat) {
    sx = oled_size.x; sy = oled_size.y;
    gy0 = oled_glass_dy - oled_glass_m.y/2;                                   // bordo del vetro lato cavetto
    hy = sy/2 - 2.5;                                                          // fila dei pin
    if (mat == "pcb") difference() {
        translate([-sx/2, -sy/2, 0]) cube([sx, sy, oled_pcb_t]);
        for (x = [-sx/2 + 2, sx/2 - 2], y = [-sy/2 + 2, sy/2 - 2]) translate([x, y, -1]) cylinder(d = 2, h = 4, $fn = 16);
        translate([-7, -sy/2 - 1, -1]) cube([14, 2, 4]);                      // incavo del cavetto
    }
    if (mat == "vetro") translate([-oled_glass_m.x/2, gy0, oled_pcb_t]) cube([oled_glass_m.x, oled_glass_m.y, oled_glass_t]);
    if (mat == "schermo") translate([-10.87, oled_win_off - 5.43, oled_stack - 0.02]) cube([21.74, 10.86, 0.04]);
    if (mat == "nero") {
        translate([oled_hdr_x - 5.08, hy - 1.25, -2.5]) cube([10.16, 2.5, 2.5]);
        for (k = [0:6]) translate([-9.5 + k*3, -2 + (k % 2)*3, -oled_comp_h]) cube([1.6, 0.8, oled_comp_h]);   // componenti sul retro
    }
    if (mat == "oro") for (k = [0:3]) translate([oled_hdr_x - 3.81 + k*2.54 - 0.32, hy - 0.32, -8.5]) cube([0.64, 0.64, 11.5]);
    if (mat == "arancio") {
        translate([-6.5, -sy/2 + 0.4, -0.1]) cube([13, 0.6, oled_stack - 0.1]);           // cavetto che gira sul bordo
        translate([-6.5, -sy/2 + 0.4, -0.15]) cube([13, gy0 + sy/2 + 2, 0.1]);            // e prosegue sul retro
    }
}

// Encoder EC11 — origine al centro della faccia di montaggio, corpo sotto
module ec11_model(mat) {
    if (mat == "nero") translate([-6.2, -6.6, -6.5]) cube([12.4, 13.2, 3.5]);
    if (mat == "metallo") {
        translate([-6.0, -6.4, -3.0]) cube([12.0, 12.8, 3.0]);
        cylinder(d = 7, h = enc_bush);                                       // boccola M7
        translate([0, 0, t_top + 0.02]) cylinder(d = 9.6, h = 1.8, $fn = 6); // dado, sul piano
        translate([0, 0, enc_bush]) cylinder(d = 6, h = enc_shaft - enc_bush);   // albero zigrinato
        for (x = [-2.5, 0, 2.5]) translate([x - 0.4, -7.5, -10.5]) cube([0.8, 0.3, 4.5]);
        for (x = [-2.5, 2.5]) translate([x - 0.4, 7.2, -10.5]) cube([0.8, 0.3, 4.5]);
    }
}

// Switch MX con stelo box, 2 pin — origine al centro della faccia superiore della piastra
module mx_model(mat) {
    if (mat == "bianco") {
        translate([-7, -7, -sw_below]) cube([14, 14, sw_below - 0.05]);      // corpo inferiore
        translate([0, 0, -sw_below - 3.0]) cylinder(d = 4, h = 3.0, $fn = 24);   // perno centrale
    }
    if (mat == "cristallo") hull() {                                         // corpo superiore trasparente
        translate([-sw_flange.x/2, -sw_flange.y/2, 0]) cube([sw_flange.x, sw_flange.y, 0.01]);
        translate([-5.8, -6.6, 5.4]) cube([11.6, 13.2, 0.6]);
    }
    if (mat == "marrone") translate([0, 0, 6.0]) {                           // box con croce, cima a sw_top
        difference() { translate([-3.4, -3.4, 0]) cube([6.8, 6.8, sw_top - 6.0]); translate([-2.85, -2.85, 1]) cube([5.7, 5.7, 10]); }
        translate([-0.6, -2.0, 0]) cube([1.2, 4.0, sw_top - 6.0 - 0.4]);
        translate([-2.0, -0.6, 0]) cube([4.0, 1.2, sw_top - 6.0 - 0.4]);
    }
    if (mat == "metallo") { translate([-3.81 - 0.4, 2.54 - 0.4, -sw_below - 3.3]) cube([0.8, 0.8, 3.3]); translate([2.54 - 0.4, 5.08 - 0.4, -sw_below - 3.3]) cube([0.8, 0.8, 3.3]); }
}

// SS12D00 — nel sistema della parete (x = 0 faccia interna, verso l'interno +x)
module ss_model(mat) {
    if (mat == "nero") translate([0.05, ss_y - ss_body.x/2, ss_z - ss_body.y/2]) cube([ss_body.z, ss_body.x, ss_body.y]);
    if (mat == "metallo") {
        translate([0.05, ss_y - ss_body.x/2 - 0.1, ss_z - ss_body.y/2 - 0.1]) cube([ss_body.z * 0.4, ss_body.x + 0.2, ss_body.y + 0.2]);
        for (k = [-1, 0, 1]) translate([ss_body.z, ss_y + k*2.0 - 0.3, ss_z - 0.3]) cube([4, 0.6, 0.6]);
    }
    if (mat == "bianco") translate([-3 + 0.05, ss_y - 0.75, ss_z - 0.75]) cube([3, 1.5, 1.5]);
}

// componenti assiali per la vetrina: diodi e resistenza (asse lungo x)
module axial(body_d, body_l, mat, body_mat, band_mat, band_x, band_w = 0.6) {
    if (mat == body_mat) rotate([0, 90, 0]) translate([0, 0, -body_l/2]) cylinder(d = body_d, h = body_l, $fn = 24);
    if (mat == band_mat) for (bx = band_x) translate([bx, 0, 0]) rotate([0, 90, 0]) translate([0, 0, -band_w/2]) cylinder(d = body_d + 0.06, h = band_w, $fn = 24);
    if (mat == "metallo") rotate([0, 90, 0]) translate([0, 0, -14]) cylinder(d = 0.5, h = 28, $fn = 8);
}
module d1n4148(mat)  axial(1.8, 3.8, mat, "vetro_ar", "nero", [1.4]);
module d1n5819(mat)  axial(2.7, 5.2, mat, "nero", "metallo_b", [2.0], 0.8);
module r100k(mat) {
    axial(2.3, 6.0, mat, "beige", "marrone", [-1.9]);
    axial(2.3, 6.0, mat, "x", "nero", [-0.9]);
    axial(2.3, 6.0, mat, "x", "giallo", [0.1]);
    axial(2.3, 6.0, mat, "x", "oro", [1.9]);
}

// posizioni nel montato
module esp_placed(mat) esp_frame() translate([0, -esp_over - 0.1, t_bot + ledge + 0.05]) esp_model(mat);
module tp_placed(mat)  tp_frame() translate([0, -tp_over - 0.1, t_bot + ledge + 0.05]) tp_model(mat);
module bat_placed(mat) translate([bat_x0 + 0.5, bat_y0 + 0.5, t_bot + 0.05]) bat_model(mat);
module oled_placed(mat) P() translate([oled_c.x, oled_c.y, -oled_back]) oled_model(mat);
module ec11_placed(mat) P() translate([enc_c.x, enc_c.y, -t_top - 0.02]) ec11_model(mat);
module mx_placed(mat)  P() for (i = [0:2], j = [0:2]) translate([each keypos(i, j), -sw_recess]) mx_model(mat);
module ss_placed(mat)  ss_frame() ss_model(mat);

// ============================================================
// Anteprima e selezione parte (STL già orientati per la stampa)
// ============================================================
module assembly() {
    color("#202124") bottom();          // nero
    color("#2a2b2f") top_shell();       // nero
    color("#f57a1f") keycaps_placed();  // arancione
    color("#0b0c0e") oled_dummy();
    color("#f57a1f") knob_placed();     // arancione
}

if (part == "assembly") assembly();
else if (part == "top")         rotate([180, 0, 0]) translate([0, 0, -Hf]) top_shell();
else if (part == "bottom")      bottom();
else if (part == "keycap")      translate([0, 0, cap_t]) rotate([180, 0, 0]) keycap();
else if (part == "keycaps9")    for (i = [0:2], j = [0:2]) translate([i*21, j*21, cap_t]) rotate([180, 0, 0]) keycap();
else if (part == "knob")        translate([0, 0, knob_h]) rotate([180, 0, 0]) knob();
else if (part == "clamp")       clamp();
else if (part == "test_keycap") test_keycap();
else if (part == "test_switch") rotate([180, 0, 0]) test_switch();
else if (part == "test_knob")   test_knob();
else if (part == "test_insert") test_insert();
else if (part == "test_oled")   rotate([180, 0, 0]) test_oled();
// ---------- parti per il visualizzatore (coordinate di montaggio) ----------
else if (part == "v_top")      top_shell();
else if (part == "v_bottom")   bottom();
else if (part == "v_keycaps")  keycaps_placed();
else if (part == "v_knob")     P() translate([enc_c.x, enc_c.y, knob_z]) knob();
else if (part == "v_clamp")    clamp_placed();
else if (part == "comp") {                       // componente dettagliato: -D comp=... -D mat=... -D mode="a"|"g"
    if (mode == "a") {
        if (comp == "esp") esp_placed(mat);
        if (comp == "tp") tp_placed(mat);
        if (comp == "bat") bat_placed(mat);
        if (comp == "oled") oled_placed(mat);
        if (comp == "ec11") ec11_placed(mat);
        if (comp == "mx") mx_placed(mat);
        if (comp == "ss") ss_placed(mat);
    } else {
        if (comp == "esp") translate([0, esp_pcb.y/2, 0]) esp_model(mat);
        if (comp == "tp") translate([0, tp_pcb.y/2, 0]) tp_model(mat);
        if (comp == "bat") translate([-bat.x/2, -bat.y/2, 0]) bat_model(mat);
        if (comp == "oled") translate([0, 0, 8.5]) oled_model(mat);
        if (comp == "ec11") translate([0, 0, 10.5]) ec11_model(mat);
        if (comp == "mx") translate([0, 0, 8.3]) mx_model(mat);
        if (comp == "ss") translate([-ss_body.z/2 - 0.5, -ss_y, -ss_z + 2]) ss_model(mat);
        if (comp == "d4148") translate([0, 0, 1]) d1n4148(mat);
        if (comp == "d5819") translate([0, 0, 1.4]) d1n5819(mat);
        if (comp == "r100k") translate([0, 0, 1.2]) r100k(mat);
    }
}
// ---------- verifiche di collisione: devono risultare vuote ----------
else if (part == "chk_top")  intersection() { top_shell(); union() { all_dummies(); clamp_placed(); knob_placed(); keycaps_placed(0); keycaps_placed(travel); } }
else if (part == "chk_bot")  intersection() { bottom(); all_dummies(); }
else if (part == "chk_fit")  intersection() { bottom(); translate([0, 0, 0.01]) top_shell(); }
else if (part == "chk_comp") {
    intersection() { switches_dummy(false); union() { bat_dummy(); esp_dummy(); tp_dummy(); ss_dummy(); } }
    intersection() { union() { oled_dummy(); enc_dummy(); clamp_placed(); } union() { esp_dummy(); tp_dummy(); bat_dummy(); ss_dummy(); } }
    intersection() { oled_dummy(); enc_dummy(); }
    intersection() { oled_dummy(); clamp_placed(); }
    intersection() { union() { esp_dummy(); tp_dummy(); } union() { bat_dummy(); ss_dummy(); } }
    intersection() { esp_dummy(); tp_dummy(); }
}
