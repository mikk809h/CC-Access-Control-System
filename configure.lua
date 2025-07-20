for _, component in ipairs({ "airlock", "control-server" }) do
    if fs.exists(component .. "/configure.lua") then
        local cmp = require(component .. ".configure")
        if cmp and type(cmp) == "table" then
            local _, _, launch = { cmp.configure() }

            if launch then
                shell.run(component .. "/startup.lua")
                return
            end
        end
    end
end
