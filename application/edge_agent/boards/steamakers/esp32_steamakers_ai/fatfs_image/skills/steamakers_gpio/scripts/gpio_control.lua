local board_manager = require("board_manager")
local delay = require("delay")

local TAG = "[steamakers_gpio]"

local aliases = {
    A0 = 2, A1 = 3, A2 = 14, A3 = 19,
    D0 = 18, D1 = 17, D8 = 47, D9 = 48,
    D10 = 10, D11 = 11, D12 = 13, D13 = 12,
    SDA = 8, SCL = 9,
}

local safe_pins = {
    [2] = true, [8] = true, [9] = true, [10] = true,
    [11] = true, [12] = true, [13] = true, [14] = true,
    [17] = true, [18] = true, [47] = true, [48] = true,
}

local conditional_pins = {
    [3] = "ESP32-S3 strapping pin (A1)",
    [19] = "USB D- pin (A3); disconnect USB OTG",
}

local adc1_pins = {
    [2] = true, [3] = true, [8] = true, [9] = true, [10] = true,
}

local function fail(message)
    error(TAG .. " " .. message)
end

local function number_arg(name, default, minimum, maximum)
    local value = args[name]
    if value == nil then
        value = default
    end
    if type(value) ~= "number" then
        fail("args." .. name .. " must be a number")
    end
    if minimum ~= nil and value < minimum then
        fail("args." .. name .. " must be >= " .. tostring(minimum))
    end
    if maximum ~= nil and value > maximum then
        fail("args." .. name .. " must be <= " .. tostring(maximum))
    end
    return value
end

local function integer_arg(name, default, minimum, maximum)
    local value = number_arg(name, default, minimum, maximum)
    if value ~= math.floor(value) then
        fail("args." .. name .. " must be an integer")
    end
    return value
end

local function resolve_pin(raw_pin)
    local pin = raw_pin
    if type(pin) == "string" then
        pin = aliases[string.upper(pin)]
    end
    if type(pin) ~= "number" or pin ~= math.floor(pin) then
        fail("args.pin must be a GPIO number or supported board alias")
    end
    if safe_pins[pin] then
        return pin, false
    end
    if conditional_pins[pin] then
        if args.allow_conditional ~= true then
            fail(string.format("GPIO%d is conditional: %s", pin, conditional_pins[pin]) ..
                 "; explicit allow_conditional=true is required")
        end
        return pin, true
    end
    fail(string.format("GPIO%d is reserved, unavailable, or not exposed as generic I/O", pin))
end

local function validate_board()
    local info, err = board_manager.get_board_info()
    if not info then
        fail("get_board_info failed: " .. tostring(err))
    end
    if info.name ~= "esp32_steamakers_ai" or info.chip ~= "esp32s3" then
        fail("unexpected board: " .. tostring(info.name) .. "/" .. tostring(info.chip))
    end
end

local function list_pins()
    print(TAG .. " header power: G=ground V=5V peripheral supply from onboard converter")
    print(TAG .. " header signal: S=ESP32-S3 GPIO, 3.3V logic; never apply a 5V signal to S/ADC")
    print(TAG .. " safe digital GPIO: 2,8,9,10,11,12,13,14,17,18,47,48")
    print(TAG .. " safe ADC1 GPIO: 2,8,9,10")
    print(TAG .. " conditional: GPIO3/A1 (strap, ADC1), GPIO19/A3 (USB D-, digital only)")
    print(TAG .. " aliases: A0=2 A1=3 A2=14 A3=19 D0=18 D1=17 D8=47 D9=48 D10=10 D11=11 D12=13 D13=12 SDA=8 SCL=9")
    print(TAG .. " reserved: boot=0 audio=4,5,6,7,15,16 TFT=20,21,38,40,41,42 PSRAM/SD=35,36,37,39 console=43,44")
end

local function digital_write(pin)
    local gpio = require("gpio")
    local level = integer_arg("level", nil, 0, 1)
    gpio.set_level(pin, level)
    gpio.set_direction(pin, "output")
    print(string.format("%s WRITE GPIO%d level=%d", TAG, pin, level))
end

local function digital_read(pin)
    local gpio = require("gpio")
    local pull = args.pull or "none"
    if pull ~= "none" and pull ~= "up" and pull ~= "down" then
        fail("args.pull must be none, up, or down")
    end
    gpio.set_direction(pin, "input")
    gpio.set_pull_mode(pin, pull)
    delay.delay_ms(5)
    local level = gpio.get_level(pin)
    print(string.format("%s READ GPIO%d level=%d pull=%s", TAG, pin, level, pull))
end

local function analog_read(pin)
    if not adc1_pins[pin] then
        fail(string.format("GPIO%d is not an allowed ADC1 pin while Wi-Fi is active", pin))
    end
    local adc = require("adc")
    local samples = integer_arg("samples", 8, 1, 64)
    local interval_ms = integer_arg("interval_ms", 5, 0, 1000)
    local channel = adc.new(pin)
    local total = 0
    local minimum
    local maximum
    for index = 1, samples do
        local millivolts = channel:read()
        total = total + millivolts
        minimum = minimum and math.min(minimum, millivolts) or millivolts
        maximum = maximum and math.max(maximum, millivolts) or millivolts
        if index < samples and interval_ms > 0 then
            delay.delay_ms(interval_ms)
        end
    end
    channel:close()
    print(string.format("%s ANALOG GPIO%d avg_mv=%.1f min_mv=%d max_mv=%d samples=%d",
                        TAG, pin, total / samples, minimum, maximum, samples))
end

local function run_pwm(pin, frequency_hz, duty_percent, duration_ms, label)
    local mcpwm = require("mcpwm")
    local pwm = mcpwm.new({
        gpio = pin,
        resolution_hz = 1000000,
        frequency_hz = frequency_hz,
        duty_percent = duty_percent,
    })
    pwm:start()
    delay.delay_ms(duration_ms)
    pwm:stop()
    pwm:close()
    require("gpio").reset(pin)
    print(string.format("%s %s GPIO%d frequency_hz=%d duty_percent=%.3f duration_ms=%d released=true",
                        TAG, label, pin, frequency_hz, duty_percent, duration_ms))
end

local function pwm_output(pin, is_tone)
    local min_frequency = is_tone and 20 or 1
    local frequency_hz = integer_arg("frequency_hz", is_tone and 1000 or nil,
                                     min_frequency, 20000)
    local duty_percent = number_arg("duty_percent", 50, 0, 100)
    local duration_ms = integer_arg("duration_ms", is_tone and 500 or nil, 10, 60000)
    run_pwm(pin, frequency_hz, duty_percent, duration_ms, is_tone and "TONE" or "PWM")
end

local function servo_move(pin)
    local angle = number_arg("angle", nil, 0, 180)
    local hold_ms = integer_arg("hold_ms", 750, 100, 10000)
    local min_pulse_us = integer_arg("min_pulse_us", 500, 400, 1500)
    local max_pulse_us = integer_arg("max_pulse_us", 2500, 1500, 3000)
    if min_pulse_us >= max_pulse_us then
        fail("min_pulse_us must be less than max_pulse_us")
    end
    local pulse_us = min_pulse_us + (max_pulse_us - min_pulse_us) * angle / 180
    local duty_percent = pulse_us * 100 / 20000
    run_pwm(pin, 50, duty_percent, hold_ms, "SERVO")
    print(string.format("%s SERVO_TARGET angle=%.1f pulse_us=%.1f", TAG, angle, pulse_us))
end

local function release_pin(pin)
    local gpio = require("gpio")
    gpio.set_level(pin, 0)
    gpio.reset(pin)
    print(string.format("%s RELEASE GPIO%d", TAG, pin))
end

args = type(args) == "table" and args or {}
local action = args.action or "list"

validate_board()

if action == "list" then
    list_pins()
else
    local pin = resolve_pin(args.pin)
    if action == "write" then
        digital_write(pin)
    elseif action == "read" then
        digital_read(pin)
    elseif action == "analog" then
        analog_read(pin)
    elseif action == "pwm" then
        pwm_output(pin, false)
    elseif action == "tone" then
        pwm_output(pin, true)
    elseif action == "servo" then
        servo_move(pin)
    elseif action == "release" then
        release_pin(pin)
    else
        fail("args.action must be list, write, read, analog, pwm, tone, servo, or release")
    end
end
