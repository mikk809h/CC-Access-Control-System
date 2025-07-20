local Configurator = {}

-- Data definitions

Configurator.keyTypeMap = {
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

Configurator.fields = {
    { key = "Identifier",                 label = "Identifier",       default = "A" },
    { key = "Name",                       label = "Name",             default = "Airlock Entrance" },
    { key = "component.entrance.door",    label = "Entrance Door",    default = "redstoneIntegrator_6" },
    { key = "component.entrance.keycard", label = "Entrance Keycard", default = "drive_4" },
    { key = "component.entrance.screen",  label = "Entrance Screen",  default = "monitor_3" },
    { key = "component.exit.door",        label = "Exit Door",        default = "redstoneIntegrator_5" },
    { key = "component.airlock.keycard",  label = "Airlock Keycard",  default = "drive_1" },
    { key = "component.airlock.screen",   label = "Airlock Screen",   default = "monitor_1" },
    { key = "component.info.screen",      label = "Info Screen",      default = "monitor_2" },
    { key = "component.other.speaker",    label = "Speaker",          default = "right" },
    { key = "component.other.modem",      label = "Modem",            default = "left" },
    { key = "openingDelay",               label = "Opening Delay",    default = 2.5,                   type = "float" },
    { key = "autoCloseTime",              label = "Auto Close Time",  default = 10,                    type = "float" },
}

Configurator.settings = {}

-- ========== Screen Utilities Module ==========
Configurator.ScreenUtils = {}

function Configurator.ScreenUtils.resetScreen()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
end

function Configurator.ScreenUtils.drawField(x, y, width, label, value, selected)
    term.setCursorPos(x, y)
    if selected then
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.black)
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
    end

    local display = string.format(" %s: %s", label, tostring(value))
    if #display > width then
        display = display:sub(1, width)
    end
    term.write(display .. string.rep(" ", width - #display))
end

function Configurator.ScreenUtils.drawPeripherals(x, y, width, height, list, selectedIndex)
    for i = 1, height do
        term.setCursorPos(x, y + i - 1)
        if i <= #list then
            if i == selectedIndex then
                term.setBackgroundColor(colors.gray)
                term.setTextColor(colors.black)
            else
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.white)
            end
            local name = list[i]
            local display = name
            if #display > width then
                display = display:sub(1, width)
            end
            term.write(display .. string.rep(" ", width - #display))
        else
            -- Clear empty lines
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.write(string.rep(" ", width))
        end
    end
end

function Configurator.ScreenUtils.drawDivider(x, height)
    for y = 1, height do
        term.setCursorPos(x, y)
        term.setBackgroundColor(colors.gray)
        term.write(" ")
    end
end

-- New function: writeWrapped
function Configurator.ScreenUtils.writeWrapped(x, y, width, text, textColor, bgColor)
    textColor = textColor or colors.white
    bgColor = bgColor or colors.black
    term.setBackgroundColor(bgColor)
    term.setTextColor(textColor)

    local posX, posY = x, y
    local spaceLeft = width
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    for i, word in ipairs(words) do
        local wordLen = #word
        if wordLen + 1 > spaceLeft then
            -- Move to next line
            posY = posY + 1
            posX = x
            spaceLeft = width
        end
        term.setCursorPos(posX, posY)
        term.write(word)
        posX = posX + wordLen
        spaceLeft = spaceLeft - wordLen
        if i < #words then
            if spaceLeft > 1 then
                term.write(" ")
                posX = posX + 1
                spaceLeft = spaceLeft - 1
            else
                posY = posY + 1
                posX = x
                spaceLeft = width
            end
        end
    end
end

-- ========== Peripheral Module ==========
Configurator.Peripheral = {}

function Configurator.Peripheral.getByType(typeName)
    local results = {}
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == typeName then
            table.insert(results, name)
        end
    end
    return results
end

-- ========== Input Module ==========
Configurator.Input = {}
function Configurator.Input.inputText(prompt, maxWidth, inputType)
    inputType = inputType or "string" -- default to string if not specified
    local width, height = term.getSize()
    local inputY = height - 2

    while true do
        term.setCursorPos(1, inputY)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.yellow)

        -- Clear line or maxWidth space
        if maxWidth and maxWidth > 0 then
            term.write(string.rep(" ", maxWidth))
            term.setCursorPos(1, inputY)
        else
            term.clearLine()
        end

        term.write(prompt .. ": ")

        term.setTextColor(colors.white)
        local input = read()

        if input == "" then
            -- Empty input returns nil (user cancelled)
            return nil
        end

        if inputType == "integer" then
            local num = tonumber(input)
            if num and math.floor(num) == num then
                return num
            else
                term.setCursorPos(1, inputY)
                term.setTextColor(colors.red)
                term.write("Invalid integer, try again...")
                sleep(1)
            end
        elseif inputType == "float" then
            local num = tonumber(input)
            if num then
                return num
            else
                term.setCursorPos(1, inputY)
                term.setTextColor(colors.red)
                term.write("Invalid number, try again...")
                sleep(1)
            end
        else -- string
            return input
        end
    end
end

-- ========== UI Module ==========
Configurator.UI = {}

function Configurator.UI.draw(fields, selectedFieldIndex, peripherals, peripheralSelectedIndex, warning)
    local width, height = term.getSize()
    local leftWidth = math.floor(width * 0.6)
    local rightX = leftWidth + 2
    local rightWidth = width - leftWidth - 3
    local rightY = 2
    local rightHeight = height - 5

    Configurator.ScreenUtils.resetScreen()

    -- Draw fields
    for i, field in ipairs(fields) do
        local label = field.label
        local value = Configurator.settings[field.key] or field.default
        Configurator.ScreenUtils.drawField(1, i + 1, leftWidth - 2, label, value, i == selectedFieldIndex)
    end

    Configurator.ScreenUtils.drawDivider(leftWidth, height)

    -- Right pane title and instructions
    term.setCursorPos(rightX, 1)
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.yellow)
    term.write("Airlock Configurator")

    -- term.setCursorPos(rightX, height - 1)
    -- term.setTextColor(colors.lightGray)
    -- term.write("Use Arrows, Enter, Mouse. ESC to cancel.")
    local instructions = "Use Arrows + Enter. CTRL+S to save and exit."
    Configurator.ScreenUtils.writeWrapped(rightX, height - 3, rightWidth, instructions, colors.lightGray, colors.black)

    if warning then
        term.setCursorPos(rightX, rightY)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.red)
        Configurator.ScreenUtils.writeWrapped(rightX, rightY, rightWidth, warning, colors.red, colors.black)
        -- term.write(warning .. string.rep(" ", rightWidth - #warning))
        for i = rightY + 2, rightY + rightHeight - 2 do
            term.setCursorPos(rightX, i)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.write(string.rep(" ", rightWidth))
        end
    elseif peripherals then
        term.setCursorPos(rightX, rightY)
        term.setTextColor(colors.yellow)
        term.write("Select:" .. string.rep(" ", rightWidth - 18))
        Configurator.ScreenUtils.drawPeripherals(rightX, rightY + 1, rightWidth, rightHeight - 5, peripherals,
            peripheralSelectedIndex)
    else
        -- Clear right pane below title
        for i = rightY, rightY + rightHeight - 2 do
            term.setCursorPos(rightX, i)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.write(string.rep(" ", rightWidth))
        end
    end
end

-- ========== Core Logic Module ==========
Configurator.Core = {}

function Configurator.Core.loadSettings(fields)
    if fs.exists(".settings") then
        settings.load(".settings")
    end
    for _, field in ipairs(fields) do
        local val = settings.get(field.key)
        Configurator.settings[field.key] = val or field.default
    end
end

function Configurator.Core.saveSettings(fields)
    for _, field in ipairs(fields) do
        settings.set(field.key, Configurator.settings[field.key])
    end
    settings.save(".settings")
end

local modifiers = {
    ctrl = false
}
function Configurator.Core.run()
    local fields = Configurator.fields
    local keyTypeMap = Configurator.keyTypeMap

    local selectedField = 1
    local peripheralSelected = nil
    local peripheralsList = nil
    local editingPeripheral = false
    local warning = nil

    local width, height = term.getSize()
    local leftWidth = math.floor(width * 0.6)
    local rightWidth = width - leftWidth - 3
    local rightY = 2
    local rightHeight = height - 3

    Configurator.Core.loadSettings(fields)

    while true do
        Configurator.UI.draw(fields, selectedField, peripheralsList, peripheralSelected, warning)
        -- Clear warning only if user moves away from the warning field
        if warningFieldIndex and selectedField ~= warningFieldIndex then
            warning = nil
            warningFieldIndex = nil
        end

        local event, param1, param2, param3 = os.pullEvent()

        if event == "key" then
            local key = param1

            if key == keys.leftCtrl or key == keys.rightCtrl then
                modifiers.ctrl = true
            elseif key == keys.s and modifiers.ctrl then
                Configurator.Core.saveSettings(fields)
                warning = "Settings saved! CTRL+E to exit."
            elseif key == keys.e and modifiers.ctrl then
                break -- Exit configuration
            elseif editingPeripheral then
                if key == keys.up then
                    peripheralSelected = peripheralSelected > 1 and peripheralSelected - 1 or #peripheralsList
                elseif key == keys.down then
                    peripheralSelected = peripheralSelected < #peripheralsList and peripheralSelected + 1 or 1
                elseif key == keys.enter then
                    if peripheralSelected and peripheralsList[peripheralSelected] then
                        local fieldKey = fields[selectedField].key
                        Configurator.settings[fieldKey] = peripheralsList[peripheralSelected]
                    end
                    editingPeripheral = false
                    peripheralsList = nil
                    peripheralSelected = nil
                elseif key == keys.escape then
                    editingPeripheral = false
                    peripheralsList = nil
                    peripheralSelected = nil
                else
                    warning = "Use Arrows + Enter. CTRL+S to save and exit."
                end
            else
                if key == keys.up then
                    selectedField = selectedField > 1 and selectedField - 1 or #fields
                elseif key == keys.down then
                    selectedField = selectedField < #fields and selectedField + 1 or 1
                elseif key == keys.enter then
                    local field = fields[selectedField]
                    local keyType = keyTypeMap[field.key]
                    if keyType then
                        peripheralsList = Configurator.Peripheral.getByType(keyType)
                        if #peripheralsList > 0 then
                            editingPeripheral = true
                            peripheralSelected = 1
                        else
                            warning = "No peripherals found for " .. keyType
                            warningFieldIndex = selectedField
                        end
                    else
                        local fieldType = field.type or "string"
                        local input = Configurator.Input.inputText("Enter " .. field.label, leftWidth - 2, fieldType)
                        if input and input ~= "" then
                            Configurator.settings[field.key] = input
                        end
                    end
                elseif key == keys.escape then
                    break
                end
            end
        elseif event == "key_up" then
            local key = param1
            if key == keys.leftCtrl or key == keys.rightCtrl then
                modifiers.ctrl = false
            end
        end
    end

    Configurator.Core.saveSettings(fields)
    Configurator.ScreenUtils.resetScreen()
    print("Configuration saved.")
end

-- ========== Entry Point ==========
Configurator.Core.run()
