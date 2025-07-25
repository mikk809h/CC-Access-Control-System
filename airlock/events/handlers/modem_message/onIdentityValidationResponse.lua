local log           = require("core.log")
local C             = require("airlock.airlock").config
local Audio         = require("core.audio")
local screenHandler = require("airlock.screenHandler")
local StateMachine  = require("airlock.statemachine")
local airlock       = require("airlock.airlock")
local helpers       = require("core.helpers")

local function onIdentityValidationResponse(event)
    local _, _, _, _, msg = table.unpack(event)
    airlock.online = true

    log.info("Identity validation received: " .. textutils.serialize(msg))

    if type(msg.target) == "table" and not helpers.isStringPresentInTable(msg.target, airlock.id) then
        log.debug("Response target mismatch: " .. tostring(msg.target))
        return
    elseif type(msg.target) == "string" and msg.target ~= airlock.id then
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
            if msg.reason and msg.reason == "lockdown_override" then
                log.info("Lockdown override detected, scheduling lockdown after transition")
                StateMachine.enqueueTransition("exit", { override_lockdown = true })
            else
                StateMachine.enqueueTransition("exit")
            end
            StateMachine.setAutoClose()
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
