local log = require "core.log"
local State = require("control-server.state")

local function handlePing(msg)
    if type(msg) ~= "table" or msg.type ~= "status" then
        log.warn("Invalid ping message: ", tostring(msg.type))
        return
    end

    local now = os.clock()
    log.debug("ACK received from ", tostring(msg.source))

    if not State.clients[msg.source] then
        State.clients[msg.source] = {}
    end

    State.clients[msg.source].lastPing = now
    State.clients[msg.source].online = true
    State.clients[msg.source].waitingForAck = false
end

return handlePing
