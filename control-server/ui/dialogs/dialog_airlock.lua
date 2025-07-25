local log = require "core.log"
-- ui/dialog_airlock.lua

return function(frame)
    local dialog = frame:addFrame()
        :setSize(30, 13)
        :setPosition(10, 6)
        :setBackground(colors.lightGray)
        :setForeground(colors.white)
        :setZ(1000)
        :setVisible(false)

    dialog:addLabel()
        :setText("Airlock Configuration")
        :setPosition("{parent.width / 2 - 10}", 1)
        :setForeground(colors.black)

    local nameField = dialog:addInput()
        :setPosition(2, 3)
        :setBackground(colors.gray)
        :setForeground(colors.white)
        :setSize(26, 1)

    dialog:addLabel()
        :setText("State: ")
        :setPosition(2, 5)

    local stateLabel = dialog:addLabel()
        :setPosition(10, 5)
        :setForeground(colors.white)
        :setText("Unknown")


    dialog:addButton()
        :setText("Save")
        :setPosition(2, "{parent.height - 1}")
        :setBackground(colors.gray)
        :setForeground(colors.lightGray)
        :setSize(10, 1)
    -- :onClick(function()
    --     local name = nameField:getText()

    --     if dialog.__onSubmit then
    --         dialog.__onSubmit({
    --             id = dialog.__airlock.id,
    --             name = name
    --         })
    --     end

    --     dialog:setVisible(false)
    -- end)

    dialog:addButton()
        :setText("Cancel")
        :setPosition(14, "{parent.height - 1}")
        :setBackground(colors.gray)
        :setForeground(colors.lightGray)
        :setSize(10, 1)
        :onClick(function()
            dialog:setVisible(false)
        end)

    return {
        open = function(airlock, onSubmit)
            dialog.__airlock = airlock
            dialog.__onSubmit = onSubmit
            log.debug("Opening dialog airlock: ", textutils.serialize(airlock))
            nameField:setText(airlock.name or "")
            stateLabel:setText(airlock.state or "Unknown")
            log.info("TEST")
            dialog:setVisible(true)
        end
    }
end
