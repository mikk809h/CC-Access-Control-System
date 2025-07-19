local log = require("core.log")
local C = require("shared.config")
local Ports = require("shared.ports")
local Init = require("core.init")
local Components = require("core.components")
local Sound = require("airlock.sound")
local Door = require("airlock.door")
local EventHandler = require("airlock.eventHandler") -- require the new event handler
local ScreenHandler = require("airlock.screenHandler")

log.info("Initializing...")
log.info("Version: 1")

Init.ValidateComponents({
    ENTRANCE = { "KEYCARD", "DOOR", "SCREEN" },
    EXIT = { "DOOR" },
    AIRLOCK = { "SCREEN", "KEYCARD" },
    INFO = { "SCREEN" },
    OTHER = { "SPEAKER", "MODEM" }
})

local wrapped = Init.WrapComponents()
Components.SetWrapper(wrapped)

ScreenHandler.init()

parallel.waitForAny(
    Sound.loop,
    Door.loop,
    EventHandler.runEventLoop -- replace your old modemEventLoop with this
)
