local installer = {}
local installDir = "/.install-cache"
local repoBranch = "main"
local repoBase = "https://raw.githubusercontent.com/mikk809h/CC-Access-Control-System/" .. repoBranch .. "/"
local manifestURL = repoBase .. "install_manifest.json?v=1"
local localManifestPath = installDir .. "/install_manifest.json"

--==[ Logging ]==--
local function log(color, prefix, msg)
    term.setTextColor(color)
    print(prefix .. " " .. msg)
    term.setTextColor(colors.white)
end

local debug = function(msg) log(colors.gray, "[d]", msg) end
local info = function(msg) log(colors.lightBlue, "[i]", msg) end
local warn = function(msg) log(colors.orange, "[!]", msg) end
local error = function(msg) log(colors.red, "[x]", msg) end

--==[ Networking ]==--
local function fetch(url)
    local res = http.get(url)
    if not res then return nil, "Failed to fetch " .. url end
    local data = res.readAll()
    res.close()
    return data
end

local function fetchJSON(url)
    local raw, err = fetch(url)
    if not raw then return nil, err end
    local ok, data = pcall(textutils.unserializeJSON, raw)
    if not ok then return nil, "Failed to parse JSON from " .. url end
    return data
end

--==[ Filesystem ]==--
local function writeFile(path, content)
    fs.makeDir(fs.getDir(path))
    local f = fs.open(path, "w")
    if not f then return false, "Failed to open file " .. path end
    f.write(content)
    f.close()
    return true
end

local function readLocalManifest()
    if not fs.exists(localManifestPath) then return nil end
    local f = fs.open(localManifestPath, "r")
    if not f then return nil end
    local content = f.readAll()
    f.close()
    local ok, data = pcall(textutils.unserializeJSON, content)
    if not ok then
        warn("Local manifest corrupted or invalid JSON")
        return nil
    end
    return data
end

--==[ Installer Logic ]==--
local function printHelp()
    print("Usage: install [components]")
    print("  -update [<component>] : update installed components")
    print("  -help                 : show this help")
    print("Components:")
    print("   airlock")
    print("   control-server")
end

local function resolveDependencies(manifest, targets)
    local seen, ordered = {}, {}
    local function visit(name)
        if seen[name] then return end
        seen[name] = true
        for _, dep in ipairs(manifest.depends[name] or {}) do
            visit(dep)
        end
        table.insert(ordered, name)
    end
    for _, name in ipairs(targets) do visit(name) end
    return ordered
end

local function downloadComponent(name, files)
    debug("Installing component: " .. name)
    for _, file in ipairs(files) do
        local content, err = fetch(repoBase .. file)
        if content then
            local ok, writeErr = writeFile(shell.resolve(file), content)
            if ok then
                info("  - " .. file)
            else
                error("  - Write failed: " .. writeErr)
            end
        else
            error("  -  Fetch failed: " .. err)
        end
    end
end

local function shouldUpdateComponent(localManifest, remoteManifest, name)
    info("Checking " .. name)
    if not localManifest or not localManifest.versions then
        info("No local manifest or versions found, updating")
        return true
    end

    local localVer = localManifest.versions[name]
    local remoteVer = remoteManifest.versions[name]
    if localVer ~= remoteVer then
        info("Component '" ..
            name .. "' needs update (local: " .. tostring(localVer) .. ", remote: " .. tostring(remoteVer) .. ")")
    else
        info("Component '" ..
            name .. "' is up to date (local: " .. tostring(localVer) .. ", remote: " .. tostring(remoteVer) .. ")")
    end
    return localVer ~= remoteVer
end

function installer.install(component)
    if not component then
        error("No component(s) specified for installation.")
        return false
    end

    local components = {}

    if type(component) == "string" then
        components = { component }
    elseif type(component) == "table" then
        components = component
    else
        error("Invalid component type passed to install()")
        return false
    end

    local remoteManifest, err = fetchJSON(manifestURL)
    if not remoteManifest then
        error("Failed to fetch remote manifest: " .. (err or "unknown error"))
        return false
    end

    local targets = components
    local fullList = resolveDependencies(remoteManifest, targets)

    fs.makeDir(installDir)

    for _, name in ipairs(fullList) do
        local files = remoteManifest.files[name]
        if files then
            downloadComponent(name, files)
        else
            warn("No files found for component: " .. name)
        end
    end
    local localManifest = readLocalManifest() or { versions = {} }

    -- Add only installed components and their versions
    for _, name in ipairs(fullList) do
        if remoteManifest.versions and remoteManifest.versions[name] then
            localManifest.versions[name] = remoteManifest.versions[name]
        end
    end

    writeFile(localManifestPath, textutils.serializeJSON(localManifest))
    info("Installation complete for component '" .. component .. "'")
    return true
end

function installer.update(component)
    local remoteManifest, err = fetchJSON(manifestURL)
    if not remoteManifest then
        error("Failed to fetch remote manifest: " .. (err or "unknown error"))
        return false
    end

    local localManifest = readLocalManifest()
    fs.makeDir(installDir)
    local targets = {}

    if component == nil then
        -- Update all
        for name in pairs(remoteManifest.files) do
            table.insert(targets, name)
        end
    elseif type(component) == "string" then
        targets = { component }
    elseif type(component) == "table" then
        targets = component
    else
        warn("Invalid component filter passed to update()")
        return false
    end

    local fullList = resolveDependencies(remoteManifest, targets)

    for _, name in ipairs(fullList) do
        if shouldUpdateComponent(localManifest, remoteManifest, name) then
            local files = remoteManifest.files[name]
            if files then
                downloadComponent(name, files)
            else
                warn("No files found for component: " .. name)
            end
        else
            info("Component '" .. name .. "' is up to date.")
        end
    end
    local updatedManifest = readLocalManifest() or { versions = {} }

    for _, name in ipairs(fullList) do
        local localVer = updatedManifest.versions[name]
        local remoteVer = remoteManifest.versions[name]
        if localVer ~= remoteVer then
            updatedManifest.versions[name] = remoteVer
        end
    end

    writeFile(localManifestPath, textutils.serializeJSON(updatedManifest))
    info("Update complete.")
    return true
end

function installer.hasUpdates(component)
    local localManifest = readLocalManifest()
    if not localManifest then return true end

    local remoteManifest, err = fetchJSON(manifestURL)
    if not remoteManifest then
        warn("Failed to fetch remote manifest: " .. (err or "unknown error"))
        return false
    end

    local componentsToCheck = {}
    if not component then
        -- Only check components listed in the local manifest
        if not localManifest.versions then
            info("No installed components found.")
            return false
        end
        for name in pairs(localManifest.versions) do
            table.insert(componentsToCheck, name)
        end
    elseif type(component) == "string" then
        componentsToCheck = { component }
    elseif type(component) == "table" then
        componentsToCheck = component
    else
        warn("Invalid component filter passed to hasUpdates")
        return false
    end

    local outdated = {}

    for _, name in ipairs(componentsToCheck) do
        if shouldUpdateComponent(localManifest, remoteManifest, name) then
            table.insert(outdated, name)
        end
    end

    return #outdated > 0, outdated
end

function installer.run(args)
    args = args or {}

    if #args == 0 then
        error("No arguments provided.")
        printHelp()
        return false
    end

    local cmd = args[1]
    if cmd == "-help" then
        printHelp()
        return false
    elseif cmd == "-update" then
        local component = args[2]
        if not installer.hasUpdates(component) then
            print("No updates available.")
            return false
        end
        if not installer.update(component) then
            print("Failed to install updates.")
            return false
        end
        print("Updates installed successfully.")
        return true
    else
        return installer.install(cmd)
    end
end

--==[ Entrypoint ]==--
if shell.getRunningProgram() == "installer.lua" then
    local success = installer.run({ ... })
    if success then
        print("Installer completed successfully.")
    else
        print("No updates applied.")
    end
else
    print("Installer module loaded. Use 'installer.update()' to apply updates.")
    return installer
end
