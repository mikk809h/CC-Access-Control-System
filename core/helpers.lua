local helpers = {}

--- Counts elements in a table.
-- If predicate is provided, counts only elements where predicate(value, key) returns true.
-- @param tbl table to count elements from
-- @param predicate optional function(value, key) -> boolean
-- @return number count of matching elements
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
