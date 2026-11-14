local BASE = "https://raw.githubusercontent.com/overthcode2011-stack/HHB/refs/heads/main/replicatedscripts/"

local function loadChunk(name)
    local ok, err = pcall(function()
        local src = game:HttpGet(BASE .. name)
        assert(type(src) == "string" and #src > 64, "empty response")
        local fn, compileErr = loadstring(src)
        assert(fn, tostring(compileErr))
        fn()
    end)
    if not ok then
        warn("[HappyHub] " .. name .. " -> " .. tostring(err))
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Happy Hub",
                Text = "Failed: " .. name,
            })
        end)
        return false
    end
    return true
end

if not loadChunk("core.lua") then return end
if not loadChunk("ui.lua") then return end
