local log           = require("core.log")
local C             = require("airlock.airlock").config
local Components    = require("core.components")
local screenHandler = require("airlock.screenHandler")
local StateMachine  = require("airlock.statemachine")


local function onKeyCardInsertedEntrance()
    log.info("Key card inserted at entrance drive")

    -- Always eject disk
    Components.callComponent(C.COMPONENTS, "ENTRANCE", "KEYCARD", "ejectDisk")

    -- Case 2: Was in 'exit' mode or anything else, force to 'enter'
    log.info("Switching airlock from exit to enter mode")
    StateMachine.enqueueTransition("entry")
    -- Door.setAirlockState("enter")
    screenHandler.updateGroup("AIRLOCK", {
        hasPresentedKeycardThisSession = false,
        validating = false,
        accessGranted = false,
        reason = "Reverted to entry",
        identifier = "",
    })
end

return {
    onKeyCardInsertedEntrance = onKeyCardInsertedEntrance
}
