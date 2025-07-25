local log           = require("core.log")
local StateMachine  = require("airlock.statemachine")
local Audio         = require("core.audio")
local ScreenHandler = require("airlock.screenHandler")
local Components    = require("core.components")
local C             = require("airlock.airlock").config
local Constants     = require("core.constants")
local airlock       = require("airlock.airlock")

local function onStatusChanged(msg)
    log.info("Status has changed", textutils.serialize(msg))
    airlock.online = true
    -- Always respond to status (even if unchanged)
    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "transmit", Constants.Ports.STATUS_RESPONSE,
        Constants.Ports.STATUS, {
            __module = "airlock",
            type = "status",
            source = C.ID,
            state = StateMachine.current_state,
        })
    ScreenHandler.update() -- Update all screens with the new status
end

return {
    onOnlineServer = onStatusChanged
}
