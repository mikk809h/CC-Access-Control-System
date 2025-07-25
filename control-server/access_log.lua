-- control-server/access_log.lua
local log = require "core.log"
local EventBus = require "core.eventbus"

local logFilePath = "data/access_log.txt"

local AccessLog = {}
AccessLog.Entries = {}

--- Appends a single access log entry to disk.
---@param entry table
function AccessLog.append(entry)
    local line = textutils.serializeJSON(entry)

    local ok, err = pcall(function()
        local handle = fs.open(logFilePath, "a")
        if handle then
            handle.writeLine(line)
            handle.close()
        else
            error("Failed to open access log file")
        end
    end)

    if not ok then
        log.error("AccessLog: Failed to write:", err)
    end
    log.info("AccessLog: Appended entry for ID: ", entry.identifier, " at ", entry.timestamp)
    AccessLog.Entries[#AccessLog.Entries + 1] = entry
    EventBus:publish("access_log", entry)
    return entry
end

--- Loads all access logs from file.
---@return table
function AccessLog.loadAll()
    local entries = {}
    if not fs.exists(logFilePath) then return entries end

    local handle = fs.open(logFilePath, "r")
    if not handle then return entries end

    while true do
        local line = handle.readLine()
        if not line then break end

        local ok, data = pcall(textutils.unserializeJSON, line)
        if ok and type(data) == "table" then
            table.insert(entries, data)
        end
    end

    handle.close()
    log.info("AccessLog: Loaded ", #entries, " entries from disk")
    AccessLog.Entries = entries
    return entries
end

return AccessLog
