local audio = require("audio")
local board_manager = require("board_manager")
local delay = require("delay")

local TAG = "[steamakers_microphone]"
local codec, rate, channels, bits =
    board_manager.get_audio_codec_input_params("audio_adc")
assert(codec, "audio_adc unavailable: " .. tostring(rate))
assert(rate == 16000 and channels == 1 and bits == 16,
       string.format("unexpected input format: %sHz/%sch/%sbit",
                     tostring(rate), tostring(channels), tostring(bits)))

local input = assert(audio.new_input({ codec, rate, channels, bits, volume = 70 }))
local analyzer = assert(audio.analyzer({ input = input }))
local ok, err = xpcall(function()
    print(string.format("%s INFO input=%dHz/%dch/%dbit", TAG, rate, channels, bits))
    print(TAG .. " ACTION speak continuously into the microphone now")
    delay.delay_ms(500)

    local max_rms = 0
    local max_peak = 0
    for _ = 1, 25 do
        -- A 20 ms window keeps both analyzer buffers below 1 KiB.
        local level = assert(analyzer:read_level({ duration_ms = 20 }))
        if level.rms > max_rms then
            max_rms = level.rms
        end
        if level.peak > max_peak then
            max_peak = level.peak
        end
    end
    assert(max_peak > 0, "microphone returned zero peak; check L/R=GND and GPIO4/5/6")
    print(string.format("%s PASS signal: max_rms=%d max_peak=%d",
                        TAG, max_rms, max_peak))
end, debug.traceback)

pcall(function() analyzer:close() end)
pcall(function() input:close() end)
if not ok then
    error(err)
end
print(TAG .. " ALL PASS")
