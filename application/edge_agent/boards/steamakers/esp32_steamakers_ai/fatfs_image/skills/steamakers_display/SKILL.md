---
{
  "name": "steamakers_display",
  "description": "Fill the ESP32 STEAMakers AI TFT with a persistent solid color or four colored quadrants and restore the normal status screen.",
  "metadata": {
    "cap_groups": [
      "cap_lua"
    ],
    "manage_mode": "readonly"
  }
}
---

# STEAMakers AI Display

Use this skill to replace the normal status screen temporarily with a solid
color or four quadrants. Start the controller as a persistent, replaceable Lua
job.

Solid color:

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/display_control.lua",
  "args": {"color": "green"},
  "timeout_ms": 0,
  "name": "steamakers_display",
  "exclusive": "steamakers_display",
  "replace": true
}
```

Four quadrants, ordered top-left, top-right, bottom-left and bottom-right:

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/display_control.lua",
  "args": {"colors": ["red", "green", "blue", "yellow"]},
  "timeout_ms": 0,
  "name": "steamakers_display",
  "exclusive": "steamakers_display",
  "replace": true
}
```

Use `lua_run_script_async`. The script accepts English, Catalan and Spanish
names for black, white, red, green, blue and yellow, plus `#RRGGBB` colors.
For a quadrant request, pass exactly four colors. If the user asks for random
colors, choose four distinct values from the supported names. Starting the job
again with `replace:true` changes the color or pattern.

To return control to the normal ESP-Claw status screen, call
`lua_stop_async_job` with `{"name":"steamakers_display"}`.

Report the selected color, but ask the user to confirm the visible result.
