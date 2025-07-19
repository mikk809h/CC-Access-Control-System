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
if fs.exists("installer.lua") then
    print("Running installer...")
    local inst = require("installer")
    if inst then
        local hasUpdates, componentsOutdated = inst.hasUpdates()
        if hasUpdates then
            print("Updates available, installing...")
            if inst.update(componentsOutdated) then
                print("Updates installed successfully.")
                print("Restarting computer...")
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
for component, path in pairs(paths) do
    print("Checking for component: " .. component)
    if fs.exists(path) then
        print("Starting component: " .. component)
        startComponent(component)
        break
    end
end
