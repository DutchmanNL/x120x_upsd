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
- Exposes the same status data over an HTTP REST API (`GET /` on a configurable port).
- Broadcasts status updates to connected WebSocket clients on a configurable port.
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

The daemon can expose UPS status data via an HTTP REST API and/or a WebSocket server. Both interfaces serve the same JSON payload. Enable them in `x120x_upsd.ini` by setting `api_port` and/or `websocket_port` to a non-zero value.

### HTTP REST API

Send a `GET /` request to the configured port to retrieve the current status as JSON.

```sh
curl http://<host>:<api_port>/
```

### WebSocket API

Connect to the WebSocket server on the configured port. The server sends the current status immediately upon connection and then broadcasts an updated payload every time the status is refreshed (interval controlled by `json_report_period`, default 30 s).

```js
const ws = new WebSocket("ws://<host>:<websocket_port>/");
ws.onmessage = (event) => console.log(JSON.parse(event.data));
```

### JSON fields

| Field | Type | Description |
|---|---|---|
| `current_capacity` | `float` | Current battery charge in percent (0–100). |
| `current_voltage` | `float` | Current battery voltage in volts. |
| `min_capacity` | `float` | Configured minimum charge percentage before shutdown. |
| `min_voltage` | `float` | Configured minimum voltage before shutdown (0 = disabled). |
| `max_capacity` | `float\|null` | Configured maximum charge percentage for charging control (`null` = not set). |
| `max_voltage` | `float` | Configured maximum voltage for charging control (0 = disabled). |
| `charger_present` | `bool` | Whether the AC power adapter / charger is detected. |
| `charger_charging` | `bool` | Whether the battery is actively being charged. |
| `shutdown_initiated` | `bool` | Whether a shutdown sequence has been triggered. |
| `timer_no_power` | `float` | Seconds elapsed since AC power was lost (0 when power is present). |
| `seconds_to_shutdown` | `float` | Seconds remaining before an automatic shutdown is triggered (only relevant when `ac_max_downtime` > 0). |
| `battery_temperature` | `float` | *(optional)* Battery temperature in °C — only present when a temperature sensor is configured. |
| `fan_state` | `string` | *(optional)* System fan state (`"on"` / `"auto"`) — only present when fan control is enabled. |

### Example response

<details>
<summary>Click to expand example JSON</summary>

```json
{
  "current_capacity": 78.5,
  "current_voltage": 4.05,
  "min_capacity": 20,
  "min_voltage": 3.5,
  "max_capacity": 80,
  "max_voltage": 0,
  "charger_present": true,
  "charger_charging": false,
  "shutdown_initiated": false,
  "timer_no_power": 0,
  "seconds_to_shutdown": 300,
  "battery_temperature": 28.4,
  "fan_state": "auto"
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
