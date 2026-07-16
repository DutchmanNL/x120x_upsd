# Changelog

## WIP
Reliable unattended recovery after power failures: the Pi now always comes back on its own when AC power returns, and outage shutdown behavior matches the configuration.

- Add `ups-poweroff-guard.service`: converts a poweroff into a reboot when AC power is still present, closing the race where power returns during the shutdown grace period and the Pi would stay off until a button press
- Fix `ac_max_downtime` being ignored while the battery is above its charge target (power cut at full battery previously drained to the minimums regardless of the setting)
- Rewrite `install.sh`: idempotent re-runs, installs the guard, stages required EEPROM settings (`POWER_OFF_ON_HALT=1`, `PSU_MAX_CURRENT=5000`), never overwrites an existing config
- Change default config to battery-based shutdown: `ac_max_downtime: 0`, `min_charge_capacity: 25`
- Document the AC-restore-edge behavior, the guard, and a full-cycle test procedure in the README

## 1.0.0
Initial fork state: upstream daemon plus combined HTTP REST API / WebSocket status server (`api_port`, default 6969).
