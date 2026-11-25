#!/bin/bash
# Fix the ENTER / BACKSLASH key mapping of the Halo keyboard on Yoga Book YB1-X9x.
#
# The shipped PC-105 layout has the two rectangles swapped relative to the
# physical keys, so Enter's left half types "\" and the "\" key types Enter.
#
# Run as root, then: systemctl restart halo-keyboard
set -e

[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }

CFG=/etc/halo-keyboard/layouts/YB1-X9x-pc105.csv
[ -f "$CFG" ] || { echo "$CFG not found (is halo-keyboard installed?)"; exit 1; }

cp -n "$CFG" "$CFG.bak" 2>/dev/null || true

# old line 43: top-right key labelled ENTER  -> actually the "\" key
sed -i '43s|.*|29;13,7;226,6;15,4;BACKSLASH;43;;|' "$CFG"
# old line 56: bottom-right labelled BACKSLASH (11mm) -> actually the wide ENTER
sed -i '56s|.*|46,5;13,7;217,5;24,5;ENTER;28;;|' "$CFG"

echo "=== patched lines ==="
sed -n '43p;56p;57p' "$CFG"

systemctl restart halo-keyboard 2>/dev/null || true
echo "done — test Enter (both halves) and the backslash key"
