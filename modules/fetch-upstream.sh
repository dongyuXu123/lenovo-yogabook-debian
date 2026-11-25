#!/bin/bash
# Download the mainline driver sources that Debian does not build.
# Usage: fetch-upstream.sh <dest-dir> [kernel-version]
set -e

DEST="${1:?dest dir}"
KVER="${2:-$(uname -r)}"

# Debian "6.12.117+deb13-amd64" -> "v6.12.117"
TAG="v$(echo "$KVER" | sed 's/[+~-].*//')"
BASE_TAG="v6.12"

FILES="drivers/power/supply/bq27xxx_battery.c
drivers/power/supply/bq27xxx_battery_i2c.c
include/linux/power/bq27xxx_battery.h
drivers/power/supply/bq25890_charger.c"

mkdir -p "$DEST/include/linux/power"

get() {
    local path="$1" out="$2" tag url
    for tag in "$TAG" "$BASE_TAG" master; do
        url="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/$path?h=$tag"
        if curl -fsSL --retry 3 --max-time 60 "$url" -o "$out" 2>/dev/null && [ -s "$out" ]; then
            echo "  ok $path ($tag)"; return 0
        fi
        url="https://raw.githubusercontent.com/torvalds/linux/$tag/$path"
        if curl -fsSL --retry 3 --max-time 60 "$url" -o "$out" 2>/dev/null && [ -s "$out" ]; then
            echo "  ok $path ($tag via github)"; return 0
        fi
    done
    echo "  FAIL $path" >&2
    return 1
}

for f in $FILES; do
    case "$f" in
        include/*) get "$f" "$DEST/include/linux/power/$(basename "$f")" ;;
        *)         get "$f" "$DEST/$(basename "$f")" ;;
    esac
done

echo "sources ready in $DEST"
