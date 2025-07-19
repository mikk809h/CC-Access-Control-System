local BaseScreen = require("airlock.screens.base")
local Status = require("airlock.state")
local log = require("core.log")
local C = require("shared.config")
local debug = require("core.debug")
local helpers = require("core.helpers")

---@type BaseScreen
local screen = BaseScreen:new("INFO", "SCREEN")
local ignoreNextResize = false


---@param self BaseScreen
function screen:setup()
    if type(self.monitor) ~= "table" or not self.monitor.setCursorPos then
        error("Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    end
    self:super()
    self.monitor.setTextScale(1)
end

---@param self BaseScreen
---@param ctx table|nil
function screen:update(ctx)
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
    if Status.lockdown then
        self:setColors(colors.white, colors.red)
        self:clear()

        self:writeCentered(2, "Gantoof", colors.white)
        self:writeCentered(3, " Nuclear Facility", colors.white)


        if Status.lockdownReason and Status.lockdownReason ~= "" then
            self:writeCentered(math.floor(h / 2) - 1, "LOCKDOWN ACTIVE", colors.white)
            self:writeCentered(math.floor(h / 2) + 1, Status.lockdownReason, colors.yellow)
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
        self:writeCentered(math.floor(h / 2) + 1, " A1 Entrance")

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
