local log           = require("core.log")
local C             = require("airlock.airlock").config
local StateMachine  = require("airlock.statemachine")
local Audio         = require("core.audio")
local ScreenHandler = require("airlock.screenHandler")
local airlock       = require("airlock.airlock")


local function onBootupResponse(msg)
    log.info("Bootup response received", textutils.serialize(msg))
    airlock.online = true
    airlock.id = msg._id

    StateMachine.setInitialState(msg.state or "closed")
    ScreenHandler.update() -- Update all screens with the new status
end

return {
    onBootupResponse = onBootupResponse
}
