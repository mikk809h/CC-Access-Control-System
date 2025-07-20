return setmetatable({}, {
    __index = {
        clients = {},
        status = {
            type = "status",
            source = nil,
            online = true,
            lockdown = false,
            lockdownReason = "",
            lockdownIDs = nil,
        },
    }
})
