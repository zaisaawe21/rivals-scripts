-- ============================================================
-- pasted Loader — Multi-Game Script Hub
-- github.com/zaisaawe21/rivals-scripts
-- ============================================================

-- LOAD PASTED UI FROM CDN
local uiLoaded, pasted = pcall(function()
    return loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/zaisaawe21/rivals-scripts@main/pasted_ui.lua"))()
end)

if not uiLoaded or not pasted then
    warn("[pasted] Failed to load UI library")
    return
end

-- ============================================================
-- WINDOW
-- ============================================================
local Window = pasted:CreateWindow({
    Name = "pasted",
    LoadingTitle = "pasted Loader",
    LoadingSubtitle = "by zaisaawe21",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "pasted",
        FileName = "pasted_config"
    },
    Discord = {
        Enabled = false,
    },
    KeySystem = false,
    ToggleUIKeybind = Enum.KeyCode.RightShift,
})

-- ============================================================
-- MAIN TAB — GAME SELECTION
-- ============================================================
local MainTab = Window:CreateTab("Games", "list")

MainTab:CreateSection("Select a game to load")

MainTab:CreateButton({
    Name = "Rivals",
    Callback = function()
        pasted:Notify({
            Title = "pasted",
            Content = "Loading Rivals script...",
            Duration = 5,
            Image = "coins",
        })
        loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/zaisaawe21/rivals-scripts@main/newrivals2.lua"))()
    end,
})

MainTab:CreateButton({
    Name = "ABA",
    Callback = function()
        pasted:Notify({
            Title = "pasted",
            Content = "Loading ABA script...",
            Duration = 5,
            Image = "swords",
        })
        loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/zaisaawe21/rivals-scripts@main/aba3.lua"))()
    end,
})

-- ============================================================
-- INFO TAB
-- ============================================================
local InfoTab = Window:CreateTab("Info", "info")

InfoTab:CreateSection("about pasted")

InfoTab:CreateParagraph({
    Title = "pasted Loader",
    Content = "Multi-game script loader for Roblox. Loads scripts directly from CDN — no local files needed. Built on pasted UI framework."
})

InfoTab:CreateParagraph({
    Title = "Games Available",
    Content = "• Rivals — Full UI, Skin Changer, Aimbot, ESP\n• ABA — Arena Combat, Scripts"
})

InfoTab:CreateParagraph({
    Title = "Usage",
    Content = [[Paste this in your executor:
loadstring(game:HttpGet("https://cdn.jsdelivr.net/gh/zaisaawe21/rivals-scripts@main/loader.lua"))()]]
})

InfoTab:CreateParagraph({
    Title = "Updates",
    Content = "Scripts update automatically from GitHub. Push new versions and jsDelivr caches them within minutes."
})

-- ============================================================
-- INIT
-- ============================================================
pasted:Notify({
    Title = "pasted",
    Content = "Ready. Select a game.",
    Duration = 3,
    Image = "check",
})
