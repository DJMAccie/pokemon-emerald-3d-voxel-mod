#!/usr/bin/env python3
"""Every Gen 1-3 species in the overworld: place the ones Emerald's own wild tables lack.

  1. dump the facts:  EM_DRIVER=tools/drivers/em_coverage_driver.lua QA_LIMIT=200 tools/qa_tryp.sh "" /tmp/cov "-" 4 0 60
  2. generate:        python3 tools/wild_extras.py /tmp/cov/run.log          -> mod/wilds/data/wild_extras.lua
  3. check only:      python3 tools/wild_extras.py /tmp/cov/run.log --report

Rules (all deterministic, no randomness):
- a species is "missing" when no EM_ map's land/water slots hold it; each gets 1-4 maps (more when common);
- a map has a habitat (meadow, forest, cave, ...) and a terrain (land/water, sea/fresh); a species' types score each habitat;
- level fit: the species' natural level (evolution chain) must not be far above the map's own level band;
- the 21 legendaries/mythicals are "unique": one fixed map each (LEGENDS), low weight, never again once caught.
The runtime (mod/wilds/lib/gen3/init.lua `sample`) appends these rows to the map's own slots with their weight.
"""
import re, sys, os, collections, zlib

T = {0:'normal',1:'fighting',2:'flying',3:'poison',4:'ground',5:'rock',6:'bug',7:'ghost',8:'steel',9:'?',
     10:'fire',11:'water',12:'grass',13:'electric',14:'psychic',15:'ice',16:'dragon',17:'dark'}

# habitat -> type -> score (0 = does not live there)
HAB = {
 'meadow':  dict(normal=3, flying=2, grass=3, bug=2, electric=2, fighting=1, fire=1, poison=1, psychic=1, ground=1, dark=1, fairy=1),
 'forest':  dict(bug=3, grass=3, poison=2, flying=2, normal=1, psychic=1, fighting=1, dark=1),
 'mountain':dict(rock=3, ground=3, fighting=2, fire=2, flying=2, steel=3, normal=1, dragon=2, electric=1),
 'desert':  dict(ground=3, rock=2, fire=2, grass=1, bug=1, dark=1, normal=1, poison=1, psychic=1),
 'ash':     dict(fire=2, ground=2, rock=2, normal=1, grass=1),
 'cave':    dict(rock=3, ground=3, poison=2, bug=1, steel=2, fighting=2, ghost=1, dark=2, normal=1, flying=1, psychic=1, dragon=1, ice=1),
 'volcano': dict(fire=3, rock=2, ground=2, steel=1, poison=1, dark=1),
 'grave':   dict(ghost=4, dark=3, poison=2, psychic=2),
 'sky':     dict(flying=3, dragon=3, psychic=1, normal=1),
 'electric':dict(electric=4, steel=2, normal=1, poison=1),
 'ice':     dict(ice=4, rock=1, psychic=1, flying=1, water=1),
 'seacave': dict(dark=3, poison=2, ghost=2, rock=2, water=1, ground=1),
 'meteor':  dict(dragon=3, rock=2, ground=2, steel=2, psychic=1, fighting=1, flying=1, normal=1),
 'victory': dict(fighting=3, rock=2, ground=2, dragon=2, dark=2, steel=2, normal=1, poison=1, psychic=1, ghost=1, flying=1),
 'ruins':   dict(psychic=3, ground=2, rock=2, ghost=2, normal=1),
 'safari':  dict(normal=3, grass=2, bug=2, flying=2, ground=2, rock=1, poison=1, psychic=2, fighting=2, electric=1, fire=1, dark=1),
 'sea':     dict(water=4),
 'fresh':   dict(water=4),
}

def habitats(mid, terrain):
    """habitat tags of an EM_ map for land/water"""
    n = mid[3:]
    if terrain == 'water':
        return None  # sea/fresh is decided from the map's own slots
    pat = [
     (r'^ROUTE10[123]$|^ROUTE110$|^ROUTE117$|^ROUTE118$|^ROUTE121$|^ROUTE123$|^ROUTE130$', ['meadow']),
     (r'^ROUTE104$|^ROUTE116$|^ROUTE119$|^ROUTE120$|^PETALBURG_WOODS$', ['forest']),
     (r'^ROUTE111$', ['desert', 'mountain']), (r'^ROUTE112$|^ROUTE115$', ['mountain']), (r'^ROUTE113$', ['ash']),
     (r'^ROUTE114$', ['forest', 'mountain']),
     (r'^DESERT_UNDERPASS$', ['desert']), (r'^MIRAGE_TOWER', ['desert', 'ruins']),
     (r'^FIERY_PATH$|^MAGMA_HIDEOUT', ['volcano']), (r'^JAGGED_PASS$', ['mountain', 'volcano']),
     (r'^METEOR_FALLS', ['meteor', 'cave']), (r'^MT_PYRE_EXTERIOR$', ['mountain', 'grave']), (r'^MT_PYRE', ['grave']),
     (r'^NEW_MAUVILLE', ['electric']), (r'^SAFARI_ZONE', ['safari']), (r'^SEAFLOOR_CAVERN', ['seacave']),
     (r'^SHOAL_CAVE_LOW_TIDE_ICE_ROOM$', ['ice']), (r'^SHOAL_CAVE', ['seacave', 'ice']),
     (r'^SKY_PILLAR', ['sky']), (r'^VICTORY_ROAD', ['victory', 'cave']),
     (r'^CAVE_OF_ORIGIN', ['ruins', 'cave']),
     (r'CAVE|TUNNEL|ARTISAN|GRANITE|RUSTURF', ['cave']),
    ]
    for rx, tags in pat:
        if re.search(rx, n):
            return tags
    return ['meadow']

SEA_BASE = {72, 73, 278, 279, 320, 321, 370}
SEA = {72,73,86,87,90,91,98,99,116,117,120,121,131,138,139,140,141,170,171,222,223,224,226,230,211,278,279,318,319,
       320,321,363,364,365,366,367,368,369,370}
FRESH = {54,55,60,61,62,118,119,183,184,186,194,195,158,159,160,258,259,260,270,271,272,283,339,340,341,342,349,350}

# unique species: nat -> (map, terrain, level)
LEGENDS = {
 144:('EM_SHOAL_CAVE_LOW_TIDE_ICE_ROOM','land',50), 145:('EM_NEW_MAUVILLE_INSIDE','land',50), 146:('EM_FIERY_PATH','land',50),
 150:('EM_ARTISAN_CAVE_B1F','land',70), 151:('EM_SAFARI_ZONE_NORTH','land',30),
 243:('EM_ROUTE120','land',40), 244:('EM_ROUTE113','land',40), 245:('EM_ROUTE119','water',40),
 249:('EM_SEAFLOOR_CAVERN_ROOM8','land',70), 250:('EM_SKY_PILLAR_3F','land',70), 251:('EM_PETALBURG_WOODS','land',30),
 377:('EM_DESERT_UNDERPASS','land',40), 378:('EM_SHOAL_CAVE_LOW_TIDE_LOWER_ROOM','land',40), 379:('EM_MIRAGE_TOWER_4F','land',40),
 380:('EM_ROUTE118','land',40), 381:('EM_ROUTE121','land',40),
 382:('EM_SEAFLOOR_CAVERN_ROOM7','water',70), 383:('EM_MAGMA_HIDEOUT_4F','land',70), 384:('EM_SKY_PILLAR_5F','land',70),
 385:('EM_METEOR_FALLS_1F_2R','land',30), 386:('EM_METEOR_FALLS_B1F_2R','land',30),
}
LEGEND_WEIGHT = 2          # of ~100 base weight: a few percent of the rolls, and only while uncaught
CAP_WEIGHT = {'land': 45, 'water': 40}   # extras per map and terrain stay below ~30% of the rolls
CAP_ROWS = 12                            # and a map never lists more than this many extra species (uniques not counted)

def parse(log):
    sp, maps = {}, {}
    for line in open(log, errors='replace'):
        if line.startswith('[cov-sp]\t'):
            f = line.rstrip('\n').split('\t')
            if 'NO INTERNAL ID' in line:
                continue
            n = int(f[1]); st = dict(kv.split('=') for kv in f[6].split(','))
            evos = []
            for e in (f[8].split(';') if len(f) > 8 and f[8] else []):
                m, p, t = e.split(':'); evos.append((int(m), int(p), int(t)))
            sp[n] = dict(n=n, name=f[3], t=(T.get(int(f[4]), '?'), T.get(int(f[5]), '?')),
                         bst=sum(int(v) for v in st.values()), catch=int(f[7].split('=')[1]), evos=evos)
        elif line.startswith('[cov-map]\t'):
            f = line.rstrip('\n').split('\t')
            slots = [tuple(int(x) for x in s.split(':')) for s in f[3].split()]
            maps.setdefault(f[1], {})[f[2]] = slots
    return sp, maps

def natural_levels(sp):
    pre = {}
    for n, s in sp.items():
        for m, p, t in s['evos']:
            pre.setdefault(t, []).append((n, m, p))
    memo = {}
    def L(n):
        if n in memo: return memo[n]
        memo[n] = 2
        s = sp[n]; evolves = bool(s['evos'])
        if n in pre:
            src, m, p = pre[n][0]
            base = L(src)
            lv = p if m in (4, 8, 9, 10, 11, 12, 13, 14) and p > 0 else {1: 25, 2: 25, 3: 25, 5: 32, 6: 34, 7: 26, 15: 30}.get(m, 30)
            memo[n] = min(60, max(base, lv))
        else:
            b = s['bst']
            memo[n] = max(2, round((b - 300) / 4)) if evolves and b > 330 else 2 if evolves else max(2, round((b - 250) / 6.5))
            memo[n] = min(60, memo[n])
        return memo[n]
    return {n: L(n) for n in sp}

def affinity(types, hab):
    w = HAB[hab]
    a = sorted((w.get(t, 0) for t in types if t != '?'), reverse=True)
    return (a[0] + 0.3 * (a[1] if len(a) > 1 else 0)) if a else 0

def water_kind(slots):
    return 'sea' if any(s[0] in SEA_BASE for s in slots) else 'fresh'

def build(sp, maps):
    lv = natural_levels(sp)
    have = collections.defaultdict(set)
    for mid, a in maps.items():
        for terr, slots in a.items():
            for s in slots: have[s[0]].add(mid)
    skip = re.compile(r'STEVENS|UNUSED|HIDDEN_FLOOR')
    cands = []  # (mid, terrain, tags/kind, lo, hi)
    for mid, a in sorted(maps.items()):
        if skip.search(mid): continue
        for terr, slots in a.items():
            los = [s[1] for s in slots]; his = [s[2] for s in slots]
            lo, hi = min(los), max(his)
            if terr == 'land': cands.append((mid, 'land', habitats(mid, 'land'), lo, hi))
            else: cands.append((mid, 'water', [water_kind(slots)], lo, hi))
    load = collections.Counter(); wsum = collections.Counter()
    out = collections.defaultdict(lambda: {'land': [], 'water': []})
    placed = {}
    # uniques first, so the caps count them
    for n, (mid, terr, level) in LEGENDS.items():
        if n not in sp: continue
        out[mid][terr].append((n, level, level, LEGEND_WEIGHT)); wsum[(mid, terr)] += LEGEND_WEIGHT
        placed.setdefault(n, []).append((mid, terr))
    missing = sorted(n for n in sp if n not in have and n not in LEGENDS)
    # rarest/strongest first so the hard-to-place species get their choice of maps
    missing.sort(key=lambda n: (-lv[n], sp[n]['catch'], n))
    for n in missing:
        s = sp[n]; types = s['t']; L0 = lv[n]
        aquatic = 'water' in types
        k = 4 if s['catch'] >= 150 else 3 if s['catch'] >= 75 else 2 if s['catch'] >= 45 else 1
        if L0 >= 40: k = min(k, 2)
        scored = []
        for mid, terr, tags, lo, hi in cands:
            if aquatic != (terr == 'water'): continue
            if terr == 'water':
                kind = tags[0]
                if kind == 'sea' and n in FRESH: continue
                if kind == 'fresh' and n in SEA: continue
                a = 3.0
            else:
                a = max(affinity(types, t) for t in tags)
                if a < 1: continue
            mid_lv = (lo + hi) / 2
            fit = -abs(mid_lv - L0) / 10.0
            if L0 > hi + 4: fit -= (L0 - hi - 4) / 2.0      # too strong for this map
            if lo - L0 > 14: fit -= (lo - L0 - 14) / 2.0    # far too weak for this map
            scored.append((a * 2 + fit - 0.6 * load[(mid, terr)] - (0.01 * (zlib.crc32(('%d:%s' % (n, mid)).encode()) % 7)), mid, terr, lo, hi))
        if not scored:   # nothing matches the habitat: the safari zones take anything
            for mid, terr, tags, lo, hi in cands:
                if terr == ('water' if aquatic else 'land') and (terr == 'water' or 'safari' in tags):
                    scored.append((-load[(mid, terr)], mid, terr, lo, hi))
        scored.sort(key=lambda x: (-x[0], x[1]))
        relaxed_order = sorted(scored, key=lambda x: (-x[4], x[1]))   # strongest map first when the level fits nowhere
        w = 3 if s['catch'] >= 120 and L0 < 30 else 2 if s['catch'] >= 45 else 1
        picked = 0
        for strict in (True, False):   # first only maps whose level band fits; if none does, the strongest map there is
            if strict is False and picked: break
            for sc, mid, terr, lo, hi in (scored if strict else relaxed_order):
                if picked >= (k if strict else 1): break
                if strict and (L0 > hi + 6 or lo - L0 > 22): continue
                if not strict and L0 <= hi + 6: continue
                if wsum[(mid, terr)] + w > CAP_WEIGHT[terr] or load[(mid, terr)] >= CAP_ROWS: continue
                lo2 = max(lo, L0); hi2 = max(lo2, min(hi, lo2 + 4)) if L0 <= hi else lo2 + 3
                out[mid][terr].append((n, lo2, hi2, w)); wsum[(mid, terr)] += w; load[(mid, terr)] += 1
                placed.setdefault(n, []).append((mid, terr)); picked += 1
        if not picked:  # every fitting map is full: take the emptiest map of the right terrain anyway
            sc, mid, terr, lo, hi = max(scored, key=lambda x: (-wsum[(x[1], x[2])], x[0]))
            lo2 = max(lo, L0)
            out[mid][terr].append((n, lo2, lo2 + 3, w)); wsum[(mid, terr)] += w; load[(mid, terr)] += 1
            placed.setdefault(n, []).append((mid, terr))
    return out, placed, have, lv

def write(out, path):
    lines = ['-- Generated by tools/wild_extras.py (do not edit by hand; edit the rules and re-run).',
             '-- Every Gen 1-3 species Emerald\'s own wild tables lack, per map: {national dex number, min level, max level, weight}.',
             '-- unique = species that stay one at a time and never spawn again once caught.',
             'return {', ' unique={' + ','.join('[%d]=true' % n for n in sorted(LEGENDS)) + '},', ' maps={']
    for mid in sorted(out):
        parts = []
        for terr in ('land', 'water'):
            rows = out[mid][terr]
            if rows: parts.append('%s={%s}' % (terr, ','.join('{%d,%d,%d,%d}' % r for r in sorted(rows))))
        if parts: lines.append('  %s={%s},' % (mid, ','.join(parts)))
    lines += [' },', '}']
    open(path, 'w').write('\n'.join(lines) + '\n')

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if not args: sys.exit(__doc__)
    sp, maps = parse(args[0])
    out, placed, have, lv = build(sp, maps)
    allsp = set(have) | set(placed)
    missing = [n for n in range(1, 387) if n in sp and n not in allsp]
    ents = sum(len(v['land']) + len(v['water']) for v in out.values())
    print('species with facts: %d; base tables cover %d; extras add %d; union %d of 386; still missing %s'
          % (len(sp), len([n for n in have if 1 <= n <= 386]), len(placed), len(allsp & set(range(1, 387))), missing))
    print('extra rows %d on %d maps; per-map rows min/max: %s' % (ents, len(out),
          (min(len(v['land']) + len(v['water']) for v in out.values()), max(len(v['land']) + len(v['water']) for v in out.values()))))
    if '--report' in sys.argv:
        for mid in sorted(out):
            for terr in ('land', 'water'):
                if out[mid][terr]:
                    print(mid, terr, ' '.join('%s%d:%d-%d/w%d' % (sp[r[0]]['name'].title(), r[0], r[1], r[2], r[3]) for r in sorted(out[mid][terr])))
        return
    dest = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'mod', 'wilds', 'data', 'wild_extras.lua')
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    write(out, dest)
    print('wrote', os.path.normpath(dest), os.path.getsize(dest), 'bytes')

if __name__ == '__main__':
    main()
