local log = require("core.log")

---@class debug
local debug = {}

--- Recursively dumps a table to the log with indentation
---@param tbl any The value to dump (usually a table)
---@param indent number? Current indentation level (used internally)
---@param maxDepth number? Maximum depth to recurse into nested tables
function debug.dump(tbl, indent, maxDepth)
    maxDepth = maxDepth or 6
    indent = indent or 0
    if maxDepth and indent >= maxDepth then
        return "MAX_DEPTH"
    end
    local prefix = string.rep("  ", indent)

    if type(tbl) ~= "table" then
        log.debug(prefix .. tostring(tbl))
        return
    end

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            log.debug(prefix .. tostring(k) .. ":")
            debug.dump(v, indent + 1)
        else
            log.debug(prefix .. tostring(k) .. ": " .. tostring(v))
        end
    end
end

return debug
