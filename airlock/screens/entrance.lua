local BaseScreen = require("airlock.screens.base")
local StateMachine = require("airlock.statemachine")
local log = require("core.log")
local C = require("airlock.airlock").config
local debug = require("core.debug")
local helpers = require("core.helpers")
local airlock = require("airlock.airlock")

local screen = BaseScreen:new("ENTRANCE", "SCREEN")

function screen:setup()
    assert(type(self) == "table", "Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    assert(type(self.monitor) == "table" and self.monitor.setCursorPos,
        "Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    self:super()
end

---@param ctx table|nil
function screen:update(ctx)
    assert(type(self) == "table", "Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    assert(type(self.monitor) == "table" and self.monitor.setCursorPos,
        "Invalid call to BaseScreen:setup — 'self' is not a screen instance.")
    if ctx and ctx.type == "event" and ctx.name == "monitor_resize" then
        log.debug("Monitor resized [entrance], reinitializing screen")
        self:setup()
    end
    local w, h = self.monitor.getSize()
    if StateMachine.current_state == "locked" then
        -- - REWRITE THIS PART TO USE PUB-SUB (subscribe to statemachine changes.)
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
        self:writeCentered(math.floor(h / 2), C.TYPE_NAME)
        self:writeCentered(math.floor(h / 2) + 2, (airlock.online and "Online " or "Offline"))
    end
end

return screen
