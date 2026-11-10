#!/bin/bash
# Build the one player zip: release/emerald_3d_voxel_mod-<x.y.z>.zip holding a single folder with the mod.
#   tools/build_release.sh [out.zip] [x.y.z]
# Committed files come from HEAD; the art that never goes in git (Fly sheets, world fill, overworld sprites)
# is copied from disk. The game reads the folder name as the mod id, so it must stay emerald_3d_voxel_mod.
set -eu
E="$(cd "$(dirname "$0")/.." && pwd)"
ID=emerald_3d_voxel_mod
VER="${2:-$(sed -n 's/.*"version": *"\([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p' "$E/mod/manifest.json" | head -1)}"
[ -n "$VER" ] || { echo "no version in mod/manifest.json (or pass x.y.z)"; exit 1; }
# No release from a red tree: lint + mod tests (2 s), then the battle-model tests (~50 s). EM_SKIP_TESTS=1 skips.
if [ -z "${EM_SKIP_TESTS:-}" ]; then
  out=$(cd "$E/mod" && tools/run_tests.sh "$E/gen1recomp" 2>&1) || { printf '%s\n' "$out" | grep -Ev '^PASS'; exit 1; }
  out=$("$E/mod/models/tools/run_tests.sh" "$E/gen1recomp" 2>&1) || { printf '%s\n' "$out" | grep -Ev '^PASS'; exit 1; }
fi
OUT="${1:-$E/release/$ID-$VER.zip}"; mkdir -p "$(dirname "$OUT")"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
W="$(mktemp -d)"; trap 'rm -r "$W"' EXIT
mkdir -p "$W/$ID"
git -C "$E" archive HEAD mod | tar -x -C "$W/$ID" --strip-components=1 \
  --exclude='tests' --exclude='tools' --exclude='.gitignore' --exclude='.modkitignore'
find "$W/$ID" -name '*.md' ! -name 'THIRD_PARTY_NOTICES.md' ! -name 'NOTICE.md' ! -name 'README.md' -delete
# mod/.gitignore keeps these two out of git; without them Fly has no sheets and no world fill.
rsync -a --exclude __pycache__ --exclude .DS_Store "$E/mod/assets/" "$W/$ID/assets/"
rsync -a --exclude __pycache__ --exclude .DS_Store "$E/mod/wilds/assets/" "$W/$ID/wilds/assets/"
cp "$E/LICENSE" "$W/$ID/LICENSE"
rm -f "$OUT"; (cd "$W" && zip -qr -X "$OUT" "$ID" -x '*.DS_Store')
echo "$OUT $(du -h "$OUT" | cut -f1)"
