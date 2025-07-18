local BaseScreen = require("airlock.screens.base")
local Status = require("airlock.state")
local log = require("core.log")
local C = require("shared.config")
local debug = require("core.debug")
local helpers = require("core.helpers")

---@type BaseScreen
local screen = BaseScreen:new("INFO", "SCREEN")

---@param self BaseScreen
function screen:setup()
    if type(self.monitor) ~= "table" or not self.monitor.setCursorPos then
        error("Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    end
    self:super()
end

---@param self BaseScreen
---@param ctx table|nil
function screen:update(ctx)
    if ctx and ctx.type == "event" and ctx.name == "monitor_resize" then
        log.debug("Monitor resized, reinitializing screen")
        self:setup()
    end
    if Status.lockdown then
        self:setColors(colors.white, colors.red)
        self:clear()
        self.monitor.setTextScale(1)
        self:clear()
        local w, h = self.monitor.getSize()

        self:writeCentered(math.floor(h / 2) - 1, "LOCKDOWN ACTIVE", colors.white)

        if Status.lockdownReason and Status.lockdownReason ~= "" then
            self:writeCentered(math.floor(h / 2) + 1, Status.lockdownReason, colors.yellow)
        end

        -- Entry is not allowed
        self.monitor.setCursorPos(1, h - 4)
        self.monitor.setTextColor(colors.black)
        self:print(" For assistance:")
        self:print("  Contact personnel at the")
        self:print("  nearest security office")
        -- self:writeCentered(h - 2, "Contact security for assistance", colors.gray)
    else
        self:setColors(colors.white, colors.green)
        self:clear()
        self.monitor.setTextScale(1.5)
        self:clear()

        local w, h = self.monitor.getSize()

        self:writeCentered(2, "Gantoof", colors.red)
        self:writeCentered(3, " Nuclear Facility", colors.orange)

        self:writeCentered(math.floor(h / 2) - 1, " Airlock")
        self:writeCentered(math.floor(h / 2), " A1 Entrance")
        self:writeCentered(math.floor(h / 2) + 2, (Status.online and "Online" or "Offline"))

        self.monitor.setTextColor(colors.gray)
        self.monitor.setCursorPos(2, h - 2)
        self.monitor.write("Days since last")
        self.monitor.setTextColor(colors.gray)
        self.monitor.setCursorPos(2, h - 1)
        self.monitor.write("incident: ")
        local daysSinceLastIncident = Status.daysSinceLastIncident or 0
        -- Write to right side of the screen
        self.monitor.setCursorPos(w - #tostring(daysSinceLastIncident) - 2, h - 1)
        self.monitor.setTextColor(daysSinceLastIncident > 8 and colors.green or
            daysSinceLastIncident > 1 and colors.yellow or colors.red)
        self.monitor.write(tostring(daysSinceLastIncident))
    end
end

return screen
