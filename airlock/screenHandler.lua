local Screens = {}
local C = require("shared.config")
local log = require("core.log")
local debug = require("core.debug")

Screens.__components = {}

function Screens.init()
    for group, components in pairs(C.COMPONENTS) do
        for name, _ in pairs(components) do
            if name:lower():find("screen") then
                local modPath = "airlock.screens." .. group:lower()
                local ok, screenModule = pcall(require, modPath)

                if ok and screenModule then
                    log.info("Loading screen ", {
                        colors.lightGray, group .. ".", name,
                        colors.gray, " (" .. modPath .. ")"
                    })

                    table.insert(Screens.__components, {
                        group = group,
                        name = name,
                        screen = screenModule
                    })

                    if screenModule.setup then
                        screenModule:setup()
                    else
                        log.warn("Screen module missing setup(): " .. modPath)
                    end
                else
                    log.error("Failed to load screen module: " .. modPath)
                end
            end
        end
    end

    log.info("Initialized " .. #Screens.__components .. " screen modules")
end

---@param screenId string|number
---@param ctx table|nil
function Screens.updateById(screenId, ctx)
    for _, component in ipairs(Screens.__components) do
        if component.screen.screenId == screenId then
            if component.screen.update then
                local success, err = pcall(component.screen.update, component.screen, ctx)
                if not success then
                    log.error("Error updating screen: " ..
                    component.group .. "." .. component.name .. " - " .. tostring(err))
                end
            else
                log.warn("Screen module missing update(): " .. component.group .. "." .. component.name)
            end
            return true
        end
    end
    log.warn("No screen found with ID: " .. tostring(screenId))
    return false
end

function Screens.updateGroup(screenGroup, ctx)
    for _, component in ipairs(Screens.__components) do
        if component.group == screenGroup then
            if component.screen.update then
                local success, err = pcall(component.screen.update, component.screen, ctx)
                if not success then
                    log.error("Error updating screen: " ..
                        component.group .. "." .. component.name .. " - " .. tostring(err))
                end
            else
                log.warn("Screen module missing update(): " .. component.group .. "." .. component.name)
            end
        end
    end
end

function Screens.update(ctx)
    for _, component in ipairs(Screens.__components) do
        if component.screen.update then
            local success, err = pcall(component.screen.update, component.screen, ctx)
            if not success then
                log.error("Error updating screen: " .. component.group .. "." .. component.name .. " - " .. tostring(err))
            end
        else
            log.warn("Screen module missing update(): " .. component.group .. "." .. component.name)
        end
    end
end

return Screens
