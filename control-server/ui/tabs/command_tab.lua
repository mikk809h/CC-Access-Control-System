local log      = require "core.log"
local debug    = require "core.debug"
local EventBus = require("core.eventbus")
local State    = require("control-server.state")

-- ui/logs_tab.lua

return function(frame, setLockdown)
    log.info("Initializing Command Tab")

    -- local lockdownInput = frame:addInput()
    --     :setText(State.status.lockdownReason or "")
    --     :setPosition(2, 2)
    --     :setSize("{parent.width - 4}", 1)
    --     :setPlaceholder("Lockdown Reason (optional)")

    -- local lockdownBtn = frame:addButton()
    --     :setText(State.status.lockdown and "Deactivate Lockdown" or "Activate Lockdown")
    --     :setSize(21, 3)
    --     :setPosition(2, 4)
    --     :setBackground(State.status.lockdown and colors.red or colors.orange)

    -- lockdownBtn:onClick(function()
    --     local isNow = not State.status.lockdown
    --     lockdownBtn:setText(isNow and "Deactivate Lockdown" or "Activate Lockdown")
    --     lockdownBtn:setBackground(isNow and colors.red or colors.orange)
    --     setLockdown(isNow, lockdownInput:getText())
    -- end)

    local airlockList = frame:addList()
        :setPosition(2, 8)
        :setSize("{parent.width - 2}", "{parent.height - 8}")
        :setBackground(colors.lightGray)
        :setForeground(colors.black)
        :setMultiSelection(true)

    local function updateList()
        airlockList:clear()
        -- for _, airlock in ipairs(State.airlocks or {}) do
        --     local item = {
        --         text = airlock.name or "Airlock",
        --         __airlock = airlock,
        --         background = airlock.locked and colors.red or colors.green,
        --         foreground = colors.black
        --     }
        --     airlockList:addItem(item)
        -- end
    end

    EventBus:subscribe("airlocks_updated", function()
        updateList()
    end)

    updateList()
    return {
        update = function()
        end
    }
end
