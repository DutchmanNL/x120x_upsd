#!/bin/sh
# Installer for the x120x UPS daemon + poweroff guard.
# Idempotent: safe to re-run for updates. An existing /usr/local/etc/x120x_upsd.ini
# is never overwritten (compare it with x120x_upsd.ini in this repo after updates).
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root: sudo ./install.sh" >&2
    exit 1
fi
cd "$(dirname "$0")"

echo "== Installing dependencies"
apt install -y python3-apscheduler python3-decorator python3-gpiozero \
    python3-smbus2 python3-systemd

# Install python3-websockets unless api_port is explicitly set to 0 in the ini file.
# The default api_port is 6969 (enabled), so websockets is installed by default.
INI_FILE="./x120x_upsd.ini"
[ -f "/usr/local/etc/x120x_upsd.ini" ] && INI_FILE="/usr/local/etc/x120x_upsd.ini"
API_PORT=$(grep -E '^\s*api_port\s*[=:]\s*[0-9]+' "$INI_FILE" 2>/dev/null | awk -F'[=:]' '{print $2}' | tr -d ' \t' | tail -1)
if [ -z "$API_PORT" ]; then API_PORT="6969"; fi
if [ "$API_PORT" != "0" ]; then
    apt install -y python3-websockets
fi

echo "== Installing UPS daemon"
install -m 755 -o root -g root x120x_upsd.py /usr/local/bin/x120x_upsd.py
if [ -f /usr/local/etc/x120x_upsd.ini ]; then
    echo "   Keeping existing /usr/local/etc/x120x_upsd.ini (repo default not applied)"
else
    install -m 644 -o root -g root x120x_upsd.ini /usr/local/etc/x120x_upsd.ini
fi
install -m 644 -o root -g root x120x_upsd.service /etc/systemd/system/x120x_upsd.service

echo "== Installing poweroff guard"
# Without the guard, a poweroff that completes while AC power is present
# (e.g. power returns during the shutdown grace period) leaves the Pi off
# forever: the X120x only powers it back on via an AC restore edge.
install -m 755 -o root -g root ups-poweroff-guard.sh /usr/local/sbin/ups-poweroff-guard.sh
install -m 644 -o root -g root ups-poweroff-guard.service /etc/systemd/system/ups-poweroff-guard.service

echo "== Enabling services"
systemctl daemon-reload
systemctl enable x120x_upsd.service ups-poweroff-guard.service
systemctl restart x120x_upsd.service

echo "== Checking Raspberry Pi EEPROM settings"
# POWER_OFF_ON_HALT=1 : Pi powers fully off on shutdown, so the UPS stops
#                       detecting it, cuts its output and arms auto-power-on.
# PSU_MAX_CURRENT=5000: accept the UPS's full 5A without throttling.
if command -v rpi-eeprom-config >/dev/null 2>&1; then
    CURRENT=$(rpi-eeprom-config)
    WANTED=$CURRENT
    for kv in POWER_OFF_ON_HALT=1 PSU_MAX_CURRENT=5000; do
        key=${kv%%=*}
        if printf '%s\n' "$WANTED" | grep -q "^${key}="; then
            WANTED=$(printf '%s\n' "$WANTED" | sed "s/^${key}=.*/${kv}/")
        else
            WANTED=$(printf '%s\n%s' "$WANTED" "$kv")
        fi
    done
    if [ "$CURRENT" = "$WANTED" ]; then
        echo "   EEPROM settings already correct"
    else
        TMP=$(mktemp)
        printf '%s\n' "$WANTED" > "$TMP"
        rpi-eeprom-config --apply "$TMP"
        rm -f "$TMP"
        echo "   EEPROM settings staged - REBOOT REQUIRED to apply them"
    fi
else
    echo "   rpi-eeprom-config not found - set POWER_OFF_ON_HALT=1 and PSU_MAX_CURRENT=5000 manually"
fi

echo "== Done"
systemctl --no-pager --lines 0 status x120x_upsd.service | head -3
