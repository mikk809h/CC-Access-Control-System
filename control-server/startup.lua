require("/initialize").initialize()
--[[
    Main Control System
    Handles modem communication, ping/status validation, and lockdown control.
]]

local log                     = require("core.log")
log.config.print              = false
log.config.logFilePath        = "logs/server.log"

local Model                   = require("core.database.model")
local User                    = require("control-server.models.user")
local Airlocks                = require("control-server.models.airlocks")

local handleValidationRequest = require("control-server.events.onValidationRequest")
local handlePing              = require("control-server.events.handlers.modem_message.ping")
local onModemMessage          = require("control-server.events.onModemMessage")

local Constants               = require("core.constants")
local Audio                   = require("core.audio")
local EventBus                = require("core.eventbus")

local State                   = require("control-server.state")
local basalt                  = require("control-server.basalt")
local C                       = require("control-server.config")


-- === Terminal Setup ===
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 2)

-- === Peripherals ===
State.Modem = nil
if periphemu then
    State.Modem = peripheral.find("modem")
else
    State.Modem = peripheral.find("modem", function(_, p) return p.isWireless() end)
end
assert(State.Modem, "No wireless modem found")

local speaker = peripheral.find("speaker")
assert(speaker, "No speaker found")
speaker.playNote("pling", 0.2, 0)

local drive = peripheral.find("drive")
assert(drive, "No drive found")

local function checkPendingAcks()
    local now = os.clock()
    local updatedResult, err = Airlocks:update({
        online = true,
        lastPing = { ["$lt"] = now - C.PING_TIMEOUT },
    }, {
        online = false,
        lastPing = 0,
    })
    if not updatedResult then
        log.error("Failed to update airlocks to offline state: ", err)
    else
        log.info("Updated airlocks to offline state: ", updatedResult)
    end
end

-- === Main Loop ===

local function runListener()
    local checkTimer = os.startTimer(C.CHECK_ACTIVITY_INTERVAL)

    State.Modem.transmit(Constants.Ports.ONLINE, Constants.Ports.PING, {
        __module = "airlock-cs",
        type = "online",
        source = C.ID,
    })
    log.info("Starting event listener...")
    while true do
        local event = { os.pullEvent() }
        if event[1] ~= "timer" then
            EventBus:publish(event[1], table.unpack(event, 2))
        end

        if event[1] == "modem_message" then
            onModemMessage(event)
        elseif event[1] == "key" then
            local key, held = event[2], event[3]
            if key == keys.p then
                if drive then
                    drive.insertDisk(1)
                end
            elseif key == keys.o then
                if drive then
                    drive.ejectDisk(1)
                end
            end
        elseif event[1] == "timer" and event[2] == checkTimer then
            checkTimer = os.startTimer(C.CHECK_ACTIVITY_INTERVAL)
            checkPendingAcks()
        end
    end
end

-- === Initialization ===

log.info("Starting ID: ", C.ID)
log.info(colors.lightGray, "Opening ports: ", colors.purple, tostring(Constants.Ports.VALIDATION), ", ",
    tostring(Constants.Ports.PING))
State.Modem.open(Constants.Ports.VALIDATION)
State.Modem.open(Constants.Ports.PING)
State.Modem.open(Constants.Ports.BOOTUP)
State.Modem.open(Constants.Ports.COMMAND_RESPONSE)
State.Modem.open(Constants.Ports.STATUS)


-- === Basalt UI Setup ===-- ui/init.lua
local mainFrame = basalt.getMainFrame()

local header = require("control-server.ui.header")(mainFrame, "Access Control Server")
local tabManager = require("control-server.ui.tab_manager")

local mainTabBuilder = require("control-server.ui.tabs.main_tab")
local commandsTabBuilder = require("control-server.ui.tabs.command_tab")
local logsTabBuilder = require("control-server.ui.tabs.logs_tab")
local usersTabBuilder = require("control-server.ui.tabs.users_tab")
local mapTabBuilder = require("control-server.ui.tabs.airlocks_tab")

local dialogUser = require("control-server.ui.dialogs.dialog_user")
local dialogAirlock = require("control-server.ui.dialogs.dialog_airlock")


local userDialog = dialogUser(mainFrame, {
    { text = "Level 10", value = "L10" },
    { text = "Level 20", value = "L20" },
    { text = "Level 30", value = "L30" },
}, drive)
local airlockDialog = dialogAirlock(mainFrame)


local container = mainFrame:addFrame()
    :setSize("{parent.width}", "{parent.height - 4}")
    :setPosition(1, 5)

local tabs = tabManager(header.tabs, container)

tabs.addTab("Main", "Main", function(frame)
    mainTabBuilder(frame)
end)

-- tabs.addTab("Command", "Command", function(frame)
--     commandsTabBuilder(frame)
-- end)

tabs.addTab("Airlocks", "Airlocks", function(frame)
    mapTabBuilder(frame, function(airlock)
        airlockDialog.open(airlock, function(val)
            log.warn("value airlock dialog", textutils.serialize(val), textutils.serialize(airlock))
            -- Update the airlock state

            for k, v in pairs(State.airlocks) do
                if v.name == airlock.name and v.locked == airlock.locked then
                    log.info("Updating airlock: ", v.name, " to ", val.name, " locked: ", val.locked)
                    v.name = val.name
                    v.locked = val.locked
                    EventBus:publish("airlocks_updated")
                    break
                end
            end
        end)
    end)
end)

tabs.addTab("Logs", "Logs", function(frame)
    logsTabBuilder(frame)
end)

tabs.addTab("Users", "Users", function(frame)
    usersTabBuilder(frame, userDialog, {
        { text = "Level 10", value = "L10" },
        { text = "Level 20", value = "L20" },
        { text = "Level 30", value = "L30" },
    })
end)

parallel.waitForAny(runListener, basalt.run, Audio.createLoopInstance(function(method, ...)
    local args = { ... }
    speaker[method](table.unpack(args))
end))
