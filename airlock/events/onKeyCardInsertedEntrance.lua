local log = require("core.log")
local C = require("shared.config")
local Ports = require("shared.ports")
local Components = require("core.components")
local Sound = require("airlock.sound")
local Status = require("airlock.state")
local Door = require("airlock.door")
local screenHandler = require("airlock.screenHandler")

local COMPONENTS = C.COMPONENTS

local function onKeyCardInsertedEntrance()
    log.info("Key card inserted at entrance drive")

    -- Always eject disk
    Components.callComponent(COMPONENTS, "ENTRANCE", "KEYCARD", "ejectDisk")

    -- Case 2: Was in 'exit' mode or anything else, force to 'enter'
    log.info("Switching airlock from exit to enter mode")
    Door.setAirlockState("enter")
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
