local helpers = {}


function helpers.split(str, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for part in string.gmatch(str, "([^" .. sep .. "]+)") do
        table.insert(t, part)
    end
    return t
end

--- Counts elements in a table.
-- If predicate is provided, counts only elements where predicate(value, key) returns true.
---@param tbl table<any, any> Table to count elements from
---@param predicate? fun(value: any, key: any): boolean Optional function to filter counted elements
---@return number count of matching elements
function helpers.count(tbl, predicate)
    local cnt = 0
    if type(tbl) ~= "table" then return 0 end
    if predicate and type(predicate) == "function" then
        for k, v in pairs(tbl) do
            if predicate(v, k) then
                cnt = cnt + 1
            end
        end
    else
        for _ in pairs(tbl) do
            cnt = cnt + 1
        end
    end
    return cnt
end

--- Checks shallow equality of two tables (only first-level keys and values).
---@param tbl1 table<any, any>
---@param tbl2 table<any, any>
---@return boolean
function helpers.equals(tbl1, tbl2)
    if type(tbl1) ~= "table" or type(tbl2) ~= "table" then
        return false
    end
    if helpers.count(tbl1) ~= helpers.count(tbl2) then
        return false
    end
    for k, v in pairs(tbl1) do
        if tbl2[k] ~= v then
            return false
        end
    end
    return true
end

return helpers
