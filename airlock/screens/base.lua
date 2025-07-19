local C = require("shared.config")
local wrap = require("core.components").getWrap
local log = require("core.log")

---@class BaseScreen
---@field monitor table
---@field screenId string|number
---@field group string
---@field name string
---@field bgColor number
---@field textColor number
local BaseScreen = {}
BaseScreen.__index = BaseScreen


---@param group string
---@param name string
---@return BaseScreen|nil
function BaseScreen:new(group, name)
    assert(group and name, "Missing group or name for BaseScreen")

    local screenId = C.COMPONENTS[group] and C.COMPONENTS[group][name]
    if not screenId then
        log.error("Invalid screen ID: " .. tostring(group) .. "." .. tostring(name))
        return nil
    end

    local monitor = wrap(C.COMPONENTS, group, name)
    if not monitor then
        log.error("Failed to wrap monitor: " .. tostring(screenId))
        return nil
    end

    local self = setmetatable({
        monitor = monitor,
        screenId = screenId,
        group = group,
        name = name,
        bgColor = colors.black,
        textColor = colors.white,
    }, BaseScreen)

    log.debug(("Screen %s.%s ready [%s]"):format(group, name, tostring(screenId)))

    local w, h = monitor.getSize()
    log.debug(("Monitor size: %dx%d"):format(w, h))

    return self
end

---@param self BaseScreen
function BaseScreen:setup()
    self:super()
end

---@param self BaseScreen
function BaseScreen:super()
    self.monitor.setBackgroundColor(self.bgColor)
    self.monitor.setTextColor(self.textColor)
    self.monitor.setTextScale(0.5)
    self.monitor.setCursorPos(1, 1)
    self.monitor.clear()

    local logger = log.redirect(self.monitor)
    logger.info("Initializing")
    logger.info("ID: ", { colors.white, self.screenId })
    logger.info("Group: ", { colors.white, self.group })
    logger.info("Name: ", { colors.white, self.name })


    local ow, oh = self.monitor.getSize()

    local minWidth = #(self.group .. "." .. self.name)
    if ow < minWidth then
        local newScale = math.min(1, math.floor(minWidth / 20))
        if self.monitor.getTextScale() ~= newScale then
            self.monitor.setTextScale(newScale)
            log.debug("  Setting text scale to: ", { colors.white, tostring(newScale) })
        end
    end
    local w, h = self.monitor.getSize()
    if w ~= ow or h ~= oh then
        logger.warn("Scaling...")
    end
    logger.info("Size: ", { colors.white, tostring(w) .. "x" .. tostring(h) })
    logger.info("Initialized")
end

---@param self BaseScreen
function BaseScreen:clear()
    self.monitor.setBackgroundColor(self.bgColor)
    self.monitor.clear()
    self.monitor.setCursorPos(1, 1)
end

---@param self BaseScreen
---@param text string
function BaseScreen:print(text)
    local w = select(1, self.monitor.getSize())
    if not text or text == "" then
        local _, y = self.monitor.getCursorPos()
        self.monitor.setCursorPos(1, y + 1)
        return
    end
    for line in tostring(text):gmatch("[^\n]+") do
        while #line > w do
            self.monitor.write(line:sub(1, w))
            line = line:sub(w + 1)
            local _, y = self.monitor.getCursorPos()
            self.monitor.setCursorPos(1, y + 1)
        end
        self.monitor.write(line or "")
        local _, y = self.monitor.getCursorPos()
        self.monitor.setCursorPos(1, y + 1)
    end
end

---@param self BaseScreen
---@param text string
---@param y integer
function BaseScreen:writeLine(text, y)
    if y then self.monitor.setCursorPos(1, y) end
    self.monitor.write(tostring(text))
end

---@param self BaseScreen
---@param text string
---@param fgColor? number
---@param bgColor? number
function BaseScreen:writeCenteredCurrent(text, fgColor, bgColor)
    local x, y = self.monitor.getCursorPos()
    self:writeCentered(y, text, fgColor, bgColor)
    self.monitor.setCursorPos(1, y + 1) -- Restore cursor position
end

---@param self BaseScreen
---@param y integer
---@param text string
---@param fgColor? number
---@param bgColor? number
function BaseScreen:writeCentered(y, text, fgColor, bgColor)
    text = tostring(text)
    local w = select(1, self.monitor.getSize())
    local x = math.floor((w - #text) / 2) + 1

    local prevFg = self.monitor.getTextColor()
    local prevBg = self.monitor.getBackgroundColor()

    if fgColor then self.monitor.setTextColor(fgColor) end
    if bgColor then self.monitor.setBackgroundColor(bgColor) end

    self.monitor.setCursorPos(x, y)
    self.monitor.write(text)

    if fgColor then self.monitor.setTextColor(prevFg) end
    if bgColor then self.monitor.setBackgroundColor(prevBg) end
end

---@param self BaseScreen
---@param fg? number
---@param bg? number
function BaseScreen:setColors(fg, bg)
    if fg then
        self.monitor.setTextColor(fg)
        self.textColor = fg
    end
    if bg then
        self.monitor.setBackgroundColor(bg)
        self.bgColor = bg
    end
end

---@param self BaseScreen
---@param startY integer
---@param endY integer
---@param bgColor? number
function BaseScreen:fillLines(startY, endY, bgColor)
    local prevBg = self.monitor.getBackgroundColor()

    if bgColor then self.monitor.setBackgroundColor(bgColor) end
    for y = startY, endY do
        self.monitor.setCursorPos(1, y)
        self.monitor.clearLine()
    end
    if bgColor then self.monitor.setBackgroundColor(prevBg) end
end

---@param self BaseScreen
---@param ctx any
function BaseScreen:update(ctx)
    log.warn("BaseScreen:update() not implemented for " .. self.group .. "." .. self.name)
end

return BaseScreen
