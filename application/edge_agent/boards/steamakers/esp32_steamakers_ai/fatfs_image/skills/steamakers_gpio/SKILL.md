---
{
  "name": "steamakers_gpio",
  "description": "Safely control generic GPIO on the ESP32 STEAMakers AI: digital I/O, ADC, PWM, buzzers, and servos. Its G-S-V headers provide 5 V peripheral power on V from the onboard converter, while S remains a 3.3 V ESP32-S3 GPIO signal and must not receive 5 V.",
  "metadata": {
    "cap_groups": [
      "cap_lua"
    ],
    "manage_mode": "readonly"
  }
}
---

# STEAMakers AI GPIO

Use this skill for generic hardware attached to the exposed headers of the
`esp32_steamakers_ai` board. The control script verifies the board identity
itself, so a separate `board_hardware_info` activation is not required.

All operations go through the board-validated script below. Do not call the raw
`gpio`, `adc`, or `mcpwm` Lua modules directly. The wrapper rejects TFT, audio,
PSRAM/microSD, console, boot, and other reserved pins.

```json
{"path":"{CUR_SKILL_DIR}/scripts/gpio_control.lua","args":{"action":"list"},"timeout_ms":10000}
```

## Supported operations

Digital output, for example an LED on GPIO10:

```json
{"path":"{CUR_SKILL_DIR}/scripts/gpio_control.lua","args":{"action":"write","pin":10,"level":1},"timeout_ms":10000}
```

Digital input with optional internal pull resistor:

```json
{"path":"{CUR_SKILL_DIR}/scripts/gpio_control.lua","args":{"action":"read","pin":8,"pull":"up"},"timeout_ms":10000}
```

Calibrated analog voltage. Only ADC1 pins are accepted while Wi-Fi is active:

```json
{"path":"{CUR_SKILL_DIR}/scripts/gpio_control.lua","args":{"action":"analog","pin":2,"samples":8},"timeout_ms":10000}
```

Finite PWM burst for a dimmable LED, transistor driver, or active load:

```json
{"path":"{CUR_SKILL_DIR}/scripts/gpio_control.lua","args":{"action":"pwm","pin":10,"frequency_hz":1000,"duty_percent":40,"duration_ms":2000},"timeout_ms":10000}
```

Finite passive-buzzer tone:

```json
{"path":"{CUR_SKILL_DIR}/scripts/gpio_control.lua","args":{"action":"tone","pin":10,"frequency_hz":880,"duration_ms":500},"timeout_ms":10000}
```

Move a conventional 50 Hz hobby servo, then release the PWM resource:

```json
{"path":"{CUR_SKILL_DIR}/scripts/gpio_control.lua","args":{"action":"servo","pin":10,"angle":90,"hold_ms":750},"timeout_ms":10000}
```

Return a pin to its reset state:

```json
{"path":"{CUR_SKILL_DIR}/scripts/gpio_control.lua","args":{"action":"release","pin":10},"timeout_ms":10000}
```

Pins may be passed as GPIO numbers or board aliases: `A0`, `A1`, `A2`, `A3`,
`D0`, `D1`, `D8`, `D9`, `D10`, `D11`, `D12`, `D13`, `SDA`, or `SCL`.

## Electrical safety

- The generic three-pin board headers expose `G` (ground), `S` (GPIO signal),
  and `V` (peripheral power). The board's internal power conversion makes 5 V
  available on the `V` position of these headers; do not incorrectly tell the
  user that every connector is limited to a 3.3 V supply.
- Distinguish supply voltage from signal voltage. The `S` position is connected
  to an ESP32-S3 GPIO and uses 3.3 V logic; a digital high on `S` is not a 5 V
  output. The onboard 5 V power converter is not a per-GPIO logic-level
  translator. Never drive `S`, or an ADC input, with a 5 V signal.
- Put a series resistor (typically 220 ohm to 1 kohm) in line with an LED.
- A compatible low-power peripheral may take 5 V from the header's `V` pin,
  within the board's shared power budget. Never power a servo, motor, relay,
  solenoid, or substantial buzzer from the `S` GPIO signal. Use a suitable
  driver, and use an external supply with common GND when the load's startup or
  running current may exceed the board's available supply current.
- Use a flyback diode for inductive loads and a transistor/MOSFET when the load
  current is beyond a small logic-level indicator.
- Before changing an output, obtain the pin, circuit, load, supply voltage, and
  active-high/active-low behavior from the user if they are not already known.
- When the user says that a pin is 5 V, clarify whether they mean the header's
  `V` supply position or its `S` GPIO signal before making an electrical claim.
- `GPIO3/A1` is an ESP32-S3 strapping pin and `GPIO19/A3` is wired to USB D-.
  They are blocked unless `allow_conditional:true` is passed after the user
  explicitly confirms the boot/USB implications. GPIO3 is permitted for ADC1;
  GPIO19 remains digital-only in this wrapper.
- PWM and servo commands are deliberately finite. `duration_ms` is at most
  60 seconds and `hold_ms` at most 10 seconds, after which the pin is reset.

Report the exact GPIO, resulting value/voltage, and operation duration from the
script output. Never claim that a physical device moved or lit unless the user
confirms the observable result.
