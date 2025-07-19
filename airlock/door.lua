---@alias AirlockState "open" | "closed" | "exit" | "enter"

---@class AirlockDoorState
---@field previous AirlockState|nil
---@field current AirlockState|nil

---@type AirlockDoorState
local state = {
    previous = nil,
    current = nil
}

local C = require("shared.config")
local Components = require("core.components")
local log = require("core.log")
local Status = require("airlock.state")

local M = {}

---@type number|nil
local autoCloseTimer = nil

---Set a door group (ENTRANCE or EXIT) to open or close via redstone.
---@param group "ENTRANCE" | "EXIT"
---@param isOpen boolean
local function setDoor(group, isOpen)
    Components.callComponent(C.COMPONENTS, group, "DOOR", "setOutput", "top", isOpen)
end

---Queue a transition to the given airlock state.
---@param newState AirlockState
function M.setAirlockState(newState)
    state.current = newState
    os.queueEvent("airlock_door")
end

---@class StateHandler
---@field [AirlockState] fun()

---@type StateHandler
local stateHandlers = {
    closed = function()
        setDoor("ENTRANCE", false)
        setDoor("EXIT", false)
    end,

    open = function()
        setDoor("ENTRANCE", true)
        setDoor("EXIT", true)
    end,

    exit = function()
        if state.previous ~= "closed" then
            setDoor("ENTRANCE", false)
            sleep(C.OPENING_DELAY)
        end
        setDoor("EXIT", true)
        autoCloseTimer = os.startTimer(C.AUTO_CLOSE_TIME)
    end,

    enter = function()
        if state.previous ~= "closed" then
            setDoor("EXIT", false)
            sleep(C.OPENING_DELAY)
        end
        setDoor("ENTRANCE", true)
    end,
}

---Execute the currently pending state transition, if any.
function M.changeAirlockState()
    local s = state.current
    if not s then return end

    local handler = stateHandlers[s]
    if handler then
        handler()
        state.previous = s
        state.current = nil
    else
        log.warn("Unhandled airlock state: " .. tostring(s))
    end
end

---Main loop that listens for door events and timers.
function M.loop()
    while true do
        local event, arg = os.pullEvent()
        if event == "airlock_door" then
            M.changeAirlockState()
        elseif event == "timer" and arg == autoCloseTimer then
            if not Status.lockdown then
                log.debug("Auto-closing airlock after delay")
                M.setAirlockState("enter")
            end
            autoCloseTimer = nil
        end
    end
end

return M
