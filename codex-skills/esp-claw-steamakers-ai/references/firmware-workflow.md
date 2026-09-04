# Firmware workflow

## Repository landmarks

- Board: `application/edge_agent/boards/steamakers/esp32_steamakers_ai/`
- Board peripherals/devices: `board_peripherals.yaml`, `board_devices.yaml`
- Board-baked skills: `fatfs_image/skills/`
- Board setup: `setup_device.c`
- Board-aware system prompt: `components/common/app_claw/app_claw.c`
- Main app: `application/edge_agent/main/main.c`
- Release packager: `tools/steamakers/package_release.sh`

Writable state uses `CLAW_PATH_DATA`, not a reusable hard-coded `/fatfs` path.
Firmware-baked skills use `{CUR_SKILL_DIR}` in their own documentation. The
read-only SYSTEM image contains baked skills; the DATA partition retains user
configuration, sessions, memory, rules, schedules, and installed skills.

## Build

Use ESP-IDF 5.5.4 and install `esp-bmgr-assist`. From
`application/edge_agent`:

```bash
. "$IDF_PATH/export.sh"
idf.py bmgr -c ./boards -b esp32_steamakers_ai
idf.py build
```

Do not edit `components/gen_bmgr_codes/` manually. If an old build directory
mixes Ninja and Unix Makefiles, regenerate only the generated build cache; do
not reset source changes.

## Flash without erasing configuration

Discover the exact serial port first. On one validated macOS setup it appeared
as `/dev/cu.usbserial-2110`, but never assume this value on another machine.

- `idf.py -p PORT app-flash` updates the compiled application.
- `idf.py -p PORT system-flash` updates board-baked skills and SYSTEM files.
- Use both when a change touches `app_claw.c` and `fatfs_image/skills/`.
- Do not flash `storage` during iterative testing unless a reset of saved
  configuration is explicitly intended.
- A merged release image at offset `0x0` is a clean installation and overwrites
  application, SYSTEM, and DATA; Wi-Fi and tokens then need reconfiguration.

## Serial isolation tests

Use a 115200-bit/s monitor on PROG/CH340. JSON on the ESP console needs escaped
double quotes, for example:

```text
lua --run --path /system/skills/steamakers_gpio/scripts/gpio_control.lua --args-json "{\"action\":\"write\",\"pin\":12,\"level\":1}" --timeout-ms 10000
lua --run-async --path /system/skills/steamakers_display/scripts/display_control.lua --args-json "{\"colors\":[\"red\",\"green\",\"blue\",\"yellow\"]}"
lua --run-async --path /system/skills/steamakers_display/scripts/display_control.lua --args-json "{\"background\":\"black\",\"commands\":[{\"op\":\"stripes\",\"orientation\":\"vertical\",\"count\":9,\"colors\":[\"yellow\",\"red\"]}]}"
```

The display controller supports general scenes through `background` and up to
64 ordered `commands`: equal stripes, grids, rectangles, rounded rectangles,
lines, pixels, circles, ellipses, triangles, arcs and printable ASCII text.
It retains the solid `color` and four-quadrant `colors` aliases. It must render
through the shared display service and framebuffer; direct exclusive mode fails
while the normal system UI owns the panel.
Colors may be names, hex strings, RGB(A) tables, or packed RGB integers. The
integer form is deliberately accepted because some LLM providers translate
named colors to values such as `16776960` (`#FFFF00`).

## Complete hardware test

The agent prompt is: `Executa la prova completa de maquinari STEAMakers`.
Activate `steamakers_hardware_test` and `board_hardware_info`, then execute these
four synchronous scripts sequentially in the same request:

1. `test_board_storage.lua`, timeout 15000 ms.
2. `test_display.lua`, timeout 15000 ms.
3. `test_speaker.lua`, args `{"volume":70}`, timeout 15000 ms.
4. `test_microphone.lua`, timeout 15000 ms.

Do not ask the user to answer “Sí” halfway through: some provider/session paths
lose the pending plan and respond with a generic greeting. The display test must
use `begin_frame`, four `fill_rect` calls, `present_full`, and `end_frame`, not
direct mode. Run each subsystem in a separate Lua execution to limit peak RAM
and isolate failures.

Validated outcomes on 2 September 2026 included:

- ESP-IDF PSRAM boot memory test OK.
- Internal storage read/write/delete round trip `ALL PASS`.
- TFT RGBW quadrants at 240×240 `ALL PASS`.
- Three ascending tones submitted at 24 kHz stereo-slot format `ALL PASS`.
- Microphone non-zero RMS and peak signal `ALL PASS`.
- A normal session, equivalent to Telegram, invoked all four stages in one
  request and returned a Catalan summary. `ask_once` is not an equivalent test
  because skill activation needs a persistent session.

Ask the user afterward whether all four quadrants filled the screen with correct
colors and no displacement, and whether the three tones were clearly audible.

## Boot screen

When Wi-Fi connects, the centered screen shows `WIFI ON`, then the assigned STA
IPv4 address, a deliberate gap, `ESP-CLAW`, `ESP32 STEAMakers AI`, and the local
time/date. Prefer the displayed numeric IP when `http://esp-claw.local/` does not
resolve. The observed DHCP address is not stable and must never be hard-coded.
