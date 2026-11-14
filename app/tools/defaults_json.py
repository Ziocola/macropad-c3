#!/usr/bin/env python3
"""Legge le pagine predefinite dal firmware (keymap.h, keycodes.h, config.h)
e scrive DefaultConfig.swift, così l'app parte con la stessa configurazione del macropad."""
import json, os, re, sys

here = os.path.dirname(os.path.abspath(__file__))
fw = os.path.join(here, '..', '..', 'firmware', 'src')
out = os.path.join(here, '..', 'Sources', 'MacropadConfig', 'DefaultConfig.swift')

def strip(c): return re.sub(r'//[^\n]*', '', c)
ns = {}
for f in ('keycodes.h', 'config.h'):
    for name, val in re.findall(r'#define\s+(\w+)\s+([^\s/]+)', open(os.path.join(fw, f)).read()):
        try: ns[name] = int(val.rstrip('UL').rstrip('f'), 0)
        except ValueError: pass

def act(l, t, m=None, w=None, u=None):
    a = {'l': l, 't': t}
    if m is not None: a['m'], a['w'] = list(m), list(w)
    if u is not None: a['u'] = u
    return a
ns.update(
    KEY=lambda l, m, k: act(l, 1, (m, k), (m, k)),
    OS=lambda l, mm, mk, wm, wk: act(l, 1, (mm, mk), (wm, wk)),
    MEDIA=lambda l, u: act(l, 2, u=u),
    WHEEL=lambda n: act('', 3, u=n),
    KNOB_KEYS=lambda l, cw, ccw: (l, cw, ccw),
)
ns['NONE'] = act('', 0)
ns['KNOB_MEDIA'] = ('Volume', act('', 2, u=ns['M_VOL_UP']), act('', 2, u=ns['M_VOL_DOWN']))
ns['KNOB_SCROLL'] = ('Scorri', act('', 3, u=-1), act('', 3, u=1))

src = strip(open(os.path.join(fw, 'keymap.h')).read())
body = re.search(r'DEFAULT_PAGES\[\]\s*=\s*\{(.*)\};', src, re.S).group(1)
pages = eval('[' + body.replace('{', '(').replace('}', ')') + ']', ns)
cfg = {'v': 1,
       'set': {'rev': bool(ns['ENC_REVERSE']), 'rot': bool(ns['OLED_ROTATE']), 'steps': ns['ENC_STEPS'],
               'disp': ns['DISPLAY_OFF_S'], 'sleep': ns['SLEEP_MIN']},
       'pages': [{'n': n, 'k': list(k), 'kl': kn[0], 'cw': kn[1], 'ccw': kn[2]} for n, k, kn in pages]}
js = json.dumps(cfg, ensure_ascii=False)
open(out, 'w').write('// Generato da tools/defaults_json.py a partire da firmware/src/keymap.h: non modificare a mano.\n'
                     'let defaultConfigJSON = #"' + js + '"#\n')
print(f"{len(cfg['pages'])} pagine -> {out}")
