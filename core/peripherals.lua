-- core/peripherals.lua

local M = {}

local devicePresets = {
    airlock = {
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
    },

    controlServer = {
        SERVER = {
            SPEAKER = { type = "speaker", id = "right" },
            MODEM = { type = "modem", id = "left" },
            KEYCARD = { type = "drive", id = 3 },
        }
    }
}

local function createDevices(devices)
    for _, group in pairs(devices) do
        for _, device in pairs(group) do
            periphemu.create(device.id, device.type)
            if device.type == "monitor" and device.blockSize then
                local name = "monitor_" .. tostring(device.id)
                peripheral.call(name, "setBlockSize", device.blockSize.width, device.blockSize.height)
            end
        end
    end
end

function M.setup(mode)
    if not periphemu then return end
    if mode == "airlock" then
        print("Setting up simulated peripherals for airlock")
        createDevices(devicePresets.airlock)
    elseif mode == "control-server" then
        print("Setting up simulated peripherals for control-server")
        createDevices(devicePresets.controlServer)
    end
end

function M.detectTestMode()
    if fs.exists(".cache/startup") then
        local f = fs.open(".cache/startup", "r")
        if f then
            local mode = f.readLine()
            f.close()
            return mode
        end
    end
    return nil
end

return M
