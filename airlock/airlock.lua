local util     = require "core.util"
local log      = require "core.log"
local debug    = require "core.debug"
local Airlock  = {}

local config   = {}

Airlock.config = config

function Airlock.load_config()
    if not settings.load("/.settings") then return false end
    log.info("Loaded settings from /.settings")

    config.COMPONENTS = {
        ENTRANCE = {
            DOOR = settings.get("component.entrance.door"),
            KEYCARD = settings.get("component.entrance.keycard"),
            SCREEN = settings.get("component.entrance.screen")
        },
        EXIT = {
            DOOR = settings.get("component.exit.door")
        },
        AIRLOCK = {
            KEYCARD = settings.get("component.airlock.keycard"),
            SCREEN = settings.get("component.airlock.screen")
        },
        INFO = {
            SCREEN = settings.get("component.info.screen")
        },
        OTHER = {
            SPEAKER = settings.get("component.other.speaker"),
            MODEM = settings.get("component.other.modem")
        },
    }

    config.ID = settings.get("Identifier")
    config.TYPE_NAME = settings.get("Name") or "Airlock Entrance"
    config.OPENING_DELAY = settings.get("openingDelay") or 2.5
    config.AUTO_CLOSE_TIME = settings.get("autoCloseTime") or 10

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
