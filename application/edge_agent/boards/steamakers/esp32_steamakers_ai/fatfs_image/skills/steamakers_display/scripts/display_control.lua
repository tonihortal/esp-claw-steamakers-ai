local board_manager = require("board_manager")
local delay = require("delay")
local display = require("display")

args = type(args) == "table" and args or {}
local TAG = "[steamakers_display]"

local aliases = {
    black = "black", negre = "black", negro = "black",
    white = "white", blanc = "white", blanco = "white",
    red = "red", vermell = "red", rojo = "red",
    green = "green", verd = "green", verde = "green",
    blue = "blue", blau = "blue", azul = "blue",
    yellow = "yellow", groc = "yellow", amarillo = "yellow",
}

local color = tostring(args.color or "black"):lower()
color = aliases[color] or color
if not aliases[color] and not color:match("^#%x%x%x%x%x%x$") then
    error(TAG .. " unsupported color: " .. color)
end

local info, info_err = board_manager.get_board_info()
assert(info, TAG .. " get_board_info failed: " .. tostring(info_err))
assert(info.name == "esp32_steamakers_ai",
       TAG .. " wrong board: " .. tostring(info.name))

local panel, io_handle, width, height, panel_if, pixel_format =
    board_manager.get_display_lcd_params("display_lcd")
assert(panel, TAG .. " display_lcd unavailable: " .. tostring(io_handle))

display.init(panel, io_handle, width, height, panel_if, pixel_format)

local ok, err = xpcall(function()
    display.begin_frame({ clear = true, color = color })
    display.present_full()
    display.end_frame()
    print(string.format("%s COLOR %s %dx%d", TAG, color, width, height))
    while true do
        delay.delay_ms(1000)
    end
end, debug.traceback)

pcall(function() display.deinit() end)
if not ok then
    error(err)
end
