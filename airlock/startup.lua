require("/initialize").initialize()

local log           = require("core.log")
local Init          = require("core.init")
local Components    = require("core.components")
local Audio         = require("core.audio")
local Door          = require("airlock.door")
local EventHandler  = require("airlock.eventHandler") -- require the new event handler
local ScreenHandler = require("airlock.screenHandler")
local configure     = require("airlock.configure")

local Airlock       = require("airlock.airlock")

if not Airlock.load_config() then
    -- try to reconfigure (user action)
    local success, error = configure.configure()
    if success then
        if not Airlock.load_config() then
            log.error("failed to load a valid configuration, please reconfigure")
            return
        end
    else
        log.error("configuration error: " .. error)
        return
    end
end


log.info("Initializing...")
log.info("Version: 1")

Init.ValidateComponents({
    ENTRANCE = { "KEYCARD", "DOOR", "SCREEN" },
    EXIT = { "DOOR" },
    AIRLOCK = { "SCREEN", "KEYCARD" },
    INFO = { "SCREEN" },
    OTHER = { "SPEAKER", "MODEM" }
}, Airlock.config.COMPONENTS)

local wrapped = Init.WrapComponents(Airlock.config.COMPONENTS)
Components.SetWrapper(wrapped)

ScreenHandler.init()

parallel.waitForAny(
    Audio.loop,
    Door.loop,
    EventHandler.runEventLoop -- replace your old modemEventLoop with this
)
