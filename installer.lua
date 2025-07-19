local http = require("http")
local fs = require("fs")
local shell = require("shell")
local args = { ... }

--=== CONFIGURATION ===--
local install_dir = "/.install-cache"
local repo_branch = "main"
local repo_path = "https://raw.githubusercontent.com/mikk809h/CC-Access-Control-System/" .. repo_branch .. "/"
local manifest_url = repo_path .. "install_manifest.json"
local local_manifest_path = install_dir .. "/install_manifest.json"

--=== UTILS ===--

local function printHelp()
    print([[
Usage:
  install.lua [-help] [component1 component2 ...]

  - If no components given: updates already installed components.
  - If components are given: installs or updates them.
  - install.lua -help         Show this help message.
]])
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
    if not raw then return nil end
    return textutils.unserializeJSON(raw)
end

local function writeFile(path, content)
    fs.makeDir(fs.getDir(path))
    local h = fs.open(path, "w")
    h.write(content)
    h.close()
end

local function readLocalManifest()
    if not fs.exists(local_manifest_path) then return nil end
    local f = fs.open(local_manifest_path, "r")
    local content = f.readAll()
    f.close()
    return textutils.unserializeJSON(content)
end

local function downloadAndInstallComponent(name, files)
    print("Installing: " .. name)
    for _, file in ipairs(files) do
        local url = repo_path .. file
        local content = fetch(url)
        if content then
            local dest = shell.resolve(file)
            writeFile(dest, content)
            print("  ✓ " .. file)
        else
            print("  ✗ Failed to fetch: " .. file)
        end
    end
end

--=== MAIN LOGIC ===--

if #args == 1 and args[1] == "-help" then
    printHelp()
    return
end

-- Ensure install dir exists
fs.makeDir(install_dir)

-- Load new manifest
local remote_manifest = fetchJSON(manifest_url)
if not remote_manifest then
    print("✗ Failed to fetch manifest.")
    return
end

-- Load old manifest if any
local existing_manifest = readLocalManifest()
local to_install = {}

-- If args given, install those
if #args > 0 then
    for _, comp in ipairs(args) do
        if remote_manifest.files[comp] then
            table.insert(to_install, comp)
        else
            print("! Unknown component: " .. comp)
        end
    end
else
    -- No args: update everything already installed
    if existing_manifest then
        for comp in pairs(existing_manifest.files) do
            if remote_manifest.files[comp] then
                table.insert(to_install, comp)
            end
        end
    else
        print("✗ No components previously installed. Specify which to install.")
        printHelp()
        return
    end
end

-- Download components
for _, comp in ipairs(to_install) do
    downloadAndInstallComponent(comp, remote_manifest.files[comp])
end

-- Save manifest for future diffing
writeFile(local_manifest_path, textutils.serializeJSON(remote_manifest))

print("\n✓ Installation complete.")
