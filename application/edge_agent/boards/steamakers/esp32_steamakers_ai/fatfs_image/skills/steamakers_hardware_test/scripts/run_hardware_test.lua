local arg_schema = require("arg_schema")
local audio = require("audio")
local board_manager = require("board_manager")
local delay = require("delay")
local display = require("display")
local storage = require("storage")

local TAG = "[steamakers_hw_test]"

local ARG_SCHEMA = {
    volume = arg_schema.int({ default = 35, min = 1, max = 70 }),
    record_ms = arg_schema.int({ default = 3000, min = 2000, max = 8000 }),
}

local ctx = arg_schema.parse(args or {}, ARG_SCHEMA)
local results = {}

local function traceback(err)
    return debug.traceback(tostring(err), 2)
end

local function run_test(name, fn)
    print(string.format("%s START %s", TAG, name))
    local ok, detail = xpcall(fn, traceback)
    if ok then
        detail = detail or "ok"
        print(string.format("%s PASS %s: %s", TAG, name, tostring(detail)))
    else
        print(string.format("%s FAIL %s: %s", TAG, name, tostring(detail)))
    end
    results[#results + 1] = { name = name, ok = ok, detail = detail }
    return ok
end

local function draw_message(title, subtitle, background)
    print(string.format("%s STATUS %s: %s", TAG, title, subtitle or ""))
end

local function test_board()
    local info, err = board_manager.get_board_info()
    assert(info, "get_board_info failed: " .. tostring(err))
    assert(info.name == "esp32_steamakers_ai", "unexpected board: " .. tostring(info.name))
    assert(info.chip == "esp32s3", "unexpected chip: " .. tostring(info.chip))
    return string.format("%s/%s version=%s", info.name, info.chip, tostring(info.version))
end

local function test_storage()
    local root = storage.get_root_dir()
    assert(root == "/fatfs", "internal FATFS is not active; storage root is " .. tostring(root))

    local path = storage.join_path(root, ".steamakers-hardware-test.tmp")
    local payload = "ESP-Claw STEAMakers AI internal storage round trip\n"
    assert(storage.write_file(path, payload))
    local actual = assert(storage.read_file(path))
    assert(actual == payload, "internal storage readback mismatch")
    assert(storage.remove(path))

    local space = assert(storage.get_free_space())
    return string.format("root=%s total=%s free=%s",
                         root, tostring(space.total), tostring(space.free))
end

local function test_display()
    local panel, io_handle, width, height, panel_if, pixel_format =
        board_manager.get_display_lcd_params("display_lcd")
    assert(panel, "display_lcd unavailable: " .. tostring(io_handle))
    assert(width == 240 and height == 240,
           string.format("unexpected display geometry: %sx%s", tostring(width), tostring(height)))

    display.init(panel, io_handle, width, height, panel_if, pixel_format)

    local half_w = math.floor(width / 2)
    local half_h = math.floor(height / 2)
    -- Direct opaque draws keep this diagnostic independent from LVGL buffers.
    display.clear("black")
    display.fill_rect(0, 0, half_w, half_h, { r = 255, g = 0, b = 0 })
    display.fill_rect(half_w, 0, width - half_w, half_h, { r = 0, g = 255, b = 0 })
    display.fill_rect(0, half_h, half_w, height - half_h, { r = 0, g = 0, b = 255 })
    display.fill_rect(half_w, half_h, width - half_w, height - half_h,
                      { r = 255, g = 255, b = 255 })
    delay.delay_ms(2000)
    display.deinit()

    return string.format("%dx%d panel_if=%s pixel_format=%s",
                         width, height, tostring(panel_if), tostring(pixel_format))
end

local function test_speaker()
    local output
    local ok, detail = xpcall(function()
        local codec, rate, channels, bits =
            board_manager.get_audio_codec_output_params("audio_dac")
        assert(codec, "audio_dac unavailable: " .. tostring(rate))
        assert(rate == 24000 and channels == 1 and bits == 16,
               string.format("unexpected output format: %sHz/%sch/%sbit",
                             tostring(rate), tostring(channels), tostring(bits)))

        draw_message("ALTAVEU", "Escolta tres tons")
        output = assert(audio.new_output({ codec, rate, channels, bits, volume = ctx.volume }))
        output:play_tone(523, 350)
        delay.delay_ms(350)
        output:play_tone(659, 350)
        delay.delay_ms(350)
        output:play_tone(784, 500)
        delay.delay_ms(500)
        return string.format("%dHz/%dch/%dbit volume=%d", rate, channels, bits, ctx.volume)
    end, traceback)

    if output then
        pcall(function() output:close() end)
    end
    if not ok then
        error(detail)
    end
    return detail
end

local function test_microphone()
    local input
    local analyzer
    local ok, detail = xpcall(function()
        local codec, rate, channels, bits =
            board_manager.get_audio_codec_input_params("audio_adc")
        assert(codec, "audio_adc unavailable: " .. tostring(rate))
        assert(rate == 16000 and channels == 1 and bits == 16,
               string.format("unexpected input format: %sHz/%sch/%sbit",
                             tostring(rate), tostring(channels), tostring(bits)))

        draw_message("MICROFON", "PARLA ARA")
        print(TAG .. " ACTION speak continuously into the microphone")
        delay.delay_ms(700)
        input = assert(audio.new_input({ codec, rate, channels, bits, volume = 70 }))
        analyzer = assert(audio.analyzer({ input = input }))
        local level = analyzer:read_level({ duration_ms = 1800 })
        assert(level.peak and level.peak > 0,
               "microphone returned zero peak; check L/R=GND and GPIO4/5/6")
        return string.format("%dHz/%dch/%dbit rms=%d peak=%d",
                             rate, channels, bits, level.rms, level.peak)
    end, traceback)

    if analyzer then
        pcall(function() analyzer:close() end)
    end
    if input then
        pcall(function() input:close() end)
    end
    if not ok then
        error(detail)
    end
    return detail
end

local function test_record_playback()
    local root = storage.get_root_dir()
    local rec_path = storage.join_path(root, ".steamakers-hardware-test.aac")
    local input
    local recorder
    local output
    local player

    local ok, detail = xpcall(function()
        local input_codec, input_rate, input_channels, input_bits =
            board_manager.get_audio_codec_input_params("audio_adc")
        assert(input_codec, "audio_adc unavailable: " .. tostring(input_rate))

        draw_message("GRAVANT", "PARLA ARA")
        print(string.format("%s ACTION recording for %d ms", TAG, ctx.record_ms))
        input = assert(audio.new_input({
            input_codec, input_rate, input_channels, input_bits, volume = 70,
        }))
        recorder = assert(audio.recorder({ input = input }))
        local rec_info = recorder:record(rec_path, { duration_ms = ctx.record_ms })
        assert(rec_info and rec_info.bytes and rec_info.bytes > 0, "recording is empty")

        recorder:close()
        recorder = nil
        input:close()
        input = nil

        local output_codec, output_rate, output_channels, output_bits =
            board_manager.get_audio_codec_output_params("audio_dac")
        assert(output_codec, "audio_dac unavailable: " .. tostring(output_rate))

        draw_message("REPRODUINT", "Escolta la teva veu")
        output = assert(audio.new_output({
            output_codec, output_rate, output_channels, output_bits, volume = ctx.volume,
        }))
        player = assert(audio.player({ output = output }))
        player:play(rec_path, { wait = true })
        local state = player:poll()
        return string.format("bytes=%d state=%s", rec_info.bytes, tostring(state.state))
    end, traceback)

    if player then
        pcall(function() player:close() end)
    end
    if output then
        pcall(function() output:close() end)
    end
    if recorder then
        pcall(function() recorder:close() end)
    end
    if input then
        pcall(function() input:close() end)
    end
    pcall(function()
        if storage.exists(rec_path) then
            storage.remove(rec_path)
        end
    end)

    if not ok then
        error(detail)
    end
    return detail
end

run_test("board", test_board)
run_test("internal_storage", test_storage)
run_test("display", test_display)
run_test("speaker", test_speaker)
run_test("microphone", test_microphone)
run_test("record_playback", test_record_playback)

local passed = 0
local failures = {}
for _, result in ipairs(results) do
    if result.ok then
        passed = passed + 1
    else
        failures[#failures + 1] = result.name
    end
end

if #failures == 0 then
    draw_message("TOT CORRECTE", "6/6 proves PASS", { r = 0, g = 80, b = 30 })
    print(TAG .. " ALL PASS")
else
    draw_message("ERROR", table.concat(failures, ", "), { r = 110, g = 0, b = 0 })
    print(string.format("%s SUMMARY %d/6 PASS; failed=%s",
                        TAG, passed, table.concat(failures, ",")))
end

delay.delay_ms(5000)

if #failures > 0 then
    error("hardware test failed: " .. table.concat(failures, ", "))
end
