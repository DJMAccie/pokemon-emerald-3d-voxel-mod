#!/bin/bash
# Render a game song to WAV: tools/music.sh MUS_RAYQUAZA_APPEARS <abs outdir> [secs]
set -u
E="$(cd "$(dirname "$0")/.." && pwd)"
EM_SONG=$1 EM_SECS=${3:-100} EM_DRIVER="$E/tools/drivers/em_music_driver.lua" QA_LIMIT=$(( ${3:-100} + 120 )) \
  "$E/tools/qa_tryp.sh" "" "$2" "-" 7 0 0
read R C B < "$2/song.rate"
/opt/homebrew/bin/ffmpeg -loglevel error -y -f s16le -ar "$R" -ac "$C" -i "$2/song.raw" "$2/$1.wav" && echo "wav ok $R Hz"
