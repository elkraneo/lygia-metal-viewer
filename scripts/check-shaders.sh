#!/bin/sh
# Compile every demo shader (and link them into one metallib, like Xcode does)
# without building the app. Usage: scripts/check-shaders.sh [file.metal ...]
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHADERS="$ROOT/LygiaViewer/Shaders"
LYGIA="${LYGIA_SOURCE_ROOT:-$ROOT/External}"
OUT="${TMPDIR:-/tmp}/lygiaviewer-shaders"
mkdir -p "$OUT"
if [ $# -eq 0 ]; then set -- $(find "$SHADERS" -name '*.metal' | sort); fi
airs=""
fail=0
for f in "$@"; do
  air="$OUT/$(basename "$f" .metal).air"
  if xcrun -sdk macosx metal -c -Wno-unused-function -I "$LYGIA" -I "$SHADERS" "$f" -o "$air"; then
    airs="$airs $air"
  else
    echo "FAILED: $f"; fail=1
  fi
done
xcrun -sdk macosx metallib $airs -o "$OUT/default.metallib"
[ $fail -eq 0 ] && echo "OK: $# shader files compiled and linked"
exit $fail
