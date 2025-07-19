local queue = {}
local Components = require("core.components")
local C = require("shared.config")
local log = require("core.log")


--- Queue a sound to be played
---@param sound SoundEnum The name of the sound to play
---@return nil
local function play(sound)
    table.insert(queue, sound)
    os.queueEvent("playSound")
end

local function loop()
    while true do
        local event = { os.pullEvent("playSound") }
        if #queue > 0 then
            local sound = table.remove(queue, 1)
            local sequence = C.SOUNDS[sound]
            if sequence then
                for _, v in ipairs(sequence) do
                    if type(v) == "table" then
                        log.info({ colors.cyan, "Playing sound: " }, { colors.white, tostring(v[1]) },
                            { colors.cyan, " at volume: " }, { colors.white, tostring(v[2]) },
                            { colors.cyan, " with pitch: " }, { colors.white, tostring(v[3]) })
                        Components.callComponent(C.COMPONENTS, "OTHER", "SPEAKER", "playNote", v[1], v[2], v[3])
                    else
                        sleep(v)
                    end
                end
            end
        end
    end
end

return {
    play = play,
    loop = loop
}
