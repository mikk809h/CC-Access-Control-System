for _, component in ipairs({ "airlock", "control-server" }) do
    if fs.exists(component .. "/configure.lua") then
        local _, _, launch = require(component .. ".configure").configure()
        if launch then
            shell.run(component .. "/startup.lua")
            return
        end
    end
end
