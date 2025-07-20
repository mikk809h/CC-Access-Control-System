local Model = require("core.database.model")


local User = Model.define("users.txt", "username", {
    "username", "level", "active"
}, {
    username = function(v) return type(v) == "string" and #v > 0 end,
    level = function(v) return type(v) == "string" and v:match("^L%d+$") end,
    active = function(v) return v == true or v == false end
})

local newUser = User:new({
    username = "newuser",
    level = "L30",
    active = true
})

newUser:update({
    username = "updateduser",
    level = "L40",
    active = false
})

-- print(newUser:__tostring())

newUser:delete()

local newUser_original = User:new({
    username = "newuser",
    level = "L20",
    active = true
})

newUser_original:delete()

-- -- QUERY PATTERN:
-- -- string | table ({ [key]: value }) | nil

-- User.find(QUERY_PATTERN) -- Example usage of find method
-- User.update(QUERY_PATTERN, { key1 = "value1", key2 = "value2" }) -- Example usage of update method
-- User.delete(QUERY_PATTERN) -- Example usage of delete method


return User
