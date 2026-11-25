#!/bin/bash
# Build and install the out-of-tree modules needed by the Lenovo Yoga Book
# YB1-X91F on Debian 13: battery (BQ27542/BQ25892) + keyboard backlight (ACPI KBLC).
set -e

[ "$(id -u)" -eq 0 ] || { echo "run as root"; exit 1; }

KVER="$(uname -r)"
WORK=/usr/src/yogabook-debian
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "== kernel $KVER =="

echo "== dependencies =="
apt-get update -qq
apt-get install -y "linux-headers-$KVER" build-essential

echo "== build tree =="
rm -rf "$WORK"
mkdir -p "$WORK"
cp "$SRC_DIR/modules/Makefile" "$SRC_DIR/modules/ybkbdbl.c" "$WORK/"

echo "== fetching upstream driver sources =="
bash "$SRC_DIR/modules/fetch-upstream.sh" "$WORK" "$KVER"

echo "== building =="
make -C "$WORK"

echo "== installing modules =="
install -d "/lib/modules/$KVER/extra"
install -m 644 "$WORK"/ybkbdbl.ko "$WORK"/bq27xxx_battery.ko \
    "$WORK"/bq27xxx_battery_i2c.ko "$WORK"/bq25890_charger.ko \
    "/lib/modules/$KVER/extra/"
depmod -a

echo "== autoload config =="
printf 'bq27xxx_battery\nbq27xxx_battery_i2c\nbq25890_charger\n' > /etc/modules-load.d/yogabook-battery.conf
printf 'ybkbdbl\n' > /etc/modules-load.d/yogabook-backlight.conf

echo "== disable suspend (Cherry Trail S3 resume is broken) =="
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target || true

echo "== backlight service =="
systemctl enable halo-keyboard-backlight.service 2>/dev/null || true

echo "== load now =="
modprobe bq27xxx_battery || true
modprobe bq27xxx_battery_i2c || true
modprobe bq25890_charger || true
modprobe ybkbdbl || true
systemctl restart halo-keyboard-backlight.service 2>/dev/null || true

echo
echo "== result =="
ls /sys/class/power_supply/ 2>/dev/null || true
cat /sys/class/power_supply/bq27542-0/capacity 2>/dev/null || echo "(battery node missing)"
cat /sys/class/leds/ybwmi::kbd_backlight/brightness 2>/dev/null || echo "(backlight node missing)"
echo "done — reboot recommended"
