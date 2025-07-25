-- ui/main_tab.lua

local log = require "core.log"
local helpers = require "core.helpers"
local State = require("control-server.state")
local EventBus = require "core.eventbus"
local Airlocks = require "control-server.models.airlocks"

return function(frame)
    log.info("Initializing Main Tab")
    frame:addLabel()
        :setText("Facility Status: ")
        :setPosition(2, 2)
        :setForeground(colors.orange)

    frame:addLabel()
        :setText("Airlock systems online: ")
        :setPosition(2, 4)
        :setForeground(colors.lightGray)

    local airlockLabel = frame:addLabel()
        :setText("0")
        :setPosition(2 + #("Airlock systems online: "), 4)
        :setForeground(colors.red)

    frame:addLabel()
        :setText("Radiation Levels:")
        :setPosition(2, 6)
        :setForeground(colors.lightGray)

    local radiationLabel = frame:addLabel()
        :setText("99 nSv/h")
        :setPosition(3 + #("Radiation Levels:"), 6)
        :setForeground(colors.white)

    local function update()
        local airlockCount = #Airlocks:find({ online = true })
        airlockLabel:setText(tostring(airlockCount))
        airlockLabel:draw()
    end

    -- Subscribe to updates
    Airlocks:on("new", update)

    Airlocks:on("update", update)

    return {
        update = function()

        end
    }
end
