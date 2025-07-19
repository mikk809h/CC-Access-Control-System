if periphemu then
    local testPeripherals = {
        ["AIRLOCK"] = {
            ["SCREEN"] = {
                type = "monitor",
                id = 3,
                blockSize = { width = 1, height = 1 }
            },
            ["KEYCARD"] = {
                type = "drive",
                id = 1
            },
        },
        ["ENTRANCE"] = {
            ["SCREEN"] = {
                type = "monitor",
                id = 1,
                blockSize = { width = 3, height = 2 }
            },
            ["KEYCARD"] = {
                type = "drive",
                id = 2
            },
        },
        ["INFO"] = {
            ["SCREEN"] = {
                type = "monitor",
                id = 2,
                blockSize = { width = 3, height = 3 }
            },
        },
        ["OTHER"] = {
            ["SPEAKER"] = {
                type = "speaker",
                id = "right"
            },
            ["MODEM"] = {
                type = "modem",
                id = "left"
            },
        }
    }

    local function createTestPeripheral(object)
        local location, peripheralType = object.id, object.type

        periphemu.create(location, peripheralType)

        if object.blockSize then
            peripheral.call("monitor_" .. tostring(location), "setBlockSize", object.blockSize.width,
                object.blockSize.height)
        end
    end

    for location, objects in pairs(testPeripherals) do
        for name, object in pairs(objects) do
            createTestPeripheral(object)
        end
    end
end


term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)

local paths = {
    ["airlock"] = "airlock/startup.lua",
    ["control-server"] = "control-server/startup.lua",
}

local function startComponent(component)
    local path = paths[component]
    if path then
        return shell.run(path)
    end
end

-- Auto update
if fs.exists("installer.lua") and not fs.exists(".dev") then
    print("Running installer...")
    local inst = require("installer")
    if inst then
        local hasUpdates, componentsOutdated = inst.hasUpdates()
        if hasUpdates then
            if inst.update(componentsOutdated) then
                print("Updates installed successfully.")
                print("Restarting computer...")
                sleep(1)
                os.reboot()
            else
                print("Failed to install updates.")
            end
        else
            print("No updates available.")
        end
    end
    sleep(1.5)
end

local lastComponentRun = nil
if fs.exists(".lastComponent") then
    local file = fs.open(".lastComponent", "r")
    if file then
        lastComponentRun = file.readAll()
        file.close()
    end
    print("Last component run: " .. lastComponentRun)
end
local countExisting = 0
for _, path in pairs(paths) do
    if fs.exists(path) then
        countExisting = countExisting + 1
    end
end
for component, path in pairs(paths) do
    print("Checking for component: " .. component)
    if fs.exists(path) then
        if countExisting > 1 and not lastComponentRun then
            print("Multiple components found, please select one to start:")
            print("Press Enter to start " .. component .. " or type 'skip' to skip this component.")
            sure = read()
            if sure:lower() == "" then
                local file = fs.open(".lastComponent", "w")
                if file then
                    file.write(component)
                    file.close()
                end
                startComponent(component)
            end
        elseif lastComponentRun then
            if lastComponentRun == component then
                startComponent(component)
            end
        else
            print("Starting component: " .. component)
            local file = fs.open(".lastComponent", "w")
            if file then
                file.write(component)
                file.close()
            end
            startComponent(component)
            break
        end
    end
end
