local AccessLog = require("control-server.access_log")
local log       = require("core.log")

log.info("Initializing onValidationRequest handler")

-- Simulated request input
local testMsg = {
    type = "validation_request",
    identifier = "test_user",
    source = "A1.Entrance"
}

-- Simulated user context
local user = {
    level = 30
}

-- Test log entries for each defined scenario
local function simulateAllLogs()
    local entries = {
        {
            description = "DENY - lockdown",
            entry = {
                identifier = testMsg.identifier,
                level = "N/A",
                source = testMsg.source,
                timestamp = os.time(),
                action = "deny",
                reason = "lockdown"
            }
        },
        {
            description = "DENY - not_found",
            entry = {
                identifier = testMsg.identifier,
                level = "N/A",
                source = testMsg.source,
                timestamp = os.time(),
                action = "deny",
                reason = "not_found"
            }
        },
        {
            description = "ALLOW - exit_granted",
            entry = {
                identifier = testMsg.identifier,
                level = user.level,
                source = testMsg.source,
                timestamp = os.time(),
                action = "allow",
                reason = "exit_granted"
            }
        },
        {
            description = "DENY - unknown_area",
            entry = {
                identifier = testMsg.identifier,
                level = user.level,
                source = testMsg.source,
                timestamp = os.time(),
                action = "deny",
                reason = "unknown_area"
            }
        },
        {
            description = "DENY - insufficient_clearance",
            entry = {
                identifier = testMsg.identifier,
                level = user.level,
                source = testMsg.source,
                timestamp = os.time(),
                action = "deny",
                reason = "insufficient_clearance"
            }
        },
        {
            description = "ALLOW - generic/other",
            entry = {
                identifier = testMsg.identifier,
                level = user.level,
                source = testMsg.source,
                timestamp = os.time(),
                action = "allow",
            }
        }
    }

    for _, e in ipairs(entries) do
        log.info("Simulating: " .. e.description)
        AccessLog.append(e.entry)
    end
end

-- Trigger test logs
return simulateAllLogs
