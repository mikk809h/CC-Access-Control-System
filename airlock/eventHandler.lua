local log           = require("core.log")
local Ports         = require("core.constants").Ports
local airlock       = require("airlock.airlock")
local helpers       = require("core.helpers")
local C             = airlock.config
local Components    = require("core.components")
local screenHandler = require("airlock.screenHandler")
local debug         = require("core.debug")
local statemachine  = require("airlock.statemachine")

local EventHandler  = {}


-- Load event modules and map their main functions here:
local eventModules = {
    onKeyCardInsertedAirlock = require("airlock.events.onKeyCardInsertedAirlock").onKeyCardInsertedAirlock,
    onKeyCardInsertedEntrance = require("airlock.events.onKeyCardInsertedEntrance")
        .onKeyCardInsertedEntrance,
    onIdentityValidationResponse = require("airlock.events.handlers.modem_message.onIdentityValidationResponse")
        .onIdentityValidationResponse,
    onOnlineServer = require("airlock.events.handlers.modem_message.onOnlineServer").onOnlineServer,
    onBootupResponse = require("airlock.events.handlers.modem_message.onBootupResponse").onBootupResponse,
    onPingResponse = require("airlock.events.handlers.modem_message.onPingResponse").onPingResponse,
    onCommand = require("airlock.events.handlers.modem_message.onCommand").onCommand,
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

function EventHandler.isMessageForMe(msg)
    if type(msg) ~= "table" then
        log.warn("Received non-table message: ", textutils.serialize(msg))
        return false
    end
    if not msg.__module or msg.__module ~= "airlock-cs" then
        log.warn("Received message from non-airlock module: ", msg.__module)
        return false
    end

    if msg.target then
        if msg.target == C.ID then return true end
        if msg.target == "any" then return true end
        if msg.target == "ACS" then return false end
        if msg.target == airlock.id then return true end
        if helpers.isStringPresentInTable(msg.target, airlock.id) then return true end
        return false
    else
        return true
    end
end

-- Modem event loop to listen and dispatch events
function EventHandler.runEventLoop()
    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "open", Ports.VALIDATION_RESPONSE)
    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "open", Ports.STATUS)
    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "open", Ports.PING_RESPONSE)
    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "open", Ports.BOOTUP_RESPONSE)
    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "open", Ports.ONLINE)
    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "open", Ports.COMMAND)

    -- Send bootup message
    Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "transmit", Ports.BOOTUP, Ports.BOOTUP_RESPONSE, {
        __module = "airlock",
        type = "bootup",
        source = C.ID,
        target = "ACS",
    })

    local pingTimer = os.startTimer(10)
    log.info("Starting event loop...")
    while true do
        local event = { os.pullEvent() }
        local eventName = event[1]
        if eventName == "modem_message" then
            local _, _, channel, replyChannel, msg = table.unpack(event)
            if EventHandler.isMessageForMe(msg) then
                if channel == Ports.VALIDATION_RESPONSE then
                    handle("onIdentityValidationResponse", event)
                elseif channel == Ports.BOOTUP_RESPONSE then
                    if type(msg) == "table" and msg.__module == "airlock-cs" and msg.type == "status" then
                        handle("onBootupResponse", msg)
                    else
                        log.warn("Invalid bootup response: ", textutils.serialize(msg))
                    end
                elseif channel == Ports.PING_RESPONSE then
                    if type(msg) == "table" and msg.__module == "airlock-cs" and msg.type == "status" then
                        handle("onPingResponse", msg)
                    else
                        log.warn("Invalid ping response: ", textutils.serialize(msg))
                    end
                elseif channel == Ports.ONLINE then
                    if type(msg) == "table" and msg.__module == "airlock-cs" and msg.type == "online" then
                        handle("onOnlineServer", msg)
                    end
                elseif channel == Ports.COMMAND then
                    if type(msg) == "table" and msg.__module == "airlock-cs" and msg.type == "command" then
                        handle("onCommand", msg)
                    end
                else
                    log.warn("Received modem message on unknown channel: ", tostring(channel), " with reply channel: ",
                        tostring(replyChannel))
                end
            else
                log.warn("Received modem message not for this module: ", textutils.serialize(msg))
            end
        elseif eventName == "disk" then
            log.debug("Disk event: ")
            debug.dump(event)
            if Components.isMatch(C.COMPONENTS, event[2], "AIRLOCK", "KEYCARD") then      -- Check if the disk is the keycard
                handle("onKeyCardInsertedAirlock", event)
            elseif Components.isMatch(C.COMPONENTS, event[2], "ENTRANCE", "KEYCARD") then -- Check if the disk is the entrance keycard
                handle("onKeyCardInsertedEntrance", event)
            else
                log.warn("Unknown disk event for component: " .. tostring(event[2]))
            end
        elseif eventName == "key" then
            if event[2] == keys.u then
                statemachine.enqueueTransition("entry")
            elseif event[2] == keys.i then
                statemachine.enqueueTransition("exit")
            elseif event[2] == keys.y then
                statemachine.enqueueTransition("locked")
            elseif event[2] == keys.t then
                statemachine.enqueueTransition("closed")
            end
        elseif eventName == "monitor_resize" then
            screenHandler.updateById(event[2], {
                type = "event",
                name = "monitor_resize",
                monitor = event[2]
            })
        elseif eventName == "timer" then
            if event[2] == pingTimer then
                pingTimer = os.startTimer(10) -- Reset the timer
                Components.callComponent(C.COMPONENTS, "OTHER", "MODEM", "transmit", Ports.PING, Ports.PING_RESPONSE, {
                    __module = "airlock",
                    type = "status",
                    source = C.ID,
                    state = statemachine.current_state,
                })
            end
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
