pcall(function()
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" and self.Name == "ShootEvent"
           and Aimbot.Enabled and Aimbot.BulletRedirect then
            local args = {...}
            local bullets = args[1]
            if type(bullets) == "table" and #bullets > 0 then
                local tgt = GetAimbotTarget()
                if tgt then
                    local pos, headInst = GetTargetPos(tgt)
                    if pos and headInst then
                        local origin = workspace.CurrentCamera.CFrame.Position
                        for _, b in ipairs(bullets) do
                            if type(b) == "table" then
                                b.Hit = headInst
                                b.Distance = (pos - origin).Magnitude
                                b.RayObject = Ray.new(origin, pos - origin)
                                b.Cframe = CFrame.new(origin, pos)
                            end
                        end
                    end
                end
            end
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
end)
