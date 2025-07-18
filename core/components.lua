local log = require("core.log")
local helpers = require("core.helpers")
local wrap = {}

function SetWrapper(tbl)
    wrap = tbl
    log.info({ colors.cyan, "Wrapper set with " }, { colors.white, helpers.count(tbl) or "unknown" },
        { colors.cyan, " components." })
end

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

function getWrap(COMPONENTS, group, name)
    local component = COMPONENTS[group] and COMPONENTS[group][name]
    if not component then
        log.error({ colors.red, "Component not found in group: " }, { colors.white, tostring(group) },
            { colors.red, ", name: " }, { colors.white, tostring(name) })
        return nil, "Component not found in group: " .. tostring(group) .. ", name: " .. tostring(name)
    end
    return wrap[component]
end

function callComponent(COMPONENTS, group, name, method, ...)
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
    useWrap = useWrap,
    callComponent = callComponent,
    getWrap = getWrap
}
