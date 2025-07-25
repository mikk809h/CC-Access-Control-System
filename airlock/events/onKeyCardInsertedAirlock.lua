local log           = require("core.log")
local C             = require("airlock.airlock").config
local Ports         = require("core.constants").Ports
local Components    = require("core.components")
local Audio         = require("core.audio")
local screenHandler = require("airlock.screenHandler")
local airlock       = require("airlock.airlock")

local function onKeyCardInsertedAirlock()
    log.info("Key card inserted event")

    if not fs.exists("disk/identity") then
        log.warn("No identity disk found - ejecting card")
        Audio.play("NO_IDENTITY")
        Components.callComponent(C.COMPONENTS, "AIRLOCK", "KEYCARD", "ejectDisk")
        return
    end

    local f = fs.open("disk/identity", "r")
    local id = f.readAll()
    f.close()

    log.debug("Read identity: " .. tostring(id))

    Components.callComponent(C.COMPONENTS, "AIRLOCK", "KEYCARD", "ejectDisk")

    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "transmit", Ports.VALIDATION, Ports.VALIDATION_RESPONSE, {
        type = "validation_request",
        direction = C.AIRLOCK_DIRECTION,
        identifier = id,
        source = airlock.id,
    })

    Audio.play("VALIDATION_REQUEST")

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
    onKeyCardInsertedAirlock = onKeyCardInsertedAirlock
}
