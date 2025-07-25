-- ui/users_tab.lua
local User     = require("control-server.models.user")
local EventBus = require("core.eventbus")
local log      = require("core.log")

---Formats a user row into a fixed-width string
---@param user table A user with at least 'username' and 'level' fields
---@param width integer Total width of the formatted line
---@return string
local function formatListItem(user, width)
    local username = user.username or "Unknown"
    local level = user.level or "N/A"

    -- Trim or pad username to fit
    local maxNameLen = width - #level - 1 -- 1 space between
    if #username > maxNameLen then
        username = username:sub(1, maxNameLen - 1) .. "…"
    end

    -- Left-align username, right-align level
    local padding = width - #username - #level
    local spaces = string.rep(" ", padding)

    return username .. spaces .. level
end


return function(frame, userDialog)
    local UserList = frame:addList()
        :setPosition(2, 3)
        :setSize("{parent.width - 2}", "{parent.height - 7}")
        :setBackground(colors.lightGray)
        :setForeground(colors.black)


    for _, user in ipairs(User:find()) do
        UserList:addItem({ text = formatListItem(user, UserList:getWidth()), __user = user })
    end

    frame:addLabel()
        :setText("Select a user")
        :setPosition(2, 2)

    frame:addLabel()
        :setText("Use buttons below to manage users.")
        :setPosition(2, "{parent.height - 1}")

    local function openDialog(mode, user)
        userDialog.open(mode, user, function(data)
            log.info("User dialog submitted with data: ", data)
            if mode == "Add" then
                local user, err = User:new {
                    username = data.username,
                    level = data.level,
                    active = true,
                }
                if err then
                    log.error("Failed to create user: ", err)
                    return { valid = false, message = err }
                end
                -- Add to UserList
                UserList:addItem({ text = formatListItem(user, UserList:getWidth()), __user = user })
                log.info("Added user: ", data.username)
                return { valid = true, message = "User added successfully" }
            elseif mode == "Edit" and user then
                log.info("Updating user: ", user.username)
                log.debug("Old user data: ", textutils.serialize(user))
                local success, err = user:update({
                    username = data.username,
                    level = data.level,
                })
                if not success and err then
                    log.error("Failed to update user: ", err)
                    return { valid = false, message = err }
                end
                log.debug("New user data: ", textutils.serialize(user))
                -- Update UserList
                for i, item in ipairs(UserList:getItems()) do
                    if item.__user.username == user.username then
                        item.text = formatListItem(user, UserList:getWidth())
                        item.__user = user
                        break
                    end
                end
                log.info("Updated user: ", data.username)
                return { valid = true, message = "User updated successfully" }
            end
        end)
    end
    frame:addButton()
        :setText("Add User")
        :setPosition(2, "{parent.height - 3}")
        :setSize(10, 1)
        :onClick(function()
            openDialog("Add", nil)
        end)

    frame:addButton()
        :setText("Edit User")
        :setPosition("{parent.width / 2 - 5}", "{parent.height - 3}")
        :setSize(11, 1)
        :onClick(function()
            local selected = UserList:getSelectedItem()
            if selected then openDialog("Edit", selected.__user) end
        end)

    frame:addButton()
        :setText("Remove User")
        :setPosition("{parent.width - 13}", "{parent.height - 3}")
        :setSize(13, 1)
        :onClick(function()
            local selected = UserList:getSelectedItem()
            if selected then
                for i, item in ipairs(UserList:getItems()) do
                    if item == selected then
                        selected.__user:delete()
                        UserList:removeItem(i)
                        break
                    end
                end
            end
        end)
end
