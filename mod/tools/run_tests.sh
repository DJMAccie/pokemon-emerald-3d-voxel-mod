#!/usr/bin/env bash
# Lint the shipped Lua, then run every tests/*_test.lua from the mod root; any failure fails the run.
#   usage: tools/run_tests.sh [engine-root]   (engine root = ../gen1recomp, for tests.modkit and src/)
set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root" || exit 2
engine="${1:-}"
[ -n "$engine" ] && export LUA_PATH="$engine/?.lua;$engine/?/init.lua;;"
export DS_MOD_PATH=.
TO=; command -v timeout >/dev/null && TO="timeout 300"
pass=0; fail=0
# Lint: every shipped file compiles, writes no global and reads no global the game does not give a mod.
# A misspelt local is a global read: nil at run time, and nothing else reports it.
std='^(love|require|pairs|ipairs|type|tostring|tonumber|math|string|table|os|io|print|error|assert|pcall|xpcall|select|unpack|setmetatable|getmetatable|rawget|rawset|rawequal|next|collectgarbage|coroutine|package|debug|bit|jit|_G|loadstring|load|dofile|loadfile|setfenv|getfenv)$'
lint=$(find main.lua lib wilds models -name '*.lua' -not -path '*/tests/*' | sort | while IFS= read -r f; do
  luajit -bl "$f" 2>&1 | awk -v f="$f" -v std="$std" '
    /^luajit: /{print "LINT  " f ": " $0; exit}
    {for(i=2;i<=3;i++) if($i=="GSET"||$i=="GGET"){n=$NF; gsub(/"/,"",n)
      if($i=="GSET") print "LINT  " f ": writes global " n; else if(n!~std) print "LINT  " f ": reads unknown global " n}}' | sort -u
done)
for f in data/*.lua data/buildings/*.lua wilds/data/*.lua; do
  luajit -b "$f" /dev/null 2>/dev/null || lint="$lint${lint:+$'\n'}LINT  $f: does not compile"
done
if [ -n "$lint" ]; then printf '%s\n' "$lint"; fail=$((fail + 1)); else echo "PASS  lint"; pass=$((pass + 1)); fi
for t in tests/*_test.lua; do
  name=$(basename "$t")
  log=$(mktemp)
  $TO luajit "$t" > "$log" 2>&1
  rc=$?
  if [ $rc -eq 0 ] && ! grep -qE '^FAIL' "$log"; then
    printf 'PASS  %-52s %s\n' "$name" "$(grep -oE '[0-9]+/[0-9]+ checks passed' "$log" | tail -1)"
    pass=$((pass + 1))
  else
    printf 'FAIL  %-52s rc=%s\n' "$name" "$rc"
    { grep -E '^FAIL' "$log" || tail -3 "$log"; } | head -3 | sed 's/^/        /'
    fail=$((fail + 1))
  fi
  rm -f "$log"
done
echo "== $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
