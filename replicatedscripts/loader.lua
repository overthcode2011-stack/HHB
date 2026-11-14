local BASE = "https://raw.githubusercontent.com/overthcode2011-stack/HHB/refs/heads/main/replicatedscripts/"
local API_URL = "https://raw.githubusercontent.com/overthcode2011-stack/HHB/refs/heads/main/API" 

local function loadChunk(url, name)
    local ok, err = pcall(function()
        local src = game:HttpGet(url)
        assert(type(src) == "string" and #src > 64, "empty response")
        local fn, compileErr = loadstring(src)
        assert(fn, tostring(compileErr))
        fn() -- Ejecuta el script sin importar si retorna algo o no
    end)

    if not ok then
        warn("[HappyHub] " .. name .. " -> " .. tostring(err))
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Happy Hub",
                Text = "Failed: " .. name,
                Duration = 5
            })
        end)
        return false
    end
    return true
end


if not loadChunk(BASE .. "core.lua", "core.lua") then return end


if not loadChunk(API_URL, "API") then return end
