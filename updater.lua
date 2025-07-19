--- Auto updating properties
local AUTHOR = "mikk809h"
local REPO = "airlock-system"

local REMOTE = "https://raw.githubusercontent.com/%s/%s/main/"
local PACKAGE_FILE = "package.json"
local VERSION_FILE = ".local_version"

local function fetch(url)
    local res = http.get(url)
    if not res then error("Failed to fetch: " .. url) end
    local data = res.readAll()
    res.close()
    return data
end

local function getRemotePackage()
    local raw = fetch(REMOTE:format(AUTHOR, REPO) .. PACKAGE_FILE)
    return textutils.unserializeJSON(raw)
end

local function getLocalVersion()
    if fs.exists(VERSION_FILE) then
        local f = fs.open(VERSION_FILE, "r")
        local v = f.readLine()
        f.close()
        return v
    end
    return nil
end

local function setLocalVersion(v)
    local f = fs.open(VERSION_FILE, "w")
    f.writeLine(v)
    f.close()
end

local function updateFiles(files)
    for _, file in ipairs(files) do
        print("Updating: " .. file)
        local content = fetch(REMOTE:format(AUTHOR, REPO) .. file)
        fs.makeDir(fs.getDir(file))
        local f = fs.open(file, "w")
        f.write(content)
        f.close()
    end
end

-- === Main ===
local ok, pkg = pcall(getRemotePackage)
if not ok then
    print("Could not load package.json:", pkg)
    return
end

local current = getLocalVersion()
if current == pkg.version then
    print("Up-to-date: v" .. current)
    return
end

print("Updating to v" .. pkg.version .. "...")
updateFiles(pkg.files)
setLocalVersion(pkg.version)
print("Update complete.")
