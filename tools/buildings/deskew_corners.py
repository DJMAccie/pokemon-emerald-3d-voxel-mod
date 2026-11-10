#!/usr/bin/env python3
"""deskew_corners.py: straighten the bevelled corner panels of building models (mod/data/buildings).

The drawings show a bevelled corner obliquely: every line on the panel climbs one pixel per column towards the
outside. The models have real 45-degree stepped corners, so each corner column takes its own art column shifted
down by that climb: lines run level and the panel's base line sits on the ground. Safe to run twice.
Quads are f,x0,x1,h0,h1,z0,z1,px,py,shade (f: 1 south 2 north 3 top 4 east 5 west; z 0 = front, negative = back)."""
import re, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2] / 'mod/data/buildings'
SHADE = 80  # one shade for both faces of a step, so the corner reads as one surface

def center(P):   # Pokemon Center, Mart: corner columns 0-7 and 56-63, rows 25+ copy the front and are level already
    def paint(f, col, z0, h, px):
        c = min(col, 63 - col)
        if c < 8 and z0 > -9 and h < 25 and px == col and (f == 1 or (f == 5 and col > 0) or (f == 4 and col < 63)):
            return col, 56 + c - h
    return paint

def gym(P):      # porch sides: columns 40-47 and 64-71; above the door line (h 20) the canopy bands of the front
    def paint(f, col, z0, h, px):
        c = col if col < 56 else 111 - col
        if not (40 <= c <= 47 and z0 >= -8 and h < 30): return
        if not ((f == 1 and -6 <= z0 <= -1) or (f == 5 and col < 56) or (f == 4 and col > 56)): return
        if h <= 20: return col, min(P - 1, P - 47 + c - h)
        return (49 if col < 56 else 62), P - 1 - h
    return paint

def contest(P):  # Lilycove contest hall: front corner columns 1-7 and 104-110
    def paint(f, col, z0, h, px):
        c = min(col, 111 - col)
        if 1 <= c <= 6 and z0 >= -8 and h < 32 and ((f == 1 and -6 <= z0 <= -1) or (f == 5 and col < 56) or (f == 4 and col > 56)):
            return col, min(P - 1, P - 8 + c - h)
    return paint

MODELS = {'pokemon_center': center, 'poke_mart': center, 'b048_lilycovecity_contestlobby': contest}
for g in ('b003_petalburgcity', 'b017_mauvillecity', 'b024_rustborocity', 'b037_fortreecity', 'b057_mossdeepcity',
          'b068_sootopoliscity', 'b089_dewfordtown', 'b093_lavaridgetown'): MODELS[g + '_gym'] = gym

for name, family in MODELS.items():
    path = ROOT / (name + '.lua'); s = path.read_text()
    y0, y1 = (int(re.search(k + r'=(\d+)', s).group(1)) for k in ('y0', 'y1'))
    paint = family((y1 - y0 + 1) * 16)
    a = s.index('quads={') + 7; b = s.index('}', a)
    n = [int(t) for t in re.findall(r'-?\d+', s[a:b])]; out = []; changed = 0
    for i in range(0, len(n), 10):
        f, x0, x1, h0, h1, z0, z1, px, py, shade = n[i:i + 10]
        cols = range(x0, x1) if f == 1 else [x0 - 1] if f == 4 else [x0] if f == 5 else []
        new = [(col, h, paint(f, col, z0, h, px)) for col in cols for h in range(h0, h1)]
        if not any(p for _, _, p in new): out += n[i:i + 10]; continue
        for col, h, p in new:
            xa, xb = (col, col + 1) if f == 1 else (x0, x1)
            q = [f, xa, xb, h, h + 1, z0, z1, p[0], p[1], SHADE] if p else [f, xa, xb, h, h + 1, z0, z1, px, py, shade]
            changed += q != n[i:i + 10]; out += q
    if changed:
        rows = [','.join(map(str, out[k:k + 60])) for k in range(0, len(out), 60)]
        path.write_text(s[:a] + '\n ' + ',\n  '.join(rows) + s[b:])
    print(name, changed, 'faces repainted')
