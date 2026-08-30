local audio = require("audio")
local board_manager = require("board_manager")
local delay = require("delay")

local TAG = "[steamakers_speaker]"
local volume = tonumber(args and args.volume) or 70
assert(volume >= 1 and volume <= 80, "volume must be in range 1..80")

local codec, rate, channels, bits =
    board_manager.get_audio_codec_output_params("audio_dac")
assert(codec, "audio_dac unavailable: " .. tostring(rate))
assert(rate == 24000 and channels == 2 and bits == 16,
       string.format("unexpected output format: %sHz/%sch/%sbit",
                     tostring(rate), tostring(channels), tostring(bits)))

local output = assert(audio.new_output({ codec, rate, channels, bits, volume = volume }))
local ok, err = xpcall(function()
    print(string.format("%s INFO output=%dHz/%dch/%dbit volume=%d",
                        TAG, rate, channels, bits, volume))
    print(TAG .. " ACTION listen for three ascending tones")
    output:play_tone(523, 350)
    delay.delay_ms(350)
    output:play_tone(659, 350)
    delay.delay_ms(350)
    output:play_tone(784, 500)
    delay.delay_ms(500)
end, debug.traceback)

pcall(function() output:close() end)
if not ok then
    error(err)
end
print(TAG .. " PASS three tones submitted")
print(TAG .. " ALL PASS")
