local log = require("core.log")
local C = require("airlock.airlock").config
local Ports = require("core.constants").Ports
local StateMachine = require("airlock.statemachine")
local Audio = require("core.audio")
local Components = require("core.components")
local ScreenHandler = require("airlock.screenHandler")
local debug = require("core.debug")
local airlock = require("airlock.airlock")

local function onCommand(msg)
    log.info("Command received", textutils.serialize(msg))
    airlock.online = true

    StateMachine.enqueueTransition(msg.transition)

    ScreenHandler.update() -- Update all screens with the new status
end

return {
    onCommand = onCommand
}
