local log       = require "core.log"
local EventBus  = require("core.eventbus")
local AccessLog = require("control-server.access_log")

return function(frame)
    log.info("Initializing Logs Tab")

    local logDisplay = frame:addDisplay()
        :setWidth("{parent.width - 2}")
        :setHeight("{parent.height - 2}")
        :setPosition(2, 2)

    local LogWindow = logDisplay:getWindow()
    local defaultColor = LogWindow.getTextColor()

    --- Helper to safely format fields
    local function safeField(value, fallback)
        return (type(value) == "string" or type(value) == "number") and tostring(value) or fallback
    end
    local function truncate(str, len)
        if #str > len then
            return str:sub(1, len)
        else
            return str .. string.rep(" ", len - #str)
        end
    end

    local function shortAction(action)
        if action == "allow" then
            return "OK"
        elseif action == "deny" then
            return "NO"
        else
            return "??"
        end
    end

    local shortMessages = {
        generic_access = "GEN",
        lockdown = "LOCKDOWN",
        not_found = "404",
        unknown_area = "UNKNOWN",
        insufficient_clearance = "CLEARANCE",
        exit_granted = "EXIT",
        default = "OK"
    }

    local function shortReason(reason)
        return shortMessages[reason] or reason:sub(1, 17):upper()
    end

    local function writeFormattedLogLine(entry)
        if type(entry) ~= "table" then return end

        local time     = tonumber(entry.timestamp) or 0
        local id       = safeField(entry.identifier, "unknown_id")
        local level    = safeField(entry.level, "N/A")
        local location = safeField(entry.source, "unknown")
        local action   = safeField(entry.action, "???")
        local reason   = safeField(entry.reason, "")

        -- truncate / abbreviate fields
        local timeStr  = textutils.formatTime(time, true):sub(1, 5) -- "HH:MM"
        -- Ensure HH:MM (if not add padding 0)
        if #timeStr < 5 then
            timeStr = " " .. timeStr
        end
        local idStr     = truncate(id, 6)
        local levelStr  = (level ~= "N/A") and ("L" .. level) or "  "
        local locStr    = truncate(location, 8)
        local actionStr = shortAction(action)
        local reasonStr = shortReason(reason)

        -- Scrolling
        local _, cy     = LogWindow.getCursorPos()
        local _, h      = LogWindow.getSize()
        if cy >= h then
            LogWindow.scroll(1)
            cy = h - 1
        end
        LogWindow.setCursorPos(1, cy)

        -- TIME (gray)
        LogWindow.setTextColor(colors.gray)
        LogWindow.write(timeStr .. " ")
        LogWindow.setTextColor(defaultColor)

        -- ID (cyan)
        LogWindow.setTextColor(colors.cyan)
        LogWindow.write(idStr .. " ")

        -- LEVEL (lightBlue) if shown
        if level ~= "N/A" then
            LogWindow.setTextColor(colors.lightBlue)
            LogWindow.write(levelStr .. " ")
        else
            LogWindow.write("    ") -- keep spacing consistent
        end

        -- LOCATION (orange)
        LogWindow.setTextColor(colors.orange)
        LogWindow.write(locStr .. " ")

        -- ACTION (colored)
        local paletteActionColors = {
            allow = colors.lime,
            deny = colors.red,
            other = colors.lightGray
        }
        local actionColor = paletteActionColors[action] or paletteActionColors.other
        LogWindow.setTextColor(actionColor)
        LogWindow.write(actionStr .. " ")

        -- MESSAGE (colored)
        local paletteMessageColors = {
            lockdown = colors.red,
            not_found = colors.lightGray,
            unknown_area = colors.orange,
            insufficient_clearance = colors.yellow,
            exit_granted = colors.lime,
            default = colors.white
        }
        local msgColor = paletteMessageColors[reason] or paletteMessageColors.default
        LogWindow.setTextColor(msgColor)
        LogWindow.write(reasonStr)

        -- Finish line
        LogWindow.setCursorPos(1, cy + 1)
        LogWindow.setTextColor(defaultColor)
    end



    local function updateLogs()
        LogWindow.clear()
        local entries = AccessLog.loadAll()
        if type(entries) ~= "table" then
            writeFormattedLogLine({ status = "error", reason = "Failed to load logs" })
            return
        end
        for _, entry in ipairs(entries) do
            writeFormattedLogLine(entry)
        end
    end
    EventBus:subscribe("access_log", function(entry)
        writeFormattedLogLine(entry)
    end)

    updateLogs()

    return {
        update = function() end
    }
end
