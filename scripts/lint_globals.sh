#!/usr/bin/env bash
# Every global a mod script reads must be the engine's or Lua's: a local lost in a refactor (ops.lua split into modules,
# 2026-10-18) reads as a global, nil at run time, with no error until that line runs. luajit's bytecode lists them.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
ALLOWED=" game script storage defines prototypes rendering settings helpers remote commands serpent log localised_print table_size
  require ipairs pairs next type tostring tonumber select error assert pcall xpcall setmetatable getmetatable rawget rawset
  unpack math string table data mods "
ALLOWED=" $(echo $ALLOWED) "
bad=0
for f in "$REPO"/landing-party/*.lua "$REPO"/landing-party/scripts/*.lua; do
  for g in $(luajit -bl "$f" | grep -oE 'GGET .*"[A-Za-z_][A-Za-z_0-9]*"' | grep -oE '"[A-Za-z_][A-Za-z_0-9]*"' | tr -d '"' | sort -u); do
    case "$ALLOWED" in *" $g "*) ;; *) echo "global read: $g in ${f#$REPO/}"; bad=1;; esac
  done
done
[ $bad -eq 0 ] && echo "globals lint ok" || { echo "GLOBALS LINT FAILED"; exit 1; }
