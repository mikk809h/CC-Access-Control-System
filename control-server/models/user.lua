---@class UserModel
---@field username string
---@field level string
---@field active boolean
---@field _id string Optional: included in runtime, required by ModelInstance

local Model = require("core.database.model")
local log   = require("core.log")


---@type Model<UserModel>
local User = Model.define("users", {
    "username", "level", "active"
}, {
    username = function(v) return type(v) == "string" and #v > 0 end,
    level = function(v) return type(v) == "string" and v:match("^L%d+$") end,
    active = function(v) return v == true or v == false end
}, {
    logger = function(msg, ...)
        -- log.info("User Model:", msg, ...)
    end
})

return User
