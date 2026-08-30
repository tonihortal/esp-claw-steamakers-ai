local board_manager = require("board_manager")
local delay = require("delay")
local display = require("display")

local TAG = "[steamakers_display]"
local panel, io_handle, width, height, panel_if, pixel_format =
    board_manager.get_display_lcd_params("display_lcd")
assert(panel, "display_lcd unavailable: " .. tostring(io_handle))
assert(width == 240 and height == 240,
       string.format("unexpected display geometry: %sx%s", tostring(width), tostring(height)))

display.init(panel, io_handle, width, height, panel_if, pixel_format, true)

local ok, err = xpcall(function()
    local half_w = math.floor(width / 2)
    local half_h = math.floor(height / 2)

    -- Direct opaque draws use a one-scanline staging buffer. The full-screen
    -- Direct draws keep this diagnostic independent from LVGL framebuffers.
    display.clear("black")
    display.fill_rect(0, 0, half_w, half_h, { r = 255, g = 0, b = 0 })
    display.fill_rect(half_w, 0, width - half_w, half_h, { r = 0, g = 255, b = 0 })
    display.fill_rect(0, half_h, half_w, height - half_h, { r = 0, g = 0, b = 255 })
    display.fill_rect(half_w, half_h, width - half_w, height - half_h,
                      { r = 255, g = 255, b = 255 })
    print(string.format("%s PASS draw: %dx%d panel_if=%s pixel_format=%s",
                        TAG, width, height, tostring(panel_if), tostring(pixel_format)))
    print(TAG .. " ACTION confirm full-screen RGBW quadrants without vertical offset")
    delay.delay_ms(5000)
end, debug.traceback)

pcall(function() display.deinit() end)
if not ok then
    error(err)
end
print(TAG .. " ALL PASS")
