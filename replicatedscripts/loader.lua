local ROOT_URL = "https://raw.githubusercontent.com/overthcode2011-stack/HHB/refs/heads/main/"
local SCRIPTS_URL = ROOT_URL .. "replicatedscripts/"

local function loadChunk(url, name)
    local ok, err = pcall(function()
        local src = game:HttpGet(url)
        assert(type(src) == "string" and #src > 64, "empty response")
        local fn, compileErr = loadstring(src)
        assert(fn, tostring(compileErr))
        fn()
    end)

    if not ok then
        warn("[HH] " .. name .. " -> " .. tostring(err))
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

if not loadChunk(ROOT_URL .. "API", "API") then return end
if not loadChunk(SCRIPTS_URL .. "config.lua", "config.lua") then return end
if not loadChunk(SCRIPTS_URL .. "logic.lua", "logic.lua") then return end
if not loadChunk(SCRIPTS_URL .. "ui.lua", "ui.lua") then return end
