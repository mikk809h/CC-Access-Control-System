local util = require "core.util"
local configurator = {}

---@class config
local settings_cfg = {}


local keyTypeMap = {
    ["component.entrance.door"] = "redstoneIntegrator",
    ["component.entrance.keycard"] = "drive",
    ["component.entrance.screen"] = "monitor",
    ["component.exit.door"] = "redstoneIntegrator",
    ["component.airlock.keycard"] = "drive",
    ["component.airlock.screen"] = "monitor",
    ["component.info.screen"] = "monitor",
    ["component.other.speaker"] = "speaker",
    ["component.other.modem"] = "modem",
}

local fields = {
    { "Identifier",                 "Identifier",                 "A" },
    { "Name",                       "Name",                       "Airlock Entrance" },
    { "component.entrance.door",    "component.entrance.door",    "redstoneIntegrator_6" },
    { "component.entrance.keycard", "component.entrance.keycard", "drive_4" },
    { "component.entrance.screen",  "component.entrance.screen",  "monitor_3" },
    { "component.exit.door",        "component.exit.door",        "redstoneIntegrator_5" },
    { "component.airlock.keycard",  "component.airlock.keycard",  "drive_1" },
    { "component.airlock.screen",   "component.airlock.screen",   "monitor_1" },
    { "component.info.screen",      "component.info.screen",      "monitor_2" },
    { "component.other.speaker",    "component.other.speaker",    "right" },
    { "component.other.modem",      "component.other.modem",      "left" },
    { "openingDelay",               "Opening Delay",              2.5 },
    { "autoCloseTime",              "Auto Close Time",            10 },
}


-- trinary operator
---@nodiscard
---@param cond any condition
---@param a any return if evaluated as true
---@param b any return if false or nil
---@return any value
function trinary(cond, a, b)
    if cond then return a else return b end
end

local function load_configuration(target, useDefaults)
    -- Load existing configuration in .settings
    print("Loading configuration from .settings")
    for _, v in pairs(fields) do settings.unset(v[1]) end

    local loaded = settings.load(".settings")

    if not loaded then
        print("No settings file found, creating a new one with default values.")
        -- If no settings file exists, create it with default values
        for _, v in pairs(fields) do
            settings.set(v[1], v[3])
        end

        loaded = true
    end
    print("Settings file loaded successfully.")
    -- If settings file exists, load it into the target table
    for _, v in pairs(fields) do
        local value = settings.get(v[1])
        if value ~= nil then
            target[v[1]] = value
        elseif useDefaults then
            target[v[1]] = v[3]
        end
    end
    -- if useDefaults then override with defaults
    if useDefaults then
        for _, v in pairs(fields) do
            if target[v[1]] == nil then
                target[v[1]] = v[3]
            end
        end
    end
end

-- reset terminal screen
local function reset_term()
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
end

local function getNamesFiltered(peripheralType)
    local names = {}
    for _, name in pairs(peripheral.getNames()) do
        if peripheral.getType(name) == peripheralType then
            table.insert(names, name)
        end
    end
    return names
end

local function fillLines(startLine, endLine)
    local oldX, oldY = term.getCursorPos()
    for i = startLine, endLine do
        term.setCursorPos(1, i)
        term.clearLine()
    end
    term.setCursorPos(oldX, oldY)
end

local function showPeripheralNamesInDrawer(peripheralType)
    local success = false
    local names = getNamesFiltered(peripheralType)
    local maxDrawerHeight = 2
    local width, height = term.getSize()
    local maxPeripheralsPerLine = math.floor(width / (#peripheralType + 2))
    local oldBackgroundColor = term.getBackgroundColor()
    local oldX, oldY = term.getCursorPos()
    -- fill with gray
    term.setBackgroundColor(colors.gray)
    fillLines(1, maxDrawerHeight)
    term.setCursorPos(1, 1)

    if #names > 0 then
        term.setTextColor(colors.lightGray)
        term.write("Available " .. peripheralType .. "s:")
        term.setTextColor(colors.white)
        term.setCursorPos(1, 2)
        local tabulatedData = { {}, {} }
        for i, name in ipairs(names) do
            local lineIndex = math.ceil(i / maxPeripheralsPerLine)
            if not tabulatedData[lineIndex] then
                tabulatedData[lineIndex] = {}
            end
            table.insert(tabulatedData[lineIndex], " " .. name .. " ")
        end
        textutils.tabulate(table.unpack(tabulatedData))
        success = true
    else
        term.setTextColor(colors.red)
        print("No " .. peripheralType .. " found.")
        success = false
    end
    term.setBackgroundColor(oldBackgroundColor)
    term.setCursorPos(oldX, oldY)
    return success
end

local function clearPeripheralDrawer()
    local width, height = term.getSize()
    local oldX, oldY = term.getCursorPos()
    term.setBackgroundColor(colors.black)
    fillLines(1, 2)
    term.setCursorPos(oldX, oldY)
end

function config_ask()
    local count = #fields
    term.setCursorPos(1, 3)
    print("Configure Airlock Entrance")
    for i, field in ipairs(fields) do
        local key, label, default = field[1], field[2], field[3]
        local current = settings_cfg[key]
        local typeHint = keyTypeMap[key]
        local validPeripherals = {}

        local peripheralsPresent = false
        if typeHint then
            validPeripherals = getNamesFiltered(typeHint)
            peripheralsPresent = showPeripheralNamesInDrawer(typeHint)
            term.setTextColor(colors.lightGray)
        else
            clearPeripheralDrawer()
            term.setTextColor(colors.yellow)
        end
        -- remove component.
        local clearKey = label:gsub("component%.", "")
        local title = string.format("[%d/%d] %s (%s): ", i, count, clearKey, tostring(current))

        local input
        if peripheralsPresent or not typeHint then
            while true do
                term.write(title)
                term.setTextColor(colors.white)
                input = read()

                if input == "" then
                    input = current or default
                end

                if typeHint then
                    local valid = false
                    for _, name in ipairs(validPeripherals) do
                        if input == name then
                            valid = true
                            break
                        end
                    end
                    if not valid then
                        term.setTextColor(colors.red)
                        print("Invalid peripheral. Try again.")
                        term.setTextColor(colors.white)
                    else
                        break
                    end
                else
                    break
                end
            end
        else
            term.write(title)
            term.setTextColor(colors.white)
            term.write("Not present")
            input = default
            print()
        end
        -- Set the value in settings
        settings.set(key, input)
    end
end

function configurator.configure()
    -- Create the configuration system.
    -- Load existing configuration in
    load_configuration(settings_cfg, true)
    reset_term()
    local status, error = pcall(function()
        config_ask()

        -- Save the configuration to .settings
        print("Saving configuration to .settings")
        local success = settings.save(".settings")
        if not success then
            error("Failed to save settings to .settings")
        end
    end)

    -- reset_term()
    if not status then
        print("configurator error: " .. error)
    end

    return status, error
end

return configurator
