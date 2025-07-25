local log = require("core.log")

---@enum SoundEnum
local SoundEnum = {
    ENTRY = "ENTRY",
    DENIED = "DENIED",
    OFFLINE = "OFFLINE",
    ONLINE = "ONLINE",
    PING = "PING",
    LOCKDOWN = "LOCKDOWN",
    LOCKDOWN_LIFTED = "LOCKDOWN_LIFTED",
    NO_IDENTITY = "NO_IDENTITY",
    EMPTY_IDENTITY = "EMPTY_IDENTITY",
    UNKNOWN_ERROR = "UNKNOWN_ERROR"
}

local Sounds = {
    ENTRY = { { "bit", 1, 12 }, 0.7, { "bit", 1, 0 }, 0.45, { "bit", 1, 6 } },
    DENIED = { { "bit", 1, 10 }, 0.15, { "bit", 1, 0 } },
    OFFLINE = { { "bit", 0.5, 1 } },
    ONLINE = { { "chime", 0.25, 0 } },
    PING = { { "bit", 0.5, 24 } },
    LOCKDOWN = { { "bit", 1, 4 }, 0.2, { "bit", 1, 0 } },
    LOCKDOWN_LIFTED = { { "bit", 1, 6 }, 0.2, { "bit", 1, 0 } },
    NO_IDENTITY = { { "bit", 1, 6 }, 0.2, { "bit", 1, 0 } },
    EMPTY_IDENTITY = { { "bit", 1, 8 }, 0.4, { "bit", 1, 5 }, 0.45, { "bit", 1, 3 } },
    UNKNOWN_ERROR = { { "bit", 1, 2 }, 0.2, { "bit", 1, 12 }, 0.4, { "bit", 1, 0 } },
}

local nextSound = nil

--- Queue a sound to be played
---@param sound SoundEnum The name of the sound to play
---@return nil
local function play(sound)
    log.debug("Queueing sound: ", sound)
    nextSound = sound
    os.queueEvent("playSound")
end

local function createLoopInstance(speaker_callback)
    assert(type(speaker_callback) == "function", "speaker_callback must be a function")
    log.debug("Creating audio loop instance")
    return function()
        while true do
            local event = { os.pullEvent("playSound") }
            log.debug("Sound event received: ", nextSound)
            if nextSound then
                local sequence = Sounds[nextSound]
                if sequence then
                    for _, v in ipairs(sequence) do
                        if type(v) == "table" then
                            log.info({ colors.cyan, "Playing sound: " }, { colors.white, tostring(v[1]) },
                                { colors.cyan, " at volume: " }, { colors.white, tostring(v[2]) },
                                { colors.cyan, " with pitch: " }, { colors.white, tostring(v[3]) })
                            speaker_callback("playNote", v[1], v[2], v[3])
                        else
                            sleep(v)
                        end
                    end
                end
            end
        end
    end
end

return {
    play = play,
    createLoopInstance = createLoopInstance
}
