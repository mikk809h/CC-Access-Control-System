local state          = { previous = "open", current = nil, __autoRevert = nil }
local C              = require("shared.config")
local Components     = require("core.components")
local log            = require("core.log")
local Status         = require("airlock.state")

local M              = {}

local autoCloseTimer = nil

function M.setDoor(group, isOpen)
    Components.callComponent(C.COMPONENTS, group, "DOOR", "setOutput", "top", isOpen)
end

function M.setAirlockState(newState)
    state.current = newState
    os.queueEvent("airlock_door")
end

function M.changeAirlockState()
    if not state.current then return end

    local s = state.current
    if s == "closed" then
        M.setDoor("ENTRANCE", false)
        M.setDoor("EXIT", false)
    elseif s == "open" then
        M.setDoor("ENTRANCE", true)
        M.setDoor("EXIT", true)
    elseif s == "exit" then
        if state.previous ~= "closed" then
            M.setDoor("ENTRANCE", false)
            sleep(C.OPENING_DELAY)
        end
        M.setDoor("EXIT", true)
        autoCloseTimer = os.startTimer(C.AUTO_CLOSE_TIME)
    elseif s == "enter" then
        if state.previous ~= "closed" then
            M.setDoor("EXIT", false)
            sleep(C.OPENING_DELAY)
        end
        M.setDoor("ENTRANCE", true)
    end

    state.previous = s
    state.current = nil
end

function M.loop()
    while true do
        local event = { os.pullEvent() }
        if event[1] == "airlock_door" then
            M.changeAirlockState()
        elseif event[1] == "timer" and event[2] == autoCloseTimer then
            if not Status.lockdown then
                log.debug("Auto-closing airlock after delay")
                M.setAirlockState("enter")
            end
            autoCloseTimer = nil
        end
    end
end

return M
