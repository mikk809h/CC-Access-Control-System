local log = require("core.log")
local Ports = require("shared.ports")
local C = require("shared.config")
local Components = require("core.components")
local screenHandler = require("airlock.screenHandler")
local debug = require("core.debug")

local EventHandler = {}


-- Load event modules and map their main functions here:
local eventModules = {
    onKeyCardInsertedAirlock = require("airlock.events.onKeyCardInsertedAirlock").onKeyCardInsertedAirlock,
    onKeyCardInsertedEntrance = require("airlock.events.onKeyCardInsertedEntrance")
        .onKeyCardInsertedEntrance,
    onIdentityValidationResponse = require("airlock.events.onIdentityValidationResponse").onIdentityValidationResponse,
    onStatus = require("airlock.events.onStatus").onStatus,
}

-- Call the event handler by name with args, if exists
local function handle(eventName, ...)
    local args = { ... }
    local handler = eventModules[eventName]
    if not handler then
        log.warn("No handler for event: " .. tostring(eventName))
        return false, "Handler not found"
    end

    local ok, err = pcall(handler, table.unpack(args))
    if not ok then
        log.error("Error in handler '" .. eventName .. "': " .. tostring(err))
        return false, err
    end
    -- log.debug("Handled event: " .. tostring(eventName))
    return true
end

-- Modem event loop to listen and dispatch events
function EventHandler.runEventLoop()
    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "open", Ports.VALIDATION_RESPONSE)
    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "open", Ports.STATUS)

    log.info("Starting event loop...")
    while true do
        local event = { os.pullEvent() }
        local eventName = event[1]
        if eventName == "modem_message" then
            local _, _, channel, replyChannel, msg = table.unpack(event)
            if channel == Ports.VALIDATION_RESPONSE then
                handle("onIdentityValidationResponse", event)
            elseif channel == Ports.STATUS then
                handle("onStatus", msg)
            end
        elseif eventName == "disk" then
            log.debug("Disk event: ")
            debug.dump(event)
            if Components.isMatch(event[2], "AIRLOCK", "KEYCARD") then      -- Check if the disk is the keycard
                handle("onKeyCardInsertedAirlock", event)
            elseif Components.isMatch(event[2], "ENTRANCE", "KEYCARD") then -- Check if the disk is the entrance keycard
                handle("onKeyCardInsertedEntrance", event)
            else
                log.warn("Unknown disk event for component: " .. tostring(event[2]))
            end
        elseif eventName == "monitor_resize" then
            screenHandler.updateById(event[2], {
                type = "event",
                name = "monitor_resize",
                monitor = event[2]
            })
        else
            -- You can add more event dispatching here if needed
        end
    end
end

-- Optional: register/override event handlers at runtime
function EventHandler.register(eventName, func)
    if type(func) ~= "function" then
        error("Handler must be a function")
    end
    eventModules[eventName] = func
    log.info("Registered handler for event: " .. tostring(eventName))
end

return EventHandler
