local log       = require "core.log"
local State     = require('control-server.state')
local User      = require('control-server.models.user')
local debug     = require('core.debug')
local helpers   = require('core.helpers')
local AccessLog = require('control-server.access_log')
local Airlocks  = require('control-server.models.airlocks')


local function handleValidationRequest(msg)
    if not msg or msg.type ~= "validation_request" or not msg.identifier or msg.identifier == "" then
        return { type = "validation_response", status = "error", message = "Invalid or missing ID" }
    end

    log.info("Validating ID: ", tostring(msg.identifier))

    local usersFound = User:find({ username = msg.identifier })
    log.debug(usersFound)

    if not usersFound or #usersFound == 0 then
        log.warn("No user found for ID: ", msg.identifier)
        AccessLog.append({
            identifier = msg.identifier,
            level = "N/A",
            source = msg.source,
            timestamp = os.time(),
            action = "deny",
            reason = "not_found",
        })
        return {
            __module = "airlock-cs",
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
            __module = "airlock-cs",
            type = "validation_response",
            status = "success",
            action = "deny",
            reason = "multiple_found",
            identifier = msg.identifier,
            target = msg.source,
        }
    end

    local user = usersFound[1]

    local userLevel = tonumber(user.level:match("L(%d+)")) -- e.g., "L10" → 10

    local foundAirlock = Airlocks:find(msg.source)
    if not foundAirlock or #foundAirlock == 0 then
        log.warn("No airlock found for source: ", msg.source)
        AccessLog.append({
            identifier = msg.identifier,
            level = userLevel,
            source = msg.source,
            timestamp = os.time(),
            action = "deny",
            reason = "airlock_not_found",
        })
        return {
            __module = "airlock-cs",
            type = "validation_response",
            status = "error",
            message = "Airlock not found",
            identifier = msg.identifier,
            target = msg.source,
        }
    end
    local relatedAirlock = foundAirlock[1]

    if relatedAirlock.state == "locked" then
        log.warn("System is in lockdown mode, denying access for ID: ", msg.identifier)
        if userLevel <= 10 then
            log.warn("User ", msg.identifier, " has high clearance, and overriding lockdown")
            AccessLog.append({
                identifier = msg.identifier,
                level = userLevel,
                source = msg.source,
                timestamp = os.time(),
                action = "allow",
                reason = "lockdown_override",
            })
            return {
                __module = "airlock-cs",
                type = "validation_response",
                status = "success",
                action = "allow",
                reason = "lockdown_override",
                identifier = msg.identifier,
                target = msg.source,
            }
        else
            AccessLog.append({
                identifier = msg.identifier,
                level = userLevel,
                source = msg.source,
                timestamp = os.time(),
                action = "deny",
                reason = "lockdown",
            })
            return {
                __module = "airlock-cs",
                type = "validation_response",
                status = "success",
                action = "deny",
                reason = "lockdown",
                identifier = msg.identifier,
                target = msg.source,
            }
        end
    end

    -- Passed level check
    log.debug("Access granted to user ", msg.identifier, " for ")
    AccessLog.append({
        identifier = msg.identifier,
        level = userLevel,
        source = msg.source,
        timestamp = os.time(),
        action = "allow",
    })
    return {
        __module = "airlock-cs",
        type = "validation_response",
        status = "success",
        action = "allow",
        identifier = msg.identifier,
        target = msg.source,
    }
end


-- local test = require('control-server.events.onValidationRequestTest')()

return handleValidationRequest
