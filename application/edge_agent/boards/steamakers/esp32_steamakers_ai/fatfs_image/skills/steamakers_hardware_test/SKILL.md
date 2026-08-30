---
{
  "name": "steamakers_hardware_test",
  "description": "Run the PSRAM, internal storage, TFT, speaker and microphone hardware tests for the ESP32 STEAMakers AI board. Requires board_hardware_info.",
  "metadata": {
    "cap_groups": [
      "cap_lua"
    ],
    "manage_mode": "readonly"
  }
}
---

# STEAMakers AI Hardware Test

Use this skill when the user asks to test, validate or diagnose the hardware of
the `esp32_steamakers_ai` board.

Before running the test:

1. Activate and read `board_hardware_info` and verify that the current board is
   `esp32_steamakers_ai`.
2. Confirm that the microSD card is removed. Never insert one while this PSRAM
   firmware is running because GPIO35-GPIO37 are assigned to octal PSRAM.
3. Confirm that the speaker is connected and warn that the speaker test plays
   three tones.
4. Tell the user to look for four colored quadrants on the TFT and to speak
   continuously while the microphone test is running.

Run these four scripts sequentially, using a separate `lua_run_script` call for
each one so failures remain isolated and easy to diagnose.

```json
{"path":"{CUR_SKILL_DIR}/scripts/test_board_storage.lua","timeout_ms":15000}
{"path":"{CUR_SKILL_DIR}/scripts/test_display.lua","timeout_ms":15000}
{"path":"{CUR_SKILL_DIR}/scripts/test_speaker.lua","args":{"volume":70},"timeout_ms":15000}
{"path":"{CUR_SKILL_DIR}/scripts/test_microphone.lua","timeout_ms":15000}
```

## Args schema

```json
{
  "type": "object",
  "properties": {
    "volume": {
      "type": "integer",
      "default": 70,
      "minimum": 1,
      "maximum": 80
    }
  }
}
```

The script checks:

- Board identity and ESP32-S3 target.
- That writable storage is the internal FATFS mount at `/fatfs`, including a
  write/read/delete round trip.
- The ST7789 handle and exact 240x240 geometry, followed by a visible RGBW
  quadrant pattern.
- The MAX98357A path at 24 kHz with identical PCM in both I2S slots through a
  three-tone sequence.
- The INMP441 path at 16 kHz mono, including non-zero peak detection over
  low-memory 20 ms capture windows.

Each script ends with its own `ALL PASS` marker. Ask the user to confirm
separately that the four colors fill the complete screen without an 80-pixel
displacement, that colors are correct, and that the three tones are clean.
Report every `PASS` or failure line from the tool result. Do not claim full
hardware validation without those visual and audible confirmations.

The ESP-IDF boot log performs the full PSRAM memory test. Speaker and microphone
remain separate checks so a failure can be attributed to the correct I2S path.
