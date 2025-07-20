-- === Terminal Setup ===
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

-- === Peripheral Simulation ===
local function setupTestPeripherals()
    if not periphemu or not fs.exists("airlock/startup.lua") then return end

    local peripherals = {
        AIRLOCK = {
            SCREEN = { type = "monitor", id = 3, blockSize = { width = 1, height = 1 } },
            KEYCARD = { type = "drive", id = 1 },
        },
        ENTRANCE = {
            SCREEN = { type = "monitor", id = 1, blockSize = { width = 3, height = 2 } },
            KEYCARD = { type = "drive", id = 2 },
        },
        INFO = {
            SCREEN = { type = "monitor", id = 2, blockSize = { width = 3, height = 3 } },
        },
        OTHER = {
            SPEAKER = { type = "speaker", id = "right" },
            MODEM = { type = "modem", id = "left" },
        },
    }

    for _, devices in pairs(peripherals) do
        for _, device in pairs(devices) do
            periphemu.create(device.id, device.type)
            if device.type == "monitor" and device.blockSize then
                local monName = "monitor_" .. tostring(device.id)
                peripheral.call(monName, "setBlockSize", device.blockSize.width, device.blockSize.height)
            end
        end
    end
end

-- === Auto Update System ===
local function performAutoUpdate()
    if not (fs.exists("installer.lua") and not fs.exists(".dev")) then return end

    print("Running installer...")
    local installer = require("installer")
    if installer then
        local hasUpdates, outdated = installer.hasUpdates()
        if hasUpdates then
            if installer.update(outdated) then
                print("Updates installed. Rebooting...")
                sleep(1)
                os.reboot()
            else
                print("Failed to install updates.")
            end
        else
            print("No updates available.")
        end
    end
end

-- === Component Loader ===
local components = {
    airlock = "airlock/startup.lua",
    ["control-server"] = "control-server/startup.lua",
}

local function loadLastComponent()
    if not fs.exists(".lastComponent") then return nil end
    local file = fs.open(".lastComponent", "r")
    if not file then return nil end
    local content = file.readAll()
    file.close()
    return content
end

local function saveLastComponent(name)
    local file = fs.open(".lastComponent", "w")
    if file then
        file.write(name)
        file.close()
    end
end

local function runComponent(name)
    local path = components[name]
    if fs.exists(path) then
        saveLastComponent(name)
        print("Starting component: " .. name)
        shell.run(path)
    end
end

local function listAvailableComponents()
    local list = {}
    for name, path in pairs(components) do
        if fs.exists(path) then
            table.insert(list, name)
        end
    end
    return list
end

local function promptComponentSelection(available)
    for _, name in ipairs(available) do
        print("Press Enter to start '" .. name .. "' or type 'skip' to skip.")
        local input = read()
        if input:lower() == "" then
            return name
        end
    end
    return nil
end

-- === Main Execution ===
setupTestPeripherals()
performAutoUpdate()

local available = listAvailableComponents()
local lastRun = loadLastComponent()

if lastRun and fs.exists(components[lastRun]) then
    print("Starting same component as last run: " .. lastRun)
    sleep(1.25)
    runComponent(lastRun)
else
    if #available == 1 then
        print("Starting componenet: " .. available[1])
        sleep(1.25)
        runComponent(available[1])
    elseif #available > 1 then
        print("Multiple components found.")
        local selected = promptComponentSelection(available)
        if selected then
            print("Starting component: " .. selected)
            sleep(1.25)
            runComponent(selected)
        else
            print("No component selected.")
        end
    else
        print("No available components to run.")
    end
end
