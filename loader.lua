-- ============================================================
-- Rivals Scripts Loader — Clean Modern Premium
-- github.com/zaisaawe21/rivals-scripts
-- Press Insert to toggle. Click a card or Load button.
-- ============================================================

local GAMES = {
	{
		name = "Rivals Script",
		icon = "⚔️",
		url = "https://cdn.jsdelivr.net/gh/zaisaawe21/rivals-scripts@main/newrivals2.lua",
		accent = Color3.fromRGB(255, 95, 85),
		desc = "Full-featured Rivals exploit with Skin Changer, Aimbot, ESP, Movement hacks, and more.",
		features = { "Skin Changer", "Aimbot", "ESP", "Movement" },
	},
	{
		name = "ABA Script",
		icon = "🔥",
		url = "https://cdn.jsdelivr.net/gh/zaisaawe21/rivals-scripts@main/aba3.lua",
		accent = Color3.fromRGB(85, 165, 255),
		desc = "Advanced ABA combat script with Zero Stun, Auto Black Flash, Lock-On, Speed Boost, and Anti-Fling.",
		features = { "Zero Stun", "Black Flash", "Lock-On", "Speed" },
	},
}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local HS = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================
-- CONSTANTS
-- ============================================================
local PALETTE = {
	bg = Color3.fromRGB(14, 14, 18),
	surface = Color3.fromRGB(22, 22, 30),
	surfaceHover = Color3.fromRGB(28, 28, 38),
	border = Color3.fromRGB(38, 38, 52),
	borderHover = Color3.fromRGB(55, 55, 75),
	text = Color3.fromRGB(235, 235, 245),
	textDim = Color3.fromRGB(140, 140, 160),
	textMuted = Color3.fromRGB(90, 90, 105),
	red = Color3.fromRGB(245, 80, 80),
	green = Color3.fromRGB(80, 210, 120),
	blue = Color3.fromRGB(90, 155, 245),
}

local TWEEN_FAST = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_SLOW = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_BOUNCE = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- ============================================================
-- HELPERS
-- ============================================================
local function create(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k == "Corner" then
			local c = Instance.new("UICorner", inst)
			c.CornerRadius = UDim.new(0, v)
		elseif k == "Stroke" then
			local s = Instance.new("UIStroke", inst)
			s.Color = v[1]
			s.Thickness = v[2] or 1
			if v[3] then s.Transparency = v[3] end
		else
			inst[k] = v
		end
	end
	return inst
end

local function gradient(parent, color1, color2, rotation)
	local g = Instance.new("UIGradient", parent)
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color1),
		ColorSequenceKeypoint.new(1, color2),
	})
	g.Rotation = rotation or 135
	return g
end

local function tween(inst, props)
	return TS:Create(inst, TWEEN_FAST, props)
end

local function tweenSlow(inst, props)
	return TS:Create(inst, TWEEN_SLOW, props)
end

local function tweenBounce(inst, props)
	return TS:Create(inst, TWEEN_BOUNCE, props)
end

-- ============================================================
-- BUILD GUI ROOT
-- ============================================================
local root = Instance.new("ScreenGui")
root.Name = "RivalsLoader"
root.ResetOnSpawn = false
root.IgnoreGuiInset = true
root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
root.Parent = playerGui

-- Dimmed overlay
local overlay = create("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Parent = root,
})

-- Subtle dot grid background (single-pixel dots to add texture)
local dotGrid = create("ImageLabel", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Image = "rbxassetid://8992230677", -- subtle noise texture
	ImageTransparency = 0.94,
	ScaleType = Enum.ScaleType.Tile,
	TileSize = UDim2.new(0, 64, 0, 64),
	Parent = root,
})

-- ============================================================
-- MAIN WINDOW
-- ============================================================
local window = create("Frame", {
	Size = UDim2.new(0, 480, 0, 400),
	Position = UDim2.new(0.5, -240, 0.5, -200),
	BackgroundColor3 = PALETTE.bg,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Parent = root,
	Corner = 14,
	Stroke = { PALETTE.border, 1 },
})

-- Title bar
local titleBar = create("Frame", {
	Size = UDim2.new(1, 0, 0, 52),
	BackgroundColor3 = PALETTE.bg,
	BorderSizePixel = 0,
	Corner = 14,
	Parent = window,
})
-- Cover bottom corners of title bar
create("Frame", {
	Size = UDim2.new(1, 0, 0, 8),
	Position = UDim2.new(0, 0, 1, -8),
	BackgroundColor3 = PALETTE.bg,
	BorderSizePixel = 0,
	Parent = titleBar,
})

local titleText = create("TextLabel", {
	Size = UDim2.new(1, -60, 1, 0),
	Position = UDim2.new(0, 18, 0, 0),
	BackgroundTransparency = 1,
	Text = "Script Loader",
	TextColor3 = PALETTE.text,
	TextSize = 17,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = titleBar,
})

local versionTag = create("TextLabel", {
	Size = UDim2.new(0, 80, 0, 18),
	Position = UDim2.new(1, -98, 0.5, -9),
	BackgroundTransparency = 1,
	Text = "v2.0",
	TextColor3 = PALETTE.textMuted,
	TextSize = 10,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = titleBar,
})

-- Close button
local closeBtn = create("TextButton", {
	Size = UDim2.new(0, 28, 0, 28),
	Position = UDim2.new(1, -34, 0, 12),
	BackgroundColor3 = PALETTE.surface,
	BorderSizePixel = 0,
	Text = "✕",
	TextColor3 = PALETTE.textDim,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	Corner = 7,
	Parent = titleBar,
})

closeBtn.MouseEnter:Connect(function()
	tween(closeBtn, { BackgroundColor3 = PALETTE.red, TextColor3 = Color3.new(1, 1, 1) }):Play()
end)
closeBtn.MouseLeave:Connect(function()
	tween(closeBtn, { BackgroundColor3 = PALETTE.surface, TextColor3 = PALETTE.textDim }):Play()
end)
closeBtn.MouseButton1Click:Connect(function()
	root:Destroy()
end)

-- Divider line under title
local divider = create("Frame", {
	Size = UDim2.new(1, -32, 0, 1),
	Position = UDim2.new(0, 16, 0, 52),
	BackgroundColor3 = PALETTE.border,
	BorderSizePixel = 0,
	Parent = window,
})

-- ============================================================
-- SCROLL FRAME
-- ============================================================
local scroll = create("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -56),
	Position = UDim2.new(0, 0, 0, 56),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = PALETTE.border,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	Parent = window,
})

local scrollList = Instance.new("UIListLayout", scroll)
scrollList.Padding = UDim.new(0, 12)
scrollList.HorizontalAlignment = Enum.HorizontalAlignment.Center
scrollList.SortOrder = Enum.SortOrder.LayoutOrder

local scrollPad = Instance.new("UIPadding", scroll)
scrollPad.PaddingTop = UDim.new(0, 16)
scrollPad.PaddingBottom = UDim.new(0, 16)

local function updateCanvas()
	scroll.CanvasSize = UDim2.new(0, 0, 0, scrollList.AbsoluteContentSize.Y + 32)
end
scrollList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
task.spawn(function()
	task.wait(0.1)
	updateCanvas()
end)

-- ============================================================
-- BUILD CARDS
-- ============================================================
local loadStates = {} -- track loading state per card
local cardRefs = {}

for idx, gameData in ipairs(GAMES) do
	local CARD_W = 432
	local CARD_H = 110

	-- Card container
	local card = create("Frame", {
		Size = UDim2.new(0, CARD_W, 0, CARD_H),
		BackgroundColor3 = PALETTE.surface,
		BorderSizePixel = 0,
		Corner = 12,
		Stroke = { PALETTE.border, 1 },
		LayoutOrder = idx,
		Parent = scroll,
	})

	-- Left accent bar
	local accentBar = create("Frame", {
		Size = UDim2.new(0, 3, 1, 0),
		BackgroundColor3 = gameData.accent,
		BorderSizePixel = 0,
		Corner = 2,
		Parent = card,
	})
	gradient(accentBar, gameData.accent, Color3.fromRGB(
		math.clamp(gameData.accent.R * 255 * 0.6, 0, 255),
		math.clamp(gameData.accent.G * 255 * 0.6, 0, 255),
		math.clamp(gameData.accent.B * 255 * 0.6, 0, 255)
	), 180)

	-- Icon circle
	local iconCircle = create("Frame", {
		Size = UDim2.new(0, 42, 0, 42),
		Position = UDim2.new(0, 18, 0, 18),
		BackgroundColor3 = gameData.accent,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		Corner = 21,
		Parent = card,
	})
	local iconText = create("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = gameData.icon,
		TextSize = 20,
		Font = Enum.Font.Gotham,
		Parent = iconCircle,
	})

	-- Game name
	local nameLabel = create("TextLabel", {
		Size = UDim2.new(0, 250, 0, 22),
		Position = UDim2.new(0, 74, 0, 14),
		BackgroundTransparency = 1,
		Text = gameData.name,
		TextColor3 = PALETTE.text,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	-- Description
	local descLabel = create("TextLabel", {
		Size = UDim2.new(0, 330, 0, 30),
		Position = UDim2.new(0, 74, 0, 38),
		BackgroundTransparency = 1,
		Text = gameData.desc,
		TextColor3 = PALETTE.textDim,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		LineHeight = 1.3,
		Parent = card,
	})

	-- Feature tags
	local tagOffset = 74
	for _, feature in ipairs(gameData.features) do
		local tag = create("Frame", {
			Size = UDim2.new(0, 8 + #feature * 7, 0, 18),
			Position = UDim2.new(0, tagOffset, 0, 78),
			BackgroundColor3 = gameData.accent,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			Corner = 4,
			Parent = card,
		})
		local tagLabel = create("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = feature,
			TextColor3 = gameData.accent,
			TextSize = 10,
			Font = Enum.Font.GothamBold,
			Parent = tag,
		})
		tagOffset = tagOffset + 14 + #feature * 7
	end

	-- Status text (hidden by default)
	local statusLabel = create("TextLabel", {
		Name = "Status",
		Size = UDim2.new(0, 160, 0, 16),
		Position = UDim2.new(0, 74, 0, 102),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = PALETTE.blue,
		TextSize = 10,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	-- Load button
	local loadBtn = create("TextButton", {
		Size = UDim2.new(0, 84, 0, 36),
		Position = UDim2.new(1, -100, 0, 37),
		BackgroundColor3 = gameData.accent,
		BorderSizePixel = 0,
		Text = "Load",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		Corner = 8,
		Parent = card,
	})

	-- Load button hover — lift + glow
	local btnGlow = create("Frame", {
		Size = UDim2.new(1, 14, 1, 14),
		Position = UDim2.new(0, -7, 0, -7),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Corner = 10,
		Stroke = { gameData.accent, 1.5, 0.7 },
		ZIndex = -1,
		Visible = false,
		Parent = loadBtn,
	})

	loadBtn.MouseEnter:Connect(function()
		if loadStates[idx] == "loading" then return end
		tween(loadBtn, {
			BackgroundColor3 = Color3.fromRGB(
				math.clamp(gameData.accent.R * 255 * 1.15, 0, 255),
				math.clamp(gameData.accent.G * 255 * 1.15, 0, 255),
				math.clamp(gameData.accent.B * 255 * 1.15, 0, 255)
			),
		}):Play()
		btnGlow.Visible = true
	end)
	loadBtn.MouseLeave:Connect(function()
		tween(loadBtn, { BackgroundColor3 = gameData.accent }):Play()
		btnGlow.Visible = false
	end)

	-- Click action
	local function loadGame()
		if loadStates[idx] == "loading" then return end
		loadStates[idx] = "loading"

		-- Animate button
		loadBtn.Text = "..."
		tween(loadBtn, {
			BackgroundColor3 = PALETTE.textDim,
		}):Play()

		statusLabel.Text = "Loading..."
		statusLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
		statusLabel.Visible = true

		-- Pulse the accent bar during load
		task.spawn(function()
			for _ = 1, 8 do
				if loadStates[idx] ~= "loading" then break end
				accentBar.BackgroundTransparency = 0.5
				task.wait(0.3)
				accentBar.BackgroundTransparency = 0.1
				task.wait(0.3)
			end
		end)

		-- Actually load the script
		task.spawn(function()
			local ok, result = pcall(function()
				loadstring(game:HttpGet(gameData.url))()
			end)
			if ok then
				loadStates[idx] = "done"
				statusLabel.Text = "✓ Loaded successfully"
				statusLabel.TextColor3 = PALETTE.green
				tween(loadBtn, { BackgroundColor3 = PALETTE.green, Text = "Done" }):Play()
			else
				loadStates[idx] = "error"
				local errMsg = tostring(result)
				if #errMsg > 35 then errMsg = errMsg:sub(1, 32) .. "..." end
				statusLabel.Text = "✕ " .. errMsg
				statusLabel.TextColor3 = PALETTE.red
				tween(loadBtn, { BackgroundColor3 = PALETTE.red, Text = "Retry" }):Play()
				loadStates[idx] = nil -- allow retry
				warn("[Loader] Failed: " .. tostring(result))
			end
		end)
	end

	loadBtn.MouseButton1Click:Connect(loadGame)

	-- Card hover effect
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			loadGame()
		end
	end)

	card.MouseEnter:Connect(function()
		tween(card, {
			BackgroundColor3 = PALETTE.surfaceHover,
		}):Play()
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, { Color = PALETTE.borderHover }):Play()
		end
	end)
	card.MouseLeave:Connect(function()
		tween(card, {
			BackgroundColor3 = PALETTE.surface,
		}):Play()
		local stroke = card:FindFirstChildOfClass("UIStroke")
		if stroke then
			tween(stroke, { Color = PALETTE.border }):Play()
		end
	end)

	table.insert(cardRefs, card)
end

-- ============================================================
-- FOOTER
-- ============================================================
local footer = create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14),
	Position = UDim2.new(0, 0, 1, -18),
	BackgroundTransparency = 1,
	Text = "github.com/zaisaawe21 — Press Insert to close",
	TextColor3 = PALETTE.textMuted,
	TextSize = 9,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = window,
})

-- ============================================================
-- TOGGLE: Insert key
-- ============================================================
local visible = true
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Insert then
		visible = not visible
		window.Visible = visible
		overlay.Visible = visible
		dotGrid.Visible = visible
	end
end)

-- ============================================================
-- ENTRANCE ANIMATION
-- ============================================================
-- Fade in overlay
overlay.BackgroundTransparency = 1
tweenSlow(overlay, { BackgroundTransparency = 0.55 }):Play()

-- Scale + fade cards in
for i, card in ipairs(cardRefs) do
	card.BackgroundTransparency = 0.6
	local origSize = card.Size
	card.Size = UDim2.new(origSize.X.Scale, origSize.X.Offset - 20, origSize.Y.Scale, origSize.Y.Offset - 4)

	task.delay(0.1 + i * 0.08, function()
		tweenBounce(card, {
			Size = origSize,
			BackgroundTransparency = 0,
		}):Play()
	end)
end

-- Window slide-in + scale
local origWinSize = window.Size
local origWinPos = window.Position
window.Size = UDim2.new(origWinSize.X.Scale, origWinSize.X.Offset, origWinSize.Y.Scale, origWinSize.Y.Offset + 30)
window.Position = origWinPos + UDim2.new(0, 0, 0, 15)
window.BackgroundTransparency = 0.3

tweenSlow(window, {
	Size = origWinSize,
	Position = origWinPos,
	BackgroundTransparency = 0,
}):Play()

return GAMES
