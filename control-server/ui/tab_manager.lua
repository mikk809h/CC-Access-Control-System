local log = require "core.log"
-- ui/tab_manager.lua

return function(tabsFrame, containerFrame)
    local tabs = {}
    local activeTab = nil

    local function switchTab(tabId)
        for id, tab in pairs(tabs) do
            local isActive = (id == tabId)
            tab.button:setBackground(isActive and colors.gray or colors.lightGray)
            tab.button:setForeground(isActive and colors.white or colors.black)
            tab.frame:setVisible(isActive)
        end
        activeTab = tabId
        log.info("Switched to ", tabId)
    end

    local function addTab(tabId, label, frameBuilder)
        log.info("Adding tab: ", tabId, " with label: ", label)
        local btnX = 1
        for _, tab in pairs(tabs) do
            btnX = btnX + tab.button:getWidth() + 1
        end

        local button = tabsFrame:addButton()
            :setText(label)
            :setPosition(btnX, 1)
            :setSize(#label + 2, 1)

        local frame = containerFrame:addFrame()
            :setSize("{parent.width}", "{parent.height}")
            :setPosition(1, 1)
            :setVisible(false)
            :setBackground(colors.gray)
            :setForeground(colors.white)

        if type(frameBuilder) ~= "function" then
            log.error("Frame builder for tab '" .. tostring(tabId) .. "' is not a function")
            log.info("TABID", textutils.serialize(tabId))
            log.info("LABEL", textutils.serialize(label))
            log.info("FRAMEBUILDER", textutils.serialize(frameBuilder))
            return nil
        end
        if frameBuilder then frameBuilder(frame) end

        button:onClick(function()
            switchTab(tabId)
        end)

        tabs[tabId] = { button = button, frame = frame }

        -- Default to first tab
        if not activeTab then switchTab(tabId) end

        return frame
    end

    return {
        addTab = addTab,
        switchTo = switchTab,
        getActiveTab = function() return activeTab end,
        getTab = function(id) return tabs[id] end
    }
end
