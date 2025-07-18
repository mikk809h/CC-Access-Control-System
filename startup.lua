if periphemu then
    -- set up the environment.
    --This is the server.
    -- Attach top modem
    -- attach right speaker
    -- attach 1 computer
    -- detach 1 computer
    -- Entrance.keycard
    periphemu.create(4, "drive")   -- drive 4 for keycard
    -- Entrtance.screen
    periphemu.create(3, "monitor") -- computer 1 for airlock entrance
    -- periphemu.create(6, "redstoneIntegrator")
    -- periphemu.create(5, "redstoneIntegrator") -- remove computer 1 to simulate a detached computer
    periphemu.create(1, "drive")   -- create computer 2 for the main system
    periphemu.create(1, "monitor") -- create computer 3
    periphemu.create(2, "monitor") -- create computer 4 for the airlock system

    -- Other.speaker
    periphemu.create("right", "speaker")
    -- Other.modem
    periphemu.create("left", "modem")


    -- Set up the monitors properly
    local function setBlockSize(monitorId, width, height)
        local monitor = peripheral.wrap("monitor_" .. tostring(monitorId))
        if monitor then
            -- monitor.setTextScale(1) -- Set text scale to 1 for better readability
            monitor.setBlockSize(width, height)
        else
            error("Monitor " .. monitorId .. " not found.")
        end
    end

    setBlockSize(3, 1, 1) -- Entrance screen
    setBlockSize(1, 3, 2) -- Airlock screen
    setBlockSize(2, 3, 3) -- Info screen
end

shell.run("main")
