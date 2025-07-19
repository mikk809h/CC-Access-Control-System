local args = { ... }

--==============================--
--         CONFIGURATION        --
--==============================--

local INSTALL_DIR = "/.install-cache"
local REPO_BRANCH = "main"
local REPO_PATH = "https://raw.githubusercontent.com/mikk809h/CC-Access-Control-System/" .. REPO_BRANCH .. "/"
local MANIFEST_URL = REPO_PATH .. "install_manifest.json"
local LOCAL_MANIFEST_PATH = INSTALL_DIR .. "/install_manifest.json"

--==============================--
--            UTILS             --
--==============================--

local function printHelp()
    print([[
Usage:
  install.lua [-help] [component1 component2 ...]

  - If no components are given: updates already installed components.
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
    local handle = fs.open(path, "w")
    handle.write(content)
    handle.close()
end

local function readLocalManifest()
    if not fs.exists(LOCAL_MANIFEST_PATH) then return nil end
    local f = fs.open(LOCAL_MANIFEST_PATH, "r")
    local content = f.readAll()
    f.close()
    return textutils.unserializeJSON(content)
end

local function downloadAndInstallComponent(name, fileList)
    print("Installing component: " .. name)
    for _, file in ipairs(fileList) do
        local url = REPO_PATH .. file
        local content = fetch(url)

        if content then
            local dest = shell.resolve(file)
            writeFile(dest, content)
            print("  Installed file: " .. file)
        else
            print("  Failed to download file: " .. file)
        end
    end
end

--==============================--
--         MAIN LOGIC           --
--==============================--

-- Handle -help flag
if #args == 1 and args[1] == "-help" then
    printHelp()
    return
end

-- Ensure install directory exists
fs.makeDir(INSTALL_DIR)

-- Fetch remote manifest
local remoteManifest = fetchJSON(MANIFEST_URL)
if not remoteManifest then
    print("Failed to fetch remote manifest.")
    return
end

-- Load existing local manifest, if any
local localManifest = readLocalManifest()

-- Determine which components to install
local componentsToInstall = {}

if #args > 0 then
    -- Install specified components
    for _, name in ipairs(args) do
        if remoteManifest.files[name] then
            table.insert(componentsToInstall, name)
        else
            print("Unknown component: " .. name)
        end
    end
else
    -- No args: update only components that were previously installed
    if localManifest then
        for name in pairs(localManifest.files) do
            if remoteManifest.files[name] then
                table.insert(componentsToInstall, name)
            end
        end
    else
        print("No components previously installed. Please specify components to install.")
        printHelp()
        return
    end
end

-- Download and install components
for _, name in ipairs(componentsToInstall) do
    downloadAndInstallComponent(name, remoteManifest.files[name])
end

-- Save the new manifest
writeFile(LOCAL_MANIFEST_PATH, textutils.serializeJSON(remoteManifest))

print("Installation complete.")
