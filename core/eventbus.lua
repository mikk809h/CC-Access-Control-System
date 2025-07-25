local EventBus = {
    listeners = {}
}

function EventBus:subscribe(eventName, callback)
    if not self.listeners[eventName] then
        self.listeners[eventName] = {}
    end
    table.insert(self.listeners[eventName], callback)
end

function EventBus:unsubscribe(eventName, callback)
    if self.listeners[eventName] then
        for i, fn in ipairs(self.listeners[eventName]) do
            if fn == callback then
                table.remove(self.listeners[eventName], i)
                break
            end
        end
    end
end

function EventBus:publish(eventName, payload)
    -- log.debug("Publishing event: ", eventName, " with payload: ", textutils.serialize(payload))
    local listeners = self.listeners[eventName] or {}
    for _, callback in ipairs(listeners) do
        callback(payload)
    end
end

return EventBus
