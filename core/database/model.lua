-- ========================================
--            TYPE DEFINITIONS
-- ========================================
---@generic T

---@alias Partial table<string, any>
---@alias Validator fun(value: any): boolean


---@class Document<T>
---@field update fun(self: Document<T>, changes: Partial<T>): boolean
---@field delete fun(self: Document<T>): boolean
---@field __tostring fun(self: Document<T>): string
---@field _id string
---@field [string]: any

---@class Model<T>
---@field new fun(self: Model<T>, values: T): Document<T> | nil, string?
---@field find fun(self: Model<T>, filter: string | Partial<T>): Document<T>[]
---@field update fun(self: Model<T>, filter: string | Partial<T>, updates: Partial<T>): integer, string?
---@field delete fun(self: Model<T>, filter: string | Partial<T>): integer
---@field _validate fun(self: Model<T>, obj: Partial<T>): boolean, string?
---@field _append fun(self: Model<T>): nil
---@field _save fun(self: Model<T>): nil
---@field _events table<string, fun(doc: Document<T>)>
---@field on fun(self: Model<T>, event: string, handler: fun(doc: Document<T>)): nil
---@field _emit fun(self: Model<T>, event: string, doc: Document<T>): nil
---@field load fun(self: Model<T>): nil


---@class ModelConfig
---@field dataDir string?
---@field logger fun(...: any)?
---@field onCreate fun(instance: table)?
---@field onUpdate fun(instance: table)?
---@field onDelete fun(instance: table)?



---@class Model<T>
local Model = {}
-- ========================================
--              MAIN FACTORY
-- ========================================
local createInstanceMethods = require("core.database.instance_methods")


---@generic T
---@param path string
---@param fields string[]
---@param validators? table<string, Validator>
---@param config? ModelConfig
---@return Model<T>
function Model.define(path, fields, validators, config)
    config = config or {}
    validators = validators or {}


    -- Logger function, can be customized or disabled
    local logger = config.logger or function(...) end

    -- Example hooks from config
    local onCreate = config.onCreate
    local onUpdate = config.onUpdate
    local onDelete = config.onDelete

    -- === INTERNAL DATA ===
    ---@type number
    local cached_id = 1000 -- Starting ID for new records
    ---@generic T
    ---@type T[]
    local data = {}

    -- === MODEL CLASS ===
    ---@generic T
    ---@type Model<T>
    local class = {}

    class._events = {} -- Event listeners for the model

    -- === INSTANCE METHODS ===
    ---@generic T
    ---@type Document<T>
    local instanceMethods = createInstanceMethods(class, logger, onUpdate, onDelete)



    -- ========================================
    --             HELPER FUNCTIONS
    -- ========================================
    --#region Helper Functions
    local function isDuplicate(_id)
        for _, obj in ipairs(data) do
            if obj._id == tostring(_id) then
                return true
            end
        end
        return false
    end

    local function open(path, mode, dataset)
        local data_path = fs.combine(config.dataDir or "data", path)
        local m = {
            ["r"] = function()
                if not fs.exists(data_path) then return end
                local f = fs.open(data_path, "r")
                if not f then
                    logger("Failed to open file for reading:", data_path)
                    return false
                end
                local read_file = f.readAll()
                local output = nil
                if read_file then
                    output = textutils.unserialiseJSON(read_file)
                end

                f.close()
                return output
            end,
            ["w"] = function()
                local f = fs.open(data_path, "w")
                if not f then
                    logger("Failed to open file for writing:", data_path)
                    return false
                end
                f.write(textutils.serializeJSON(dataset))
                f.close()
                return true
            end,
        }
        return m[mode]()
    end

    local function matchOperator(value, operatorTable)
        if type(value) ~= "number" then
            return false
        end
        for op, expected in pairs(operatorTable) do
            if op == "$eq" and value ~= expected then return false end
            if op == "$ne" and value == expected then return false end
            if op == "$lt" and not (value < expected) then return false end
            if op == "$lte" and not (value <= expected) then return false end
            if op == "$gt" and not (value > expected) then return false end
            if op == "$gte" and not (value >= expected) then return false end
            -- Extendable: add $in, $regex, etc.
            -- add $and, $or
        end
        return true
    end
    local function resolveDotPath(obj, path)
        local curr = obj
        for key in string.gmatch(path, "[^%.]+") do
            if type(curr) ~= "table" then return nil end
            curr = curr[key]
        end
        return curr
    end

    local function matchFilter(obj, filter)
        for key, expected in pairs(filter) do
            local actual
            if type(key) == "string" and key:find("%.") then
                actual = resolveDotPath(obj, key)
            else
                actual = obj[key]
            end

            if type(expected) == "table" and next(expected) and type(next(expected)) == "string" and next(expected):sub(1, 1) == "$" then
                if not matchOperator(actual, expected) then
                    return false
                end
            elseif actual ~= expected then
                return false
            end
        end
        return true
    end

    --#endregion

    -- ========================================
    --             MODEL METHODS
    -- ========================================
    --#region Model Methods


    ---Subscribe to an event
    ---@param self Model<T>
    ---@param event string
    ---@param handler fun(doc: Document<T>)
    function class:on(event, handler)
        self._events = self._events or {}
        self._events[event] = self._events[event] or {}
        table.insert(self._events[event], handler)
    end

    ---Emit an event
    ---@param self Model<T>
    ---@param event string
    ---@param doc Document<T>
    function class:_emit(event, doc)
        local listeners = self._events and self._events[event]
        if listeners then
            for _, fn in ipairs(listeners) do
                pcall(fn, doc) -- Use pcall to isolate errors
            end
        end
    end

    ---Validates a value table against validators
    ---@generic T
    ---@param self Model<T>
    ---@param obj Partial<T>
    ---@return boolean
    ---@return string? err
    function class:_validate(obj)
        for field, value in pairs(obj) do
            local validate = validators[field]
            if validate and not validate(value) then
                logger("  Validation failed for field:", field, "value:", value)
                return false,
                    string.format("Validation failed for field '%s': %s", field, tostring(value), debug.traceback("", 2))
            end
        end
        logger("Validation successful")
        return true
    end

    ---Appends a single object to the file
    ---@generic T
    ---@param self Model<T>
    ---@return nil
    function class:_append()
        open(path, "w", data)
    end

    ---Saves the entire dataset to the file
    ---@generic T
    ---@param self Model<T>
    ---@return nil
    function class:_save()
        logger("Saving all data to file:", path, textutils.serialize(data))
        open(path, "w", data)
        logger("Save complete")
    end

    function class:new(values)
        assert(type(values) == "table", "Expected table to create new instance")
        local valid, valid_err = self:_validate(values)
        if not valid then
            logger("Validation failed for values:", valid_err)
            return nil, valid_err
        end

        local _id = cached_id + 1
        if isDuplicate(_id) then
            logger("Duplicate _id found:", _id)
            return nil, "Duplicate _id found: " .. tostring(_id)
        end
        cached_id = _id
        values._id = tostring(_id) -- Ensure _id is a string
        logger("Creating new document with values:", values)

        table.insert(data, values)

        local obj = setmetatable(values, { __index = instanceMethods })
        self:_append()

        self:_emit("create", obj)
        if onCreate then
            onCreate(obj)
            logger("onCreate hook called for instance with _id:", _id)
        end
        logger("Document created with _id:", _id)
        return obj, nil
    end

    ---Finds one or more instances
    ---@param self Model<T>
    ---@param filter string | Partial<T>
    ---@return Document<T>[]
    ---@example
    ---User:find("Alice")
    ---User:find({ level = "L20" })
    ---User:find({ lastPing = { ["$lt"] = os.clock() - 60 }, online = true })
    function class:find(filter)
        logger("Finding instances with filter:", filter)
        local results = {}

        for _, obj in ipairs(data) do
            local match = false

            if not filter then
                match = true
            else
                if type(filter) == "string" then
                    match = obj._id == filter
                elseif type(filter) == "table" then
                    match = matchFilter(obj, filter)
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
    ---@param self Model<T>
    ---@param filter string | Partial<T>
    ---@param updates Partial<T>
    ---@return integer, string? err
    ---@example
    ---User:update("Alice", { level = "L40" })
    ---User:update({ active = true }, { level = "L50" })
    ---User:update({ lastPing = { ["$lt"] = os.clock() - 60 }, online = true }, { online = false })
    function class:update(filter, updates)
        local valid, valid_err = self:_validate(updates)
        if not valid then
            logger("Validation failed for values:", valid_err)
            return nil, valid_err
        end
        logger("Updating instances with filter:", filter, "and updates:", updates)
        local count = 0
        local matches = self:find(filter)
        for _, obj in ipairs(matches) do
            for k, v in pairs(updates) do
                if k == "_id" then
                    logger("Updating uniquekey field from", obj._id, "to", v)
                    obj._id = v
                else
                    obj[k] = v
                end
            end
            count = count + 1
            self:_emit("update", obj)
            if onUpdate then
                onUpdate(obj)
                logger("onUpdate hook called for instance with _id:", obj._id)
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
    ---@param self Model<T>
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
                match = obj._id == filter
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
                logger("Deleting instance with _id:", obj._id)
                table.remove(data, i)
                count = count + 1
                self:_emit("delete", obj)
                if onDelete then
                    onDelete(obj)
                    logger("onDelete hook called for instance with _id:", obj._id)
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

    --#endregion


    --#region Loading
    ---Loads all records from the file into memory
    ---@param self Model<T>
    ---@return nil
    ---@example
    ---User:load()
    function class:load()
        logger("Loading data from file:", path)
        if not fs.exists(fs.combine(config.dataDir or "data", path)) then
            logger("File does not exist, skipping load")
            return
        end
        local loaded_data = open(path, "r")
        if not loaded_data then
            logger("Failed to load data from file:", path)
            return
        end
        local i = 0
        for _, obj in ipairs(loaded_data) do
            local idnumber = tonumber(obj._id)
            if idnumber ~= nil then
                if idnumber > cached_id then
                    cached_id = idnumber
                end
            else
                logger("Invalid _id found in data, skipping:", obj._id)
            end
        end
        logger("Indexed last _id as:", cached_id)
        data = loaded_data or {}
    end

    --#endregion
    -- Load existing records at init
    class:load()

    return class
end

return Model
