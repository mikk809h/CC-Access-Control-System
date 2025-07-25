---@type Ports
local Ports = {
    VALIDATION = 55780,
    VALIDATION_RESPONSE = 55785,
    STATUS = 55010,
    STATUS_RESPONSE = 55011,
    ONLINE = 55015, -- This is used to broadcast that clients should send their ping asap.
    PING = 55000,
    PING_RESPONSE = 55005,
    BOOTUP = 55020,
    BOOTUP_RESPONSE = 55025,
    COMMAND = 55880,
    COMMAND_RESPONSE = 55881
}


return {
    Ports = Ports,
}
