local args = { ... }

--=== CONFIG ===--
local installDir = "/.install-cache"
local repoBranch = "main"
local repoURL = "https://raw.githubusercontent.com/mikk809h/CC-Access-Control-System/" .. repoBranch .. "/"
local manifestURL = repoURL .. "install_manifest.json"
local localManifestPath = installDir .. "/install_manifest.json"

--=== UTILS ===--
local function color(c) term.setTextColor(c) end
local function info(msg)
    color(colors.lightBlue)
    print("[i] " .. msg)
    color(colors.white)
end
local function ok(msg)
    color(colors.lime)
    print("[+] " .. msg)
    color(colors.white)
end
local function fail(msg)
    color(colors.red)
    print("[x] " .. msg)
    color(colors.white)
end
local function warn(msg)
    color(colors.orange)
    print("[!] " .. msg)
    color(colors.white)
end

local function fetch(url)
    local res = http.get(url)
    if not res then return nil end
    local body = res.readAll()
    res.close()
    return body
end

local function fetchJSON(url)
    local raw = fetch(url)
    return raw and textutils.unserializeJSON(raw) or nil
end

local function writeFile(path, content)
    fs.makeDir(fs.getDir(path))
    local f = fs.open(path, "w")
    f.write(content)
    f.close()
end

local function readLocalManifest()
    if not fs.exists(localManifestPath) then return nil end
    local f = fs.open(localManifestPath, "r")
    local content = f.readAll()
    f.close()
    return textutils.unserializeJSON(content)
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
    for _, t in ipairs(targets) do visit(t) end
    return ordered
end

local function downloadComponent(name, files)
    color(colors.yellow)
    print("Installing component: " .. name)
    color(colors.white)
    for _, file in ipairs(files) do
        local content = fetch(repoURL .. file)
        if content then
            writeFile(shell.resolve(file), content)
            ok(file)
        else
            fail(file)
        end
    end
end

local function printHelp()
    print("Usage: install [components]")
    print("  - If none: updates current install")
    print("  - -help: show this help")
end

--=== MAIN ===--
if #args == 1 and args[1] == "-help" then
    printHelp()
    return
end

fs.makeDir(installDir)
local remote = fetchJSON(manifestURL)
if not remote then
    fail("Manifest fetch failed")
    return
end

local localManifest = readLocalManifest()
local toInstall = {}

if #args > 0 then
    for _, name in ipairs(args) do
        if remote.files[name] then
            table.insert(toInstall, name)
        else
            warn("Unknown: " .. name)
        end
    end
else
    if not localManifest then
        warn("No local manifest found.")
        printHelp()
        return
    end
    for name in pairs(localManifest.files) do
        if remote.files[name] then
            table.insert(toInstall, name)
        end
    end
end

if #toInstall == 0 then
    warn("Nothing to install.")
    return
end

local fullList = resolveDependencies(remote, toInstall)
for _, name in ipairs(fullList) do
    downloadComponent(name, remote.files[name])
end

writeFile(localManifestPath, textutils.serializeJSON(remote))
color(colors.lime)
print("Done.")
color(colors.white)
