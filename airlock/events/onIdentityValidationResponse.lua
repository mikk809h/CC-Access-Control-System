local log = require("core.log")
local C = require("airlock.airlock").config
local Audio = require("core.audio")
local Door = require("airlock.door")
local screenHandler = require("airlock.screenHandler")

local function onIdentityValidationResponse(event)
    local _, _, _, _, msg = table.unpack(event)

    log.info("Identity validation received: " .. textutils.serialize(msg))

    if msg.target ~= C.ID then
        log.debug("Response target mismatch: " .. tostring(msg.target))
        return
    end

    if msg.status == "success" then
        if msg.action == "allow" then
            log.info("Access granted - opening airlock")

            screenHandler.updateGroup("AIRLOCK", {
                hasPresentedKeycardThisSession = true,
                validating = false,
                accessGranted = true,
                reason = "",
                identifier = msg.identifier,
            })
            Audio.play("ENTRY")
            Door.setAirlockState("exit")
        else
            log.warn("Access denied by validation")
            screenHandler.updateGroup("AIRLOCK", {
                hasPresentedKeycardThisSession = true,
                validating = false,
                accessGranted = false,
                reason = msg.reason or "Unknown",
                identifier = msg.identifier,
            })
            Audio.play("DENIED")
        end
    elseif msg.status == "error" then
        log.error("Validation error received")
        screenHandler.updateGroup("AIRLOCK", {
            hasPresentedKeycardThisSession = true,
            validating = false,
            accessGranted = false,
            reason = msg.reason or "Unknown error",
            identifier = msg.identifier,
        })
        Audio.play("UNKNOWN_ERROR")
    else
        log.warn("Unknown validation status: " .. tostring(msg.status))
    end
end

return {
    onIdentityValidationResponse = onIdentityValidationResponse
}
