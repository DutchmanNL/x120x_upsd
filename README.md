[![CC BY-SA 4.0][cc-by-sa-shield]][cc-by-sa]

# Readme for x120x_upsd
This python program is to provide a systemd service that can manage the various aspects of the [Geekworm X120X UPS](https://geekworm.com/collections/ups-hat/Raspberry-Pi+Raspberry-Pi-5) boards for the Raspbery Pi 5.

This program is inspired by the python examples for the X120X UPS's but extended heavily.

I wrote this because I needed something a bit more robust and flexible than what was available in the original examples.

## Functionality
- Shutdown the pi on timeout of power and/or settable minimums of battery charge or voltage.
- Charge the battery to a set maximum level (charge or voltage) so not to overcharge the battery and prolong battery life.
- Only start charging when the pi has been running for a certain time so the battery can be warmed up by the Pi itself when when it might be used in colder ( < 10 degrees Celsius) environments. This is not really precise and very dependent on the environment. Adding and monitoring a temperature sensor is a todo.
- Uses the systemd journal for logging. See it using `journalctl -xeu x120x_upsd.service`
- Writes a json status report to a tmpfs based location for ingestion into other tools.
- Exposes UPS status data over a combined HTTP REST API and WebSocket server on a single configurable port (default: 6969, configured via `api_port`). `GET /` returns the current status as JSON; WebSocket clients receive the current status immediately on connect and on every update.
- It is meant to run as a systemd service, but can be run directly.
- A temperature sensor attached to the lithium-cells can be used to monitor the cells to be in the correct temperature range for charging or dis-charging. Currently the Adafruit DHT22 and DHT11 are implemented. Pull requests for other types are welcome.
- Cool down the case by spinning the system fan when the batteries reach 50C.

## Install
1. Clone or download this repository.
2. Review the `x12x_ups.ini` and set according to your needs. [^1]
3. Review and understand the provided `install.sh` script as it is a good practice. 
4. Run it with `sudo sh -x ./install.sh` to install files and dependencies and enable and start the service.
5. Optionally: To stop charging quickly after power on so that the deamon can manage it, add `gpio=16=pu` to `/boot/firware/config.txt` and reboot.
6. Optionally: If using the DHT11 or DHT22 temperature sensor to monitor the lithium cell(s) add the adafruit dht package to your system and the system packages it depends on[^2]:
```
sudo apt install python3-ftdi python3-sysv-ipc python3-usb python3-typing-extensions
sudo python -m pip install --break-system-packages adafruit-circuitpython-dht
```

## JSON API

The daemon exposes a combined HTTP REST API and WebSocket server on a single port (default: **6969**).

Configure the port and bind address in `x120x_upsd.ini`:
```ini
# Uncomment and change as needed:
api_port = 6969
api_bind_address = 0.0.0.0
```

### HTTP REST API

Send an HTTP `GET` request to `/` to retrieve the current UPS status as JSON:

```
GET http://<host>:6969/
```

### WebSocket API

Connect to `ws://<host>:6969/` to receive the current UPS status as JSON immediately on connect and again on every update.

### JSON Response Fields

| Field | Type | Description |
|---|---|---|
| `charger_present` | boolean | Whether the AC power/charger is connected |
| `charger_charging` | boolean | Whether the battery is actively charging |
| `current_capacity` | float | Current battery charge level (%) |
| `current_voltage` | float | Current battery voltage (V) |
| `min_capacity` | integer | Configured minimum charge capacity before shutdown (%) |
| `min_voltage` | float | Configured minimum voltage before shutdown (V) |
| `max_capacity` | integer | Configured maximum charge capacity (%) |
| `max_voltage` | float | Configured maximum charge voltage (V); `0` means voltage limit is disabled (charge by percentage only) |
| `shutdown_initiated` | boolean | Whether a shutdown has been initiated |
| `timer_no_power` | float | Seconds elapsed since AC power was lost |
| `seconds_to_shutdown` | float | Seconds remaining until automatic shutdown |
| `battery_temperature` | float | Battery temperature in °C *(only present when a temperature sensor is configured)* |
| `fan_state` | string | Current fan state *(only present when a fan is available)* |

<details>
<summary>Example JSON response</summary>

```json
{
  "charger_present": true,
  "charger_charging": true,
  "current_capacity": 75.5,
  "current_voltage": 4.05,
  "min_capacity": 20,
  "min_voltage": 3.5,
  "max_capacity": 80,
  "max_voltage": 0,
  "shutdown_initiated": false,
  "timer_no_power": 0.0,
  "seconds_to_shutdown": 300.0
}
```

</details>

## Todo
- ~~Add monitoring for a temperature sensor to measure battery temperature. Need to decide which sensor 1st.~~
- ~~An api for an applet of some sorts? HTTP REST API and WebSocket added.~~

## License
This work is licensed under a
[Creative Commons Attribution-ShareAlike 4.0 International License][cc-by-sa].

[![CC BY-SA 4.0][cc-by-sa-image]][cc-by-sa]

[cc-by-sa]: http://creativecommons.org/licenses/by-sa/4.0/
[cc-by-sa-image]: https://licensebuttons.net/l/by-sa/4.0/88x31.png
[cc-by-sa-shield]: https://img.shields.io/badge/License-CC%20BY--SA%204.0-lightgrey.svg

[^1]: Not mentioned in the ini is the parameter `disable_self_protect`. Setting this to `on` or `True` will enable you to discharge the lithium cells to the hardware default which I think is at 2.5 Volts. Some say newer cells can handle that. The script has it hardcoded at 3.0. You can set your own mimumum voltage by enabling this parameter and setting `min_voltage`.

[^2]: If there probably is a proper way to do this where the script plus depending python packages are installed together. I still have to look into that. Suggestions or a pull request are welcome.
