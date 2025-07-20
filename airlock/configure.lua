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

Configurator.Peripheral.Monitor = {}

function Configurator.Peripheral.Monitor.writeCFGMode()
    local monitors = Configurator.Peripheral.getByType("monitor")
    if #monitors > 0 then
        for _, monitor in ipairs(monitors) do
            local mon = peripheral.wrap(monitor)
            if mon then
                mon.setBackgroundColor(colors.orange)
                mon.setTextColor(colors.black)
                mon.clear()
                mon.setCursorPos(2, 2)
                mon.write("Configuration")
                mon.setCursorPos(2, 3)
                mon.write("Required")
                mon.setCursorPos(2, 4)
                mon.setTextColor(colors.gray)
                mon.write(monitor)
            end
        end
    end
end

function Configurator.Peripheral.Monitor.writeIdentifier()
    local monitors = Configurator.Peripheral.getByType("monitor")

    local minimumWidth = #"monitor_XX"
    if #monitors > 0 then
        for i, monitor in ipairs(monitors) do
            local mon = peripheral.wrap(monitor)
            if mon then
                local currentScale = mon.getTextScale()
                if currentScale ~= 1 then
                    mon.setTextScale(1)
                end
                local size = { mon.getSize() }
                if size[1] < minimumWidth then
                    mon.setTextScale(0.5)
                else
                    mon.setTextScale(1)
                end
                mon.setBackgroundColor(colors.gray)
                mon.setTextColor(colors.white)
                mon.clear()
                mon.setCursorPos(1, 1)
                mon.write(monitor)
            end
        end
    end
end

function Configurator.Peripheral.Monitor.writeSelection(selected)
    local mon = peripheral.wrap(selected)
    if mon then
        mon.setBackgroundColor(colors.green)
        mon.setTextColor(colors.black)
        mon.setTextScale(1)
        mon.clear()
        -- Center print "THIS MONITOR"
        local width, height = mon.getSize()
        local text = "THIS MONITOR"
        local textWidth = #text

        if textWidth > width then
            local textLines = { "THIS", "MONITOR" }
            for i, line in ipairs(textLines) do
                local x = math.floor((width - #line) / 2) + 1
                local y = math.floor(height / 2) + i - 1
                mon.setCursorPos(x, y)
                mon.write(line)
            end
        else
            local x = math.floor((width - textWidth) / 2) + 1
            local y = math.floor(height / 2) + 1
            mon.setCursorPos(x, y)
            mon.write(text)
        end
    end
end

function Configurator.Peripheral.Monitor.clearIdentifiers()
    local monitors = Configurator.Peripheral.getByType("monitor")
    if #monitors > 0 then
        for _, monitor in ipairs(monitors) do
            local mon = peripheral.wrap(monitor)
            if mon then
                mon.setTextColor(colors.white)
                mon.setBackgroundColor(colors.black)
                mon.setTextScale(1)
                mon.clear()
            end
        end
    end
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

Event = {}

local modifiers = {
    ctrl = false
}

function Event.onKeyDown(key)
    if key == keys.leftCtrl or key == keys.rightCtrl then
        modifiers.ctrl = true
    elseif key == keys.s and modifiers.ctrl then
        Event.onSave()
    elseif (key == keys.e or key == keys.t) and modifiers.ctrl then
        Event.onExit()
    elseif Configurator.editingPeripheral then
        if key == keys.up then
            Event.onPeripheralUp()
        elseif key == keys.down then
            Event.onPeripheralDown()
        elseif key == keys.enter then
            Event.onPeripheralSelect()
        elseif key == keys.left or key == keys.backspace or key == keys.escape then
            Event.onPeripheralCancel()
        end
    else
        if key == keys.up then
            Event.onCursorUp()
        elseif key == keys.down then
            Event.onCursorDown()
        elseif key == keys.enter or key == keys.right then
            Event.onSelect()
        elseif key == keys.escape then
            Event.onExit()
        end
    end
end

function Event.onKeyUp(key)
    if key == keys.leftCtrl or key == keys.rightCtrl then
        modifiers.ctrl = false
    end
end

-- =========================
-- = UI Intent Handlers =
-- =========================

function Event.onCursorUp()
    local fields = Configurator.fields
    Configurator.selectedField = Configurator.selectedField > 1 and Configurator.selectedField - 1 or #fields
end

function Event.onCursorDown()
    local fields = Configurator.fields
    Configurator.selectedField = Configurator.selectedField < #fields and Configurator.selectedField + 1 or 1
end

function Event.onPeripheralUp()
    local selected = Configurator.peripheralsList[Configurator.peripheralSelected]
    local field = Configurator.fields[Configurator.selectedField]
    local fieldKey = field.key
    local pType = Configurator.keyTypeMap[fieldKey]
    if pType == "monitor" then
        Configurator.Peripheral.Monitor.writeIdentifier()
    end

    Configurator.peripheralSelected = Configurator.peripheralSelected > 1 and Configurator.peripheralSelected - 1 or
        #Configurator.peripheralsList

    selected = Configurator.peripheralsList[Configurator.peripheralSelected]
    field = Configurator.fields[Configurator.selectedField]
    fieldKey = field.key
    pType = Configurator.keyTypeMap[fieldKey]
    if pType == "monitor" then
        Configurator.Peripheral.Monitor.writeSelection(selected)
    end
end

function Event.onPeripheralDown()
    local selected = Configurator.peripheralsList[Configurator.peripheralSelected]
    local field = Configurator.fields[Configurator.selectedField]
    local fieldKey = field.key
    local pType = Configurator.keyTypeMap[fieldKey]
    if pType == "monitor" then
        Configurator.Peripheral.Monitor.writeIdentifier()
    end
    Configurator.peripheralSelected = Configurator.peripheralSelected < #Configurator.peripheralsList and
        Configurator.peripheralSelected + 1 or 1

    selected = Configurator.peripheralsList[Configurator.peripheralSelected]
    field = Configurator.fields[Configurator.selectedField]
    fieldKey = field.key
    pType = Configurator.keyTypeMap[fieldKey]
    if pType == "monitor" then
        Configurator.Peripheral.Monitor.writeSelection(selected)
    end
end

function Event.onMouseDown(button, x, y)
    local leftWidth = Configurator.leftWidth
    local fields = Configurator.fields
    local rightX = leftWidth + 2
    local listStartY = Configurator.rightY

    if not Configurator.editingPeripheral then
        -- Clicked in the field list
        if y >= 2 and y <= #fields + 1 and x <= leftWidth - 2 then
            Configurator.selectedField = y - 1
            Event.onSelect() -- Simulate pressing Enter on the field
        end
    else
        -- Clicked inside peripheral selection pane
        if x >= rightX and x < rightX + Configurator.rightWidth and y >= listStartY then
            local relY = y - listStartY + 1
            if relY >= 1 and relY <= #Configurator.peripheralsList then
                Configurator.peripheralSelected = relY
                Event.onPeripheralSelect()
            end
        elseif x <= leftWidth - 2 then
            -- Clicked outside the peripheral selection area, cancel editing
            Event.onPeripheralCancel()
        end
    end
end

function Event.onMouseUp(button, x, y)
    -- Reserved for future use
    -- You could add logic here for click-release patterns or button state
end

function Event.onMouseDrag(button, x, y)
    if Configurator.editingPeripheral then
        local rightX = Configurator.leftWidth + 2
        local listStartY = Configurator.rightY
        local listEndY = listStartY + Configurator.rightHeight - 1

        if x >= rightX and x < rightX + Configurator.rightWidth and y >= listStartY and y <= listEndY then
            local relY = y - listStartY + 1
            if relY >= 1 and relY <= #Configurator.peripheralsList then
                Configurator.peripheralSelected = relY
            end
        end
    end
end

function Event.onMouseScroll(direction, x, y)
    -- direction: 1 = down, -1 = up
    if Configurator.editingPeripheral and Configurator.peripheralsList then
        local max = #Configurator.peripheralsList
        if direction == 1 then
            -- scroll down
            Event.onPeripheralDown()
        elseif direction == -1 then
            -- scroll up
            Event.onPeripheralUp()
        end
    else
        -- Optionally scroll fields list (if you later want to support scrolling fields visually)
        local max = #Configurator.fields
        if direction == 1 then
            -- scroll down
            Event.onCursorDown()
        elseif direction == -1 then
            -- scroll up
            Event.onCursorUp()
        end
    end
end

function Event.onPeripheralSelect()
    local selected = Configurator.peripheralsList[Configurator.peripheralSelected]
    local field = Configurator.fields[Configurator.selectedField]
    local fieldKey = field.key
    Configurator.settings[fieldKey] = selected

    if Configurator.keyTypeMap[fieldKey] == "monitor" then
        Configurator.Peripheral.Monitor.clearIdentifiers()
    end

    Configurator.editingPeripheral = false
    Configurator.peripheralsList = nil
    Configurator.peripheralSelected = nil
end

function Event.onPeripheralCancel()
    Configurator.editingPeripheral = false
    Configurator.peripheralsList = nil
    Configurator.peripheralSelected = nil
end

function Event.onSelect()
    local field = Configurator.fields[Configurator.selectedField]
    local keyType = Configurator.keyTypeMap[field.key]

    if keyType then
        local list = Configurator.Peripheral.getByType(keyType)
        if #list > 0 then
            Configurator.editingPeripheral = true
            Configurator.peripheralsList = list
            Configurator.peripheralSelected = 1
            Configurator.warning = nil
            if keyType == "monitor" then
                Configurator.Peripheral.Monitor.writeIdentifier()
            end
        else
            Configurator.warning = "No peripherals found for " .. keyType
            Configurator.warningFieldIndex = Configurator.selectedField
        end
    else
        local input = Configurator.Input.inputText("Enter " .. field.label, math.floor(term.getSize() * 0.6) - 2,
            field.type or "string")
        if input and input ~= "" then
            Configurator.settings[field.key] = input
        end
    end
end

function Event.onSave()
    Configurator.Core.saveSettings(Configurator.fields)
    Configurator.warning = "Settings saved! CTRL+E to exit."
end

function Event.onExit()
    Configurator.shouldExit = true
end

function Configurator.run()
    Configurator.Peripheral.Monitor.writeCFGMode()
    local fields = Configurator.fields

    -- Initialize Configurator state
    Configurator.selectedField = 1
    Configurator.editingPeripheral = false
    Configurator.peripheralSelected = nil
    Configurator.peripheralsList = nil
    Configurator.warning = nil
    Configurator.warningFieldIndex = nil
    Configurator.shouldExit = false

    local width, height = term.getSize()
    Configurator.leftWidth = math.floor(width * 0.6)
    Configurator.rightWidth = width - Configurator.leftWidth - 3
    Configurator.rightY = 3
    Configurator.rightHeight = height - 3

    -- Load settings
    Configurator.Core.loadSettings(fields)

    -- Main event loop
    while not Configurator.shouldExit do
        -- Draw UI
        Configurator.UI.draw(
            fields,
            Configurator.selectedField,
            Configurator.peripheralsList,
            Configurator.peripheralSelected,
            Configurator.warning
        )

        -- Clear warning if cursor moved away
        if Configurator.warningFieldIndex and Configurator.selectedField ~= Configurator.warningFieldIndex then
            Configurator.warning = nil
            Configurator.warningFieldIndex = nil
        end

        -- Wait for event
        local event, p1, p2, p3 = os.pullEvent()

        if event == "key" then
            Event.onKeyDown(p1)
        elseif event == "key_up" then
            Event.onKeyUp(p1)
        elseif event == "mouse_click" then
            Event.onMouseDown(p1, p2, p3)
        elseif event == "mouse_up" then
            Event.onMouseUp(p1, p2, p3)
        elseif event == "mouse_drag" then
            Event.onMouseDrag(p1, p2, p3)
        elseif event == "mouse_scroll" then
            Event.onMouseScroll(p1, p2, p3)
        end
    end

    -- Save settings and exit
    Configurator.Core.saveSettings(fields)
    Configurator.ScreenUtils.resetScreen()
    -- clear identifiers
    Configurator.Peripheral.Monitor.clearIdentifiers()
    print("Configuration saved.")

    Configurator.Peripheral.Monitor.clearIdentifiers()

    return true
end

-- ========== Entry Point ==========
-- Configurator.run()

return Configurator
