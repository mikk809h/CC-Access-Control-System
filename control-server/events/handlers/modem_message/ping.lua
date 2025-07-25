local log      = require("core.log")
local State    = require("control-server.state")
local EventBus = require("core.eventbus")
local AirLocks = require("control-server.models.airlocks")
local C        = require("control-server.config")

-- Define the typing for the message

---@class PingMessage
---@field __module "airlock" | string -- The module that sent the ping, should be "airlock"
---@field type "status" | string -- The type of ping message, should be "status" for airlocks
---@field source string -- The source of the ping, typically the airlock's identifier
---@field state "open" | "closed" | "locked" | "entry" | "exit" -- The status of the airlock

---@param msg PingMessage
---@return nil
local function handlePing(msg)
    if type(msg) ~= "table" then
        return
    end
    if msg.__module ~= "airlock" then
        log.warn("Received ping from non-airlock module: ", msg.__module)
        return
    end
    if msg.type ~= "status" then
        log.warn("Invalid ping message: ", tostring(msg.type))
        return
    end

    local now = os.clock()
    log.debug("Ping received from ", tostring(msg.source), textutils.serialise(msg))

    local existing = AirLocks:find({ name = msg.source })
    local airlockDoc = nil
    if not existing or #existing == 0 then
        log.warn("No airlock found for source: ", msg.source)
        return {
            __module = "airlock-cs",
            type = "status",
            source = C.ID,
            target = msg.source,
            error = "Run BOOTUP sequence first"
        }
    else
        ---@type Document<AirlockFields>
        airlockDoc = existing[1]
        -- Update existing airlock entry
        airlockDoc.online = true
        airlockDoc.state = msg.state
        airlockDoc.lastPing = now
        airlockDoc:update({
            online = true,
            state = msg.state,
            lastPing = now,
            awaitingPong = false,
        })

        return {
            __module = "airlock-cs",
            type = "status",
            source = C.ID,
            target = airlockDoc.name,
            _id = airlockDoc._id,
            state = airlockDoc.state,
            config = airlockDoc.config,
        }
    end
end

return handlePing
