-- Loader for newrivals2.lua
-- Paste this one line into your executor autoexec:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/zaisaawe21/rivals-scripts/main/loader.lua"))()
local scriptUrl = "https://raw.githubusercontent.com/zaisaawe21/rivals-scripts/main/newrivals2.lua"
local success, err = pcall(function() loadstring(game:HttpGet(scriptUrl))() end)
if not success then warn("[rivals-loader] Failed: " .. tostring(err)) end
