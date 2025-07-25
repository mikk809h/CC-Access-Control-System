---@class Scheduler
local Scheduler = {}

local scheduled = {}

--- Schedule a function to run after a delay (in seconds)
---@param delay number
---@param callback fun()
function Scheduler.schedule(delay, callback)
    assert(type(delay) == "number" and delay > 0, "Invalid delay")
    assert(type(callback) == "function", "Callback must be a function")

    local timerId = os.startTimer(delay)
    scheduled[timerId] = callback
    return timerId
end

--- Starts the scheduler loop. Call this once from somewhere central (e.g., a coroutine)
function Scheduler.loop()
    while true do
        local event, id = os.pullEvent("timer")
        local cb = scheduled[id]
        if cb then
            scheduled[id] = nil
            pcall(cb)
        end
    end
end

return Scheduler
