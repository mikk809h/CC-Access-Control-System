---@class Model
local Model = {}

-- === TYPE DEFINITIONS ===
---@generic T
---@alias Partial table<string, any>

---@alias Validator fun(value:any):boolean

---@generic T
---@class ModelInstance<T>
---@field update fun(self: ModelInstance<T>, changes:Partial<T>): boolean
---@field delete fun(self: ModelInstance<T>): boolean
---@field __tostring fun(self: ModelInstance<T>): string
---@field [string]: any

---@generic T
---@class ModelClass<T>
---@field new fun(self: ModelClass<T>, values: T): ModelInstance<T>
---@field find fun(self: ModelClass<T>, filter: string | Partial<T>): ModelInstance<T>[]
---@field update fun(self: ModelClass<T>, filter: string | Partial<T>, updates: Partial<T>): integer
---@field delete fun(self: ModelClass<T>, filter: string | Partial<T>): integer
---@field _validate fun(self: ModelClass<T>, obj: Partial<T>): nil
---@field _append fun(self: ModelClass<T>, obj: T): nil
---@field _save fun(self: ModelClass<T>): nil
---@field load fun(self: ModelClass<T>): nil

---@class ModelConfig
---@field logger fun(...: any) | nil A logging function, like `print`. Optional.
---@field onCreate fun(instance: table) | nil Hook called after creating a new instance.
---@field onUpdate fun(instance: table) | nil Hook called after updating an instance.
---@field onDelete fun(instance: table) | nil Hook called after deleting an instance.


-- Splits a string on "|" characters
---@param line string
---@return string[]
local function splitLine(line)
    local parts = {}
    for part in string.gmatch(line, "([^|]+)") do
        table.insert(parts, part)
    end
    return parts
end

---Defines a model dynamically
---@generic T
---@param path string -- The file path to store the model data
---@param key string -- The unique key field for the model
---@param fields string[] -- The fields of the model
---@param validators table<string, Validator>|nil -- Optional validators for each field
---@param config? ModelConfig -- Optional configuration for the model
---@return ModelClass<T>
function Model.define(path, key, fields, validators, config)
    config = config or {}

    -- Logger function, can be customized or disabled
    local logger = config.logger or function(...) end

    -- Example hooks from config
    local onCreate = config.onCreate
    local onUpdate = config.onUpdate
    local onDelete = config.onDelete

    validators = validators or {}

    -- === INTERNAL DATA ===
    local data = {} ---@type T[]
    local indexMap = {} ---@type table<string, integer>

    -- === INSTANCE METHODS ===
    local instanceMethods = {} ---@type ModelInstance<T>

    -- === MODEL CLASS ===
    local class = {} ---@type ModelClass<T>

    ---Updates the current instance with new values
    ---@param self ModelInstance<T>
    ---@param changes Partial<T>
    ---@return boolean
    ---@example
    ---user:update({ level = "L30" })
    function instanceMethods:update(changes)
        logger("Instance update called for key:", self[key], "with changes:", changes)
        local result = class:update(self[key], changes) > 0
        if result and onUpdate then
            onUpdate(self)
            logger("onUpdate hook called for instance with key:", self[key])
        end
        return result
    end

    ---Deletes the current instance
    ---@param self ModelInstance<T>
    ---@return boolean
    ---@example
    ---user:delete()
    function instanceMethods:delete()
        logger("Instance delete called for key:", self[key])
        local result = class:delete(self[key]) > 0
        if result and onDelete then
            onDelete(self)
            logger("onDelete hook called for instance with key:", self[key])
        end
        return result
    end

    ---@param self ModelInstance<T>
    ---@return string
    function instanceMethods:__tostring()
        local values = {}
        for _, f in ipairs(fields) do
            table.insert(values, tostring(self[f]))
        end
        return string.format("<%s: %s>", key, table.concat(values, ", "))
    end

    ---Validates a value table against validators
    ---@param self ModelClass<T>
    ---@param obj T
    ---@return nil
    function class:_validate(obj)
        logger("Validating object for model at path:", path)
        for _, field in ipairs(fields) do
            local val = obj[field]
            local validate = validators[field]
            if validate and not validate(val) then
                logger("Validation failed for field:", field, "value:", val)
                error(string.format("Validation failed for field '%s': %s", field, tostring(val)))
            end
        end
        logger("Validation successful")
    end

    ---Appends a single object to the file
    ---@param self ModelClass<T>
    ---@param obj T
    ---@return nil
    function class:_append(obj)
        logger("Appending new object to file:", path)
        local f = fs.open(path, "a")
        local line = {}
        for _, field in ipairs(fields) do
            table.insert(line, tostring(obj[field]))
        end
        f.writeLine(table.concat(line, "|"))
        f.close()
        logger("Append complete")
    end

    ---Saves the entire dataset to the file
    ---@param self ModelClass<T>
    ---@return nil
    function class:_save()
        logger("Saving all data to file:", path)
        local f = fs.open(path, "w")
        for _, obj in ipairs(data) do
            local line = {}
            for _, field in ipairs(fields) do
                table.insert(line, tostring(obj[field]))
            end
            f.writeLine(table.concat(line, "|"))
        end
        f.close()
        logger("Save complete")
    end

    ---Creates a new instance of the model
    ---@param self ModelClass<T>
    ---@param values T
    ---@return ModelInstance<T>
    ---@example
    ---User:new({ username = "Alice", level = "L10", active = true })
    function class:new(values)
        logger("Creating new instance with values:", values)
        assert(type(values) == "table", "Expected table to create new instance")
        self:_validate(values)

        local id = values[key]
        if indexMap[id] then
            error("Duplicate " .. key .. ": " .. tostring(id))
        end

        table.insert(data, values)
        indexMap[id] = #data

        local obj = setmetatable(values, { __index = instanceMethods })
        self:_append(obj)

        if onCreate then
            onCreate(obj)
            logger("onCreate hook called for instance with key:", id)
        end
        logger("Instance created with key:", id)
        return obj
    end

    ---Finds one or more instances
    ---@param self ModelClass<T>
    ---@param filter string | Partial<T>
    ---@return ModelInstance<T>[]
    ---@example
    ---User:find("Alice")
    ---User:find({ level = "L20" })
    function class:find(filter)
        logger("Finding instances with filter:", filter)
        local results = {}
        for _, obj in ipairs(data) do
            local match = true
            if type(filter) == "string" then
                match = obj[key] == filter
            elseif type(filter) == "table" then
                for k, v in pairs(filter) do
                    if obj[k] ~= v then
                        match = false
                        break
                    end
                end
            end
            if match then
                table.insert(results, setmetatable(obj, { __index = instanceMethods }))
            end
        end
        logger("Found", #results, "matching instances")
        return results
    end

    ---Updates matching records
    ---@param self ModelClass<T>
    ---@param filter string | Partial<T>
    ---@param updates Partial<T>
    ---@return integer
    ---@example
    ---User:update("Alice", { level = "L40" })
    ---User:update({ active = true }, { level = "L50" })
    function class:update(filter, updates)
        logger("Updating instances with filter:", filter, "and updates:", updates)
        self:_validate(updates)
        local count = 0
        local matches = self:find(filter)
        for _, obj in ipairs(matches) do
            for k, v in pairs(updates) do
                if k == key then
                    logger("Updating uniquekey field from", obj[key], "to", v)
                    indexMap[v] = indexMap[obj[key]]
                    indexMap[obj[key]] = nil
                    obj[key] = v
                else
                    obj[k] = v
                end
            end
            count = count + 1
            if onUpdate then
                onUpdate(obj)
                logger("onUpdate hook called for instance with key:", obj[key])
            end
        end

        if count > 0 then
            self:_save()
            logger("Updated", count, "instances")
        else
            logger("No instances updated")
        end
        return count
    end

    ---Deletes matching records
    ---@param self ModelClass<T>
    ---@param filter string | Partial<T>
    ---@return integer
    ---@example
    ---User:delete("Alice")
    ---User:delete({ level = "L50" })
    function class:delete(filter)
        logger("Deleting instances with filter:", filter)
        local count = 0
        for i = #data, 1, -1 do
            local obj = data[i]
            local match = false
            if type(filter) == "string" then
                match = obj[key] == filter
            elseif type(filter) == "table" then
                match = true
                for k, v in pairs(filter) do
                    if obj[k] ~= v then
                        match = false
                        break
                    end
                end
            end
            if match then
                logger("Deleting instance with key:", obj[key])
                indexMap[obj[key]] = nil
                table.remove(data, i)
                count = count + 1
                if onDelete then
                    onDelete(obj)
                    logger("onDelete hook called for instance with key:", obj[key])
                end
            end
        end
        if count > 0 then
            self:_save()
            logger("Deleted", count, "instances")
        else
            logger("No instances deleted")
        end
        return count
    end

    ---Loads all records from the file into memory
    ---@param self ModelClass<T>
    ---@return nil
    ---@example
    ---User:load()
    function class:load()
        logger("Loading data from file:", path)
        if not fs.exists(path) then return end
        local f = fs.open(path, "r")
        local i = 0
        while true do
            local line = f.readLine()
            if not line then break end
            local parts = splitLine(line)
            if #parts == #fields then
                local obj = {}
                for j, field in ipairs(fields) do
                    local val = parts[j]
                    if val == "true" then val = true end
                    if val == "false" then val = false end
                    obj[field] = val
                end
                i = i + 1
                table.insert(data, obj)
                indexMap[obj[key]] = i
            else
                logger("Line skipped due to incorrect field count:", line)
            end
        end
        f.close()
        logger("Loaded", i, "records from file")
    end

    -- Load existing records at init
    class:load()

    return class
end

return Model
