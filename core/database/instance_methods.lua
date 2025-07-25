--
-- === INSTANCE METHODS ===
---@generic T
---@type Document<T>
-- local instanceMethods = createInstanceMethods(class, logger, onUpdate, onDelete)

function createInstanceMethods(class, logger, onUpdate, onDelete)
    ---@class Document<T>
    ---@field _id string
    ---@field update fun(self: Document<T>, changes: table): boolean
    ---@field delete fun(self: Document<T>): boolean
    ---@field __tostring fun(self: Document<T>): string

    local fields = class.fields
    ---@type Document<T>
    local instanceMethods = {}

    function instanceMethods:update(changes)
        logger("Instance update for _id:", self._id)
        local success = class:update(self._id, changes) > 0
        if success and onUpdate then onUpdate(self) end
        return success
    end

    function instanceMethods:delete()
        logger("Instance delete for _id:", self._id)
        local success = class:delete(self._id) > 0
        if success and onDelete then onDelete(self) end
        return success
    end

    function instanceMethods:__tostring()
        local values = {}
        for _, f in ipairs(fields) do
            table.insert(values, tostring(self[f]))
        end
        return string.format("<%s: %s>", self._id, table.concat(values, ", "))
    end

    return instanceMethods
end

return createInstanceMethods
