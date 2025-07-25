local log      = require("core.log")
local State    = require("control-server.state")
local EventBus = require("core.eventbus")
local AirLocks = require("control-server.models.airlocks")
local C        = require("control-server.config")

-- Define the typing for the message

---@class BootupMessage
---@field __module "airlock" -- The module that sent the ping, should be "airlock"
---@field type "bootup" -- The type of ping message, should be "status" for airlocks
---@field target "ACS" -- The target of the bootup message, typically the control server ID
---@field source string -- The source of the ping, typically the airlock's identifier

---@param msg BootupMessage
---@return nil
local function handleBootup(msg)
    if type(msg) ~= "table" then
        return
    end
    if msg.__module ~= "airlock" then
        log.warn("Received ping from non-airlock module: ", msg.__module)
        return
    end
    if msg.type ~= "bootup" then
        log.warn("Invalid bootup message: ", tostring(msg.type))
        return
    end
    if msg.target ~= "ACS" then
        log.warn("Bootup message target is not ACS: ", tostring(msg.target))
        return
    end

    local now = os.clock()
    log.debug("Bootup received from ", tostring(msg.source), textutils.serialise(msg))

    local existing = AirLocks:find({ name = msg.source })
    local airlockDoc = nil
    if not existing or #existing == 0 then
        log.warn("No airlock found for source: ", msg.source)
        -- Create airlock entry
        airlockDoc, err = AirLocks:new({
            name = msg.source,
            online = true,
            lastPing = now,
            awaitingPong = false,
            state = "open",

            ---@type AirlockFieldsConfig
            config = {
                peripherals = {},
                auto_close = true,
                auto_close_timeout = 7.5,
                after_auto_close_state = "entry",
                open_delay = 2.3,
            },
        })
        if not airlockDoc then
            log.error("Failed to create airlock entry: ", err)
            return {
                __module = "airlock-cs",
                type = "status",
                source = C.ID,
                target = msg.source,
                error = "Failed to create airlock entry",
                reason = err,
            }
        end
        return {
            __module = "airlock-cs",
            type = "status",
            source = C.ID,
            target = airlockDoc.name,
            _id = airlockDoc._id,
            state = airlockDoc.state,
            config = airlockDoc.config,
        }
    else
        ---@type Document<AirlockFields>
        airlockDoc = existing[1]
        -- Update existing airlock entry
        airlockDoc.online = true
        airlockDoc.lastPing = now
        airlockDoc:update({
            online = true,
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

return handleBootup
