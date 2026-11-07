#!/bin/bash
# Record trailer shots as 60 fps ProRes clips in a private QA copy:
#   tools/trailer.sh <abs shots.lua> <abs outdir> [only="name1 name2"]
# One game step per video frame; see tools/drivers/em_trailer_driver.lua for the shot format.
set -u
E="$(cd "$(dirname "$0")/.." && pwd)"
EM_ONLY=${3:-} EM_SHOTS="$1" EM_DRIVER="$E/tools/drivers/em_trailer_driver.lua" QA_LIMIT=${QA_LIMIT:-400} \
  "$E/tools/qa_tryp.sh" "" "$2" "-" 7 0 0
