#!/bin/bash
# Sprite-stack sweep over the whole world: per map one shot per tree style and the frame time.
#   tools/stack_sweep.sh <outdir> [level=7] [mapset=world]
# Edit mod/lib (or point QA_SRC at a probe copy), run this, open <outdir>/sheet.png and <outdir>/perf.txt.
# One QA game at a time by default, so the frame times are fair (games share the GPU); about 15 min.
# SWEEP_PAR=4 runs the four groups at once (fast, for looks only: the times are then not comparable).
# EM_PERF_STYLES (default modeled,stacked) and EM_PERF_FRAMES (default 200) pass through to the driver.
set -u
OUT=$1; LEVEL=${2:-7}; SET=${3:-world}
E="$(cd "$(dirname "$0")/.." && pwd)"
FILES=${SWEEP_FILES:-"NativeTreeArt.lua VoxelHull.lua TreePresentation.lua Gen3Outdoor.lua Gen3Scene.lua Gen3Objects.lua"} # the lib files under test
case "$SET" in
 world) MAPSETS=(
  "{'EM_LITTLEROOT_TOWN',10,8},{'EM_ROUTE101',10,10},{'EM_OLDALE_TOWN',10,10},{'EM_ROUTE102',20,10}"
  "{'EM_PETALBURG_CITY',15,15},{'EM_PETALBURG_WOODS',26,22},{'EM_RUSTBORO_CITY',16,30},{'EM_ROUTE104',20,40}"
  "{'EM_FORTREE_CITY',20,10},{'EM_ROUTE119',20,60},{'EM_ROUTE120',20,30},{'EM_LILYCOVE_CITY',30,15}"
  "{'EM_ROUTE110',15,40},{'EM_MAUVILLE_CITY',20,10},{'EM_EVER_GRANDE_CITY',18,41},{'EM_ROUTE123',40,10}") ;;
 quick) MAPSETS=("{'EM_LITTLEROOT_TOWN',10,8}" "{'EM_ROUTE101',10,10}" "{'EM_PETALBURG_WOODS',26,22}" "{'EM_FORTREE_CITY',20,10}") ;;
 *) echo "mapset: world or quick"; exit 2 ;;
esac
mkdir -p "$OUT"
i=0
for g in "${MAPSETS[@]}"; do
 i=$((i+1))
 EM_TOUR=1 QA_LIMIT=400 EM_PERF_FRAMES=${EM_PERF_FRAMES:-200} EM_DRIVER="$E/tools/drivers/em_perf_driver.lua" \
  "$E/tools/qa_tryp.sh" "$FILES" "$OUT/g$i" "$g" "$LEVEL" 0 60 > "$OUT/g$i.log" 2>&1 &
 sleep 2
 [ "${SWEEP_PAR:-1}" -gt 1 ] || wait
done
wait
python3 "$E/tools/stack_sheet.py" "$OUT"
