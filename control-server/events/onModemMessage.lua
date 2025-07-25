local log = require "core.log"
local handlePing = require("control-server.events.handlers.modem_message.ping")
local handleBootup = require("control-server.events.handlers.modem_message.bootup")
local onValidationRequest = require("control-server.events.onValidationRequest")
local Constants = require("core.constants")
local State = require("control-server.state")

local function onModemMessage(event)
    local _, side, channel, replyChannel, message = table.unpack(event)

    log.debug("modem_message on ", tostring(channel), ":", tostring(replyChannel))

    if channel == Constants.Ports.VALIDATION and replyChannel == Constants.Ports.VALIDATION_RESPONSE then
        local response = onValidationRequest(message)
        State.Modem.transmit(Constants.Ports.VALIDATION_RESPONSE, Constants.Ports.VALIDATION, response)
        log.info("Validation response sent to channel ", tostring(channel))
    elseif channel == Constants.Ports.BOOTUP and replyChannel == Constants.Ports.BOOTUP_RESPONSE then
        local resp = handleBootup(message)
        if resp and type(resp) == "table" then
            -- respond transmit.
            State.Modem.transmit(Constants.Ports.BOOTUP_RESPONSE, Constants.Ports.PING, resp)
            log.info("Bootup response sent to channel ", tostring(channel), " with target ", tostring(resp.target))
        else
            log.warn("Invalid response from onBootup: ", tostring(resp))
        end
    elseif channel == Constants.Ports.PING and replyChannel == Constants.Ports.PING_RESPONSE then
        local resp = handlePing(message)
        if resp and type(resp) == "table" then
            -- respond transmit.
            State.Modem.transmit(Constants.Ports.PING_RESPONSE, Constants.Ports.PING, resp)
            log.info("Ping response sent to channel ", tostring(channel), " with target ", tostring(resp.target))
        else
            log.warn("Invalid response from onPing: ", tostring(resp))
        end
    elseif channel == Constants.Ports.COMMAND_RESPONSE and replyChannel == Constants.Ports.COMMAND then
        -- Handle command response
        handlePing(message)
    else
        log.warn("Received message on unknown channel: ", tostring(channel), " with reply channel: ",
            tostring(replyChannel))
    end
end


return onModemMessage
