local util = require "core.util"
local Airlock = {}

local config = {}

Airlock.config = config

function Airlock.load_config()
    if not settings.load("/.settings") then return false end

    return true
end

function Airlock.validate_config(cfg)
    local cfv = util.new_validator()

    -- cfv.assert_type_num(cfg.SpeakerVolume)
    -- cfv.assert_range(cfg.SpeakerVolume, 0, 3)

    -- cfv.assert_channel(cfg.SVR_Channel)
    -- cfv.assert_channel(cfg.RTU_Channel)
    -- cfv.assert_type_num(cfg.ConnTimeout)
    -- cfv.assert_min(cfg.ConnTimeout, 2)
    -- cfv.assert_type_num(cfg.TrustedRange)
    -- cfv.assert_min(cfg.TrustedRange, 0)
    -- cfv.assert_type_str(cfg.AuthKey)

    -- if type(cfg.AuthKey) == "string" then
    --     local len = string.len(cfg.AuthKey)
    --     cfv.assert(len == 0 or len >= 8)
    -- end

    -- cfv.assert_type_int(cfg.LogMode)
    -- cfv.assert_range(cfg.LogMode, 0, 1)
    -- cfv.assert_type_str(cfg.LogPath)
    -- cfv.assert_type_bool(cfg.LogDebug)

    -- cfv.assert_type_int(cfg.FrontPanelTheme)
    -- cfv.assert_range(cfg.FrontPanelTheme, 1, 2)
    -- cfv.assert_type_int(cfg.ColorMode)
    -- cfv.assert_range(cfg.ColorMode, 1, themes.COLOR_MODE.NUM_MODES)

    -- cfv.assert_type_table(cfg.Peripherals)
    -- cfv.assert_type_table(cfg.Redstone)

    return cfv.valid()
end

return Airlock
