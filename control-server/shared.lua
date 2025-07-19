BROADCAST_INTERVAL = 10
CHECK_ACTIVITY_INTERVAL = 1
PING_TIMEOUT = 5

Port = {
    --[[
        Ping is the port used to "Ping" the server.
    --]]
    ["PING"] = 55000,
    --[[
        Status is the broadcast port from the server to all computers.
        This ping includes status messages and more.
    --]]
    ["STATUS"] = 55010,
    ["VALIDATION"] = 55780,
    ["VALIDATION_RESPONSE"] = 55785,
}
