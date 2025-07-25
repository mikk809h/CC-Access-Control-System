local log = require("core.log")
local C = require("airlock.airlock").config
local Ports = require("core.constants").Ports
local StateMachine = require("airlock.statemachine")
local Audio = require("core.audio")
local Components = require("core.components")
local ScreenHandler = require("airlock.screenHandler")
local debug = require("core.debug")
local airlock = require("airlock.airlock")

local function onPingResponse(msg)
    log.info("Ping Response received")
    airlock.id = msg._id or airlock.id
    airlock.online = true

    if msg.error and msg.error == "Run BOOTUP sequence first" then
        -- Send the bootup request.

        Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "transmit", Ports.BOOTUP, Ports.BOOTUP_RESPONSE, {
            __module = "airlock",
            type = "bootup",
            source = C.ID,
            target = "ACS",
        })
    end
    ScreenHandler.update() -- Update all screens with the new status
end

return {
    onPingResponse = onPingResponse
}
