"""Contact sheet + frame-time table for tools/stack_sweep.sh.

python3 tools/stack_sheet.py <outdir>
Reads <outdir>/g*/run.log ([EM perf] lines) and <outdir>/g*/<MAP>_<level>_<style>.png.
Writes <outdir>/perf.txt (one row per map: ms per style, speed-up) and <outdir>/sheet.png
(one row per map, one column per style, the centre of each shot at half size).
"""
import glob, os, re, sys
from PIL import Image, ImageChops, ImageDraw

out = sys.argv[1]
perf = {}  # map -> style -> (mean, median, p95)
styles = []
for log in sorted(glob.glob(os.path.join(out, 'g*', 'run.log'))):
    for line in open(log, errors='replace'):
        m = re.search(r'\[EM perf\] (\S+) (\S+) level (\d+) mean ([\d.]+) median ([\d.]+) p95 ([\d.]+)', line)
        if m:
            mp, st = m.group(1), m.group(2)
            perf.setdefault(mp, {})[st] = tuple(float(m.group(k)) for k in (4, 5, 6))
            if st not in styles:
                styles.append(st)

rows = ['map'.ljust(28) + ''.join(f'{s} median ms'.rjust(22) for s in styles) + '   speed-up']
for mp, d in perf.items():
    line = mp.ljust(28) + ''.join((f'{d[s][1]:.1f}' if s in d else '-').rjust(22) for s in styles)
    if len(styles) >= 2 and styles[0] in d and styles[1] in d:
        line += f'   {d[styles[0]][1] / d[styles[1]][1]:.2f}x'
    rows.append(line)
open(os.path.join(out, 'perf.txt'), 'w').write('\n'.join(rows) + '\n')
print('\n'.join(rows))

shots = {}
for p in glob.glob(os.path.join(out, 'g*', '*.png')):
    m = re.match(r'(.+)_(\d+)_([a-z]+)\.png$', os.path.basename(p))
    if m:
        shots.setdefault(m.group(1), {})[m.group(3)] = p
if not shots:
    sys.exit('no shots')
W, H = 640, 280  # the middle band of a 1280x720 shot, at half size
names = sorted(shots)
cols = styles or sorted({s for d in shots.values() for s in d})
diff = len(cols) == 2  # a third column: where the two styles differ, in red over a grey copy
ncol = len(cols) + (1 if diff else 0)
sheet = Image.new('RGB', (W * ncol, (H + 18) * len(names)), (20, 20, 20))
draw = ImageDraw.Draw(sheet)
for r, mp in enumerate(names):
    for c, st in enumerate(cols):
        p = shots[mp].get(st)
        if not p:
            continue
        im = Image.open(p).convert('RGB').crop((0, 160, 1280, 720))
        im = im.resize((W, H), Image.NEAREST)
        sheet.paste(im, (c * W, r * (H + 18) + 18))
        ms = perf.get(mp, {}).get(st)
        draw.text((c * W + 4, r * (H + 18) + 3), f'{mp}  {st}' + (f'  {ms[1]:.1f} ms' if ms else ''), fill=(255, 255, 255))
    if diff and all(shots[mp].get(st) for st in cols):
        a, b = (Image.open(shots[mp][st]).convert('RGB').crop((0, 160, 1280, 720)) for st in cols)
        d = ImageChops.difference(a, b).convert('L').point(lambda v: 255 if v > 24 else 0)
        base = b.convert('L').convert('RGB').point(lambda v: v // 2)
        base.paste((255, 40, 40), mask=d)
        sheet.paste(base.resize((W, H), Image.NEAREST), (len(cols) * W, r * (H + 18) + 18))
        share = d.histogram()[255] / (d.width * d.height)
        draw.text((len(cols) * W + 4, r * (H + 18) + 3), f'diff {share * 100:.1f}% of pixels', fill=(255, 255, 255))
sheet.save(os.path.join(out, 'sheet.png'))
print('sheet', os.path.join(out, 'sheet.png'))
