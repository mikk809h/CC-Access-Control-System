local log           = require("core.log")
local StateMachine  = require("airlock.statemachine")
local Audio         = require("core.audio")
local ScreenHandler = require("airlock.screenHandler")
local Components    = require("core.components")
local C             = require("airlock.airlock").config
local Constants     = require("core.constants")
local airlock       = require("airlock.airlock")

local function onOnlineServer(msg)
    log.info("Server is online. Sending our current state")
    airlock.online = true
    -- Always respond to status (even if unchanged)
    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "transmit", Constants.Ports.PING,
        Constants.Ports.PING_RESPONSE, {
            __module = "airlock",
            type = "status",
            source = C.ID,
            state = StateMachine.current_state,
        })
    ScreenHandler.update() -- Update all screens with the new status
end

return {
    onOnlineServer = onOnlineServer
}
