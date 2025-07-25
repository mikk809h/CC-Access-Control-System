return setmetatable({}, {
    __index = {
        accessLog = {},
        ---@type {table}
        Modem = nil
    }
})
