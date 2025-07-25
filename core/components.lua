local log = require("core.log")
local helpers = require("core.helpers")

---@class ComponentWrapper
---@field [string] table  -- device table indexed by component names

---@type ComponentWrapper
local wrap = {}

--- Set the wrapper table for components
---@param tbl ComponentWrapper
function SetWrapper(tbl)
    wrap = tbl
    log.info({ colors.cyan, "Wrapper set with " }, { colors.white, helpers.count(tbl) or "unknown" },
        { colors.cyan, " components." })
end

--- Call a method on a wrapped component
---@param component string
---@param method string
---@param ... any
---@return boolean|nil success
---@return any|nil result_or_error
function useWrap(component, method, ...)
    local args = { ... }
    local device = wrap[component]
    if not device then
        log.error({ colors.red, "Component not found: " }, { colors.white, tostring(component) })
        return nil, "Component not found"
    end

    local fn = device[method]
    if type(fn) ~= "function" then
        log.error({ colors.red, "Invalid method: " }, { colors.white, tostring(method) },
            { colors.red, " on component: " },
            { colors.white, tostring(component) })
        return nil, "Invalid method: " .. tostring(method)
    end

    local ok, res = pcall(fn, table.unpack(args))
    if ok then
        return true, res
    else
        log.error({ colors.red, "Error calling method: " }, { colors.white, tostring(method) },
            { colors.red, " on component: " }, { colors.white, tostring(component) }, { colors.red, " - " },
            { colors.white, tostring(res) })

        -- Show args
        log.debug({ colors.cyan, "With args: " }, { colors.white, table.concat({ ... }, ", ") })
        return nil, res
    end
end

function isMatch(components, wrapId, group, name)
    if not wrapId or not group or not name then
        log.warn("Invalid arguments for isMatch: wrapId, group, and name are required.")
        return false
    end
    local matchName = components[group] and components[group][name]
    if not matchName then
        log.warn("Component not found for ID: " .. tostring(wrapId))
        return false
    end
    return matchName == wrapId
end

function getWrap(COMPONENTS, group, name)
    local component = COMPONENTS[group] and COMPONENTS[group][name]
    if not component then
        log.error({ colors.red, "Component not found in group: " }, { colors.white, tostring(group) },
            { colors.red, ", name: " }, { colors.white, tostring(name) })
        return nil, "Component not found in group: " .. tostring(group) .. ", name: " .. tostring(name)
    end
    return wrap[component]
end

--- Call a method on a component identified by group and name
---@param COMPONENTS table<string, table<string, string>>
---@param group string
---@param name string
---@param method string
---@param ... any
---@return boolean|nil success
---@return any|nil result_or_error
function callComponent(COMPONENTS, group, name, method, ...)
    assert(COMPONENTS, "COMPONENTS table is required")
    assert(group, "Group name is required")
    assert(name, "Component name is required")
    assert(method, "Method name is required")
    local component = COMPONENTS[group] and COMPONENTS[group][name]
    if not component then
        log.error({ colors.red, "Component not found in group: " }, { colors.white, tostring(group) },
            { colors.red, ", name: " }, { colors.white, tostring(name) })
        return nil, "Component not found in group: " .. tostring(group) .. ", name: " .. tostring(name)
    end
    return useWrap(component, method, ...)
end

return {
    SetWrapper = SetWrapper,
    isMatch = isMatch,
    useWrap = useWrap,
    callComponent = callComponent,
    getWrap = getWrap
}
