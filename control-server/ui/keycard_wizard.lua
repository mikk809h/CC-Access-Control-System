return function(mainFrame, DialogUsername)
    local width, height = term.getSize()
    local frame = mainFrame:addFrame()
        :setSize("{parent.width / 2 + 1}", "{parent.height / 2}")
        :setPosition(math.floor(width / 4), math.floor(height / 4))
        :setBackground(colors.gray)
        :setForeground(colors.lightGray)
        :setZ(1000)
        :setVisible(false)

    frame:addLabel()
        :setText("Keycard Wizard")
        :setPosition(2, 2)
        :setForeground(colors.black)

    local status = frame:addLabel()
        :setText("Please insert keycard...")
        :setPosition(2, 4)
        :setForeground(colors.white)

    frame:addButton()
        :setText("Cancel")
        :setPosition(2, 8)
        :setSize(10, 1)
        :setBackground(colors.black)
        :setForeground(colors.red)
        :onClick(function() frame:setVisible(false) end)

    local writeButton = frame:addButton()
        :setText("Write")
        :setSize(10, 1)
        :setPosition(15, 8)
        :setBackground(colors.black)
        :setForeground(colors.green)

    writeButton:onClick(function()
        if drive.isDiskPresent() then
            status:setText("Saving...")
            status:setForeground(colors.orange)
            local diskDir = drive.getMountPath()
            local file = fs.open(diskDir .. "/identity", "w")
            file.writeLine(DialogUsername:getText())
            file.close()
            drive.setDiskLabel("Keycard: " .. tostring(DialogUsername:getText()))
            sleep(0.25)
            status:setText("Saved!")
            status:setForeground(colors.green)
            sleep(1)
            frame:setVisible(false)
        else
            status:setText("No keycard found!")
            status:setForeground(colors.red)
        end
    end)

    return frame, status
end
