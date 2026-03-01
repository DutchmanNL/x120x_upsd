#!/bin/sh
apt install -y python3-apscheduler python3-decorator python3-gpiozero \
    python3-smbus2 python3-systemd

# Install python3-websockets unless combined_port is explicitly set to 0 in the ini file.
# The default combined_port is 6969 (enabled), so websockets is installed by default.
INI_FILE="./x120x_upsd.ini"
[ -f "/usr/local/etc/x120x_upsd.ini" ] && INI_FILE="/usr/local/etc/x120x_upsd.ini"
COMBINED_PORT=$(grep -E '^\s*combined_port\s*[=:]\s*[0-9]+' "$INI_FILE" 2>/dev/null | awk -F'[=:]' '{print $2}' | tr -d ' \t' | tail -1)
if [ -z "$COMBINED_PORT" ]; then COMBINED_PORT="6969"; fi
if [ "$COMBINED_PORT" != "0" ]; then
    apt install -y python3-websockets
fi
cp x120x_upsd.py /usr/local/bin
cp -n x120x_upsd.ini /usr/local/etc || true
cp x120x_upsd.service /etc/systemd/system

chown root:root /usr/local/bin/x120x_upsd.py /usr/local/etc/x120x_upsd.ini /etc/systemd/system/x120x_upsd.service
chmod 644 /usr/local/etc/x120x_upsd.ini /etc/systemd/system/x120x_upsd.service
chmod 755 /usr/local/bin/x120x_upsd.py

systemctl daemon-reload
systemctl enable x120x_upsd.service
systemctl start x120x_upsd.service
