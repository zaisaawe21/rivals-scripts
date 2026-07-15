-- ============================================================
-- Multi-Game Loader — zaisaawe21/rivals-scripts
-- Select a game, loads the script from GitHub CDN.
-- ============================================================

-- CONFIG — Add new games here:
local GAMES = {
    {
        name = "Rivals Script",
        url = "https://cdn.jsdelivr.net/gh/zaisaawe21/rivals-scripts@main/newrivals2.lua",
        color = Color3.fromRGB(255, 80, 80),
        desc = "Full UI · Skin Changer · Aimbot · ESP · Movement",
    },
    {
        name = "Aba Script",
        url = "https://cdn.jsdelivr.net/gh/zaisaawe21/rivals-scripts@main/aba3.lua",
        color = Color3.fromRGB(80, 180, 255),
        desc = "ABA · Arena · Combat",
    },
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- LOADER GUI
-- ============================================================
local loaderScreen = Instance.new("ScreenGui")
loaderScreen.Name = "MultiLoader"
loaderScreen.ResetOnSpawn = false
loaderScreen.IgnoreGuiInset = true
loaderScreen.Parent = playerGui

-- Background dim
local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
bg.BackgroundTransparency = 0.6
bg.BorderSizePixel = 0
bg.Parent = loaderScreen

-- Main container
local container = Instance.new("Frame")
container.Name = "Container"
container.Size = UDim2.new(0, 420, 0, 380)
container.Position = UDim2.new(0.5, -210, 0.5, -190)
container.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
container.BackgroundTransparency = 0
container.BorderSizePixel = 0
container.Parent = loaderScreen
Instance.new("UICorner", container).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", container).Color = Color3.fromRGB(40, 40, 60)

-- Top bar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 45)
topBar.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
topBar.BorderSizePixel = 0
topBar.Parent = container
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Script Loader"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
closeBtn.BackgroundTransparency = 0
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 20
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = topBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- Scroll frame for game cards
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ScrollFrame"
scrollFrame.Size = UDim2.new(1, 0, 1, -50)
scrollFrame.Position = UDim2.new(0, 0, 0, 50)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, (#GAMES * 85) + 20)
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
scrollFrame.Parent = container

local uiList = Instance.new("UIListLayout")
uiList.Name = "List"
uiList.Padding = UDim.new(0, 10)
uiList.HorizontalAlignment = Enum.HorizontalAlignment.Center
uiList.SortOrder = Enum.SortOrder.LayoutOrder
uiList.Parent = scrollFrame

Instance.new("UIPadding", scrollFrame).PaddingTop = UDim.new(0, 10)

-- ============================================================
-- GAME CARDS
-- ============================================================
local selectedName = nil

local function loadScript(url, cardFrame)
    -- Flash card green to indicate loading
    local success = Instance.new("Frame")
    success.Size = UDim2.new(1, 0, 1, 0)
    success.BackgroundColor3 = Color3.fromRGB(40, 200, 80)
    success.BackgroundTransparency = 0.85
    success.BorderSizePixel = 0
    success.Parent = cardFrame
    Instance.new("UICorner", success).CornerRadius = UDim.new(0, 10)
    
    -- Update status text
    local statusLabel = cardFrame:FindFirstChild("Status")
    if statusLabel then
        statusLabel.Text = "Loading..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
    end
    
    -- Actually load the script
    task.spawn(function()
        local ok, result = pcall(function()
            loadstring(game:HttpGet(url))()
        end)
        if not ok then
            if statusLabel then
                statusLabel.Text = "Error: " .. tostring(result):sub(1, 30)
                statusLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
            end
            warn("[MultiLoader] Failed to load: " .. tostring(result))
        end
    end)
end

for idx, gameData in GAMES do
    local card = Instance.new("Frame")
    card.Name = "Card_" .. idx
    card.Size = UDim2.new(1, -20, 0, 75)
    card.BackgroundColor3 = Color3.fromRGB(24, 24, 38)
    card.BackgroundTransparency = 0
    card.BorderSizePixel = 0
    card.LayoutOrder = idx
    card.Parent = scrollFrame
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
    Instance.new("UIStroke", card).Color = Color3.fromRGB(40, 40, 60)
    
    -- Color accent bar
    local accent = Instance.new("Frame")
    accent.Name = "Accent"
    accent.Size = UDim2.new(0, 4, 1, 0)
    accent.BackgroundColor3 = gameData.color
    accent.BorderSizePixel = 0
    accent.Parent = card
    Instance.new("UICorner", accent).CornerRadius = UDim.new(0, 2)
    
    -- Game name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, -60, 0, 24)
    nameLabel.Position = UDim2.new(0, 16, 0, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = gameData.name
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextSize = 16
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = card
    
    -- Description
    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "Desc"
    descLabel.Size = UDim2.new(1, -60, 0, 18)
    descLabel.Position = UDim2.new(0, 16, 0, 34)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = gameData.desc
    descLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
    descLabel.TextSize = 12
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.Parent = card
    
    -- Status label (hidden until interacted)
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "Status"
    statusLabel.Size = UDim2.new(1, -60, 0, 16)
    statusLabel.Position = UDim2.new(0, 16, 0, 54)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = ""
    statusLabel.TextColor3 = Color3.fromRGB(120, 200, 120)
    statusLabel.TextSize = 10
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = card
    
    -- Load button
    local loadBtn = Instance.new("TextButton")
    loadBtn.Name = "LoadBtn"
    loadBtn.Size = UDim2.new(0, 80, 0, 28)
    loadBtn.Position = UDim2.new(1, -95, 0.5, -14)
    loadBtn.BackgroundColor3 = gameData.color
    loadBtn.Text = "Load"
    loadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    loadBtn.TextSize = 13
    loadBtn.Font = Enum.Font.GothamBold
    loadBtn.BorderSizePixel = 0
    loadBtn.Parent = card
    Instance.new("UICorner", loadBtn).CornerRadius = UDim.new(0, 6)
    
    -- Hover effect
    loadBtn.MouseEnter:Connect(function()
        TweenService:Create(loadBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(
                math.clamp(gameData.color.R * 255 * 0.8, 0, 255),
                math.clamp(gameData.color.G * 255 * 0.8, 0, 255),
                math.clamp(gameData.color.B * 255 * 0.8, 0, 255)
            )
        }):Play()
    end)
    loadBtn.MouseLeave:Connect(function()
        TweenService:Create(loadBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = gameData.color
        }):Play()
    end)
    
    -- Load action
    loadBtn.MouseButton1Click:Connect(function()
        selectedName = gameData.name
        nameLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
        loadScript(gameData.url, card)
    end)
    
    -- Click on entire card also loads
    local cardBtn = Instance.new("TextButton")
    cardBtn.Name = "CardBtn"
    cardBtn.Size = UDim2.new(1, 0, 1, 0)
    cardBtn.BackgroundTransparency = 1
    cardBtn.Text = ""
    cardBtn.Parent = card
    cardBtn.ZIndex = 0
    
    cardBtn.MouseButton1Click:Connect(function()
        selectedName = gameData.name
        nameLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
        loadScript(gameData.url, card)
    end)
end

-- ============================================================
-- CLOSE BUTTON
-- ============================================================
closeBtn.MouseButton1Click:Connect(function()
    loaderScreen:Destroy()
end)

-- Close on Insert key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        loaderScreen:Destroy()
    end
end)

-- ============================================================
-- FADE IN ANIMATION
-- ============================================================
bg.BackgroundTransparency = 1
container.Size = UDim2.new(0, 420, 0, 0)
container.Position = UDim2.new(0.5, -210, 0.5, 0)

TweenService:Create(bg, TweenInfo.new(0.3), {
    BackgroundTransparency = 0.6
}):Play()

TweenService:Create(container, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 420, 0, 380),
    Position = UDim2.new(0.5, -210, 0.5, -190),
}):Play()

return GAMES
