---
{
  "name": "steamakers_display",
  "description": "Draw persistent custom scenes, patterns, shapes and ASCII text on the ESP32 STEAMakers AI TFT, or restore the normal status screen.",
  "metadata": {
    "cap_groups": [
      "cap_lua"
    ],
    "manage_mode": "readonly"
  }
}
---

# STEAMakers AI Display

Use this skill to replace the normal status screen temporarily with a custom
240 x 240 scene. Start the controller as a persistent, replaceable Lua job with
`lua_run_script_async`; do not calculate equal divisions manually.

Nine equal vertical stripes, starting with yellow and alternating red:

```json
{
  "path": "{CUR_SKILL_DIR}/scripts/display_control.lua",
  "args": {
    "background": "black",
    "commands": [
      {
        "op": "stripes",
        "orientation": "vertical",
        "count": 9,
        "colors": ["yellow", "red"]
      }
    ]
  },
  "timeout_ms": 0,
  "name": "steamakers_display",
  "exclusive": "steamakers_display",
  "replace": true
}
```

`colors` are repeated cyclically. `stripes` computes every boundary so that any
number from 1 to 64 covers the complete screen without gaps. Use `horizontal`
for horizontal stripes. A regular grid uses:

```json
{"op":"grid","columns":3,"rows":3,"colors":["red","green","blue"]}
```

Compose more elaborate drawings by appending commands in paint order:

- `rect`: `x`, `y`, `width`, `height`, `color`, optional `filled:false`.
- `round_rect`: the rectangle fields plus `radius`.
- `line`: `x0`, `y0`, `x1`, `y1`, `color`; `pixel`: `x`, `y`, `color`.
- `circle`: `cx`, `cy`, `radius`, `color`, optional `filled:false`.
- `ellipse`: `cx`, `cy`, `radius_x`, `radius_y`, `color`, optional
  `filled:false`.
- `triangle`: `x1`, `y1`, `x2`, `y2`, `x3`, `y3`, `color`, optional
  `filled:false`.
- `arc`: `cx`, `cy`, `radius`, `start_deg`, `end_deg`, `color`. Add
  `inner_radius` to draw a filled ring segment.
- `text`: `x`, `y`, `text`, optional `color`, `font_size`, and `bg`. To align
  inside a box, provide both `width` and `height`, plus optional `align` and
  `valign`.

Coordinates start at `(0,0)` in the top-left. Shapes may be partially outside
the screen and are clipped. Text is limited to 96 printable ASCII bytes.

Colors accept English, Catalan and Spanish common names, hexadecimal `#RGB`,
`#RGBA`, `#RRGGBB`, `#RRGGBBAA`, or RGB(A) objects such as
`{"r":20,"g":80,"b":220}`. The named palette includes black, white, red,
green, blue, yellow, cyan, magenta, orange, purple, pink, brown and gray.
Packed RGB integers from `0` (`#000000`) to `16777215` (`#FFFFFF`) are also
accepted for compatibility with LLM providers that encode colors numerically.

For backward compatibility, `args.color` still makes a solid screen and
`args.colors` with exactly four values still makes quadrants ordered top-left,
top-right, bottom-left and bottom-right. Prefer `background` plus `commands` for
new requests. Starting the job again with `replace:true` changes the scene.

To return control to the normal ESP-Claw status screen, call
`lua_stop_async_job` with `{"name":"steamakers_display"}`.

Describe what was submitted, but never claim the physical result until the
user confirms what is visible.
