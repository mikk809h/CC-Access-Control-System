require("/initialize").initialize()
--[[
    Main Control System
    Handles modem communication, ping/status validation, and lockdown control.
]]

local log                     = require("core.log")
local User                    = require("control-server.models.user")
local handleValidationRequest = require("control-server.events.onValidationRequest")
local handlePing              = require("control-server.events.onPing")
local Constants               = require("core.constants")
local State                   = require("control-server.state")
local basalt                  = require("control-server.basalt")

BROADCAST_INTERVAL            = 10
CHECK_ACTIVITY_INTERVAL       = 1
PING_TIMEOUT                  = 5


TYPE_NAME = "Access Control System"
ID = "ACS"

SOUNDS = {
    LOCKDOWN = {
        { "bass", 1, 12 },
        0.4,
        { "bass", 1, 6 },
        0.2,
        { "bass", 1, 0 },
    },
    LOCKDOWN_LIFTED = {
        { "bass", 1, 6 },
        0.4,
        { "bass", 1, 0 },
        0.2,
        { "bass", 1, 12 },
    },
}



-- === Terminal Setup ===
local width, height = term.getSize()
term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 2)

-- === Globals ===

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
    local f = fs.open("logs/server.log", "a")
    f.writeLine(table.concat({ ... }, " "))
    f.close()
    Log = {}
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

-- === State.status Management ===

local function setStatusField(key, value)
    if State.status[key] ~= value then
        State.status[key] = value
    end
end

local function broadcastStatus()
    modem.transmit(Constants.Ports.STATUS, Constants.Ports.PING, State.status)
    LastBroadcastTime = os.clock()
    -- Set all systems to waiting for ACK
    for id, sys in pairs(State.clients) do
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

local function checkPendingAcks()
    local now = os.clock()
    for id, sys in pairs(State.clients) do
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

    if channel == Constants.Ports.VALIDATION and replyChannel == Constants.Ports.VALIDATION_RESPONSE then
        local response = handleValidationRequest(message)
        modem.transmit(Constants.Ports.VALIDATION_RESPONSE, Constants.Ports.VALIDATION, response)
        printf(colors.lime, "Validation response sent to channel ", colors.purple, tostring(channel))
    elseif channel == Constants.Ports.PING and replyChannel == Constants.Ports.STATUS then
        handlePing(message)

        -- Limit broadcast to avoid flood if multiple pings are received
        if LastBroadcastTime == 0 or (os.clock() - LastBroadcastTime > 2) then
            broadcastStatus()
        end
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
            --     setLockdown(not State.status.lockdown, "Manual toggle", { "A1.Entrance" })
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

-- === Initialization ===

printf(colors.lightGray, "Starting ", colors.purple, TYPE_NAME, colors.gray, -3, "ID: ", colors.purple, ID)
printf(colors.lightGray, "Opening ports: ", colors.purple, tostring(Constants.Ports.VALIDATION), ", ",
    tostring(Constants.Ports.PING))
modem.open(Constants.Ports.VALIDATION)
modem.open(Constants.Ports.PING)

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
            printf(textutils.serialize(selectedItem))
            selectedItem.__user:update({
                username = username,
                level = level.value,
                active = true,
            })
            selectedItem.text = username
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
    elseif dialogAddUserButton:getText() == "Add User" then
        local user = User:new {
            username = username,
            level = level.value,
            active = true
        }
        UserList:addItem({ text = username, __user = user })
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
    :setForeground(colors.yellow)

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
    :setText(State.status.online and "Online" or "Offline")
    :setPosition(2 + #("Facility Status: "), 2)
    :setForeground(State.status.online and colors.green or colors.red)

local lockdownActive = mainTab:addLabel()
    :setText("Lockdown active! ")
    --align right
    :setPosition("{parent.width - " .. tostring(#("Lockdown active! ")) .. "}", 2)
    :setForeground(colors.red)
    :setVisible(State.status.lockdown)

mainTab:addLabel()
    :setText("Airlock systems online: ")
    :setPosition(2, 4)
    :setForeground(colors.lightGray)

local airlockCount = count(State.clients, function(sys) return sys.online end)
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
    :setBackground(State.status.lockdown and colors.red or colors.orange)
lockdownBtn:onClick(function()
    -- toggle color
    onLockdown(not State.status.lockdown)
end)

local lockdownInput = logsTab:addInput()
    :setText(State.status.lockdownReason or "")
    :setSize("{parent.width - 4}", 1)
    :setPosition(2, 2)
    :setPlaceholder("Lockdown Reason (optional)")
    :onKey(function(self, key)
        if key == keys.enter or key == keys.numPadEnter then
            onLockdown(not State.status.lockdown)
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


for _, user in ipairs(User:find()) do
    UserList:addItem({
        text = user.username,
        __user = user,
    })
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
        DialogUsername:setText(selectedItem.__user.username or "")
        -- Set the selected attribute for the dropdown
        dialogLevelDropdown:setItems(defaultLevels)
        local items = dialogLevelDropdown:getItems()
        printf(colors.lightGray, "Setting user level to: ", colors.purple, selectedItem.__user.level or "UNKNOWN")
        for _, item in ipairs(items) do
            printf(colors.lightGray, "Checking item: ", colors.purple, item.value)
            if item.value == selectedItem.__user.level then
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
        selectedItem.__user:delete() -- Delete the user from the database
        UserList:removeItem(index)
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

    airlockCount = count(State.clients, function(sys) return sys.online end)
    airlockLabel:setText(tostring(airlockCount))
    airlockLabel:setForeground(airlockCount > 0 and colors.green or colors.red)

    statusLabel:setText(State.status.online and "Online" or "Offline")
    statusLabel:setForeground(State.status.online and colors.green or colors.red)

    lockdownActive:setVisible(State.status.lockdown)
    lockdownActive:setText(State.status.lockdown and "Lockdown active! " .. (State.status.lockdownReason or "") or
        "No lockdown active")
    lockdownActive:setForeground(State.status.lockdown and colors.red or colors.green)

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
            local newCount = count(State.clients, function(sys) return sys.online end)
            if newCount ~= airlockCount then
                airlockCount = newCount
                airlockLabel:setText(tostring(airlockCount))
                airlockLabel:setForeground(airlockCount > 0 and colors.green or colors.red)
            end

            local newStatus = State.status.online and "Online" or "Offline"
            if newStatus ~= statusLabel:getText() then
                statusLabel:setText(newStatus)
                statusLabel:setForeground(State.status.online and colors.green or colors.red)
            end

            if State.status.lockdown then
                lockdownActive:setText("Lockdown active! " .. (State.status.lockdownReason or ""))
                lockdownActive:setForeground(colors.red)
            else
                lockdownActive:setText("No lockdown active")
                lockdownActive:setForeground(colors.green)
            end
            sleep(1)
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
