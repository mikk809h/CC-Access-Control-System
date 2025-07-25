-- === Terminal Setup ===
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

-- === Peripheral Simulation ===

if fs.exists("core/peripherals.lua") then
    print("Loading peripheral simulation...")
    local peripherals = require("core.peripherals")

    local mode = peripherals.detectTestMode()
    if mode then
        peripherals.setup(mode)
    end
end


-- === Auto Update System ===
local function performAutoUpdate()
    if not (fs.exists("installer.lua") and not fs.exists("__DEV__")) then return end

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
    if fs.exists("__DEV__") then
        print("Running in development mode, skipping last component load.")
        return nil
    end
    if not fs.exists(".cache") then
        fs.makeDir(".cache")
    end
    if not fs.exists(".cache/startup") then return nil end
    local file = fs.open(".cache/startup", "r")
    if not file then return nil end
    local content = file.readAll()
    file.close()
    return content
end

local function saveLastComponent(name)
    local file = fs.open(".cache/startup", "w")
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
performAutoUpdate()

local available = listAvailableComponents()
local lastRun = loadLastComponent()

if lastRun and fs.exists(components[lastRun]) then
    print("Starting same component as last run: " .. lastRun)
    sleep(0.6)
    runComponent(lastRun)
else
    if #available == 1 then
        print("Starting componenet: " .. available[1])
        sleep(0.6)
        runComponent(available[1])
    elseif #available > 1 then
        print("Multiple components found.")
        local selected = promptComponentSelection(available)
        if selected then
            print("Starting component: " .. selected)
            sleep(0.6)
            runComponent(selected)
        else
            print("No component selected.")
        end
    else
        print("No available components to run.")
    end
end
