local BaseScreen = require("airlock.screens.base")
local StateMachine = require("airlock.statemachine")
local log = require("core.log")
local C = require("airlock.airlock").config
local helpers = require("core.helpers")

local screen = BaseScreen:new("AIRLOCK", "SCREEN")
local prev = {
    online = nil,
    lockdown = nil,
    reason = nil,
    identifier = nil,
    __ctx = nil,
    __ctx_timestamp = nil,
}

--- override setup
function screen:setup()
    assert(type(self) == "table", "Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    if type(self.monitor) ~= "table" or not self.monitor.setCursorPos then
        error("Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    end
    self:super()
    self.monitor.setTextScale(0.5)
end

---@param ctx table|nil
function screen:update(ctx)
    assert(type(self) == "table", "Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    assert(type(self.monitor) == "table" and self.monitor.setCursorPos,
        "Invalid call to BaseScreen:setup — 'self' is not a screen instance.")

    if type(self) ~= "table" then
        error("Invalid call to BaseScreen:update — 'self' is not a screen instance.")
    end
    if type(self.monitor) ~= "table" or not self.monitor.setCursorPos then
        error("Invalid call to BaseScreen:update — 'self' is not a screen instance.")
    end

    if not ctx then
        if prev.__ctx and os.clock() - prev.__ctx_timestamp > 5 then
            if prev.__ctx.hasPresentedKeycardThisSession then
                log.debug("Clearing session context after 5 seconds")
                prev.__ctx = nil
            end
        end
        ctx = prev.__ctx
    else
        if ctx.type == "event" then
            if ctx.name == "monitor_resize" then
                log.debug("Monitor resized [airlock], reinitializing screen")
                prev.__ctx = nil
                prev.__ctx_timestamp = nil
                self:setup()
                return
            else
                log.debug("Received event: " .. ctx.eventName)
            end
        end
        prev.__ctx_timestamp = os.clock()
        prev.__ctx = ctx
    end


    local identifier = ctx and ctx.identifier or "Unknown"
    local w, h = self.monitor.getSize()
    local cY = math.floor(h / 2)

    if w < 20 or h < 5 then
        self:clear()
        self:writeCentered(1, "MONITOR TOO SMALL", colors.red)
        log.warn("Screen too small: " .. w .. "x" .. h)
        return
    end

    self:clear()
    self:setColors(colors.white, colors.black)
    self:writeCentered(2, "Gantoof", colors.red)
    self:writeCentered(3, "Nuclear  Facility", colors.orange)
    self:writeCentered(5, C.TYPE_NAME)
    self:writeCentered(6, "ID: " .. C.ID, colors.lightGray)
    self:writeCentered(h - 2, "Sneak-click keycard in card reader below", colors.gray)
    self:writeCentered(h - 1, "v v v v v", colors.gray)

    local function handleLock(state)
        if state == "locked" then
            self:fillLines(cY - 1, cY + 2, colors.red)
            self:writeCentered(cY, "LOCKDOWN PROTOCOL ACTIVE", colors.white, colors.red)
            if StateMachine.reason and StateMachine.reason ~= "" then
                self:writeCentered(cY + 1, StateMachine.reason:sub(1, 51), colors.white, colors.red)
            else
                self:writeCentered(cY + 1, "Unknown reason", colors.white, colors.red)
            end
        else -- "unlocked" or any other state
            self:fillLines(cY - 1, cY + 2, colors.black)
        end
    end
    handleLock(StateMachine.current_state)

    if ctx then
        if ctx.hasPresentedKeycardThisSession then
            self:writeCentered(cY + 5, "Key: " .. identifier, colors.lightGray)

            if ctx.validating then
                self:writeCentered(cY + 6, "Validating...", colors.yellow)
            elseif ctx.accessGranted then
                self:writeCentered(cY + 6, "Access granted", colors.green)
            else
                self:writeCentered(cY + 6, "Access denied", colors.red)
            end
        end
    end
end

return screen
