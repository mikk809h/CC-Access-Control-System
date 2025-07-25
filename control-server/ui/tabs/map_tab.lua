-- ui/sitemap_tab.lua

local EventBus  = require("core.eventbus")
local State     = require("control-server.state")
local C         = require("control-server.config")
local Airlocks  = require("control-server.models.airlocks")
local log       = require("core.log")
local debug     = require("core.debug")
local constants = require("core.constants")

return function(frame, openAirlockConfigCallback)
    -- Add trend display to top
    local drawMap = function() end
    local airlockButtons = {}
    local selectedAirlocks = {}

    frame:addButton()
        :setText("Unknown")
        :setSize(9, 1)
        :setPosition(2, 2)
        :setBackground(colors.lightGray)
        :setForeground(colors.black)
        :onClick(function(_, button, x, y)
            log.debug("Unknown button clicked")
            debug.dump({ button = button, x = x, y = y })
        end)

    frame:addButton()
        :setText("Open")
        :setSize(6, 1)
        :setPosition(12, 2)
        :setBackground(colors.yellow)
        :setForeground(colors.black)

    frame:addButton()
        :setText("Closed")
        :setSize(8, 1)
        :setPosition(19, 2)
        :setBackground(colors.orange)
        :setForeground(colors.black)

    frame:addButton()
        :setText("Locked")
        :setSize(8, 1)
        :setPosition(28, 2)
        :setBackground(colors.red)
        :setForeground(colors.white)

    frame:addButton()
        :setText("Entry")
        :setSize(7, 1)
        :setPosition(37, 2)
        :setBackground(colors.green)
        :setForeground(colors.white)

    frame:addButton()
        :setText("Exit")
        :setSize(6, 1)
        :setPosition(45, 2)
        :setBackground(colors.blue)
        :setForeground(colors.white)

    frame:addLabel()
        :setText(("-"):rep(49))
        :setPosition(2, 3)
        :setForeground(colors.lightGray)

    frame:addLabel()
        :setText("RClick=config LClick=select")
        :setPosition(2, 1)
        :setForeground(colors.white)

    frame:addButton()
        :setText("All")
        :setSize(5, 1)
        :setPosition("{parent.width - 12}", 1)
        :setBackground(colors.lightGray)
        :setForeground(colors.black)
        :onClick(function()
            log.info("Selecting all airlocks")
            selectedAirlocks = {}
            local _airlocks = Airlocks:find()
            for _, airlock in ipairs(_airlocks) do
                selectedAirlocks[airlock._id] = true
            end
            drawMap()
        end)
    frame:addButton()
        :setText("None")
        :setSize(6, 1)
        :setPosition("{parent.width - 6}", 1)
        :setBackground(colors.lightGray)
        :setForeground(colors.black)
        :onClick(function()
            log.info("Resetting airlock selections")
            selectedAirlocks = {}
            drawMap()
        end)

    drawMap = function()
        log.info("Drawing map with airlocks")

        -- Clear existing buttons
        for _, btn in ipairs(airlockButtons) do
            frame:removeChild(btn)
        end
        airlockButtons = {}

        local _airlocks = Airlocks:find()
        log.debug("Found airlocks: ", textutils.serialize(_airlocks))

        for i, airlock in ipairs(_airlocks) do
            local bg_col = colors.lightGray
            local fg_col = colors.black

            if airlock.state == "open" then
                bg_col = colors.yellow
            elseif airlock.state == "closed" then
                bg_col = colors.orange
            elseif airlock.state == "locked" then
                bg_col = colors.red
                fg_col = colors.white
            elseif airlock.state == "entry" then
                bg_col = colors.green
                fg_col = colors.white
            elseif airlock.state == "exit" then
                bg_col = colors.blue
                fg_col = colors.white
            end

            local x = 2 + ((i - 1) % 3) * 10
            local y = 4 + math.floor((i - 1) / 3) * 3
            local label = airlock.name or ("Airlock " .. i)

            -- Highlight if selected
            local isSelected = selectedAirlocks[airlock._id]
            if isSelected then
                label = "*" .. label .. "*"
            end

            local btn = frame:addButton()
                :setText(label)
                :setPosition(x, y)
                :setSize(8, 1)
                :setBackground(bg_col)
                :setForeground(fg_col)
                :onClick(function(_, button, _x, _y)
                    if button == 1 then
                        -- Toggle selection
                        if not selectedAirlocks[airlock._id] then
                            log.info("Selecting airlock: " .. airlock._id)
                            selectedAirlocks[airlock._id] = true
                        else
                            selectedAirlocks[airlock._id] = false
                            log.info("Deselecting airlock: " .. airlock.name)
                        end
                        drawMap()
                    elseif button == 2 then
                        -- Open config
                        log.debug("Configuring airlock: ", textutils.serialize(airlock))
                        if openAirlockConfigCallback then
                            openAirlockConfigCallback(airlock)
                        end
                    end
                end)

            table.insert(airlockButtons, btn)
        end
    end

    -- Command Button
    local function commandSelectedAirlocks(state)
        local selected = {}
        for id, isSelected in pairs(selectedAirlocks) do
            if isSelected then
                table.insert(selected, id)
            end
        end
        log.info("Commanding selected airlocks: " .. textutils.serialize(selected))
        if #selected == 0 then
            log.warn("No airlocks selected for command")
            return
        end

        if State.Modem then
            State.Modem.transmit(constants.Ports.COMMAND, constants.Ports.COMMAND_RESPONSE, {
                __module = "airlock-cs",
                type = "command",
                source = C.ID,
                target = selected,
                transition = state,
            })
        else
            log.error("Modem not initialized, cannot send command")
        end
    end
    -- Utility functions
    local function yLine(offset)
        return frame:getHeight() - offset
    end

    local function noAirlocksSelected()
        return next(selectedAirlocks) == nil
    end

    local function makeCommandButton(props)
        frame:addButton()
            :setText(props.text)
            :setSize(props.width or (#props.text + 2), 1)
            :setPosition(props.x, yLine(1))
            :setBackground(props.bg or colors.lightGray)
            :setForeground(props.fg or colors.black)
            :onClick(props.onClick)
    end

    -- Divider line
    frame:addLabel()
        :setText(("-"):rep(49))
        :setPosition(2, yLine(3))
        :setForeground(colors.lightGray)

    -- Section Headers
    local sectionHeaders = {
        { text = "Lockdown", x = 7 },
        { text = "General",  x = 23 },
        { text = "Force",    x = 40 }
    }

    for _, header in ipairs(sectionHeaders) do
        frame:addLabel()
            :setText(header.text)
            :setPosition(header.x, yLine(2))
            :setForeground(colors.white)
    end

    -- Lockdown Section Buttons
    local lockdownButtons = {
        {
            text = "Enable",
            x = 2,
            bg = colors.red,
            onClick = function()
                if noAirlocksSelected() then
                    log.warn("No airlocks selected for command")
                    return
                end
                -- Now run Lockdown on selected airlocks
                commandSelectedAirlocks("locked")
            end
        },
        {
            text = "Disable",
            x = 11,
            bg = colors.green,
            onClick = function()
                if noAirlocksSelected() then
                    log.warn("No airlocks selected for command")
                    return
                end
                commandSelectedAirlocks("closed")
            end
        },
    }

    -- General Section Buttons
    local generalButtons = {
        {
            text = "Entry",
            x = 21,
            onClick = function()
                if noAirlocksSelected() then
                    log.warn("No airlocks selected for command")
                    return
                end
                commandSelectedAirlocks("entry")
            end
        },
        {
            text = "Exit",
            x = 29,
            onClick = function()
                if noAirlocksSelected() then
                    log.warn("No airlocks selected for command")
                    return
                end
                commandSelectedAirlocks("exit")
            end
        },
    }

    -- Open/Close Control Buttons
    local controlButtons = {
        {
            text = "Open",
            x = 36,
            bg = colors.yellow,
            onClick = function()
                if noAirlocksSelected() then
                    log.warn("No airlocks selected for command")
                    return
                end
                commandSelectedAirlocks("open")
            end
        },
        {
            text = "Close",
            x = 43,
            bg = colors.orange,
            onClick = function()
                if noAirlocksSelected() then
                    log.warn("No airlocks selected for command")
                    return
                end
                commandSelectedAirlocks("closed")
            end
        },
    }

    -- Render All Button Groups
    for _, btn in ipairs(lockdownButtons) do makeCommandButton(btn) end
    for _, btn in ipairs(generalButtons) do makeCommandButton(btn) end
    for _, btn in ipairs(controlButtons) do makeCommandButton(btn) end


    Airlocks:on("new", drawMap)
    Airlocks:on("update", drawMap)
    Airlocks:on("delete", drawMap)

    drawMap()

    return {
        update = drawMap
    }
end
