local log = require("core.log")
local C = require("shared.config")
local Ports = require("shared.ports")
local Components = require("core.components")
local Sound = require("airlock.sound")
local Status = require("airlock.state")
local screenHandler = require("airlock.screenHandler")

local COMPONENTS = C.COMPONENTS

local function onKeyCardInserted()
    log.info("Key card inserted event")

    if not Status.online then
        log.warn("System offline - ejecting card")
        Sound.play("OFFLINE")
        Components.callComponent(COMPONENTS, "AIRLOCK", "KEYCARD", "ejectDisk")
        return
    end

    if not fs.exists("disk/identity") then
        log.warn("No identity disk found - ejecting card")
        Sound.play("NO_IDENTITY")
        Components.callComponent(COMPONENTS, "AIRLOCK", "KEYCARD", "ejectDisk")
        return
    end

    local f = fs.open("disk/identity", "r")
    local id = f.readAll()
    f.close()

    log.debug("Read identity: " .. tostring(id))

    Components.callComponent(COMPONENTS, "AIRLOCK", "KEYCARD", "ejectDisk")

    Components.callComponent(COMPONENTS, "OTHER", "MODEM", "transmit", Ports.VALIDATION, Ports.VALIDATION_RESPONSE, {
        type = "validation_request",
        direction = C.AIRLOCK_DIRECTION,
        identifier = id,
        source = C.ID,
    })

    Sound.play("VALIDATION_REQUEST")

    -- Update the screen to show the validation request
    screenHandler.updateGroup("AIRLOCK", {
        hasPresentedKeycardThisSession = true,
        validating = true,
        accessGranted = false,
        reason = "",
    })
    log.info("Validation request sent for id " .. tostring(id))
end

return {
    onKeyCardInserted = onKeyCardInserted
}
