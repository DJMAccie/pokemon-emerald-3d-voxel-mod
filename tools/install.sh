#!/bin/bash
# Zet de mod (de map mod/ van deze repo) in het echte spel en in de testkopie.
#   tools/install.sh          installeren
#   tools/install.sh --check  alleen controleren of spel en testkopie gelijk zijn aan de bron
# Weigert zolang het spel (of een testrun) draait: het spel schrijft bij afsluiten zijn bestanden terug.
set -eu
E="$(cd "$(dirname "$0")/.." && pwd)"
AS="$HOME/Library/Application Support"
TARGETS=("$AS/pokemon-love2d" "$AS/pokemon-love2d-rseqa")
ID="emerald_3d_voxel_mod"
# Deze mod heette eerder anders en zat in losse mappen; alles wat nog naar deze repo wijst
# (manifest github) verhuist mee, een map van een andere mod blijft staan.
LEGACY_RE='"github"[[:space:]]*:[[:space:]]*"DJMAccie/(Emerald|pokemon-emerald-3d-voxel-mod)"'
legacy(){ for d in "$1"/mods/*/; do
  [ -d "$d" ] || continue
  if [ "$(basename "$d")" = "$ID" ]; then continue; fi
  grep -Eq "$LEGACY_RE" "$d/manifest.json" 2>/dev/null || continue
  printf "%s\n" "$d"
done; }
# baseroms/ en colosseum/ zijn lokale ROM-gegevens in de spelmap: nooit kopieren of wissen.
OPTS=(-a --delete --exclude .gitignore --exclude .modkitignore --exclude /docs --exclude /tests --exclude /tools
      --exclude /baseroms --exclude /colosseum --exclude __pycache__ --exclude .DS_Store
      --include '*/THIRD_PARTY_NOTICES.md' --include '*/NOTICE.md' --exclude '*.md')
if [ "${1:-}" = "--check" ]; then
  bad=0
  for t in "${TARGETS[@]}"; do
    changes=$(rsync -n -c "${OPTS[@]}" --itemize-changes "$E/mod/" "$t/mods/$ID/") || { bad=1; continue; }
    n=$(printf '%s\n' "$changes" | awk 'NF && !/^\.d/ {n++} END {print n+0}')
    echo "$(basename "$t") $ID: $n verschillen"; [ "$n" = 0 ] || bad=1
  done
  exit $bad
fi
# Geen installatie met rode tests of lint (2 s). EM_SKIP_TESTS=1 slaat dit over.
if [ -z "${EM_SKIP_TESTS:-}" ] && [ -d "$E/gen1recomp" ]; then
  out=$(cd "$E/mod" && tools/run_tests.sh "$E/gen1recomp" 2>&1) || {
    printf '%s\n' "$out" | grep -Ev '^PASS'; echo "Tests rood: niet geinstalleerd (cd mod && tools/run_tests.sh ../gen1recomp)."; exit 1; }
fi
if pgrep -f "MacOS/love" >/dev/null; then echo "Het spel (of een testrun) draait: sluit het eerst."; exit 1; fi
for t in "${TARGETS[@]}"; do
  mkdir -p "$t/mods/$ID"
  legacy "$t" | while IFS= read -r old; do
    for keep in baseroms colosseum; do
      if [ -d "$old/$keep" ] && [ ! -d "$t/mods/$ID/$keep" ]; then mv "$old/$keep" "$t/mods/$ID/$keep"; fi
    done
    rm -rf "$old"
    echo "weg: $(basename "$t")/mods/$(basename "$old") (zit nu in $ID)"
  done
  rsync "${OPTS[@]}" "$E/mod/" "$t/mods/$ID/"
done
"$0" --check && echo "Geinstalleerd: $(git -C "$E" log -1 --format='%h %s')"
