-- ABA Script v13 — pasted edition
-- RShift = toggle menu visibility
-- New: Combo Escape Slide, Auto Block, Hitbox Dodge, Aggressive Recovery

local plr = game.Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local cam = workspace.CurrentCamera
local VIM = game:GetService("VirtualInputManager")

-- ============================================================
-- CLEANUP
-- ============================================================
if _G.abaConns then for _,c in ipairs(_G.abaConns) do pcall(function() c:Disconnect() end) end end
_G.abaConns = {}
if _G.abaLockHL then pcall(function() _G.abaLockHL:Destroy() end) end
local old = playerGui:FindFirstChild("ABAMenu"); if old then old:Destroy() end

-- ============================================================
-- FEATURE FLAGS
-- ============================================================
if _G.abaInitDone ~= true then
    _G.abaStunEnabled  = false
    _G.abaSpeedEnabled = false
    _G.abaBlackFlashEnabled = false
    _G.abaAntiFlingEnabled = false
    _G.abaComboPauseEnabled = false
    _G.abaComboEscapeEnabled = false   -- NEW: escape slide on combo
    _G.abaAutoBlockEnabled = false     -- NEW: auto block when comboed
    _G.abaHitboxDodgeEnabled = false   -- NEW: micro-dodge on combo hits
    _G.abaSkillPauseDuration = 0.8
    _G.abaClickPauseDuration = 0.4
    _G.abaTpKeybind = _G.abaTpKeybind or { type="key", code=Enum.KeyCode.T }
end
SPEED = 22
local lastSkillTime = 0
local lastClickTime = 0
local zeroStunSV = nil

-- Track skill keys and clicks
table.insert(_G.abaConns, UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.Two or 
       input.KeyCode == Enum.KeyCode.Three or input.KeyCode == Enum.KeyCode.Four or 
       input.KeyCode == Enum.KeyCode.Q then
        lastSkillTime = os.clock()
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        lastClickTime = os.clock()
    end
end))

-- ============================================================
-- STUN PHYSICS CLASSES
-- ============================================================
local STUN_CLASSES = {
    BodyVelocity=true, BodyPosition=true, BodyGyro=true, BodyAngularVelocity=true,
    BodyForce=true, LinearVelocity=true, AngularVelocity=true,
    VectorForce=true, AlignPosition=true, AlignOrientation=true,
}

local function nukeHRP(hrp)
    if not hrp then return end
    pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    pcall(function() hrp.AssemblyAngularVelocity = Vector3.zero end)
    for _, v in ipairs(hrp:GetChildren()) do
        if STUN_CLASSES[v.ClassName] then
            pcall(function() v:Destroy() end)
        end
    end
end

local function restoreHumanoid(hum)
    if not hum then return end
    hum.WalkSpeed    = _G.abaSpeedEnabled and SPEED or 16
    hum.JumpPower    = 50
    hum.PlatformStand = false
    hum.Sit          = false
end

-- ============================================================
-- ANIMATION TRACKING
-- ============================================================
local charConns = {}
local activeMoveAnimations = {}

local function clearCharConns()
    for _, c in ipairs(charConns) do pcall(function() c:Disconnect() end) end
    charConns = {}
end

local function clearActiveMoveAnimations()
    activeMoveAnimations = {}
end

local function isMoveAnimationPlaying()
    local playing = false
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local name = string.lower(track.Name or "")
            local animId = track.Animation and tostring(track.Animation.AnimationId) or ""
            if string.find(animId, "1461128166") or string.find(animId, "7324112923") or name == "animation" then
                return true
            end
            local isMovement = string.find(name, "idle") or string.find(name, "walk") 
                or string.find(name, "run") or string.find(name, "jump") 
                or string.find(name, "fall") or string.find(name, "climb") 
                or string.find(name, "swim") or string.find(name, "sit") 
                or string.find(name, "toolnone")
            if not isMovement and track.Length > 0 then
                playing = true
                break
            end
        end
    end
    return playing
end

-- ============================================================
-- COMBO ESCAPE SLIDE
-- ============================================================
local function triggerDesyncSlide(hrp, intensity)
    -- intensity: 1 = subtle (looks like lag), 2 = medium, 3 = obvious
    if not hrp then return end
    pcall(function()
        if hrp:FindFirstChild("LagDesync") then return end
        
        local bp = Instance.new("BodyVelocity")
        bp.Name = "LagDesync"
        bp.MaxForce = Vector3.new(100000, 0, 100000)
        
        local backDir = -hrp.CFrame.LookVector
        local sideDir = hrp.CFrame.RightVector * (math.random() > 0.5 and 1 or -1)
        local slideDist = intensity == 1 and 0.3 or (intensity == 2 and 0.6 or 1.0)
        local slideDir = (backDir * 0.4 + sideDir * slideDist).Unit
        
        bp.Velocity = slideDir * (14 + intensity * 4)
        bp.Parent = hrp
        
        task.spawn(function()
            task.wait(0.08 + intensity * 0.04)
            pcall(function() bp:Destroy() end)
        end)
    end)
end

-- ============================================================
-- AUTO BLOCK — tap F when comboed
-- ============================================================
local lastAutoBlock = 0
local function autoBlock()
    if not _G.abaAutoBlockEnabled then return end
    local now = os.clock()
    if now - lastAutoBlock < 0.5 then return end  -- don't spam
    lastAutoBlock = now
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.F, false, nil)
        task.wait(0.05)
        VIM:SendKeyEvent(false, Enum.KeyCode.F, false, nil)
    end)
end

-- ============================================================
-- HITBOX DODGE — micro-nudge HRP when comboed
-- ============================================================
local lastHitboxDodge = 0
local function hitboxDodge(hrp)
    if not _G.abaHitboxDodgeEnabled then return end
    if not hrp then return end
    local now = os.clock()
    if now - lastHitboxDodge < 0.3 then return end
    lastHitboxDodge = now
    
    local sideDir = hrp.CFrame.RightVector * (math.random() > 0.5 and 0.6 or -0.6)
    local original = hrp.CFrame
    hrp.CFrame = hrp.CFrame + sideDir
    
    -- Snap back after 0.12s — looks like a tiny lag spike
    task.delay(0.12, function()
        if hrp and hrp.Parent then
            pcall(function() hrp.CFrame = original end)
        end
    end)
end

-- ============================================================
-- SMART STUN BYPASS (enhanced)
-- ============================================================
local function checkAndRecoverStun(hum, hrp)
    if not _G.abaStunEnabled then return end
    if isMoveAnimationPlaying() then return end
    if _G.abaComboPauseEnabled and (os.clock() - lastSkillTime < _G.abaSkillPauseDuration or os.clock() - lastClickTime < _G.abaClickPauseDuration) then return end
    
    local now = os.clock()
    if _G.stunReleaseTime and now < _G.stunReleaseTime then return end
    
    local isTryingToAct = false
    if hum.MoveDirection.Magnitude > 0 then
        isTryingToAct = true
    elseif UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.F) then
        isTryingToAct = true
    elseif now - lastClickTime < 0.6 or now - lastSkillTime < 1.0 then
        isTryingToAct = true
    end
    
    -- Enhanced: also trigger escape when being burst-damaged (comboed)
    local inCombo = _G.comboHits and _G.comboHits >= 2
    if inCombo then
        isTryingToAct = true  -- force recovery attempt
    end
    
    if isTryingToAct then
        local wasStunned = (hum.WalkSpeed < 5) or hum.PlatformStand or hum.Sit
        restoreHumanoid(hum)
        
        if hrp then
            for _, v in ipairs(hrp:GetChildren()) do
                if STUN_CLASSES[v.ClassName] and v.Name ~= "LagDesync" then
                    pcall(function() v:Destroy() end)
                end
            end
        end
        
        if wasStunned and inCombo then
            -- COMBO ESCAPE: slide + block + dodge
            if _G.abaComboEscapeEnabled then
                triggerDesyncSlide(hrp, _G.comboHits >= 4 and 3 or 2)
            end
            if _G.abaAutoBlockEnabled then
                autoBlock()
            end
            if _G.abaHitboxDodgeEnabled then
                hitboxDodge(hrp)
            end
            _G.comboHits = 0
        end
    end
end

local function setupStunBypass()
    clearCharConns()
    clearActiveMoveAnimations()
    local char = plr.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    local animator = hum:FindFirstChildOfClass("Animator") or hum
    table.insert(charConns, animator.AnimationPlayed:Connect(function(track)
        local now = os.clock()
        local name = string.lower(track.Name or "")
        local animId = track.Animation and track.Animation.AnimationId or ""
        local isSkillKeyPress = (now - lastSkillTime < 1.0) or (now - lastClickTime < 1.0)
        local isExplicitMove = string.find(name, "dash") or string.find(name, "barrage") or string.find(name, "rush")
            or string.find(name, "m1") or string.find(name, "combo") or string.find(name, "attack")
            or string.find(name, "punch") or string.find(name, "kick") or string.find(name, "slash")
            or string.find(name, "hit") or string.find(name, "swing") or string.find(name, "strike")
            or string.find(name, "animation")
        
        if isSkillKeyPress or isExplicitMove then
            local ignoreNames = {"idle", "walk", "run", "jump", "fall", "climb", "swim", "sit", "toolnone"}
            local isIgnore = false
            for _, ignore in ipairs(ignoreNames) do
                if string.find(name, ignore) then isIgnore = true; break end
            end
            if not isIgnore then
                activeMoveAnimations[track] = true
                local stopConn
                stopConn = track.Stopped:Connect(function()
                    activeMoveAnimations[track] = nil
                    if stopConn then stopConn:Disconnect() end
                end)
                table.insert(charConns, stopConn)
            end
        end
    end))

    -- Enhanced combo tracking with lower threshold
    local lastHealth = hum.Health
    table.insert(charConns, hum.HealthChanged:Connect(function(health)
        if health < lastHealth then
            local now = os.clock()
            if now - (_G.lastDamageTime or 0) < 1.5 then  -- tighter window
                _G.comboHits = (_G.comboHits or 0) + 1
            else
                _G.comboHits = 1
            end
            _G.lastDamageTime = now
            
            -- Shorter stun window — recover faster
            if not _G.stunReleaseTime or now > _G.stunReleaseTime then
                _G.stunReleaseTime = now + (math.random(15, 25) / 100)  -- was 22-38, now 15-25
            end
            
            -- IMMEDIATE combo escape check on damage
            if _G.comboHits >= 2 then
                if _G.abaComboEscapeEnabled then
                    triggerDesyncSlide(hrp, 2)
                end
                if _G.abaHitboxDodgeEnabled then
                    hitboxDodge(hrp)
                end
            end
        end
        lastHealth = health
    end))

    local function onStunDetected()
        local now = os.clock()
        if not _G.stunReleaseTime or now > _G.stunReleaseTime then
            _G.stunReleaseTime = now + (math.random(15, 25) / 100)
        end
        checkAndRecoverStun(hum, hrp)
    end

    table.insert(charConns, hum.Changed:Connect(function(p)
        if not _G.abaStunEnabled then return end
        if isMoveAnimationPlaying() then return end
        if p == "WalkSpeed" or p == "JumpPower" or p == "PlatformStand" or p == "Sit" then
            if hum.WalkSpeed < 5 or hum.PlatformStand or hum.Sit then
                onStunDetected()
            end
        end
    end))

    table.insert(charConns, hrp.ChildAdded:Connect(function(v)
        if not _G.abaStunEnabled then return end
        if isMoveAnimationPlaying() then return end
        if STUN_CLASSES[v.ClassName] and v.Name ~= "LagDesync" then
            onStunDetected()
        end
    end))
end

local function hookTimeStop()
    for _, name in ipairs({"TimeStop","TimeStopSDio"}) do
        local r = game.ReplicatedStorage:FindFirstChild(name)
        if r then
            table.insert(_G.abaConns, r.OnClientEvent:Connect(function()
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                restoreHumanoid(hum)
                nukeHRP(hrp)
            end))
        end
    end
end

local MOVER_NAMES = {"StunBV", "FlingFloat", "DownerFloat", "SuperUpFoat", "downer", "upper"}
local PHYSICS_CLASSES = {
    BodyVelocity=true, BodyPosition=true, BodyGyro=true, BodyAngularVelocity=true,
    BodyForce=true, LinearVelocity=true, AngularVelocity=true,
    VectorForce=true, AlignPosition=true, AlignOrientation=true
}

local function stripAllStunPhysics(hrp)
    if not hrp then return end
    for _, moverName in ipairs(MOVER_NAMES) do
        local mover = hrp:FindFirstChild(moverName)
        if mover then
            for _, child in ipairs(mover:GetChildren()) do
                if PHYSICS_CLASSES[child.ClassName] then
                    pcall(function() child:Destroy() end)
                end
            end
        end
    end
    for _, child in ipairs(hrp:GetChildren()) do
        if PHYSICS_CLASSES[child.ClassName] then
            pcall(function() child:Destroy() end)
        end
    end
end

local lastSafeCFrame = nil

-- HEARTBEAT — absolute coverage
table.insert(_G.abaConns, RS.Heartbeat:Connect(function()
    local char = plr.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Anti-Fling
    if _G.abaAntiFlingEnabled and not isMoveAnimationPlaying() then
        local vel = hrp.AssemblyLinearVelocity
        local ang = hrp.AssemblyAngularVelocity
        if vel.Magnitude > 150 or ang.Magnitude > 150 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if lastSafeCFrame then hrp.CFrame = lastSafeCFrame end
        else
            if vel.Magnitude < 70 and ang.Magnitude < 70 then lastSafeCFrame = hrp.CFrame end
        end
    end

    checkAndRecoverStun(hum, hrp)
end))

local function hookMatchEnd()
    local playWinMusic = game.ReplicatedStorage:FindFirstChild("PlayWinMusic")
    if playWinMusic then
        table.insert(_G.abaConns, playWinMusic.OnClientEvent:Connect(function()
            _G.abaStunEnabled = false
            print("[ABA] Match ended, Zero Stun disabled.")
        end))
    end
end

setupStunBypass()
hookTimeStop()
hookMatchEnd()

table.insert(_G.abaConns, plr.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart", 10)
    char:WaitForChild("Humanoid", 10)
    setupStunBypass()
    if _G.abaStunEnabled or _G.abaSpeedEnabled then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then restoreHumanoid(hum) end
    end
end))

-- Speed Boost
table.insert(_G.abaConns, RS.Heartbeat:Connect(function()
    if not _G.abaSpeedEnabled then return end
    local char = plr.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed > 0 and hum.WalkSpeed ~= SPEED then
        hum.WalkSpeed = SPEED
    end
end))

-- ============================================================
-- AUTO BLACK FLASH
-- ============================================================
local _bfHooked = false
local function enableBlackFlash()
    if _bfHooked then return end
    local bfc = game.ReplicatedStorage:FindFirstChild("BlackFlashCheck")
    if not bfc then return end
    bfc.OnClientInvoke = function(...)
        if _G.abaBlackFlashEnabled then return true end
        return false
    end
    _bfHooked = true
end

local function disableBlackFlash()
    _G.abaBlackFlashEnabled = false
end

-- ============================================================
-- LOCK-ON
-- ============================================================
_G.abaLockHL  = nil
local lockTarget    = nil
local lockActive    = false
local lockMode      = "HOLD"
local lockBind      = nil
local bindListening = false
local bindListenConns = {}
local onLockModeChanged = nil

local function clearHL()
    if _G.abaLockHL then pcall(function() _G.abaLockHL:Destroy() end); _G.abaLockHL = nil end
end

local function getNearestToMouse()
    local live = workspace:FindFirstChild("Live"); if not live then return nil end
    local myChar = plr.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart"); if not myHRP then return nil end
    local myTeam = plr.Team
    local mouse = plr:GetMouse()
    local ray = cam:ScreenPointToRay(mouse.X, mouse.Y)
    local best, bestScore = nil, math.huge
    for _, c in ipairs(live:GetChildren()) do
        if c ~= myChar then
            local cp = game.Players:GetPlayerFromCharacter(c)
            if not cp then continue end
            if myTeam and cp.Team == myTeam then continue end
            local hrp = c:FindFirstChild("HumanoidRootPart")
            local hum = c:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local toC  = hrp.Position - ray.Origin
                local dot  = toC:Dot(ray.Direction)
                local near = ray.Origin + ray.Direction * math.max(0, dot)
                local score= (hrp.Position - near).Magnitude + (hrp.Position - myHRP.Position).Magnitude * 0.05
                if score < bestScore then bestScore = score; best = c end
            end
        end
    end
    return best
end

local function setLockTarget(t)
    clearHL()
    lockTarget = t
    if lockTarget then
        _G.abaLockHL = Instance.new("Highlight")
        _G.abaLockHL.OutlineColor = Color3.fromRGB(220,50,50)
        _G.abaLockHL.FillTransparency = 1; _G.abaLockHL.OutlineTransparency = 0
        _G.abaLockHL.Adornee = lockTarget; _G.abaLockHL.Parent = lockTarget
    end
end

local function startLock()
    if not lockActive then setLockTarget(getNearestToMouse()) end
    lockActive = true
end

local function stopLock()
    lockActive = false; clearHL(); lockTarget = nil
    cam.CameraType = Enum.CameraType.Custom
end

table.insert(_G.abaConns, RS.Heartbeat:Connect(function()
    if not lockActive then return end
    local myChar = plr.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
    if not lockTarget or not lockTarget.Parent then setLockTarget(getNearestToMouse()) end
    if not lockTarget then return end
    local tHRP = lockTarget:FindFirstChild("HumanoidRootPart"); if not tHRP then return end
    local tHum = lockTarget:FindFirstChildOfClass("Humanoid")
    if tHum and tHum.Health <= 0 then setLockTarget(getNearestToMouse()); return end
    local dir = (tHRP.Position - myHRP.Position) * Vector3.new(1,0,1)
    if dir.Magnitude > 0.5 then myHRP.CFrame = CFrame.new(myHRP.Position, myHRP.Position + dir.Unit) end
    cam.CFrame = CFrame.new(myHRP.Position + Vector3.new(0,3,0), tHRP.Position + Vector3.new(0,2,0))
end))

local bindConns = {}
local function clearBindConns()
    for _, c in ipairs(bindConns) do pcall(function() c:Disconnect() end) end
    bindConns = {}
end

local function inputMatchesBind(inp, bind)
    if not bind then return false end
    if bind.type == "key" then return inp.KeyCode == bind.code
    elseif bind.type == "mouse" then
        local typeName = tostring(inp.UserInputType):gsub("Enum%.UserInputType%.", "")
        if bind.inputTypeName then return typeName == bind.inputTypeName
        else return inp.UserInputType == bind.inputType end
    end
    return false
end

local function applyBind(bind)
    clearBindConns()
    lockBind = bind
    table.insert(bindConns, UIS.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if not inputMatchesBind(inp, lockBind) then return end
        if lockMode == "HOLD" then startLock() else if lockActive then stopLock() else startLock() end end
    end))
    table.insert(bindConns, UIS.InputEnded:Connect(function(inp)
        if lockMode ~= "HOLD" then return end
        if inputMatchesBind(inp, lockBind) then stopLock() end
    end))
end

applyBind({ type="key", code=Enum.KeyCode.E })

local mouseTypeNames = {
    [Enum.UserInputType.MouseButton1] = "LMB",
    [Enum.UserInputType.MouseButton2] = "RMB",
    [Enum.UserInputType.MouseButton3] = "MMB",
    ["MouseButton4"] = "MB4",
    ["MouseButton5"] = "MB5",
}
local function getBindLabel(bind)
    if not bind then return "None" end
    if bind.type == "key" then return tostring(bind.code):gsub("Enum%.KeyCode%.", "")
    elseif bind.type == "mouse" then
        if bind.inputTypeName then return mouseTypeNames[bind.inputTypeName] or bind.inputTypeName end
        return mouseTypeNames[bind.inputType] or "Mouse"
    end
    return "?"
end

-- ============================================================
-- GUI
-- ============================================================
local W=450; local TITLE_H=40; local ROW_H=40; local SLIDER_H=28; local PAD=10
do
local TW=TweenInfo.new(0.15, Enum.EasingStyle.Quad)

local function mkF(p,sz,pos,col,r)
    local f=Instance.new("Frame",p); f.Size=sz; f.Position=pos
    f.BackgroundColor3=col; f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,r or 8); return f
end

local sg = Instance.new("ScreenGui")
sg.Name="ABAMenu"; sg.ResetOnSpawn=false
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.Parent=playerGui

-- Calculate height: title(40) + tab bar(32+8) + 3 tabs * ROW_H(40+6) each + settings sliders + hint
local rows = 8  -- 3 combat + 2 extras + 3 sliders
local H = TITLE_H + 48 + rows * (ROW_H + 6) + 16 + 22
local win = mkF(sg,UDim2.new(0,W,0,H),UDim2.new(0.5,-W/2,0.5,-H/2),Color3.fromRGB(12,12,12),10)
win.Active=true; win.Draggable=true
local ws=Instance.new("UIStroke",win); ws.Color=Color3.fromRGB(48,48,48); ws.Thickness=1

local tbar=mkF(win,UDim2.new(1,0,0,TITLE_H),UDim2.new(0,0,0,0),Color3.fromRGB(18,18,18),10)
local tp=Instance.new("Frame",tbar); tp.Size=UDim2.new(1,0,0,10); tp.Position=UDim2.new(0,0,1,-10)
tp.BackgroundColor3=Color3.fromRGB(18,18,18); tp.BorderSizePixel=0
local tl=Instance.new("TextLabel",tbar); tl.Size=UDim2.new(1,-50,1,0); tl.Position=UDim2.new(0,14,0,0)
tl.BackgroundTransparency=1; tl.Text="✦  ABA pasted v13"; tl.Font=Enum.Font.GothamBold
tl.TextSize=14; tl.TextColor3=Color3.fromRGB(255,255,255); tl.TextXAlignment=Enum.TextXAlignment.Left
local colBtn=Instance.new("TextButton",tbar); colBtn.Size=UDim2.new(0,26,0,26)
colBtn.Position=UDim2.new(1,-34,0.5,-13); colBtn.BackgroundColor3=Color3.fromRGB(35,35,35)
colBtn.BorderSizePixel=0; colBtn.Text="–"; colBtn.TextColor3=Color3.fromRGB(180,180,180)
colBtn.Font=Enum.Font.GothamBold; colBtn.TextSize=15
Instance.new("UICorner",colBtn).CornerRadius=UDim.new(0,5)

-- Tabs Header Bar
local tabsBar = mkF(win, UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, TITLE_H + 8), Color3.fromRGB(18, 18, 18), 6)
local tLayout = Instance.new("UIListLayout", tabsBar)
tLayout.FillDirection = Enum.FillDirection.Horizontal
tLayout.Padding = UDim.new(0, 4)
tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local tabButtons = {}
local tabFrames = {}

local function createTabFrame(parent)
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 1, 0); sf.Position = UDim2.new(0, 0, 0, 0)
    sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0
    sf.CanvasSize = UDim2.new(0, 0, 0, 0); sf.ScrollBarThickness = 4
    sf.ScrollBarImageColor3 = Color3.fromRGB(60,60,60); sf.Parent = parent
    local ll = Instance.new("UIListLayout", sf)
    ll.Padding = UDim.new(0, 6); ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
    local pad = Instance.new("UIPadding", sf)
    pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6)
    pad.PaddingLeft = UDim.new(0, 6); pad.PaddingRight = UDim.new(0, 6)
    ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        sf.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y + 12)
    end)
    return sf
end

local function addTab(name, width)
    width = width or 85
    local btn = Instance.new("TextButton", tabsBar)
    btn.Size = UDim2.new(0, width, 0, 24)
    btn.BackgroundColor3 = Color3.fromRGB(24, 24, 24); btn.BorderSizePixel = 0
    btn.Text = name; btn.Font = Enum.Font.GothamBold; btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(140, 140, 140)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    local stroke = Instance.new("UIStroke", btn); stroke.Color = Color3.fromRGB(35, 35, 35); stroke.Thickness = 1
    
    local container = mkF(win, UDim2.new(1, -20, 1, -TITLE_H - 78), UDim2.new(0, 10, 0, TITLE_H + 48), Color3.fromRGB(12, 12, 12), 0)
    container.BackgroundTransparency = 1; container.Visible = false
    local sf = createTabFrame(container)
    
    btn.MouseButton1Click:Connect(function()
        for tName, tBtn in pairs(tabButtons) do
            tBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24); tBtn.TextColor3 = Color3.fromRGB(140, 140, 140)
            tabFrames[tName].Visible = false
        end
        btn.BackgroundColor3 = Color3.fromRGB(200, 40, 40); btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        container.Visible = true
    end)
    
    tabButtons[name] = btn; tabFrames[name] = container
    return sf
end

local combatTab = addTab("Combat", 70)
local defenseTab = addTab("Defense", 72)
local extrasTab = addTab("Extras", 65)
local settingsTab = addTab("Settings", 75)

tabButtons["Combat"].BackgroundColor3 = Color3.fromRGB(200, 40, 40)
tabButtons["Combat"].TextColor3 = Color3.fromRGB(255, 255, 255)
tabFrames["Combat"].Visible = true

local isDraggingSlider = false

local function buildSlider(parent, labelText, min, max, default, decimals, onChange)
    local row = mkF(parent, UDim2.new(1,-10,0,SLIDER_H), UDim2.new(0,0,0,0), Color3.fromRGB(16,16,16), 7)
    Instance.new("UIStroke",row).Color = Color3.fromRGB(35,35,35)
    local lbl = Instance.new("TextLabel", row); lbl.Size = UDim2.new(0,110,1,0); lbl.Position = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(160,160,160); lbl.TextXAlignment = Enum.TextXAlignment.Left
    local valLbl = Instance.new("TextLabel", row); valLbl.Size = UDim2.new(0,38,1,0); valLbl.Position = UDim2.new(1,-44,0,0)
    valLbl.BackgroundTransparency = 1; valLbl.Font = Enum.Font.GothamBold; valLbl.TextSize = 11
    valLbl.TextColor3 = Color3.fromRGB(220,220,220); valLbl.TextXAlignment = Enum.TextXAlignment.Right
    local trackBg = mkF(row, UDim2.new(1,-174,0,6), UDim2.new(0,120,0.5,-3), Color3.fromRGB(35,35,35), 99)
    local fill = mkF(trackBg, UDim2.new(0,0,1,0), UDim2.new(0,0,0,0), Color3.fromRGB(200,40,40), 99)
    local knob = mkF(trackBg, UDim2.new(0,14,0,14), UDim2.new(0,0,0.5,-7), Color3.fromRGB(255,255,255), 99)
    local trackBtn = Instance.new("TextButton", trackBg); trackBtn.Size = UDim2.new(1,0,1,20)
    trackBtn.Position = UDim2.new(0,0,0,-7); trackBtn.BackgroundTransparency = 1; trackBtn.Text = ""; trackBtn.ZIndex = 5
    local currentVal = default; local dragging = false
    local function applyPos(mouseX)
        local absX = trackBg.AbsolutePosition.X; local absW = math.max(trackBg.AbsoluteSize.X, 1)
        local t = math.clamp((mouseX - absX) / absW, 0, 1)
        local v = math.clamp(decimals and math.floor((min + t * (max - min))*10+0.5)/10 or math.floor(min + t * (max - min)+0.5), min, max)
        currentVal = v; local ft = (v - min) / (max - min)
        fill.Size = UDim2.new(ft, 0, 1, 0); knob.Position = UDim2.new(ft, -7, 0.5, -7)
        valLbl.Text = tostring(v); onChange(v)
    end
    task.spawn(function() task.wait(); applyPos(trackBg.AbsolutePosition.X + (default - min)/(max - min) * trackBg.AbsoluteSize.X) end)
    trackBtn.MouseButton1Down:Connect(function()
        dragging = true; isDraggingSlider = true; win.Draggable = false
        applyPos(plr:GetMouse().X)
    end)
    table.insert(_G.abaConns, RS.Heartbeat:Connect(function()
        if not dragging then return end; applyPos(plr:GetMouse().X)
    end))
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false; isDraggingSlider = false; win.Draggable = true
        end
    end)
    return function(v) applyPos(trackBg.AbsolutePosition.X + (v - min)/(max - min) * trackBg.AbsoluteSize.X) end
end

local function buildToggle(parent, label, onEnable, onDisable)
    local row=mkF(parent,UDim2.new(1,-10,0,ROW_H),UDim2.new(0,0,0,0),Color3.fromRGB(22,22,22),7)
    Instance.new("UIStroke",row).Color=Color3.fromRGB(40,40,40)
    local dot=mkF(row,UDim2.new(0,8,0,8),UDim2.new(0,10,0.5,-4),Color3.fromRGB(60,60,60),99)
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-76,1,0)
    lbl.Position=UDim2.new(0,24,0,0); lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=13; lbl.TextColor3=Color3.fromRGB(210,210,210)
    lbl.TextXAlignment=Enum.TextXAlignment.Left
    local pill=mkF(row,UDim2.new(0,46,0,24),UDim2.new(1,-54,0.5,-12),Color3.fromRGB(45,45,45),99)
    local knob=mkF(pill,UDim2.new(0,18,0,18),UDim2.new(0,3,0.5,-9),Color3.fromRGB(140,140,140),99)
    local btn=Instance.new("TextButton",row); btn.Size=UDim2.new(1,0,1,0)
    btn.BackgroundTransparency=1; btn.Text=""
    local state=false
    local function sv(s)
        state=s
        TS:Create(pill,TW,{BackgroundColor3=s and Color3.fromRGB(200,40,40) or Color3.fromRGB(45,45,45)}):Play()
        TS:Create(knob,TW,{BackgroundColor3=s and Color3.fromRGB(255,255,255) or Color3.fromRGB(140,140,140),
            Position=s and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)}):Play()
        TS:Create(dot,TW,{BackgroundColor3=s and Color3.fromRGB(80,220,80) or Color3.fromRGB(60,60,60)}):Play()
        lbl.TextColor3=s and Color3.fromRGB(255,255,255) or Color3.fromRGB(210,210,210)
    end
    btn.MouseButton1Click:Connect(function() sv(not state); if state then onEnable() else onDisable() end end)
    return sv
end

-- ============================================================
-- BUILD ROWS
-- ============================================================

-- COMBAT TAB
zeroStunSV = buildToggle(combatTab, "Zero Stun",
    function()
        _G.abaStunEnabled = true
        local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed=16; hum.JumpPower=50; hum.PlatformStand=false end
    end,
    function() _G.abaStunEnabled=false end)

buildToggle(combatTab, "Combo Pause",
    function() _G.abaComboPauseEnabled = true end,
    function() _G.abaComboPauseEnabled = false end)

buildToggle(combatTab, "Speed Boost",
    function()
        _G.abaSpeedEnabled = true
        local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed > 0 then hum.WalkSpeed=SPEED end
    end,
    function()
        _G.abaSpeedEnabled = false
        local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed=16 end
    end)

-- DEFENSE TAB (NEW)
buildToggle(defenseTab, "Combo Escape",
    function() _G.abaComboEscapeEnabled = true end,
    function() _G.abaComboEscapeEnabled = false end)

buildToggle(defenseTab, "Auto Block",
    function() _G.abaAutoBlockEnabled = true end,
    function() _G.abaAutoBlockEnabled = false end)

buildToggle(defenseTab, "Hitbox Dodge",
    function() _G.abaHitboxDodgeEnabled = true end,
    function() _G.abaHitboxDodgeEnabled = false end)

-- EXTRAS TAB
buildToggle(extrasTab, "Auto Black Flash",
    function() _G.abaBlackFlashEnabled = true; enableBlackFlash() end,
    function() disableBlackFlash() end)

buildToggle(extrasTab, "Anti-Fling",
    function() _G.abaAntiFlingEnabled = true end,
    function() _G.abaAntiFlingEnabled = false end)

buildToggle(extrasTab, "Stream Mode",
    function() win.Visible = false end,
    function() end)

-- SETTINGS TAB
buildSlider(settingsTab, "Speed (ws)", 16, 150, SPEED, false, function(v)
    SPEED = v
    if _G.abaSpeedEnabled then
        local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed > 0 then hum.WalkSpeed = SPEED end
    end
end)

buildSlider(settingsTab, "Skill Pause (s)", 0, 2, _G.abaSkillPauseDuration, true, function(v)
    _G.abaSkillPauseDuration = v
end)

buildSlider(settingsTab, "Click Pause (s)", 0, 1, _G.abaClickPauseDuration, true, function(v)
    _G.abaClickPauseDuration = v
end)

-- Hint
local hint = Instance.new("TextLabel", win)
hint.Size = UDim2.new(1, -20, 0, 16)
hint.Position = UDim2.new(0, 10, 1, -22)
hint.BackgroundTransparency = 1
hint.Text = "RShift = Toggle | pasted edition"
hint.TextColor3 = Color3.fromRGB(58, 58, 58)
hint.Font = Enum.Font.Gotham; hint.TextSize = 10
hint.TextXAlignment = Enum.TextXAlignment.Center

colBtn.MouseButton1Click:Connect(function() win.Visible = false end)

local menuVis=true
UIS.InputBegan:Connect(function(i,g)
    if g then return end
    if i.KeyCode==Enum.KeyCode.RightShift then menuVis=not menuVis; win.Visible=menuVis end
end)

_G.abaInitDone = true
end

print("[ABA v13 pasted] — Zero Stun, Combo Escape, Auto Block, Hitbox Dodge, Black Flash, Speed, Anti-Fling")
