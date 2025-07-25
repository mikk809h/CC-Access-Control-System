local log      = require "core.log"
local EventBus = require("core.eventbus")

-- ui/dialog_user.lua
return function(mainFrame, defaultLevels, drive)
    local currentMode = nil
    local callback = nil
    local editingUser = nil
    local currentDisk = nil

    local frame = mainFrame:addFrame()
        :setSize("{parent.width - 2}", "{parent.height - 2}")
        :setPosition(2, 2)
        :setBackground(colors.black)
        :setForeground(colors.lightGray)
        :setVisible(false)
        :setZ(900)

    local title = frame:addLabel()
        :setText("User Management")
        :setPosition(2, 2)
        :setForeground(colors.yellow)

    frame:addLabel()
        :setText("Username:")
        :setPosition(2, 4)

    local inputUsername = frame:addInput()
        :setPlaceholder("e.g. alice01")
        :setPosition(2, 5)
        :setSize("{parent.width - 4}", 1)
        :setBackground(colors.lightGray)
        :setForeground(colors.black)

    frame:addLabel()
        :setText("Access Level:")
        :setPosition(2, 7)

    local levelDropdown = frame:addDropdown()
        :setPosition(2, 8)
        :setSize("{parent.width - 4}", 1)
        :setItems(defaultLevels)
        :setSelectedText("Select User Level")
        :setBackground(colors.lightGray)
        :setForeground(colors.black)

    local errorLabel = frame:addLabel()
        :setText("")
        :setPosition(4, 10)
        :setForeground(colors.red)

    local keycardLabel = frame:addLabel()
        :setText("Insert keycard to write user ID...")
        :setPosition(2, 12)
        :setForeground(colors.gray)

    local keycardStatus = frame:addLabel()
        :setText("No disk inserted")
        :setPosition(2, 13)
        :setForeground(colors.gray)

    local writeCardBtn = frame:addButton()
        :setText("Write Keycard")
        :setPosition(16, 16)
        :setSize(17, 1)
        :setBackground(colors.lightGray)
        :setForeground(colors.black)
        :setVisible(false)
        :onClick(function()
            if not currentDisk then return end
            local username = inputUsername:getText()

            if not username or username == "" then
                keycardStatus:setText("Enter username first")
                keycardStatus:setForeground(colors.red)
                return
            end
            local path = drive.getMountPath()
            local h = fs.open(path .. "/identity", "w")
            if h then
                h.writeLine(username)
                h.close()
                keycardStatus:setText("Keycard written for '" .. username .. "'")
                keycardStatus:setForeground(colors.lime)
            else
                keycardStatus:setText("Failed to write to keycard")
                keycardStatus:setForeground(colors.red)
            end
        end)

    local submitBtn = frame:addButton()
        :setText("Submit")
        :setPosition("{parent.width - 12}", "{parent.height - 1}")
        :setSize(10, 1)
        :setBackground(colors.lightGray)
        :setForeground(colors.black)

    local cancelBtn = frame:addButton()
        :setText("Cancel")
        :setPosition(2, "{parent.height - 1}")
        :setSize(10, 1)
        :onClick(function()
            frame:setVisible(false)
        end)


    submitBtn:onClick(function()
        local username = inputUsername:getText()
        local level = levelDropdown:getSelectedItem()

        if not username or username == "" then
            errorLabel:setText("Username required")
            return
        end
        if not level then
            errorLabel:setText("Select user level")
            return
        end

        errorLabel:setText("")

        if callback then
            local success = callback({
                username = username,
                level = level.value,
                user = editingUser
            })

            if type(success) == "table" then
                if success.valid then
                    log.info("User saved successfully: ", textutils.serialize(success))

                    -- Write to keycard if disk present
                    if currentDisk then
                        local h = fs.open(currentDisk .. "/user.txt", "w")
                        if h then
                            h.writeLine(username)
                            h.close()
                            keycardStatus:setText("Keycard written for '" .. username .. "'")
                            keycardStatus:setForeground(colors.lime)
                        else
                            keycardStatus:setText("Failed to write to keycard")
                            keycardStatus:setForeground(colors.red)
                        end
                    end

                    frame:setVisible(false)
                    return
                else
                    log.error("Failed to save user: ", textutils.serialize(success))
                    errorLabel:setText(success.message or "Failed to save user")
                    return
                end
            else
                log.error("Failed to save user: ", textutils.serialize(success))
                errorLabel:setText("Unknown error. Check log")
                return
            end
        end
    end)

    --- Event hooks for disk insertion/removal
    EventBus:subscribe("disk", function(side)
        currentDisk = side
        keycardStatus:setText("Disk inserted on " .. side)
        keycardStatus:setForeground(colors.yellow)
        writeCardBtn:setVisible(true)
    end)

    EventBus:subscribe("disk_eject", function(side)
        if side == currentDisk then
            currentDisk = nil
            keycardStatus:setText("No disk inserted")
            keycardStatus:setForeground(colors.gray)

            writeCardBtn:setVisible(false)
        end
    end)

    return {
        open = function(mode, user, onSubmit)
            if mode ~= "Add" and mode ~= "Edit" then
                log.error("Invalid mode: " .. tostring(mode))
                return
            end
            currentMode = mode
            editingUser = user
            callback = onSubmit
            inputUsername:setText(user and user.username or "")
            levelDropdown:clear()
            levelDropdown:setItems(defaultLevels)

            if user then
                local items = levelDropdown:getItems()
                for _, item in ipairs(items) do
                    item.selected = (item.value == user.level)
                end
                levelDropdown:setItems(items)
            end

            submitBtn:setText(mode == "Edit" and "Save" or "Add")
            title:setText(mode == "Edit" and "Edit User" or "Add User")
            errorLabel:setText("")
            keycardStatus:setText(currentDisk and ("Disk inserted on " .. currentDisk) or "No disk inserted")
            keycardStatus:setForeground(currentDisk and colors.yellow or colors.gray)
            frame:setVisible(true)
        end
    }
end
