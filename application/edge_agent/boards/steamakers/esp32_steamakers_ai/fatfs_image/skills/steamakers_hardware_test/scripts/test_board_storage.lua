local board_manager = require("board_manager")
local storage = require("storage")

local TAG = "[steamakers_board_storage]"

local info, info_err = board_manager.get_board_info()
assert(info, "get_board_info failed: " .. tostring(info_err))
assert(info.name == "esp32_steamakers_ai", "unexpected board: " .. tostring(info.name))
assert(info.chip == "esp32s3", "unexpected chip: " .. tostring(info.chip))
print(string.format("%s PASS board: %s/%s version=%s",
                    TAG, info.name, info.chip, tostring(info.version)))

local root = storage.get_root_dir()
assert(root == "/fatfs", "internal FATFS is not active; storage root is " .. tostring(root))

local path = storage.join_path(root, ".steamakers-hardware-test.tmp")
local payload = "ESP-Claw STEAMakers AI internal storage round trip\n"
assert(storage.write_file(path, payload))
local actual = assert(storage.read_file(path))
assert(actual == payload, "internal storage readback mismatch")
assert(storage.remove(path))

local space = assert(storage.get_free_space())
print(string.format("%s PASS internal storage: root=%s total=%s free=%s",
                    TAG, root, tostring(space.total), tostring(space.free)))
print(TAG .. " ALL PASS")
