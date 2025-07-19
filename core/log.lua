---@class Logger
---@field debug fun(...): nil
---@field info fun(...): nil
---@field warn fun(...): nil
---@field error fun(...): nil
---@field critical fun(...): nil
local log = {}

local defaultColor = colors.lightGray
local levelColors = {
    DEBUG = colors.gray,
    INFO = colors.cyan,
    WARN = colors.yellow,
    ERROR = colors.red,
    CRITICAL = colors.orange,
}

--- Returns current time as [HH:MM:SS]
---@return string
local function getTimestamp()
    local time = textutils.formatTime(os.time(), true)
    return time
end

--- Write wrapped text to a target
---@param target table monitor/terminal-like object
---@param sText string|number
---@return integer nLinesPrinted
local function write(target, sText)
    assert(1, sText, "string", "number")

    local w, h = target.getSize()
    local x, y = target.getCursorPos()

    local nLinesPrinted = 0
    local function newLine()
        if y + 1 <= h then
            target.setCursorPos(1, y + 1)
        else
            target.setCursorPos(1, h)
            target.scroll(1)
        end
        x, y = target.getCursorPos()
        nLinesPrinted = nLinesPrinted + 1
    end

    -- Print the line with proper word wrapping
    sText = tostring(sText)
    while #sText > 0 do
        local whitespace = string.match(sText, "^[ \t]+")
        if whitespace then
            -- Print whitespace
            target.write(whitespace)
            x, y = target.getCursorPos()
            sText = string.sub(sText, #whitespace + 1)
        end

        local newline = string.match(sText, "^\n")
        if newline then
            -- Print newlines
            newLine()
            sText = string.sub(sText, 2)
        end

        local text = string.match(sText, "^[^ \t\n]+")
        if text then
            sText = string.sub(sText, #text + 1)
            if #text > w then
                -- Print a multiline word
                while #text > 0 do
                    if x > w then
                        newLine()
                    end
                    target.write(text)
                    text = string.sub(text, w - x + 2)
                    x, y = target.getCursorPos()
                end
            else
                -- Print a word normally
                if x + #text - 1 > w then
                    newLine()
                end
                target.write(text)
                x, y = target.getCursorPos()
            end
        end
    end

    return nLinesPrinted
end

--- Print values with tab separation and wrapping
---@param target table
---@param ... any
---@return integer
local function print(target, ...)
    local nLinesPrinted = 0
    local nLimit = select("#", ...)
    for n = 1, nLimit do
        local s = tostring(select(n, ...))
        if n < nLimit then
            s = s .. "\t"
        end
        nLinesPrinted = nLinesPrinted + write(target, s)
    end
    nLinesPrinted = nLinesPrinted + write(target, "\n")
    return nLinesPrinted
end

--- Core print function for colored log output
---@param target table
---@param level string
---@param ... any
local function coloredPrintToTarget(target, level, ...)
    -- if target width is too small, do not include timestamp
    local w, _ = target.getSize()
    if w > 20 then
        local timestamp = getTimestamp()

        -- Print timestamp
        target.setTextColor(levelColors[level] or defaultColor)
        write(target, timestamp .. " ")
    end

    -- Print message
    target.setTextColor(defaultColor)
    local args = { ... }
    for _, part in ipairs(args) do
        if type(part) == "table" and part[1] and part[2] then
            target.setTextColor(part[1])
            write(target, tostring(part[2]))
            target.setTextColor(defaultColor)
        else
            write(target, tostring(part))
        end
    end

    print(target)
end

--- Create a logger for a specific output device
---@param target table
---@return Logger
local function makeLogger(target)
    local instance = {}

    instance.debug = function(...) coloredPrintToTarget(target, "DEBUG", ...) end
    instance.info = function(...) coloredPrintToTarget(target, "INFO", ...) end
    instance.warn = function(...) coloredPrintToTarget(target, "WARN", ...) end
    instance.error = function(...) coloredPrintToTarget(target, "ERROR", ...) end
    instance.critical = function(...) coloredPrintToTarget(target, "CRITICAL", ...) end

    return instance
end

-- Core logger to terminal
log.debug = function(...) coloredPrintToTarget(term, "DEBUG", ...) end
log.info = function(...) coloredPrintToTarget(term, "INFO", ...) end
log.warn = function(...) coloredPrintToTarget(term, "WARN", ...) end
log.error = function(...) coloredPrintToTarget(term, "ERROR", ...) end
log.critical = function(...) coloredPrintToTarget(term, "CRITICAL", ...) end

--- Redirect logger to a different output target (e.g., monitor)
---@param target table
---@return Logger
function log.redirect(target)
    if not target or type(target.write) ~= "function" then
        error("log.redirect requires a valid output component (e.g., monitor)")
    end
    return makeLogger(target)
end

return log
