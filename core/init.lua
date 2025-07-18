local log        = require("core.log")
local COMPONENTS = require("shared.config").COMPONENTS
local helpers    = require("core.helpers")
local wrap       = {}

function ValidateComponents(required)
    log.info({ colors.cyan, "Validating components..." })
    for group, components in pairs(required) do
        for _, name in ipairs(components) do
            if not COMPONENTS[group] or not COMPONENTS[group][name] then
                local errMsg = "Missing: " .. group .. "." .. name
                log.error({ colors.red, errMsg })
                error(errMsg)
            else
                log.info({ colors.green, "Found: " }, { colors.white, group .. "." .. name })
            end
        end
    end
    log.info({ colors.cyan, "Validation done." })
end

function WrapComponents()
    log.info({ colors.cyan, "Wrapping peripherals..." })
    for group, components in pairs(COMPONENTS) do
        for name, location in pairs(components) do
            local present = peripheral.isPresent(location)
            if not present then
                local errMsg = "Missing: " .. group .. "." .. name .. " at " .. location
                log.error({ colors.red, errMsg })
            else
                local p = peripheral.wrap(location)
                if p then
                    wrap[location] = p
                    log.info({ colors.green, "Wrapped: " }, { colors.white, location })
                else
                    local errMsg = "Failed: " .. location
                    log.error({ colors.red, errMsg })
                    error(errMsg)
                end
            end
        end
        sleep(0.05)
    end
    log.info({ colors.cyan, "Wrap done." }, { colors.white, helpers.count(wrap) or "unknown" },
        { colors.cyan, " components wrapped." })
    return wrap
end

return {
    ValidateComponents = ValidateComponents,
    WrapComponents = WrapComponents,
}
