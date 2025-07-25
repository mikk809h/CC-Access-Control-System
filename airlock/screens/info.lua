local BaseScreen = require("airlock.screens.base")
local StateMachine = require("airlock.statemachine")
local log = require("core.log")
local debug = require("core.debug")
local helpers = require("core.helpers")
local C = require("airlock.airlock").config

---@type BaseScreen
local screen = BaseScreen:new("INFO", "SCREEN")
local ignoreNextResize = false


---@param self BaseScreen
function screen:setup()
    assert(type(self) == "table", "Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    assert(type(self.monitor) == "table" and self.monitor.setCursorPos,
        "Invalid call to BaseScreen:setup — 'self' is not a screen instance.")

    self:super()
    self.monitor.setTextScale(1)
end

---@param self BaseScreen
---@param ctx table|nil
function screen:update(ctx)
    assert(type(self) == "table", "Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    assert(type(self.monitor) == "table" and self.monitor.setCursorPos,
        "Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    if ctx and ctx.type == "event" and ctx.name == "monitor_resize" then
        if ignoreNextResize then
            -- log.debug("Ignoring next resize event for info screen")
            ignoreNextResize = false
        else
            log.debug("Monitor resized [info], reinitializing screen")
            self:setup()
            ignoreNextResize = true
        end
    end
    local w, h = self.monitor.getSize()
    if StateMachine.current_state == "locked" then
        self:setColors(colors.white, colors.red)
        self:clear()

        self:writeCentered(2, "Gantoof", colors.white)
        self:writeCentered(3, " Nuclear Facility", colors.white)


        if StateMachine.reason and StateMachine.reason ~= "" then
            self:writeCentered(math.floor(h / 2) - 1, "LOCKDOWN ACTIVE", colors.white)
            self:writeCentered(math.floor(h / 2) + 1, StateMachine.reason, colors.yellow)
        else
            self:writeCentered(math.floor(h / 2), "LOCKDOWN ACTIVE", colors.white)
        end

        self:fillLines(h - 4, h, colors.gray)
        self.monitor.setBackgroundColor(colors.gray)
        -- Entry is not allowed
        self.monitor.setCursorPos(1, h - 3)
        self.monitor.setTextColor(colors.white)
        self:print("  For assistance:")
        self.monitor.setTextColor(colors.lightGray)
        self:print("  Contact personnel at the")
        self:print("  nearest security office")
        -- self:writeCentered(h - 2, "Contact security for assistance", colors.gray)
    else
        self:setColors(colors.white, colors.green)
        self:clear()

        self:writeCentered(2, "Gantoof", colors.white)
        self:writeCentered(3, " Nuclear Facility", colors.white)

        self:writeCentered(math.floor(h / 2), " Airlock")
        self:writeCentered(math.floor(h / 2) + 1, C.TYPE_NAME)

        self:fillLines(h - 3, h, colors.gray)
        self.monitor.setBackgroundColor(colors.gray)
        self.monitor.setTextColor(colors.white)
        self.monitor.setCursorPos(4, h - 2)
        self.monitor.write("Days since last incident")
        self.monitor.setTextColor(colors.lightGray)
        self:writeCentered(h - 1, " CLASSIFIED", colors.lightGray)
    end
end

return screen
