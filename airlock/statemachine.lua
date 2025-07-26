local log = require "core.log"
local Components = require "core.components"
local C = require("airlock.airlock").config
local Scheduler = require("core.scheduler")

---@enum StateEnum
local StateEnum = {
    ENTRY  = "entry",
    EXIT   = "exit",
    OPEN   = "open", -- Both doors open (rare)
    CLOSED = "closed",
    LOCKED = "locked",
    JAMMED = "jammed",
}

---@class StateMachine
local SM = {}

---@type string|nil The reason for the current_state.
SM.reason = nil
---@type StateEnum
SM.current_state = StateEnum.CLOSED

local transitions = {}
local subscribers = {}

local autoCloseTimerEnabled = false
local autoCloseTimer = nil
local transitionQueue = {}

---@param group "ENTRANCE" | "EXIT"
---@param open boolean
local function setDoor(group, open)
    local ok = Components.callComponent(C.COMPONENTS, group, "DOOR", "setOutput", "top", open)
    if not ok then
        return false, ("Failed to set %s door to %s"):format(group, tostring(open))
    end
    return true
end


SM.context = {
    openEntryDoor = function()
        log.info("Opening ENTRY door...")
        return setDoor("ENTRANCE", true)
    end,

    closeEntryDoor = function()
        log.info("Closing ENTRY door...")
        return setDoor("ENTRANCE", false)
    end,

    openExitDoor = function()
        log.info("Opening EXIT door...")
        return setDoor("EXIT", true)
    end,

    closeExitDoor = function()
        log.info("Closing EXIT door...")
        return setDoor("EXIT", false)
    end,

    pressurize = function()
        log.info("Pressurizing chamber...")
        sleep(C.OPENING_DELAY)
        return true, nil
    end,

    depressurize = function()
        log.info("Depressurizing chamber...")
        sleep(C.OPENING_DELAY)
        return true, nil
    end,
}


local function notify(eventName, newState, oldState)
    local list = subscribers[eventName]
    if list then
        for _, fn in ipairs(list) do
            pcall(fn, newState, oldState)
        end
    end
end

local function fail(reason, from, to)
    SM.last_error = {
        reason = reason,
        from   = from,
        to     = to,
        time   = os.epoch("utc"),
    }
    notify("error", to, from)              -- generic error event
    notify("error:" .. from .. "->" .. to) -- transition-specific error channel
end

-- Pub-sub methods
function SM.subscribe(eventName, callback)
    subscribers[eventName] = subscribers[eventName] or {}
    table.insert(subscribers[eventName], callback)
end

function SM.unsubscribe(eventName, callback)
    local list = subscribers[eventName]
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == callback then
            table.remove(list, i)
            break
        end
    end
end

---@param nextState StateEnum
---@param context table|nil
function SM.enqueueTransition(nextState, context)
    table.insert(transitionQueue, { state = nextState, context = context })
    os.queueEvent("transition")
    return true
end

local function processNextTransition()
    local next = table.remove(transitionQueue, 1)
    if not next then return false end

    local nextState = next.state
    local ctx = next.context or {}

    local key = SM.current_state .. "->" .. nextState
    if SM.current_state == StateEnum.LOCKED and nextState ~= "closed" then
        if not ctx.override_lockdown then
            log.warn("Airlock locked. Cannot transition.")
            return false
        else
            log.info("High-clearance override: allowing transition from LOCKED to " .. nextState)
            key = "closed->" .. nextState -- Allow any transition from LOCKED with override
        end
    end

    local wildcardKey = "*->" .. nextState
    local handler = transitions[key] or transitions[wildcardKey]

    if not handler then
        log.warn("Invalid transition: " .. key .. " (or " .. wildcardKey .. ")")
        return false
    end

    notify("from:" .. SM.current_state, nextState, SM.current_state)
    notify("changing", nextState, SM.current_state)
    if nextState == "locked" then
        notify("locked", nextState, SM.current_state)
    elseif SM.current_state == "locked" then
        notify("unlocked", nextState, SM.current_state)
    end
    local ok, err = handler()
    if ok then
        local oldState = SM.current_state
        SM.current_state = nextState
        notify("change", nextState, oldState)
        notify("to:" .. nextState, nextState, oldState)
        -- Auto-return to LOCKED if this was a high-clearance override
        if ctx.override_lockdown and nextState ~= StateEnum.LOCKED then
            Scheduler.schedule(C.AUTO_CLOSE_TIME, function()
                log.info("Lockdown override ended, returning to LOCKED state")
                SM.enqueueTransition(StateEnum.LOCKED)
            end)
        end
        return true
    else
        log.warn(("Transition failed: %s (%s)"):format(key, tostring(err)))
        fail(err or "unknown", SM.current_state, nextState)
        return false
    end
end

function SM.setInitialState(state)
    -- Also execute the initial state
    if state == SM.current_state then
        log.info("Already in initial state:", state)
        return
    end
    table.insert(transitionQueue, { state = state, context = nil })
    processNextTransition()
    log.info("Initial state set to:", state)
end

local function atomic(steps)
    local done = {}
    for _, step in ipairs(steps) do
        local ok, err = step.do_()
        if not ok then
            for i = #done, 1, -1 do
                pcall(done[i].undo)
            end
            return false, err
        end
        table.insert(done, step)
    end
    return true
end

-- CLOSED -> ENTRY
transitions[StateEnum.CLOSED .. "->" .. StateEnum.ENTRY] = function()
    return atomic({
        {
            do_  = SM.context.openEntryDoor,
            undo = SM.context.closeEntryDoor,
        },
    })
end

--OPEN -> ENTRY
transitions[StateEnum.OPEN .. "->" .. StateEnum.ENTRY] = function()
    return atomic({
        {
            do_  = SM.context.openEntryDoor,
            undo = SM.context.closeEntryDoor,
        },
        {
            do_  = SM.context.closeExitDoor,
            undo = SM.context.openExitDoor,
        },
    })
end

-- ENTRY -> CLOSED
transitions[StateEnum.ENTRY .. "->" .. StateEnum.CLOSED] = function()
    return atomic({
        {
            do_  = SM.context.closeEntryDoor,
            undo = SM.context.openEntryDoor,
        },
    })
end

-- ENTRY -> EXIT
transitions[StateEnum.ENTRY .. "->" .. StateEnum.EXIT] = function()
    return atomic({
        {
            do_  = SM.context.closeEntryDoor,
            undo = SM.context.openEntryDoor,
        },
        {
            do_  = SM.context.pressurize,
            undo = function()
                log.warn("Rollback: skipping depressurize after pressurize (noop)")
                return true
            end,
        },
        {
            do_  = SM.context.openExitDoor,
            undo = SM.context.closeExitDoor,
        },
        {
            do_ = function()
                autoCloseTimer = os.startTimer(C.AUTO_CLOSE_TIME)
                return true
            end,
            undo = function()
                log.warn("Rollback: skipping auto-close timer (noop)")
                return true
            end,
        }
    })
end

-- EXIT -> ENTRY
transitions[StateEnum.EXIT .. "->" .. StateEnum.ENTRY] = function()
    return atomic({
        {
            do_  = SM.context.closeExitDoor,
            undo = SM.context.openExitDoor,
        },
        {
            do_  = SM.context.pressurize,
            undo = function()
                log.warn("Rollback: skipping depressurize after pressurize (noop)")
                return true
            end,
        },
        {
            do_  = SM.context.openEntryDoor,
            undo = SM.context.closeEntryDoor,
        },
    })
end

-- CLOSED -> EXIT
transitions[StateEnum.CLOSED .. "->" .. StateEnum.EXIT] = function()
    return atomic({
        {
            do_  = SM.context.openExitDoor,
            undo = SM.context.closeExitDoor,
        },
        {
            do_ = function()
                autoCloseTimer = os.startTimer(C.AUTO_CLOSE_TIME)
                return true
            end,
            undo = function()
                log.warn("Rollback: skipping auto-close timer (noop)")
                return true
            end,
        }
    })
end

-- OPEN -> EXIT
transitions[StateEnum.OPEN .. "->" .. StateEnum.EXIT] = function()
    return atomic({
        {
            do_  = SM.context.closeEntryDoor,
            undo = SM.context.openEntryDoor,
        },
        {
            do_  = SM.context.openExitDoor,
            undo = SM.context.closeExitDoor,
        },
    })
end

-- EXIT -> CLOSED
transitions[StateEnum.EXIT .. "->" .. StateEnum.CLOSED] = function()
    return atomic({
        {
            do_  = SM.context.closeExitDoor,
            undo = SM.context.openExitDoor,
        },
    })
end

-- CLOSED -> LOCKED
transitions["*->" .. StateEnum.LOCKED] = function()
    if SM.current_state ~= StateEnum.CLOSED then
        return atomic({
            {
                do_  = SM.context.closeExitDoor,
                undo = SM.context.openExitDoor,
            },
            {
                do_  = SM.context.closeEntryDoor,
                undo = SM.context.openEntryDoor,
            },
        })
    end
    log.info("Airlock locked.")
    return true
end

-- LOCKED -> CLOSED
transitions[StateEnum.LOCKED .. "->" .. StateEnum.CLOSED] = function()
    log.info("Airlock unlocked.")
    return true
end

-- CLOSED -> OPEN
transitions["*->" .. StateEnum.OPEN] = function()
    return atomic({
        {
            do_  = SM.context.openEntryDoor,
            undo = SM.context.closeEntryDoor,
        },
        {
            do_  = SM.context.openExitDoor,
            undo = SM.context.closeExitDoor,
        },
    })
end

-- OPEN -> CLOSED
transitions["*->" .. StateEnum.CLOSED] = function()
    return atomic({
        {
            do_  = SM.context.closeEntryDoor,
            undo = SM.context.openEntryDoor,
        },
        {
            do_  = SM.context.closeExitDoor,
            undo = SM.context.openExitDoor,
        },
    })
end

function SM.setAutoClose()
    if SM.current_state == StateEnum.EXIT then
        autoCloseTimer = os.startTimer(C.AUTO_CLOSE_TIME)
    else
        autoCloseTimer = nil
    end
    autoCloseTimerEnabled = true
end

function SM.loop()
    -- Handle first state -(/CLOSED\)
    transitions["*->" .. StateEnum.CLOSED]()

    while true do
        local event, arg = os.pullEvent()
        if event == "timer" and arg == autoCloseTimer and autoCloseTimerEnabled then
            autoCloseTimerEnabled = false
            autoCloseTimer = nil
            log.debug("Auto-closing airlock")
            SM.enqueueTransition(StateEnum.ENTRY)
        elseif event == "transition" then
            -- Process next transition in queue
            while #transitionQueue > 0 do
                local success = processNextTransition()
                if not success then
                    break -- Stop processing if transition failed
                end
            end
            -- processNextTransition()
        else
            -- -- Also process transitions if queue not empty and no transition event (optional)
            -- if #transitionQueue > 0 then
            --     processNextTransition()
            -- end
        end
    end
end

return SM
