local log = require("core.log")

local debug = {}


function debug.dump(tbl, indent, maxDepth)
    if maxDepth and indent >= maxDepth then
        return "MAX_DEPTH"
    end
    indent = indent or 0
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
