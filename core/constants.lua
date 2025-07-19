---@class Ports
---@field VALIDATION integer
---@field VALIDATION_RESPONSE integer
---@field STATUS integer
---@field PING integer

---@type Ports
local Ports = {
    VALIDATION = 55780,
    VALIDATION_RESPONSE = 55785,
    STATUS = 55010,
    PING = 55000,
}





return {
    Ports = Ports,
}
