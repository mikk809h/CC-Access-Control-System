return setmetatable({}, {
    __index = {
        online = nil,
        lockdown = nil,
        lockdownReason = "",
        lockdownIDs = {},
    }
})
