local log            = require "core.log"
local State          = require('control-server.state')
local User           = require('control-server.models.user')
local debug          = require('core.debug')
local helpers        = require('core.helpers')

local requiredLevels = {
    A1 = 10,
    A2 = 20,
    A3 = 30,
}

local function handleValidationRequest(msg)
    if not msg or msg.type ~= "validation_request" or not msg.identifier or msg.identifier == "" then
        return { type = "validation_response", status = "error", message = "Invalid or missing ID" }
    end

    log.info("Validating ID: ", tostring(msg.identifier))

    if State.status.lockdown then
        return {
            type = "validation_response",
            status = "success",
            action = "deny",
            reason = "lockdown",
            identifier = msg.identifier,
            target = msg.source,
        }
    end

    local usersFound = User:find(msg.identifier)
    log.debug(usersFound)

    if not usersFound or #usersFound == 0 then
        log.warn("No user found for ID: ", msg.identifier)
        return {
            type = "validation_response",
            status = "success",
            action = "deny",
            reason = "not_found",
            identifier = msg.identifier,
            target = msg.source,
        }
    end

    log.info("User found for ID: ", msg.identifier)
    if #usersFound > 1 then
        log.warn("Multiple users found for ID: ", msg.identifier)
        return {
            type = "validation_response",
            status = "success",
            action = "deny",
            reason = "multiple_found",
            identifier = msg.identifier,
            target = msg.source,
        }
    end
    local user = usersFound[1]


    local parts = helpers.split(msg.source or "", ".")
    if #parts ~= 2 then
        log.warn("Invalid source format: ", msg.source)
        return {
            type = "validation_response",
            status = "error",
            message = "Invalid source format",
            identifier = msg.identifier,
            target = msg.source,
        }
    end

    local area, direction = parts[1], parts[2]
    if not string.match(area, "^A%d+$") or (direction ~= "Entrance" and direction ~= "Exit") then
        log.warn("Invalid source structure: ", msg.source)
        return {
            type = "validation_response",
            status = "error",
            message = "Invalid source structure",
            identifier = msg.identifier,
            target = msg.source,
        }
    end

    -- Everyone can EXIT.
    if direction == "Exit" then
        log.info("Access granted for exit to user ", msg.identifier)
        return {
            type = "validation_response",
            status = "success",
            action = "allow",
            identifier = msg.identifier,
            target = msg.source,
        }
    end
    local userLevel = tonumber(user.level:match("L(%d+)")) -- e.g., "L10" → 10
    local requiredLevel = requiredLevels[area]

    if not requiredLevel then
        log.warn("Unknown area: ", area)
        return {
            type = "validation_response",
            status = "error",
            message = "Unknown area",
            identifier = msg.identifier,
            target = msg.source,
        }
    end

    if userLevel > requiredLevel then
        log.warn("Access denied for user ", msg.identifier, " to ", area, ": insufficient level")
        return {
            type = "validation_response",
            status = "success",
            action = "deny",
            reason = "insufficient_clearance",
            identifier = msg.identifier,
            target = msg.source,
        }
    end

    -- Passed level check
    log.debug("Access granted to user ", msg.identifier, " for ", area)
    return {
        type = "validation_response",
        status = "success",
        action = "allow",
        identifier = msg.identifier,
        target = msg.source,
    }
end

log.info("Initializing onValidationRequest handler")
handleValidationRequest({
    type = "validation_request",
    identifier = "test_user",
    source = "A1.Entrance"
})

return handleValidationRequest
