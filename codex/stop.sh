#!/bin/sh
# Codex Stop hook: keep the reverser going until `ilio submit` accepted a flag (cap: 30 continues).
[ -f /work/FLAG ] || [ -f /work/HELP.md ] && exit 0
n=$(cat /work/.stops 2>/dev/null || echo 0); [ "$n" -ge 30 ] && exit 0
echo $((n + 1)) > /work/.stops
echo "No correct flag yet (ilio submit has not returned correct). Keep working: check /work/notes.md, pick the next most promising lead, and continue." >&2
exit 2
