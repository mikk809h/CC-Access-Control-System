---@alias SoundNote { [1]: string, [2]: number, [3]: number }
---@alias SoundEntry (SoundNote | number)[]
---@alias ComponentGroup { [string]: string }

---@class Config
---@field ID string
---@field TYPE_NAME string
---@field OPENING_DELAY number
---@field AUTO_CLOSE_TIME number
---@field AIRLOCK_DIRECTION '"IN"' | '"OUT"'
---@field COMPONENTS table<string, ComponentGroup>
---@field SOUNDS table<string, SoundEntry>

---@type Config
return {
    ID = "A1.Entrance",
    TYPE_NAME = "Airlock A1 Entrance",
    OPENING_DELAY = 2.5,
    AUTO_CLOSE_TIME = 10,
    AIRLOCK_DIRECTION = "IN",
    COMPONENTS = {
        ENTRANCE = { DOOR = "redstoneIntegrator_6", KEYCARD = "drive_4", SCREEN = "monitor_3" },
        EXIT = { DOOR = "redstoneIntegrator_5" },
        AIRLOCK = { KEYCARD = "drive_1", SCREEN = "monitor_1" },
        INFO = { SCREEN = "monitor_2" },
        OTHER = { SPEAKER = "right", MODEM = "left" },
    },
    SOUNDS = {
        ENTRY = { { "bit", 1, 12 }, 0.7, { "bit", 1, 0 }, 0.45, { "bit", 1, 6 } },
        DENIED = { { "bit", 1, 10 }, 0.15, { "bit", 1, 0 } },
        OFFLINE = { { "bit", 0.5, 1 } },
        ONLINE = { { "chime", 0.25, 2 } },
        LOCKDOWN = { { "bit", 1, 4 }, 0.2, { "bit", 1, 0 } },
        NO_IDENTITY = { { "bit", 1, 6 }, 0.2, { "bit", 1, 0 } },
        EMPTY_IDENTITY = { { "bit", 1, 8 }, 0.4, { "bit", 1, 5 }, 0.45, { "bit", 1, 3 } },
        UNKNOWN_ERROR = { { "bit", 1, 2 }, 0.2, { "bit", 1, 12 }, 0.4, { "bit", 1, 0 } },
    }
}
