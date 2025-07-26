local EventBus  = require("core.eventbus")
local State     = require("control-server.state")
local C         = require("control-server.config")
local Airlocks  = require("control-server.models.airlocks")
local log       = require("core.log")
local debug     = require("core.debug")
local constants = require("core.constants")

return function(frame, openAirlockConfigCallback)
    -- Local state
    local selectedAirlocks = {}
    local airlockButtonCache = {}

    -- Utility Module
    local UIUtils = {
        yLine = function(offset)
            return frame:getHeight() - offset
        end,

        noAirlocksSelected = function()
            return next(selectedAirlocks) == nil
        end,

        separator = function(y)
            local line = ("-"):rep(frame:getWidth() - 2)
            return frame:addLabel():setText(line):setPosition(2, y):setForeground(colors.lightGray)
        end,

        createButton = function(props)
            local btn = frame:addButton()
            btn:setText(props.text)
                :setSize(props.size or (#props.text + 2), 1)
                :setPosition(props.x, props.y)
                :setBackground(props.bg or colors.lightGray)
                :setForeground(props.fg or colors.black)

            if props.onClick then
                btn:onClick(props.onClick)
            end

            return btn
        end
    }

    -- Header Rendering
    local function drawHeader()
        local headers = {
            { text = "Unknown", size = 9, x = 2,  bg = colors.lightGray, fg = colors.black },
            { text = "Open",    size = 6, x = 12, bg = colors.yellow,    fg = colors.black },
            { text = "Closed",  size = 8, x = 19, bg = colors.orange,    fg = colors.black },
            { text = "Locked",  size = 8, x = 28, bg = colors.red,       fg = colors.white },
            { text = "Entry",   size = 7, x = 37, bg = colors.green,     fg = colors.white },
            { text = "Exit",    size = 6, x = 45, bg = colors.blue,      fg = colors.white },
        }

        for _, h in ipairs(headers) do
            UIUtils.createButton {
                text = h.text, size = h.size, x = h.x, y = 2,
                bg = h.bg, fg = h.fg,
                onClick = function(_, button, x, y)
                    if h.text == "Unknown" then
                        log.debug("Unknown button clicked")
                        debug.dump({ button = button, x = x, y = y })
                    end
                end
            }
        end

        UIUtils.separator(3)
        frame:addLabel():setText("RClick=config LClick=select"):setPosition(2, 1):setForeground(colors.white)

        -- Select All / None
        local actions = {
            {
                text = "All",
                x = frame:getWidth() - 12,
                action = function()
                    selectedAirlocks = {}
                    for _, airlock in ipairs(Airlocks:find()) do
                        selectedAirlocks[airlock._id] = true
                    end
                    log.info("Selected all airlocks")
                end
            },

            {
                text = "None",
                x = frame:getWidth() - 6,
                action = function()
                    selectedAirlocks = {}
                    log.info("Cleared all selections")
                end
            }
        }

        for _, a in ipairs(actions) do
            UIUtils.createButton {
                text = a.text, x = a.x, y = 1,
                onClick = function()
                    a.action()
                    drawMap()
                end
            }
        end
    end

    -- Command Section
    local function commandSelectedAirlocks(state)
        local targets = {}
        for id, selected in pairs(selectedAirlocks) do
            if selected then table.insert(targets, id) end
        end

        if #targets == 0 then
            return log.warn("No airlocks selected for command")
        end

        if not State.Modem then
            return log.error("Modem not initialized")
        end

        State.Modem.transmit(constants.Ports.COMMAND, constants.Ports.COMMAND_RESPONSE, {
            __module = "airlock-cs",
            type = "command",
            source = C.ID,
            target = targets,
            transition = state,
        })

        log.info("Commanded airlocks: " .. textutils.serialize(targets))
    end

    local function renderCommandSection()
        UIUtils.separator(UIUtils.yLine(2))

        local sections = {
            {
                label = "Lockdown",
                x = 7,
                buttons = {
                    { text = "Enable",  x = 2,  bg = colors.red,    state = "locked" },
                    { text = "Disable", x = 11, bg = colors.orange, state = "closed" },
                }
            },
            {
                label = "General",
                x = 23,
                buttons = {
                    { text = "Entry", x = 21, bg = colors.green, state = "entry" },
                    { text = "Exit",  x = 29, bg = colors.blue,  state = "exit" },
                }
            },
            {
                label = "Force",
                x = 40,
                buttons = {
                    { text = "Open",  x = 36, bg = colors.yellow, state = "open" },
                    { text = "Close", x = 43, bg = colors.orange, state = "closed" },
                }
            },
        }

        for _, section in ipairs(sections) do
            frame:addLabel():setText(section.label):setPosition(section.x, UIUtils.yLine(0)):setForeground(colors.white)

            for _, btn in ipairs(section.buttons) do
                UIUtils.createButton {
                    text = btn.text, x = btn.x, y = UIUtils.yLine(1), bg = btn.bg,
                    onClick = function()
                        if UIUtils.noAirlocksSelected() then
                            return log.warn("No airlocks selected for command")
                        end
                        commandSelectedAirlocks(btn.state)
                    end
                }
            end
        end

        UIUtils.createButton {
            text = "R", x = frame:getWidth() - 1, y = UIUtils.yLine(0),
            bg = colors.lightGray,
            onClick = function()
                if UIUtils.noAirlocksSelected() then
                    return log.warn("No airlocks selected for command")
                end
                commandSelectedAirlocks("reboot")
            end
        }
    end
    local function categorizeAirlocks(airlocks)
        local segments = {
            A1 = {}, -- Reactor Containment
            A2 = {}, -- Inner Perimeter
            A3 = {}, -- Outer Perimeter
            Unknown = {}
        }

        for _, airlock in ipairs(airlocks) do
            local name = airlock.name or ""
            local zone = name:match("^(A[1-3])") or "Unknown"
            table.insert(segments[zone], airlock)
        end

        return segments
    end
    function drawMap()
        local airlocks = Airlocks:find()
        local segments = categorizeAirlocks(airlocks)
        local validIDs = {}

        local zoneOrder = { "A3", "A2", "A1" }
        local columnX = {
            A3 = 2,
            A2 = math.floor(frame:getWidth() / 3),
            A1 = math.floor(2 * frame:getWidth() / 3),
        }

        local zoneLabels = {
            A3 = "A3 - Outer",
            A2 = "A2 - Inner",
            A1 = "A1 - Reactor",
        }

        local maxRows = 0

        -- Render zone headers
        for _, zone in ipairs(zoneOrder) do
            local x = columnX[zone]
            frame:addLabel()
                :setText(zoneLabels[zone])
                :setPosition(x, 4)
                :setForeground(colors.white)
        end

        -- Render airlocks under each zone, vertically
        for _, zone in ipairs(zoneOrder) do
            local list = segments[zone]
            local x = columnX[zone]
            for i, airlock in ipairs(list) do
                local y = 5 + i -- 1-based vertical stacking
                validIDs[airlock._id] = true

                local label = airlock.name or ("Airlock " .. i)
                if selectedAirlocks[airlock._id] then
                    label = "*" .. label .. "*"
                end

                local bg, fg = colors.lightGray, colors.black
                if airlock.state == "open" then
                    bg = colors.yellow
                elseif airlock.state == "closed" then
                    bg = colors.orange
                elseif airlock.state == "locked" then
                    bg, fg = colors.red, colors.white
                elseif airlock.state == "entry" then
                    bg, fg = colors.green, colors.white
                elseif airlock.state == "exit" then
                    bg, fg = colors.blue, colors.white
                end

                local btn = airlockButtonCache[airlock._id]
                if btn then
                    btn:setText(label)
                        :setPosition(x, y)
                        :setBackground(bg)
                        :setForeground(fg)
                else
                    btn = frame:addButton()
                        :setText(label):setSize(12, 1)
                        :setPosition(x, y)
                        :setBackground(bg)
                        :setForeground(fg)
                        :onClick(function(_, button)
                            if button == 1 then
                                selectedAirlocks[airlock._id] = not selectedAirlocks[airlock._id]
                                log.info((selectedAirlocks[airlock._id] and "Selected" or "Deselected") ..
                                    " airlock: " .. airlock._id)
                                drawMap()
                            elseif button == 2 and openAirlockConfigCallback then
                                openAirlockConfigCallback(airlock)
                            end
                        end)
                    airlockButtonCache[airlock._id] = btn
                end

                if i > maxRows then maxRows = i end
            end
        end

        -- Remove stale buttons
        for id, btn in pairs(airlockButtonCache) do
            if not validIDs[id] then
                frame:removeChild(btn)
                airlockButtonCache[id] = nil
            end
        end
    end

    -- Bind Events
    Airlocks:on("new", drawMap)
    Airlocks:on("update", drawMap)
    Airlocks:on("delete", drawMap)

    -- Initial UI Render
    drawHeader()
    renderCommandSection()
    drawMap()

    return {
        update = drawMap
    }
end
