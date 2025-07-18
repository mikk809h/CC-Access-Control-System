local log = require("core.log")
local Ports = require("shared.ports")
local C = require("shared.config")
local Components = require("core.components")
local screenHandler = require("airlock.screenHandler")
local EventHandler = {}

-- Load event modules and map their main functions here:
local eventModules = {
    onKeyCardInserted = require("airlock.events.onKeyCardInserted").onKeyCardInserted,
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
            handle("onKeyCardInserted")
        elseif eventName == "monitor_resize" then
            screenHandler.update({
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
