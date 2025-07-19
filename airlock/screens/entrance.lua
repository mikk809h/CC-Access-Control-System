local BaseScreen = require("airlock.screens.base")
local Status = require("airlock.state")
local log = require("core.log")
local C = require("shared.config")
local debug = require("core.debug")
local helpers = require("core.helpers")

local screen = BaseScreen:new("ENTRANCE", "SCREEN")

function screen:setup()
    if type(self.monitor) ~= "table" or not self.monitor.setCursorPos then
        error("Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    end
    self:super()
end

---@param ctx table|nil
function screen:update(ctx)
    if ctx and ctx.type == "event" and ctx.name == "monitor_resize" then
        log.debug("Monitor resized [entrance], reinitializing screen")
        self:setup()
    end
    local w, h = self.monitor.getSize()
    if Status.lockdown then
        self:setColors(colors.white, colors.red)
        self:clear()

        self:writeCentered(math.floor(h / 2), "LOCKDOWN")
        self:writeCentered(math.floor(h / 2) + 2, "ACTIVE", colors.white)

        self:writeCentered(2, "No entry", colors.black)
    else
        self:setColors(colors.white, colors.green)
        self:clear()

        local w, h = self.monitor.getSize()
        self:writeCentered(math.floor(h / 2) - 1, "Airlock")
        self:writeCentered(math.floor(h / 2), "A1 Entrance")
        self:writeCentered(math.floor(h / 2) + 2, (Status.online and "Online " or "Offline"))
    end
end

return screen
