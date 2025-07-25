return function(mainFrame, TYPE_NAME)
    local header = mainFrame:addFrame()
        :setSize("{parent.width}", 3)
        :setPosition(1, 1)
        :setBackground(colors.lightGray)

    header:addLabel()
        :setText("Gantoof Nuclear Power Plant")
        :setPosition("{(parent.width - 30) / 2}", 2)
        :setForeground(colors.yellow)

    header:addLabel()
        :setText(TYPE_NAME)
        :setPosition("{(parent.width - " .. #TYPE_NAME .. ") / 2}", 3)
        :setForeground(colors.gray)

    local tabs = mainFrame:addFrame()
        :setSize("{parent.width}", 1)
        :setPosition(1, 4)
        :setBackground(colors.lightGray)

    return {
        header = header,
        tabs = tabs,
        addTab = function(label, x, onClick)
            return tabs:addButton()
                :setText(label)
                :setPosition(x, 1)
                :setSize(#label + 2, 1)
                :setBackground(colors.gray)
                :setForeground(colors.white)
                :onClick(onClick)
        end
    }
end
