#!/usr/bin/env python3
"""deskew_corners.py: straighten the bevelled front corners of the Pokemon Center and Mart models.

The drawing shows the two front corner panels (columns 0-7 and 56-63) obliquely: every line on them climbs one pixel
per column towards the outside. The model has real 45-degree corners, so each corner column takes its own art column
shifted down by that climb: lines run level and the panel's base line sits on the ground. Safe to run twice."""
import re, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[2] / 'mod/data/buildings'
W, BEVEL, TOP = 64, 8, 25  # picture width, corner columns, first eave row (those rows copy the front, already level)
for name in ('pokemon_center', 'poke_mart'):
    path = ROOT / (name + '.lua'); s = path.read_text()
    a = s.index('quads={') + 7; b = s.index('}', a)
    tok = list(re.finditer(r'-?\d+', s[a:b])); out = []; last = 0; changed = 0
    for i in range(0, len(tok), 10):
        f, x0, x1, h0, h1, z0, z1, px, py, shade = (int(t.group()) for t in tok[i:i + 10])
        col = x0 - 1 if f == 4 else x0          # the voxel column this face belongs to
        c = col if col < BEVEL else W - 1 - col  # 0 = outer edge, 7 = where the front wall starts
        corner = c < BEVEL and z0 > -BEVEL - 1 and h0 < TOP and h1 == h0 + 1 and px == col and (f == 1 or (f == 5 and 0 < x0 < BEVEL) or (f == 4 and x0 > W - BEVEL))
        if corner and py != W - BEVEL + c - h0:
            t = tok[i + 8]; out.append(s[a + last:a + t.start()]); out.append(str(W - BEVEL + c - h0)); last = t.end(); changed += 1
    out.append(s[a + last:b])
    path.write_text(s[:a] + ''.join(out) + s[b:])
    print(name, changed, 'faces repainted')
