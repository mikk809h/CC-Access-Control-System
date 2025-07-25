require("/initialize").initialize()
local Constants        = require("core.constants")
local Scheduler        = require("core.scheduler")

local log              = require("core.log")
log.config.logFilePath = "logs/airlock.log"

local Init             = require("core.init")
local Components       = require("core.components")
local Audio            = require("core.audio")

local EventHandler     = require("airlock.eventHandler") -- require the new event handler
local ScreenHandler    = require("airlock.screenHandler")
local Configurator     = require("airlock.configure")
local StateMachine     = require("airlock.statemachine")
local Airlock          = require("airlock.airlock")

if not Airlock.load_config() then
    log.warn("Failed to load a valid configuration, attempting to reconfigure...")
    sleep(0.5)
    -- try to reconfigure (user action)
    local success, error = Configurator.run()
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
Init.ValidateComponents({
    ENTRANCE = { "KEYCARD", "DOOR", "SCREEN" },
    EXIT = { "DOOR" },
    AIRLOCK = { "SCREEN", "KEYCARD" },
    INFO = { "SCREEN" },
    OTHER = { "SPEAKER", "MODEM" }
}, Airlock.config.COMPONENTS)

local wrapped = Init.WrapComponents(Airlock.config.COMPONENTS)
Components.SetWrapper(wrapped)

StateMachine.subscribe("changing", function(newState, oldState)
    log.info("State changing from " .. oldState .. " to " .. newState)
    Components.callComponent(Airlock.config.COMPONENTS, "OTHER", "MODEM", "transmit", Constants.Ports.COMMAND_RESPONSE,
        Constants.Ports.COMMAND, {
            __module = "airlock",
            type = "status",
            source = Airlock.config.ID,
            state = newState,
        })
end)
ScreenHandler.init()


StateMachine.subscribe("change", function(newState, oldState)
    ScreenHandler.update({
        type = "state_change"
    })
    log.info("State changed from " .. oldState .. " to " .. newState)
    Components.callComponent(Airlock.config.COMPONENTS, "OTHER", "MODEM", "transmit", Constants.Ports.COMMAND_RESPONSE,
        Constants.Ports.COMMAND, {
            __module = "airlock",
            type = "status",
            source = Airlock.config.ID,
            state = newState,
        })
end)

parallel.waitForAny(
    Audio.createLoopInstance(function(method, ...)
        local args = { ... }
        Components.callComponent(Airlock.config.COMPONENTS, "OTHER", "SPEAKER", method, table.unpack(args))
    end),
    StateMachine.loop,
    EventHandler.runEventLoop,
    Scheduler.loop
)
