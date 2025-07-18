local log = require("core.log")
local C = require("shared.config")
local Ports = require("shared.ports")
local Status = require("airlock.state")
local Door = require("airlock.door")
local Sound = require("airlock.sound")
local Components = require("core.components")
local ScreenHandler = require("airlock.screenHandler")

-- Keep a copy of the last applied state to detect changes
local previous = {
    online = nil,
    lockdown = nil,
    lockdownIDs = {},
    inLocalLockdown = false,
}

local function isLocalLockdown(lockdownIDs)
    if type(lockdownIDs) ~= "table" then return true end
    for _, id in ipairs(lockdownIDs) do
        if id == C.ID then return true end
    end
    return false
end

local function onStatus(msg)
    log.info("Status update received")

    -- Detect change in online status
    if previous.online ~= msg.online then
        previous.online = msg.online
        Status.online = msg.online
        log.debug("Online status changed: " .. tostring(msg.online))
    end

    -- Detect change in lockdown status
    local isNowLocked = msg.lockdown and isLocalLockdown(msg.lockdownIDs)
    if previous.inLocalLockdown ~= isNowLocked then
        previous.inLocalLockdown = isNowLocked
        Status.lockdown = msg.lockdown
        Status.lockdownIDs = msg.lockdownIDs or {}
        Status.lockdownReason = msg.lockdownReason

        if isNowLocked then
            log.warn("Lockdown active on this airlock")
            Door.setAirlockState("closed")
            Sound.play("LOCKDOWN")
        else
            log.info("Lockdown cleared - airlock open")
            Door.setAirlockState("enter")
            Sound.play("ONLINE")
        end
    end

    -- Always respond to status (even if unchanged)
    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "transmit", Ports.PING, Ports.STATUS, {
        type = "status",
        source = C.ID,
    })
    ScreenHandler.update() -- Update all screens with the new status
end

return {
    onStatus = onStatus
}
