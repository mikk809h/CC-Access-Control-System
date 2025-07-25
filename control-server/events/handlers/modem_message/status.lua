local log      = require("core.log")
local State    = require("control-server.state")
local EventBus = require("core.eventbus")
local AirLocks = require("control-server.models.airlocks")
local C        = require("control-server.config")

-- Define the typing for the message

---@class StatusResponseMessage
---@field __module "airlock" | string -- The module that sent the ping, should be "airlock"
---@field type "status" | string -- The type of ping message, should be "status" for airlocks
---@field source string -- The source of the ping, typically the airlock's identifier
---@field state "open" | "closed" | "locked" | "entry" | "exit" -- The status of the airlock

---@param msg StatusResponseMessage
---@return nil
local function handleStatusResponse(msg)
    if type(msg) ~= "table" then
        return
    end
    if msg.__module ~= "airlock" then
        log.warn("Received status from non-airlock module: ", msg.__module)
        return
    end
    if msg.type ~= "status" then
        log.warn("Invalid status message: ", tostring(msg.type))
        return
    end

    log.debug("Status response received from ", tostring(msg.source))
end

return handleStatusResponse
