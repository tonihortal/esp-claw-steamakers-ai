---
{
  "name": "steamakers_display",
  "description": "Fill the ESP32 STEAMakers AI TFT with a persistent solid color and restore the normal status screen.",
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
color. Start the controller as a persistent, replaceable Lua job:

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

Use `lua_run_script_async`. The script accepts English, Catalan and Spanish
names for black, white, red, green, blue and yellow, plus `#RRGGBB` colors.
Starting it again with `replace:true` changes the color.

To return control to the normal ESP-Claw status screen, call
`lua_stop_async_job` with `{"name":"steamakers_display"}`.

Report the selected color, but ask the user to confirm the visible result.
