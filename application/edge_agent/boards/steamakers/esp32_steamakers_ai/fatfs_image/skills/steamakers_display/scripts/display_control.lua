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

local function normalize_color(value)
    local color = tostring(value or ""):lower()
    color = aliases[color] or color
    if not aliases[color] and not color:match("^#%x%x%x%x%x%x$") then
        error(TAG .. " unsupported color: " .. color)
    end
    return color
end

local colors
local color
if type(args.colors) == "table" then
    assert(#args.colors == 4, TAG .. " colors must contain exactly four values")
    colors = {}
    for index = 1, 4 do
        colors[index] = normalize_color(args.colors[index])
    end
else
    color = normalize_color(args.color or "black")
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
    display.begin_frame({ clear = true, color = color or "black" })
    if colors then
        local half_w = math.floor(width / 2)
        local half_h = math.floor(height / 2)
        display.fill_rect(0, 0, half_w, half_h, colors[1])
        display.fill_rect(half_w, 0, width - half_w, half_h, colors[2])
        display.fill_rect(0, half_h, half_w, height - half_h, colors[3])
        display.fill_rect(half_w, half_h, width - half_w, height - half_h, colors[4])
    end
    display.present_full()
    display.end_frame()
    if colors then
        print(string.format("%s QUADRANTS %s,%s,%s,%s %dx%d",
                            TAG, colors[1], colors[2], colors[3], colors[4], width, height))
    else
        print(string.format("%s COLOR %s %dx%d", TAG, color, width, height))
    end
    while true do
        delay.delay_ms(1000)
    end
end, debug.traceback)

pcall(function() display.deinit() end)
if not ok then
    error(err)
end
