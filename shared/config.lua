---@alias ComponentGroup { [string]: string }

---@class Config
---@field ID string
---@field TYPE_NAME string
---@field OPENING_DELAY number
---@field AUTO_CLOSE_TIME number
---@field AIRLOCK_DIRECTION '"IN"' | '"OUT"'
---@field COMPONENTS table<string, ComponentGroup>

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
}
