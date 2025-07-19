--[[
    Main Control System
    Handles modem communication, ping/status validation, and lockdown control.
]]

-- === Dependencies ===
require("config")
require("shared")

-- === Terminal Setup ===
local width, height = term.getSize()
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 2)

-- === Globals ===

---@type table<string, { lastPing: number, online: boolean, waitingForAck: boolean }>
local Systems = {}

---@type table
local Status = {
    type = "status",
    source = ID,
    online = true,
    lockdown = false,
    lockdownReason = "",
    lockdownIDs = nil,
}

local Log = {}
LogWindow = nil

local LastBroadcastTime = 0

-- === Peripherals ===
local modem = nil
if periphemu then
    modem = peripheral.find("modem")
else
    modem = peripheral.find("modem", function(_, p) return p.isWireless() end)
end
assert(modem, "No wireless modem found")

local speaker = peripheral.find("speaker")
assert(speaker, "No speaker found")
speaker.playNote("pling", 0.2, 0)

local drive = peripheral.find("drive")
assert(drive, "No drive found")

-- === Utility Functions === --

--- Colored print with inline formatting and alignment
---@param ... any
local function printf(...)
    Log[#Log + 1] = { os.clock(), ... }
    if LogWindow then
        local defaultColor = LogWindow.getTextColor()

        -- LogWindow.write(...)
        local w, h = LogWindow.getSize()
        local cX, cY = LogWindow.getCursorPos()
        -- if cy will be greater than h, scroll
        if cY >= h then
            LogWindow.scroll(1)
            cY = h - 1
        end
        LogWindow.setCursorPos(1, cY)
        LogWindow.setTextColor(colors.gray)
        LogWindow.write(string.format("%8s ", os.date("%H:%M:%S")))
        LogWindow.setTextColor(defaultColor)
        local args = { ... }
        for i = 1, #args do
            local arg = args[i]
            if type(arg) == "string" then
                LogWindow.write(arg)
            elseif type(arg) == "number" then
                if arg == -3 then
                    local width = LogWindow.getSize()
                    local x = select(1, LogWindow.getCursorPos())

                    local remainingText = ""
                    for j = i + 1, #args do
                        if type(args[j]) == "string" then
                            remainingText = remainingText .. args[j]
                        end
                    end

                    local padding = width - x - #remainingText + 1
                    if padding > 0 then
                        LogWindow.write(string.rep(" ", padding))
                    end
                elseif arg >= 0 then
                    LogWindow.setTextColor(arg)
                else
                    LogWindow.setTextColor(defaultColor)
                end
            end
        end
        LogWindow.setTextColor(defaultColor)
        LogWindow.setCursorPos(1, cY + 1)
    end
end

--- Count items in a table optionally filtered
---@param tbl table
---@param predicate fun(value:any):boolean
local function count(tbl, predicate)
    local c = 0
    for _, v in pairs(tbl) do
        if not predicate or predicate(v) then
            c = c + 1
        end
    end
    return c
end

-- === Status Management ===

local function setStatusField(key, value)
    if Status[key] ~= value then
        Status[key] = value
    end
end

local function broadcastStatus()
    modem.transmit(Port.STATUS, Port.PING, Status)
    LastBroadcastTime = os.clock()
    -- printf(
    --     colors.gray, "Broadcasting status.",
    --     colors.gray, " online systems: ",
    --     colors.purple, tostring(count(Systems, function(sys) return sys.online end))
    -- )
    -- Set all systems to waiting for ACK
    for id, sys in pairs(Systems) do
        sys.waitingForAck = true
    end
end

--- Plays a sound based on the provided sound name.
-- @param sound The name of the sound to play.
local function playSound(sound)
    ActiveSound = sound
end

--- Enable or disable lockdown mode
---@param lockdown boolean
---@param reason string?
---@param ids table?
function setLockdown(lockdown, reason, ids)
    setStatusField("lockdown", lockdown)
    setStatusField("lockdownReason", reason or "")
    setStatusField("lockdownIDs", ids or nil)
    broadcastStatus()
    if reason and reason == "" then
        reason = "No reason provided"
    end
    if lockdown then
        printf(colors.red, "Lockdown: ", colors.lightGray, reason or "No reason provided")
        playSound("LOCKDOWN")
    else
        printf(colors.green, "Lockdown lifted")
        playSound("LOCKDOWN_LIFTED")
    end
end

-- === Handlers ===

local function handleValidationRequest(msg)
    if not msg or msg.type ~= "validation_request" or not msg.identifier or msg.identifier == "" then
        return { type = "validation_response", status = "error", message = "Invalid or missing ID" }
    end

    printf(colors.green, "Validating ID: ", colors.lightGray, tostring(msg.identifier))

    if Status.lockdown then
        printf(colors.red, "Validation failed: Lockdown active")
        return {
            type = "validation_response",
            status = "success",
            action = "deny",
            reason = "lockdown",
            identifier = msg.identifier,
            target = msg.source,
        }
    end
    return {
        type = "validation_response",
        status = "success",
        action = "allow",
        identifier = msg.identifier,
        target = msg.source,
    }
end


local function handlePing(msg)
    if type(msg) ~= "table" or msg.type ~= "status" then
        printf(colors.red, "Invalid ping message: ", colors.lightGray, tostring(msg.type))
        return
    end

    local now = os.clock()
    printf(colors.lightGray, "ACK received from ", colors.purple,
        msg.source)

    if not Systems[msg.source] then
        Systems[msg.source] = {}
    end

    Systems[msg.source].lastPing = now
    Systems[msg.source].online = true
    Systems[msg.source].waitingForAck = false
end

local function checkPendingAcks()
    local now = os.clock()
    for id, sys in pairs(Systems) do
        if sys.waitingForAck and (now - LastBroadcastTime > PING_TIMEOUT) then
            if sys.online then
                printf(colors.red, colors.purple, id, colors.red, " timed out")
            end
            sys.online = false
            sys.waitingForAck = false
        end
    end
end

-- === Event System ===

local Event = {}

function Event.onModemMessage(evt)
    local _, side, channel, replyChannel, message = table.unpack(evt)
    printf(colors.gray, "modem_message on ", tostring(channel), ":", tostring(replyChannel))

    if channel == Port.VALIDATION and replyChannel == Port.VALIDATION_RESPONSE then
        local response = handleValidationRequest(message)
        modem.transmit(Port.VALIDATION_RESPONSE, Port.VALIDATION, response)
        printf(colors.lime, "Validation response sent to channel ", colors.purple, tostring(channel))
    elseif channel == Port.PING and replyChannel == Port.STATUS then
        handlePing(message)
    end
end

-- === Main Loop ===

local function runListener()
    local broadcastTimer = os.startTimer(BROADCAST_INTERVAL)
    local checkTimer = os.startTimer(CHECK_ACTIVITY_INTERVAL)

    while true do
        local event = { os.pullEvent() }

        if event[1] == "modem_message" then
            Event.onModemMessage(event)
        elseif event[1] == "key" then
            local key, held = event[2], event[3]
            -- printf("Keys pressed: ", colors.purple, textutils.serialize(event))
            -- if not held then
            --     printf("Key pressed: ", colors.purple, keys.getName(key))
            -- end
            -- if key == keys.l then
            --     setLockdown(not Status.lockdown, "Manual toggle", { "A1.Entrance" })
            --     -- elseif key == keys.q then
            --     --     LogWindow.scroll(-1)
            --     -- elseif key == keys.e then
            --     --     LogWindow.scroll(1)
            -- end
        elseif event[1] == "timer" and event[2] == broadcastTimer then
            broadcastTimer = os.startTimer(BROADCAST_INTERVAL)
            broadcastStatus()
        elseif event[1] == "timer" and event[2] == checkTimer then
            checkTimer = os.startTimer(CHECK_ACTIVITY_INTERVAL)
            checkPendingAcks()
        elseif event[1] == "term_resize" then
            width, height = term.getSize()
            if LogWindow and LogFrame and LogDisplay then
                printf(colors.lightGray, "Terminal resized to ", colors.purple, tostring(width), "x", tostring(height))
            end
        end
    end
end

function splitString(str, sep)
    local parts = {}
    for part in str:gmatch("([^" .. sep .. "]+)") do
        parts[#parts + 1] = part
    end
    return parts
end

function getUsers()
    -- read users.txt line by line.
    -- layout:
    -- username|level|active
    -- example:
    -- User1|L10|true

    local users = {}
    if fs.exists("users.txt") then
        local file = fs.open("users.txt", "r")
        for line in file.readLine do
            printf(colors.lightGray, "Reading user: ", colors.purple, line)
            local parts = splitString(line, "|")
            if #parts == 3 then
                local username = parts[1]
                local level = parts[2]
                local active = parts[3] == "true"
                users[#users + 1] = { text = username, __meta = { username = username, level = level, active = active } }
            end
        end
        file.close()
    end
    return users
end

function saveUsers()
    -- save users to users.txt
    local file = fs.open("users.txt", "w")
    for _, user in ipairs(UserList:getItems()) do
        printf(textutils.serialize(user))
        if user.__meta then
            local line = string.format("%s|%s|%s", user.__meta.username, user.__meta.level or 1,
                user.__meta.active and "true" or "false")
            file.writeLine(line)
        end
    end
    file.close()
    printf(colors.green, "Users saved to users.txt")
end

-- === Initialization ===

printf(colors.lightGray, "Starting ", colors.purple, TYPE_NAME, colors.gray, -3, "ID: ", colors.purple, ID)
printf(colors.lightGray, "Opening ports: ", colors.purple, tostring(Port.VALIDATION), ", ", tostring(Port.PING))
modem.open(Port.VALIDATION)
modem.open(Port.PING)

broadcastStatus()

ActiveSound = nil
local function soundPlayer()
    while true do
        if ActiveSound ~= nil then
            if SOUNDS[ActiveSound] ~= nil then
                for _, v in pairs(SOUNDS[ActiveSound]) do
                    if type(v) == "table" then
                        local a, b, c = table.unpack(v)
                        speaker.playNote(a, b, c)
                    else
                        sleep(v)
                    end
                end
            end
            ActiveSound = nil
        end
        sleep(0.25)
    end
end


-- === Basalt UI Setup ===


local basalt = require("basalt")

local mainFrame = basalt.getMainFrame()

local CurrentPage = "Main"


-- === Keycard Wizard === --

local keycardWizardFrame = mainFrame:addFrame()
    :setSize("{parent.width / 2 + 1}", "{parent.height / 2}")
    :setPosition(math.floor(width / 4), math.floor(height / 4))
    :setBackground(colors.gray)
    :setForeground(colors.lightGray)
    :setZ(1000)
    :setVisible(false)

keycardWizardFrame:addLabel()
    :setText("Keycard Wizard")
    :setPosition(2, 2)
    :setForeground(colors.black)

local keycardWizardStatus = keycardWizardFrame:addLabel()
    :setText("Please insert keycard...")
    :setPosition(2, 4)
    :setForeground(colors.white)

keycardWizardFrame:addButton()
    :setText("Cancel")
    :setPosition(2, 8)
    :setSize(10, 1)
    :setBackground(colors.black)
    :setForeground(colors.red)
    :onClick(function()
        keycardWizardFrame:setVisible(false)
    end)
local keycardWizardWriteButton = keycardWizardFrame:addButton()
    :setText("Write")
    :setSize(10, 1)
    :setPosition(15, 8)
    :setBackground(colors.black)
    :setForeground(colors.green)
keycardWizardWriteButton:onClick(function()
    if drive.isDiskPresent() then
        keycardWizardStatus:setText("Saving...")
        keycardWizardStatus:setForeground(colors.orange)
        local diskDir = drive.getMountPath()
        local file = fs.open(diskDir .. "/identity", "w")
        file.writeLine(DialogUsername:getText())
        file.close()

        drive.setDiskLabel("Keycard: " .. tostring(DialogUsername:getText()))
        sleep(0.25)
        keycardWizardStatus:setText("Saved!")
        keycardWizardStatus:setForeground(colors.green)
        sleep(1)
        keycardWizardFrame:setVisible(false)
    else
        keycardWizardStatus:setText("No keycard found!")
        keycardWizardStatus:setForeground(colors.red)
    end
end)

-- === Dialog Frame ===

--#region Dialog Frame
local dialogFrame = mainFrame:addFrame()
    :setSize("{parent.width - 2}", "{parent.height - 2}")
    :setPosition(2, 2)
    :setBackground(colors.black)
    :setForeground(colors.lightGray)
    :setVisible(false)
    :setZ(900)

local dialogTitle = dialogFrame:addLabel()
    :setText("Add User")
    :setPosition(2, 2)
    :setForeground(colors.lightGray)

DialogUsername = dialogFrame:addInput()
    :setPlaceholder("Enter username")
    :setPosition(2, 4)
    :setSize("{parent.width - 4}", 1)
    :setBackground(colors.lightGray)
    :setForeground(colors.black)

local defaultLevels = {
    { text = "Level 10", value = "L10" },
    { text = "Level 20", value = "L20" },
    { text = "Level 30", value = "L30" },
}
local dialogLevelDropdown = dialogFrame:addDropdown()
    :setPosition(2, 6)
    :setSelectedText("Select User Level")
    :setSize("{parent.width - 4}", 1)
    :setBackground(colors.lightGray)
    :setForeground(colors.black)
    :setItems(defaultLevels)

dialogFrame:addLabel()
    :setPosition(2, 8)
    :setForeground(colors.lightGray)
    :setText("L10 = Technician, L20 = Monitor, L30 = Guest")
dialogFrame:addLabel()
    :setPosition(2, 7)
    :setForeground(colors.gray)
    :setText("Lowest number = highest level")

-- Separator
dialogFrame:addLabel()
    :setPosition(2, 9)
    :setForeground(colors.gray)
    :setText(string.rep("-", dialogFrame:getWidth() - 4))

local dialogKeycardStatus = dialogFrame:addLabel()
    :setPosition(4, 11)
    :setForeground(colors.red)
    :setText("")

--Back
dialogFrame:addButton()
    :setText("Back")
    :setPosition(2, "{parent.height - 1}")
    :setSize(10, 1)
    :setBackground(colors.lightGray)
    :setForeground(colors.black)
    :onClick(function()
        dialogFrame:setVisible(false)
    end)


local dialogWriteKeycardButton = dialogFrame:addButton()
    :setText("Write Keycard")
    :setPosition("{parent.width / 2 - 8}", "{parent.height - 1}")
    :setSize(17, 1)
    :setBackground(colors.lightGray)
    :setForeground(colors.black)
    :onClick(function()
        keycardWizardFrame:setVisible(true)
        if drive.isDiskPresent() then
            keycardWizardStatus:setText("Ready to write.")
            keycardWizardStatus:setForeground(colors.green)
        else
            keycardWizardStatus:setText("Please insert keycard...")
            keycardWizardStatus:setForeground(colors.lightGray)
        end
    end)

local dialogAddUserButton = dialogFrame:addButton()
    :setText("Add User")
    :setPosition("{parent.width - 12}", "{parent.height - 1}")
    :setSize(10, 1)
    :setBackground(colors.lightGray)
    :setForeground(colors.black)
dialogAddUserButton:onClick(function()
    local username = DialogUsername:getText()
    local level = dialogLevelDropdown:getSelectedItem()
    if not level then
        printf(colors.red, "Please select a user level")
        return
    end
    if not username or username == "" then
        printf(colors.red, "Username cannot be empty")
        return
    end

    -- Now if the addUserText is "Save User", we edit the user
    if dialogAddUserButton:getText() == "Save User" then
        local selectedItem = UserList:getSelectedItem()
        if selectedItem then
            printf(colors.lightGray, "Saving user: ", colors.purple, username)
            -- Build a new user list
            local newUserList = {}
            for _, item in ipairs(UserList:getItems()) do
                if item.__meta.username == selectedItem.__meta.username then
                    newUserList[#newUserList + 1] = {
                        text = username,
                        __meta = { username = username, level = level.value, active = true }
                    }
                else
                    newUserList[#newUserList + 1] = item
                end
            end
            UserList:setItems(newUserList)
            saveUsers()
            DialogUsername:setText("")
            dialogLevelDropdown:clear()
            dialogLevelDropdown:setItems(defaultLevels)
            dialogFrame:setVisible(false)

            printf(colors.green, "User saved: ", colors.lightGray, username)
            return
        else
            printf(colors.red, "No user selected to edit")
            return
        end
    else
        UserList:addItem({ text = username, __meta = { username = username, level = level.value, active = true } })
        saveUsers()
        DialogUsername:setText("")
        dialogLevelDropdown:clear()
        dialogLevelDropdown:setItems(defaultLevels)
        dialogFrame:setVisible(false)

        printf(colors.green, "Added new user: ", colors.lightGray, username)
    end
end)


--#endregion Dialog Frame


--#region Header
local headerFrame = mainFrame:addFrame()
    :setSize("{parent.width}", 3)
    :setPosition(1, 1)
    :setBackground(colors.lightGray)

headerFrame:addLabel()
    :setText("Gantoof Nuclear Power Plant")
    :setPosition(math.floor((headerFrame:getWidth() - #("Gantoof Nuclear Power Plant")) / 2), 2)
    :setForeground(colors.orange)

headerFrame:addLabel()
    :setText(TYPE_NAME)
    :setPosition(math.floor((headerFrame:getWidth() - #TYPE_NAME) / 2), 3)
    :setForeground(colors.gray)

local tabsFrame = mainFrame:addFrame()
    :setSize("{parent.width}", 1)
    :setPosition(1, 4)
    :setBackground(colors.lightGray)


local mainTabBtn = tabsFrame:addButton()
    :setText("Main")
    :setPosition(1, 1)
    :setSize(8, 1)
    :setBackground(colors.gray)
    :setForeground(colors.white)
local logsTabBtn = tabsFrame:addButton()
    :setText("Logs")
    :setPosition(9, 1)
    :setSize(8, 1)
local usersTabBtn = tabsFrame:addButton()
    :setText("Users")
    :setPosition(17, 1)
    :setSize(9, 1)
--#endregion Header


local containerFrame = mainFrame:addFrame()
    :setSize("{parent.width}", "{parent.height - 4}")
    :setPosition(1, 5)
    :setBackground(colors.gray)
    :setForeground(colors.white)

-- === Main Tab === --
--#region Main Tab

local mainTab = containerFrame:addFrame()
    :setSize("{parent.width}", "{parent.height}")
    :setPosition(1, 1)
    :setBackground(colors.gray)
    :setForeground(colors.white)

mainTab:addLabel()
    :setText("Facility Status: ")
    :setPosition(2, 2)
    :setForeground(colors.orange)

local statusLabel = mainTab:addLabel()
    :setText(Status.online and "Online" or "Offline")
    :setPosition(2 + #("Facility Status: "), 2)
    :setForeground(Status.online and colors.green or colors.red)

local lockdownActive = mainTab:addLabel()
    :setText("Lockdown active! ")
    --align right
    :setPosition("{parent.width - " .. tostring(#("Lockdown active! ")) .. "}", 2)
    :setForeground(colors.red)
    :setVisible(Status.lockdown)

mainTab:addLabel()
    :setText("Airlock systems online: ")
    :setPosition(2, 4)
    :setForeground(colors.lightGray)

local airlockCount = count(Systems, function(sys) return sys.online end)
local airlockLabel = mainTab:addLabel()
    :setText(tostring(airlockCount))
    :setPosition(2 + #("Airlock systems online: "), 4)
    :setForeground(airlockCount > 0 and colors.green or colors.red)

--#endregion Main Tab


-- === Logs Tab === --
--#region Logs Tab


local logsTab = containerFrame:addFrame()
    :setSize("{parent.width}", "{parent.height}")
    :setPosition(1, 1)
    :setBackground(colors.gray)
    :setForeground(colors.white)
    :setVisible(false)

local lockdownBtn = logsTab:addButton()
    :setText("Activate Lockdown")
    :setSize(21, 3)
    :setPosition(2, 4)
    :setBackground(Status.lockdown and colors.red or colors.orange)
lockdownBtn:onClick(function()
    -- toggle color
    onLockdown(not Status.lockdown)
end)

local lockdownInput = logsTab:addInput()
    :setText(Status.lockdownReason or "")
    :setSize("{parent.width - 4}", 1)
    :setPosition(2, 2)
    :setPlaceholder("Lockdown Reason (optional)")
    :onKey(function(self, key)
        if key == keys.enter or key == keys.numPadEnter then
            onLockdown(not Status.lockdown)
        end
    end)

function onLockdown(isLockdown)
    lockdownBtn:setBackground(isLockdown and colors.red or colors.orange)
    lockdownBtn:setText(isLockdown and "Deactivate Lockdown" or "Activate Lockdown")
    headerFrame:setBackground(isLockdown and colors.red or colors.lightGray)
    setLockdown(isLockdown, lockdownInput:getText(), nil)
end

local logHeight = math.floor(height / 2.2)

LogFrame = logsTab:addFrame()
    :setSize("{parent.width}", logHeight + 1)
    :setPosition(1, "{parent.height - " .. tostring(logHeight - 1) .. "}")
    :setBackground(colors.gray)
    :setForeground(colors.white)

-- LogFrame.visible = true
LogDisplay = LogFrame:addDisplay()
    :setWidth("{parent.width}")
    :setHeight("{parent.height - 1}")
    :setPosition(1, 1)

LogWindow = LogDisplay:getWindow()

LogWindow.clear()
printf(colors.lightGray, "Terminal size: ", colors.purple, tostring(width), "x", tostring(height))

--#endregion Logs Tab


-- === Users Tab === --
-- Contains user CRUD operations, user management, and more.
--#region Users Tab

local usersTab = containerFrame:addFrame()
    :setSize("{parent.width}", "{parent.height}")
    :setPosition(1, 1)
    :setBackground(colors.gray)
    :setForeground(colors.white)
    :setVisible(false)

UserList = usersTab:addList()
    :setPosition(2, 3)
    :setSize("{parent.width - 2}", "{parent.height - 7}")
    :setBackground(colors.lightGray)
    :setForeground(colors.black)
-- :onSelect(function(self, item)
--     printf(colors.lightGray, "Selected user: ", colors.purple, tostring(item))
-- end)

for _, user in ipairs(getUsers()) do
    UserList:addItem(user)
end

local addUserBtn = usersTab:addButton()
    :setText("Add User")
    :setPosition(2, "{parent.height - 3}")
    :setSize(10, 1)
addUserBtn:onClick(function()
    -- Open Dialog
    dialogFrame:setVisible(true)
    DialogUsername:setText("")
    dialogAddUserButton:setText("Add User")
    dialogLevelDropdown:clear()
    dialogLevelDropdown:setItems(defaultLevels)
end)

local editUserBtn = usersTab:addButton()
    :setText("Edit User")
    :setPosition("{parent.width / 2 - 5}", "{parent.height - 3}")
    :setSize(11, 1)
editUserBtn:onClick(function()
    local selectedItem = UserList:getSelectedItem()
    if selectedItem then
        printf(colors.lightGray, "Editing user: ", colors.purple, selectedItem.text)
        printf(colors.lightGray, "User data: ", colors.purple, textutils.serialize(selectedItem))
        dialogFrame:setVisible(true)
        DialogUsername:setText(selectedItem.__meta.username or "")
        -- Set the selected attribute for the dropdown
        dialogLevelDropdown:setItems(defaultLevels)
        local items = dialogLevelDropdown:getItems()
        printf(colors.lightGray, "Setting user level to: ", colors.purple, selectedItem.__meta.level or "UNKNOWN")
        for _, item in ipairs(items) do
            printf(colors.lightGray, "Checking item: ", colors.purple, item.value)
            if item.value == selectedItem.__meta.level then
                printf(colors.lightGray, "Found matching item: ", colors.purple, item.value)
                item.selected = true
            else
                item.selected = false
            end
        end
        dialogLevelDropdown:setItems(items)

        dialogAddUserButton:setText("Save User")
    else
        printf(colors.red, "No user selected to edit")
    end
end)

local removeUserBtn = usersTab:addButton()
    :setText("Remove User")
    :setPosition("{parent.width - 13}", "{parent.height - 3}")
    :setSize(13, 1)
removeUserBtn:onClick(function()
    local selectedItem = UserList:getSelectedItem()

    if selectedItem then
        --  find index of this  selected item
        local index = 0
        for i, item in ipairs(UserList:getItems()) do
            if item == selectedItem then
                index = i
                break
            end
        end
        printf(colors.lightGray, "Removing user: ", colors.purple, textutils.serialize(selectedItem))

        UserList:removeItem(index)
        saveUsers()
        -- printf(colors.red, "Removed user: ", colors.lightGray, selectedItem)
    else
        printf(colors.red, "No user selected to remove")
    end
end)

usersTab:addLabel()
    :setText("Select a user")
    :setPosition(2, 2)
    :setForeground(colors.lightGray)
usersTab:addLabel()
    :setText("Use the buttons to add, remove & manage users.")
    :setPosition(2, "{parent.height - 1}")
    :setForeground(colors.lightGray)




--#endregion Users Tab

--#region Tab Switching
mainTabBtn:onClick(function()
    if CurrentPage == "Main" then
        return
    end
    CurrentPage = "Main"
    printf(colors.lightGray, "Switched to ", colors.purple, "Main")
    mainTabBtn:setBackground(colors.gray)
    mainTabBtn:setForeground(colors.white)

    logsTabBtn:setBackground(colors.lightGray)
    logsTabBtn:setForeground(colors.black)

    usersTabBtn:setBackground(colors.lightGray)
    usersTabBtn:setForeground(colors.black)

    airlockCount = count(Systems, function(sys) return sys.online end)
    airlockLabel:setText(tostring(airlockCount))
    airlockLabel:setForeground(airlockCount > 0 and colors.green or colors.red)

    statusLabel:setText(Status.online and "Online" or "Offline")
    statusLabel:setForeground(Status.online and colors.green or colors.red)

    lockdownActive:setVisible(Status.lockdown)
    lockdownActive:setText(Status.lockdown and "Lockdown active! " .. (Status.lockdownReason or "") or
        "No lockdown active")
    lockdownActive:setForeground(Status.lockdown and colors.red or colors.green)

    logsTab:setVisible(false)
    usersTab:setVisible(false)
    mainTab:setVisible(true)
end)

logsTabBtn:onClick(function()
    if CurrentPage == "Logs" then
        return
    end
    CurrentPage = "Logs"
    printf(colors.lightGray, "Switched to ", colors.purple, "Logs")
    mainTabBtn:setBackground(colors.lightGray)
    mainTabBtn:setForeground(colors.black)

    logsTabBtn:setBackground(colors.gray)
    logsTabBtn:setForeground(colors.white)

    usersTabBtn:setBackground(colors.lightGray)
    usersTabBtn:setForeground(colors.black)

    logsTab:setVisible(true)
    usersTab:setVisible(false)
    mainTab:setVisible(false)
end)

usersTabBtn:onClick(function()
    if CurrentPage == "Users" then
        return
    end
    CurrentPage = "Users"
    printf(colors.lightGray, "Switched to ", colors.purple, "Users")
    mainTabBtn:setBackground(colors.lightGray)
    mainTabBtn:setForeground(colors.black)

    usersTabBtn:setBackground(colors.gray)
    usersTabBtn:setForeground(colors.white)

    logsTabBtn:setBackground(colors.lightGray)
    logsTabBtn:setForeground(colors.black)

    logsTab:setVisible(false)
    mainTab:setVisible(false)
    usersTab:setVisible(true)
end)

--#endregion Tab Switching

parallel.waitForAny(runListener, basalt.run, function()
        while true do
            -- Update main tab
            local newCount = count(Systems, function(sys) return sys.online end)
            if newCount ~= airlockCount then
                airlockCount = newCount
                airlockLabel:setText(tostring(airlockCount))
                airlockLabel:setForeground(airlockCount > 0 and colors.green or colors.red)
            end

            local newStatus = Status.online and "Online" or "Offline"
            if newStatus ~= statusLabel:getText() then
                statusLabel:setText(newStatus)
                statusLabel:setForeground(Status.online and colors.green or colors.red)
            end

            if Status.lockdown then
                lockdownActive:setText("Lockdown active! " .. (Status.lockdownReason or ""))
                lockdownActive:setForeground(colors.red)
            else
                lockdownActive:setText("No lockdown active")
                lockdownActive:setForeground(colors.green)
            end
            sleep(1)
        end
    end, function()
        -- autosave log append
        while true do
            sleep(2)
            local logFile = nil
            if not fs.exists("logs") then
                logFile = fs.open("logs", "w")
            else
                logFile = fs.open("logs", "a")
            end

            if logFile then
                for _, entry in ipairs(Log) do
                    local time = os.date("%H:%M:%S", entry[1])
                    local text = table.concat({ table.unpack(entry, 2) }, " ")
                    logFile.writeLine(string.format("[%s] %s", time, text))
                end
                logFile.close()
                Log = {} -- Clear the log after saving
            else
                printf(colors.red, "Failed to open log file for writing.")
            end
        end
    end, soundPlayer,
    function()
        while true do
            local event = { os.pullEvent() }

            if event[1] == "disk" then
                -- Disk inserted or ejected
                if keycardWizardFrame.visible then
                    if drive and drive.isDiskPresent() then
                        keycardWizardStatus:setText("Ready to write.")
                        keycardWizardStatus:setForeground(colors.lime)
                    else
                        keycardWizardStatus:setText("Please insert keycard...")
                        keycardWizardStatus:setForeground(colors.red)
                    end
                end
            elseif event[1] == "disk_eject" then
                -- Disk ejected
                if keycardWizardFrame.visible then
                    keycardWizardStatus:setText("Keycard removed...")
                    keycardWizardStatus:setForeground(colors.red)
                end
            end
        end
    end)
