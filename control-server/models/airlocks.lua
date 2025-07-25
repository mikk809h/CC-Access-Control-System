local Model = require("core.database.model")
local log   = require("core.log")

---@class AirlockFieldsConfig
---@field peripherals {[componentName: string]: string} -- Mapping of component names to their Peripheral name
---@field auto_close boolean -- Should the airlock auto-close after a timeout?
---@field auto_close_timeout number -- Timeout in seconds for auto-close
---@field after_auto_close_state "entry" | "close"
---@field open_delay number -- Delay in seconds between closing door 1 and opening door 2


---@class AirlockFields
---@field name string Typically the airlock identifier
---@field online boolean is this airlock online? (Reset on reboot)
---@field state StateEnum the statemachine state
---@field lastPing number Timestamp of the last ping sent
---@field config AirlockFieldsConfig Configuration for the airlock
---@field level number Minimum Access level required to open the airlock

---@type Model<AirlockFields>
local Airlock = Model.define("airlocks", {
    "name", "state", "config", "online", "lastPing", "level"
}, {
    name = function(v) return type(v) == "string" and #v > 0 end,
    online = function(v) return type(v) == "boolean" end,
    lastPing = function(v) return type(v) == "number" end,
    state = function(v) return type(v) == "string" and #v > 0 end,
    config = function(v) return type(v) == "table" end,
    level = function(v) return type(v) == "number" end,
}, {
    logger = function(msg, ...)
        -- log.info("Airlock Model:", msg, ...)
    end
})

log.info("Airlock model initialized")
local updatesToOffline = Airlock:update({
    online = true,
}, {
    online = false,
    lastPing = 0,
})

log.info("Airlock model initialized with updates to offline state: ", updatesToOffline)

return Airlock
