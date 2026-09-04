local board_manager = require("board_manager")
local delay = require("delay")
local display = require("display")

args = type(args) == "table" and args or {}
local TAG = "[steamakers_display]"
local MAX_COMMANDS = 64
local MAX_DIVISIONS = 64
local MAX_TEXT_BYTES = 96
local MIN_COORDINATE = -480
local MAX_COORDINATE = 720
local MAX_SIZE = 720

local aliases = {
    black = "black", negre = "black", negro = "black",
    white = "white", blanc = "white", blanco = "white",
    red = "red", vermell = "red", rojo = "red",
    green = "green", verd = "green", verde = "green",
    blue = "blue", blau = "blue", azul = "blue",
    yellow = "yellow", groc = "yellow", amarillo = "yellow",
    cyan = "cyan", cian = "cyan",
    magenta = "magenta",
    orange = "#ff8000", taronja = "#ff8000", naranja = "#ff8000",
    purple = "#800080", porpra = "#800080", lila = "#800080", morado = "#800080",
    pink = "#ff69b4", rosa = "#ff69b4",
    brown = "#8b4513", marro = "#8b4513", marron = "#8b4513",
    gray = "#808080", grey = "#808080", gris = "#808080",
}

local function fail(message)
    error(TAG .. " " .. message, 0)
end

local function normalize_color(value, field)
    if type(value) == "number" then
        if value % 1 ~= 0 or value < 0 or value > 0xffffff then
            fail((field or "color") .. " numeric RGB must be an integer from 0 to 16777215")
        end
        return string.format("#%06x", math.tointeger(value))
    end

    if type(value) == "table" then
        local normalized = {}
        for _, channel in ipairs({ "r", "g", "b" }) do
            local component = value[channel]
            if type(component) ~= "number" or component % 1 ~= 0 or
               component < 0 or component > 255 then
                fail((field or "color") .. "." .. channel .. " must be an integer from 0 to 255")
            end
            normalized[channel] = math.tointeger(component)
        end
        if value.a ~= nil and (type(value.a) ~= "number" or value.a % 1 ~= 0 or
                               value.a < 0 or value.a > 255) then
            fail((field or "color") .. ".a must be an integer from 0 to 255")
        end
        if value.a ~= nil then
            normalized.a = math.tointeger(value.a)
        end
        return normalized
    end

    local color = tostring(value or ""):lower()
    color = aliases[color] or color
    if color ~= "black" and color ~= "white" and color ~= "red" and
       color ~= "green" and color ~= "blue" and color ~= "yellow" and
       color ~= "cyan" and color ~= "magenta" and
       not color:match("^#%x%x%x$") and not color:match("^#%x%x%x%x$") and
       not color:match("^#%x%x%x%x%x%x$") and
       not color:match("^#%x%x%x%x%x%x%x%x$") then
        fail("unsupported " .. (field or "color") .. ": " .. color)
    end
    return color
end

local function integer(value, field, minimum, maximum)
    if type(value) ~= "number" or value % 1 ~= 0 then
        fail(field .. " must be an integer")
    end
    if minimum ~= nil and value < minimum then
        fail(field .. " is below its minimum")
    end
    if maximum ~= nil and value > maximum then
        fail(field .. " exceeds its maximum")
    end
    return math.tointeger(value)
end

local function coordinate(value, field)
    return integer(value, field, MIN_COORDINATE, MAX_COORDINATE)
end

local function size(value, field)
    return integer(value, field, 1, MAX_SIZE)
end

local function number(value, field)
    if type(value) ~= "number" then
        fail(field .. " must be a number")
    end
    return value
end

local function color_list(values, field)
    if type(values) ~= "table" or #values < 1 or #values > 16 then
        fail(field .. " must contain between 1 and 16 colors")
    end
    local result = {}
    for index, value in ipairs(values) do
        result[index] = normalize_color(value, field .. "[" .. index .. "]")
    end
    return result
end

local function draw_stripes(command, screen_width, screen_height)
    local orientation = tostring(command.orientation or "vertical"):lower()
    local count = integer(command.count, "stripes.count", 1, MAX_DIVISIONS)
    local colors = color_list(command.colors, "stripes.colors")
    if orientation ~= "vertical" and orientation ~= "horizontal" then
        fail("stripes.orientation must be vertical or horizontal")
    end

    for index = 0, count - 1 do
        local color = colors[(index % #colors) + 1]
        if orientation == "vertical" then
            local x0 = math.floor(index * screen_width / count)
            local x1 = math.floor((index + 1) * screen_width / count)
            display.fill_rect(x0, 0, x1 - x0, screen_height, color)
        else
            local y0 = math.floor(index * screen_height / count)
            local y1 = math.floor((index + 1) * screen_height / count)
            display.fill_rect(0, y0, screen_width, y1 - y0, color)
        end
    end
end

local function draw_grid(command, screen_width, screen_height)
    local columns = integer(command.columns, "grid.columns", 1, MAX_DIVISIONS)
    local rows = integer(command.rows, "grid.rows", 1, MAX_DIVISIONS)
    local colors = color_list(command.colors, "grid.colors")
    for row = 0, rows - 1 do
        local y0 = math.floor(row * screen_height / rows)
        local y1 = math.floor((row + 1) * screen_height / rows)
        for column = 0, columns - 1 do
            local x0 = math.floor(column * screen_width / columns)
            local x1 = math.floor((column + 1) * screen_width / columns)
            local color = colors[((row * columns + column) % #colors) + 1]
            display.fill_rect(x0, y0, x1 - x0, y1 - y0, color)
        end
    end
end

local function draw_command(command, screen_width, screen_height)
    if type(command) ~= "table" then
        fail("every command must be an object")
    end
    local op = tostring(command.op or command.type or ""):lower()
    local color

    if op == "stripes" then
        draw_stripes(command, screen_width, screen_height)
    elseif op == "grid" then
        draw_grid(command, screen_width, screen_height)
    elseif op == "rect" or op == "round_rect" then
        local x = coordinate(command.x, op .. ".x")
        local y = coordinate(command.y, op .. ".y")
        local w = size(command.width, op .. ".width")
        local h = size(command.height, op .. ".height")
        color = normalize_color(command.color, op .. ".color")
        if op == "round_rect" then
            local radius = integer(command.radius, op .. ".radius", 0, MAX_SIZE)
            if command.filled == false then
                display.draw_round_rect(x, y, w, h, radius, color)
            else
                display.fill_round_rect(x, y, w, h, radius, color)
            end
        elseif command.filled == false then
            display.draw_rect(x, y, w, h, color)
        else
            display.fill_rect(x, y, w, h, color)
        end
    elseif op == "line" then
        display.draw_line(coordinate(command.x0, "line.x0"),
                          coordinate(command.y0, "line.y0"),
                          coordinate(command.x1, "line.x1"),
                          coordinate(command.y1, "line.y1"),
                          normalize_color(command.color, "line.color"))
    elseif op == "pixel" then
        display.draw_pixel(coordinate(command.x, "pixel.x"),
                           coordinate(command.y, "pixel.y"),
                           normalize_color(command.color, "pixel.color"))
    elseif op == "circle" then
        local cx = coordinate(command.cx, "circle.cx")
        local cy = coordinate(command.cy, "circle.cy")
        local radius = integer(command.radius, "circle.radius", 1, MAX_SIZE)
        color = normalize_color(command.color, "circle.color")
        if command.filled == false then
            display.draw_circle(cx, cy, radius, color)
        else
            display.fill_circle(cx, cy, radius, color)
        end
    elseif op == "ellipse" then
        local cx = coordinate(command.cx, "ellipse.cx")
        local cy = coordinate(command.cy, "ellipse.cy")
        local rx = integer(command.radius_x, "ellipse.radius_x", 1, MAX_SIZE)
        local ry = integer(command.radius_y, "ellipse.radius_y", 1, MAX_SIZE)
        color = normalize_color(command.color, "ellipse.color")
        if command.filled == false then
            display.draw_ellipse(cx, cy, rx, ry, color)
        else
            display.fill_ellipse(cx, cy, rx, ry, color)
        end
    elseif op == "triangle" then
        local points = {
            coordinate(command.x1, "triangle.x1"), coordinate(command.y1, "triangle.y1"),
            coordinate(command.x2, "triangle.x2"), coordinate(command.y2, "triangle.y2"),
            coordinate(command.x3, "triangle.x3"), coordinate(command.y3, "triangle.y3"),
        }
        color = normalize_color(command.color, "triangle.color")
        if command.filled == false then
            display.draw_triangle(points[1], points[2], points[3], points[4],
                                  points[5], points[6], color)
        else
            display.fill_triangle(points[1], points[2], points[3], points[4],
                                  points[5], points[6], color)
        end
    elseif op == "arc" then
        local cx = coordinate(command.cx, "arc.cx")
        local cy = coordinate(command.cy, "arc.cy")
        local radius = integer(command.radius or command.outer_radius,
                               "arc.radius", 1, MAX_SIZE)
        local start_deg = number(command.start_deg, "arc.start_deg")
        local end_deg = number(command.end_deg, "arc.end_deg")
        color = normalize_color(command.color, "arc.color")
        if command.inner_radius ~= nil then
            display.fill_arc(cx, cy,
                             integer(command.inner_radius, "arc.inner_radius", 0, radius),
                             radius, start_deg, end_deg, color)
        else
            display.draw_arc(cx, cy, radius, start_deg, end_deg, color)
        end
    elseif op == "text" then
        local text = tostring(command.text or "")
        local printable_ascii = #text <= MAX_TEXT_BYTES
        for index = 1, #text do
            local byte = text:byte(index)
            if byte < 32 or byte > 126 then
                printable_ascii = false
                break
            end
        end
        if not printable_ascii then
            fail("text must contain at most 96 printable ASCII bytes")
        end
        local options = {
            color = normalize_color(command.color or "white", "text.color"),
            font_size = integer(command.font_size or 24, "text.font_size", 1, 255),
        }
        if command.bg ~= nil then
            options.bg = normalize_color(command.bg, "text.bg")
        end
        local x = coordinate(command.x, "text.x")
        local y = coordinate(command.y, "text.y")
        if command.width ~= nil or command.height ~= nil then
            options.align = tostring(command.align or "left")
            options.valign = tostring(command.valign or "top")
            display.draw_text_aligned(x, y,
                                      size(command.width, "text.width"),
                                      size(command.height, "text.height"),
                                      text, options)
        else
            display.draw_text(x, y, text, options)
        end
    else
        fail("unsupported command op: " .. op)
    end
end

local info, info_err = board_manager.get_board_info()
assert(info, TAG .. " get_board_info failed: " .. tostring(info_err))
assert(info.name == "esp32_steamakers_ai",
       TAG .. " wrong board: " .. tostring(info.name))

local panel, io_handle, width, height, panel_if, pixel_format =
    board_manager.get_display_lcd_params("display_lcd")
assert(panel, TAG .. " display_lcd unavailable: " .. tostring(io_handle))

local commands = args.commands
if commands ~= nil and (type(commands) ~= "table" or #commands > MAX_COMMANDS) then
    fail("commands must be an array with at most 64 entries")
end

-- Preserve the original public formats as compact aliases.
if commands == nil and type(args.colors) == "table" then
    assert(#args.colors == 4, TAG .. " colors must contain exactly four values")
    commands = {{ op = "grid", columns = 2, rows = 2, colors = args.colors }}
end

local background = normalize_color(args.background or args.color or "black", "background")
display.init(panel, io_handle, width, height, panel_if, pixel_format)

local ok, err = xpcall(function()
    display.begin_frame({ clear = true, color = background })
    if commands then
        for _, command in ipairs(commands) do
            draw_command(command, width, height)
        end
    end
    display.present_full()
    display.end_frame()
    print(string.format("%s SCENE commands=%d background=%s %dx%d",
                        TAG, commands and #commands or 0, tostring(background), width, height))
    while true do
        delay.delay_ms(1000)
    end
end, debug.traceback)

pcall(function() display.deinit() end)
if not ok then
    error(err)
end
