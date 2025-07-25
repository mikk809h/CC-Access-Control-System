local Model = require("core.database.model")

local function assertEqual(a, b, msg)
    if a ~= b then
        error(msg or ("Assertion failed: expected " .. tostring(b) .. ", got " .. tostring(a)), 2)
    end
end

local function testModel()
    local testDataPath = "test_data"
    if fs.exists(testDataPath) then fs.delete(testDataPath) end
    fs.makeDir(testDataPath)

    local logs = {}
    local function logger(...)
        table.insert(logs, textutils.serialize({ ... }))
    end

    local User = Model.define("users.json", { "username", "level", "active" }, {
        username = function(v) return type(v) == "string" end,
        level = function(v) return type(v) == "string" end,
        active = function(v) return type(v) == "boolean" end,
    }, {
        dataDir = testDataPath,
        logger = logger
    })

    print("Running test: create valid user")
    local u1, err = User:new({ username = "Alice", level = "L1", active = true })
    assertEqual(err, nil)
    assertEqual(u1.username, "Alice")

    print("Running test: reject invalid user")
    local u2, err2 = User:new({ username = "Bob", level = 1, active = "yes" })
    assertEqual(u2, nil)
    assert(err2:match("Validation failed"))

    print("Running test: find user by _id")
    local found = User:find(u1._id)
    assertEqual(#found, 1)
    assertEqual(found[1].username, "Alice")

    print("Running test: update user instance")
    local ok = u1:update({ level = "L10" })
    assertEqual(ok, true)
    assertEqual(User:find(u1._id)[1].level, "L10")

    print("Running test: class update")
    local count = User:update({ username = "Alice" }, { active = false })
    assertEqual(count, 1)
    assertEqual(User:find(u1._id)[1].active, false)

    print("Running test: delete user by instance")
    local okDel = u1:delete()
    assertEqual(okDel, true)
    assertEqual(#User:find(u1._id), 0)

    print("Running test: persistence")
    local u3 = User:new({ username = "Charlie", level = "L5", active = true })
    local id3 = u3._id
    local UserReloaded = Model.define("users.json", { "username", "level", "active" }, nil, {
        dataDir = testDataPath,
        logger = logger
    })
    local foundAgain = UserReloaded:find(id3)
    assertEqual(#foundAgain, 1)
    assertEqual(foundAgain[1].username, "Charlie")

    term.setTextColor(colors.green)
    print("✅ All model tests passed.")
    sleep(5)
    read()
end

testModel()
