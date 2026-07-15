-- ABA Script Menu v12
-- RShift = toggle menu visibility

local plr = game.Players.LocalPlayer
local playerGui = plr:WaitForChild("PlayerGui")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local cam = workspace.CurrentCamera

-- ============================================================
-- CLEANUP (always clear old connections; keep GUI/flags on re-run)
-- ============================================================
if _G.abaConns then for _,c in ipairs(_G.abaConns) do pcall(function() c:Disconnect() end) end end
_G.abaConns = {}
if _G.abaLockHL then pcall(function() _G.abaLockHL:Destroy() end) end
local old = playerGui:FindFirstChild("ABAMenu"); if old then old:Destroy() end

-- ============================================================
-- FEATURE FLAGS (preserve across re-executions)
-- ============================================================
if _G.abaInitDone ~= true then
    _G.abaStunEnabled  = false
    _G.abaSpeedEnabled = false
    _G.abaBlackFlashEnabled = false
    _G.abaAntiFlingEnabled = false
    _G.abaComboPauseEnabled = false
    _G.abaSkillPauseDuration = 0.8
    _G.abaClickPauseDuration = 0.4
    _G.abaTpKeybind = _G.abaTpKeybind or { type="key", code=Enum.KeyCode.T }
end
SPEED = 22  -- global so slider can update it
local lastSkillTime = 0
local lastClickTime = 0
local zeroStunSV = nil

-- Track skill keys (1, 2, 3, 4, Q) and clicks (LMB)
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
-- ZERO STUN
-- Strategy: destroy ALL physics objects on our HRP instantly + zero assembly velocity.
-- Our own combo forces apply to the ENEMY's HRP server-side, never our own, so this is safe.
-- Heartbeat runs every frame for maximum coverage.
-- ============================================================

local STUN_CLASSES = {
    BodyVelocity=true, BodyPosition=true, BodyGyro=true, BodyAngularVelocity=true,
    BodyForce=true, LinearVelocity=true, AngularVelocity=true,
    VectorForce=true, AlignPosition=true, AlignOrientation=true,
    Attachment=false, -- don't destroy attachments, game needs those
}

local function nukeHRP(hrp)
    if not hrp then return end
    -- Zero velocity FIRST before destroying so there's no 1-frame fling
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

local charConns = {}  -- per-character connections, cleared on each respawn

local function clearCharConns()
    for _, c in ipairs(charConns) do pcall(function() c:Disconnect() end) end
    charConns = {}
end

local activeMoveAnimations = {}

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
            
            -- Explicitly allow Might Guy's Dynamic Entry animations or animations simply named "animation"
            if string.find(animId, "1461128166") or string.find(animId, "7324112923") or name == "animation" then
                return true
            end
            
            -- Ignore standard Roblox movement/idle animations
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
-- LEGIT STUN BYPASS UTILS
-- ============================================================
local function triggerDesyncSlide(hrp)
    if not hrp then return end
    pcall(function()
        if hrp:FindFirstChild("LagDesync") then return end
        
        local bp = Instance.new("BodyVelocity")
        bp.Name = "LagDesync"
        bp.MaxForce = Vector3.new(100000, 0, 100000) -- horizontal only
        
        -- Choose sliding direction: backwards relative to current face direction,
        -- plus a slight random horizontal offset for desync feel.
        local backDir = -hrp.CFrame.LookVector
        local sideDir = hrp.CFrame.RightVector * (math.random(-5, 5) / 10)
        local slideDir = (backDir + sideDir).Unit
        
        bp.Velocity = slideDir * math.random(15, 20)
        bp.Parent = hrp
        
        task.spawn(function()
            -- Slide for 0.18 to 0.26 seconds
            task.wait(math.random(18, 26) / 100)
            bp:Destroy()
        end)
    end)
end

local function checkAndRecoverStun(hum, hrp)
    if not _G.abaStunEnabled then return end
    if isMoveAnimationPlaying() then return end
    if _G.abaComboPauseEnabled and (os.clock() - lastSkillTime < _G.abaSkillPauseDuration or os.clock() - lastClickTime < _G.abaClickPauseDuration) then return end
    
    local now = os.clock()
    if _G.stunReleaseTime and now < _G.stunReleaseTime then
        return -- let the hit/knockback play out naturally
    end
    
    -- Only bypass/recover if player is trying to input an action:
    -- 1) they are pressing movement keys (MoveDirection > 0)
    -- 2) they are holding block (F key) or jump (Space)
    -- 3) they recently clicked or used skills
    local isTryingToAct = false
    if hum.MoveDirection.Magnitude > 0 then
        isTryingToAct = true
    elseif UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.F) then
        isTryingToAct = true
    elseif now - lastClickTime < 0.6 or now - lastSkillTime < 1.0 then
        isTryingToAct = true
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
        
        -- If we were being comboed, trigger a lag slip/desync slide
        if wasStunned and _G.comboHits and _G.comboHits >= 2 then
            triggerDesyncSlide(hrp)
            _G.comboHits = 0 -- reset combo hits after escape
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

    -- Hook animations played on the humanoid/animator
    local animator = hum:FindFirstChildOfClass("Animator") or hum
    table.insert(charConns, animator.AnimationPlayed:Connect(function(track)
        local now = os.clock()
        local name = string.lower(track.Name or "")
        local animId = track.Animation and track.Animation.AnimationId or ""
        
        -- Detect if move/skill animation started within 1.0 second of pressing a skill key OR clicking M1
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
                if string.find(name, ignore) then
                    isIgnore = true
                    break
                end
            end
            
            if not isIgnore then
                print("[ABA Move Detector] Active skill animation detected: " .. (track.Name or "Unknown") .. " | ID: " .. tostring(animId))
                activeMoveAnimations[track] = true
                
                -- Track when it stops
                local stopConn
                stopConn = track.Stopped:Connect(function()
                    activeMoveAnimations[track] = nil
                    if stopConn then stopConn:Disconnect() end
                    print("[ABA Move Detector] Move animation finished: " .. (track.Name or "Unknown"))
                end)
                table.insert(charConns, stopConn)
            end
        end
    end))

    -- Track health changes to count combo hits and define a stun duration delay
    local lastHealth = hum.Health
    table.insert(charConns, hum.HealthChanged:Connect(function(health)
        if health < lastHealth then
            local now = os.clock()
            if now - (_G.lastDamageTime or 0) < 2.0 then
                _G.comboHits = (_G.comboHits or 0) + 1
            else
                _G.comboHits = 1
            end
            _G.lastDamageTime = now
            -- Flinch/Stun window: let the game stun us for 0.22s to 0.38s
            if not _G.stunReleaseTime or now > _G.stunReleaseTime then
                _G.stunReleaseTime = now + (math.random(22, 38) / 100)
            end
        end
        lastHealth = health
    end))

    local function onStunDetected()
        local now = os.clock()
        if not _G.stunReleaseTime or now > _G.stunReleaseTime then
            _G.stunReleaseTime = now + (math.random(22, 38) / 100)
        end
        checkAndRecoverStun(hum, hrp)
    end

    -- React the instant any stun property is set
    table.insert(charConns, hum.Changed:Connect(function(p)
        if not _G.abaStunEnabled then return end
        if isMoveAnimationPlaying() then return end
        if p == "WalkSpeed" or p == "JumpPower" or p == "PlatformStand" or p == "Sit" then
            if hum.WalkSpeed < 5 or hum.PlatformStand or hum.Sit then
                onStunDetected()
            end
        end
    end))

    -- Destroy physics stun objects the instant they land on our HRP (after the delay)
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

-- Shared: strip physics from all mover parts + HRP
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

local function fullRecover(hum, hrp)
    if not hum or not hrp then return end
    stripAllStunPhysics(hrp)
    pcall(function() hrp.AssemblyLinearVelocity = Vector3.new(0, math.min(hrp.AssemblyLinearVelocity.Y, 0), 0) end)
    pcall(function() hrp.AssemblyAngularVelocity = Vector3.zero end)
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    hum.PlatformStand = false
    hum.Sit = false
    hum.AutoRotate = true
    if hum.WalkSpeed <= 0 then hum.WalkSpeed = _G.abaSpeedEnabled and SPEED or 16 end
    if hum.JumpPower <= 0 then hum.JumpPower = 50 end
end



local lastSafeCFrame = nil

-- Heartbeat: runs EVERY frame — absolute coverage
table.insert(_G.abaConns, RS.Heartbeat:Connect(function()
    _G.__hbCount = (_G.__hbCount or 0) + 1
    local char = plr.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- ================================================================
    -- ANTI-FLING — recover from clipping / velocity spike flings
    -- ================================================================
    if _G.abaAntiFlingEnabled and not isMoveAnimationPlaying() then
        local vel = hrp.AssemblyLinearVelocity
        local ang = hrp.AssemblyAngularVelocity
        if vel.Magnitude > 150 or ang.Magnitude > 150 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if lastSafeCFrame then
                hrp.CFrame = lastSafeCFrame
            end
        else
            if vel.Magnitude < 70 and ang.Magnitude < 70 then
                lastSafeCFrame = hrp.CFrame
            end
        end
    end


    -- ================================================================
    -- SMART STUN RECOVERY (heartbeat portion)
    -- ================================================================
    checkAndRecoverStun(hum, hrp)
end))



local function hookMatchEnd()
    local playWinMusic = game.ReplicatedStorage:FindFirstChild("PlayWinMusic")
    if playWinMusic then
        table.insert(_G.abaConns, playWinMusic.OnClientEvent:Connect(function()
            if zeroStunSV then
                zeroStunSV(false)
            else
                _G.abaStunEnabled = false
            end
            print("[ABA] Match ended, Zero Stun disabled.")
        end))
    end
end

setupStunBypass()
hookTimeStop()
hookMatchEnd()
-- Re-hook on every respawn immediately — no task.wait so hooks are live from frame 1
table.insert(_G.abaConns, plr.CharacterAdded:Connect(function(char)
    -- Wait for HumanoidRootPart and Humanoid to exist before hooking
    char:WaitForChild("HumanoidRootPart", 10)
    char:WaitForChild("Humanoid", 10)
    setupStunBypass()
    -- Also immediately restore state if features are on
    if _G.abaStunEnabled or _G.abaSpeedEnabled then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then restoreHumanoid(hum) end
    end
end))

-- ============================================================
-- SPEED BOOST
-- Heartbeat enforces speed every frame. CharacterAdded above handles respawn.
-- ============================================================
table.insert(_G.abaConns, RS.Heartbeat:Connect(function()
    if not _G.abaSpeedEnabled then return end
    local char = plr.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed > 0 and hum.WalkSpeed ~= SPEED then
        hum.WalkSpeed = SPEED
    end
end))

-- ============================================================
-- AUTO BLACK FLASH (Yuji Itadori)
-- The server calls BlackFlashCheck:InvokeClient(windowSize, precision)
-- to ask if the player timed the Black Flash input correctly.
-- We hook OnClientInvoke to always return true = guaranteed BF every hit.
-- ============================================================
local _bfOriginalHandler = nil  -- stores original handler if we need to restore
local _bfHooked = false

local function enableBlackFlash()
    if _bfHooked then return end
    local bfc = game.ReplicatedStorage:FindFirstChild("BlackFlashCheck")
    if not bfc then
        warn("[AutoBF] BlackFlashCheck RemoteFunction not found in ReplicatedStorage")
        return
    end
    -- Override the OnClientInvoke callback
    -- Server sends (windowSize, precision) — we always return true
    bfc.OnClientInvoke = function(...)
        if _G.abaBlackFlashEnabled then
            return true
        end
        -- If disabled mid-flight, return false (miss)
        return false
    end
    _bfHooked = true
    print("[AutoBF] Hooked — every M1 hit will trigger Black Flash")
end

local function disableBlackFlash()
    -- We can't easily restore the original obfuscated handler,
    -- but the flag check inside the hook handles enable/disable cleanly.
    -- The hook returns false when disabled, so it acts like a normal miss.
    _G.abaBlackFlashEnabled = false
    print("[AutoBF] Disabled — Black Flash back to normal timing")
end

-- ============================================================
-- HITBOX EXPANDER
-- Two-pronged approach:
-- 1) CFrame lunge on M1: teleport our HRP toward nearest enemy for 2 frames
--    so the server's magnitude-based hit check passes, then snap back.
-- 2) Hook GetPartDistance: return reduced distance for ability/skill checks.


-- ============================================================
-- LOCK-ON — custom bind, HOLD or TOGGLE mode
-- Supports ALL keyboard keys AND mouse buttons (LMB, RMB, MMB)
-- ============================================================
_G.abaLockHL  = nil
local lockTarget    = nil
local lockActive    = false
local lockMode      = "HOLD"  -- "HOLD" or "TOGGLE"
local lockBind      = nil     -- { type="key", code=Enum.KeyCode.X } or { type="mouse", inputType=... / inputTypeName=... }
local bindListening = false
local bindListenConns = {}
-- callback so the GUI button can update when mode changes from code
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
            -- Player check: skip NPCs / Dummies that aren't real Players
            local cp = game.Players:GetPlayerFromCharacter(c)
            if not cp then continue end
            -- Team check: skip teammates
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
    -- Pick target at the moment of activation — stays locked until deactivated
    if not lockActive then
        setLockTarget(getNearestToMouse())
    end
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
    -- If current target died or left, pick the next nearest automatically
    if not lockTarget or not lockTarget.Parent then
        setLockTarget(getNearestToMouse())
    end
    if not lockTarget then return end
    local tHRP = lockTarget:FindFirstChild("HumanoidRootPart"); if not tHRP then return end
    local tHum = lockTarget:FindFirstChildOfClass("Humanoid")
    -- If target is dead, pick next
    if tHum and tHum.Health <= 0 then
        setLockTarget(getNearestToMouse()); return
    end
    local dir = (tHRP.Position - myHRP.Position) * Vector3.new(1,0,1)
    if dir.Magnitude > 0.5 then myHRP.CFrame = CFrame.new(myHRP.Position, myHRP.Position + dir.Unit) end
    cam.CFrame = CFrame.new(myHRP.Position + Vector3.new(0,3,0), tHRP.Position + Vector3.new(0,2,0))
end))

-- Current bind connections
local bindConns = {}
local function clearBindConns()
    for _, c in ipairs(bindConns) do pcall(function() c:Disconnect() end) end
    bindConns = {}
end

-- Check if an InputObject matches the current bind
local function inputMatchesBind(inp, bind)
    if not bind then return false end
    if bind.type == "key" then
        return inp.KeyCode == bind.code
    elseif bind.type == "mouse" then
        local typeName = tostring(inp.UserInputType):gsub("Enum%.UserInputType%.", "")
        if bind.inputTypeName then
            return typeName == bind.inputTypeName
        else
            return inp.UserInputType == bind.inputType
        end
    end
    return false
end

local function applyBind(bind)
    clearBindConns()
    lockBind = bind
    table.insert(bindConns, UIS.InputBegan:Connect(function(inp, gpe)
        if gpe then return end
        if not inputMatchesBind(inp, lockBind) then return end
        if lockMode == "HOLD" then
            startLock()
        else -- TOGGLE: off→lock, on→unlock
            if lockActive then stopLock() else startLock() end
        end
    end))
    table.insert(bindConns, UIS.InputEnded:Connect(function(inp)
        if lockMode ~= "HOLD" then return end -- TOGGLE ignores release
        if inputMatchesBind(inp, lockBind) then stopLock() end
    end))
end

-- Default bind: E key
applyBind({ type="key", code=Enum.KeyCode.E })

-- Key name helper
-- MB4/MB5 don't exist in Enum.UserInputType, so we match by name string at runtime
local mouseTypeNames = {
    [Enum.UserInputType.MouseButton1] = "LMB",
    [Enum.UserInputType.MouseButton2] = "RMB",
    [Enum.UserInputType.MouseButton3] = "MMB",
    ["MouseButton4"] = "MB4",
    ["MouseButton5"] = "MB5",
}
local function getBindLabel(bind)
    if not bind then return "None" end
    if bind.type == "key" then
        local s = tostring(bind.code)
        return s:gsub("Enum%.KeyCode%.", "")
    elseif bind.type == "mouse" then
        if bind.inputTypeName then
            return mouseTypeNames[bind.inputTypeName] or bind.inputTypeName
        end
        return mouseTypeNames[bind.inputType] or "Mouse"
    end
    return "?"
end



local W=450; local TITLE_H=40; local ROW_H=40; local SLIDER_H=28; local PAD=10
do -- GUI block (always rebuilt on re-execution)

local TW=TweenInfo.new(0.15, Enum.EasingStyle.Quad)

local function mkF(p,sz,pos,col,r)
    local f=Instance.new("Frame",p); f.Size=sz; f.Position=pos
    f.BackgroundColor3=col; f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,r or 8); return f
end

local sg = Instance.new("ScreenGui")
sg.Name="ABAMenu"; sg.ResetOnSpawn=false
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.Parent=playerGui

local win = mkF(sg,UDim2.new(0,W,0,330),UDim2.new(0.5,-W/2,0.5,-165),Color3.fromRGB(12,12,12),10)
win.Active=true; win.Draggable=true
local ws=Instance.new("UIStroke",win); ws.Color=Color3.fromRGB(48,48,48); ws.Thickness=1

-- Title bar
local tbar=mkF(win,UDim2.new(1,0,0,TITLE_H),UDim2.new(0,0,0,0),Color3.fromRGB(18,18,18),10)
local tp=Instance.new("Frame",tbar); tp.Size=UDim2.new(1,0,0,10); tp.Position=UDim2.new(0,0,1,-10)
tp.BackgroundColor3=Color3.fromRGB(18,18,18); tp.BorderSizePixel=0
local tl=Instance.new("TextLabel",tbar); tl.Size=UDim2.new(1,-50,1,0); tl.Position=UDim2.new(0,14,0,0)
tl.BackgroundTransparency=1; tl.Text="✦  ABA Scripts Premium"; tl.Font=Enum.Font.GothamBold
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
tLayout.Padding = UDim.new(0, 6)
tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local tabButtons = {}
local tabFrames = {}

local function createTabFrame(parent)
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.Position = UDim2.new(0, 0, 0, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.ScrollBarThickness = 4
    sf.ScrollBarImageColor3 = Color3.fromRGB(60,60,60)
    sf.Parent = parent
    
    local ll = Instance.new("UIListLayout", sf)
    ll.Padding = UDim.new(0, 6)
    ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
    
    local pad = Instance.new("UIPadding", sf)
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingBottom = UDim.new(0, 6)
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    
    local function updateCanvas()
        sf.CanvasSize = UDim2.new(0, 0, 0, ll.AbsoluteContentSize.Y + 12)
    end
    ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
    task.spawn(updateCanvas)
    
    return sf
end

local function addTab(name)
    local btn = Instance.new("TextButton", tabsBar)
    btn.Size = UDim2.new(0, 130, 0, 24)
    btn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(140, 140, 140)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(35, 35, 35)
    stroke.Thickness = 1
    
    local container = mkF(win, UDim2.new(1, -20, 1, -TITLE_H - 78), UDim2.new(0, 10, 0, TITLE_H + 48), Color3.fromRGB(12, 12, 12), 0)
    container.BackgroundTransparency = 1
    container.Visible = false
    
    local sf = createTabFrame(container)
    
    btn.MouseButton1Click:Connect(function()
        for tName, tBtn in pairs(tabButtons) do
            tBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
            tBtn.TextColor3 = Color3.fromRGB(140, 140, 140)
            tabFrames[tName].Visible = false
        end
        btn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        container.Visible = true
    end)
    
    tabButtons[name] = btn
    tabFrames[name] = container
    return sf
end

local combatTab = addTab("Combat")
local extrasTab = addTab("Extras")
local settingsTab = addTab("Settings")

-- Select Combat by default
tabButtons["Combat"].BackgroundColor3 = Color3.fromRGB(200, 40, 40)
tabButtons["Combat"].TextColor3 = Color3.fromRGB(255, 255, 255)
tabFrames["Combat"].Visible = true

-- Slider row — draggable bar with live value label
local isDraggingSlider = false  -- shared flag to block window drag

local function buildSlider(parent, labelText, min, max, default, decimals, onChange)
    local row = mkF(parent, UDim2.new(1,-10,0,SLIDER_H), UDim2.new(0,0,0,0), Color3.fromRGB(16,16,16), 7)
    Instance.new("UIStroke",row).Color = Color3.fromRGB(35,35,35)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(0,110,1,0); lbl.Position = UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency = 1; lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11
    lbl.TextColor3 = Color3.fromRGB(160,160,160); lbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size = UDim2.new(0,38,1,0); valLbl.Position = UDim2.new(1,-44,0,0)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Enum.Font.GothamBold; valLbl.TextSize = 11
    valLbl.TextColor3 = Color3.fromRGB(220,220,220); valLbl.TextXAlignment = Enum.TextXAlignment.Right

    -- Track
    local trackBg = mkF(row, UDim2.new(1,-174,0,6), UDim2.new(0,120,0.5,-3), Color3.fromRGB(35,35,35), 99)
    local fill = mkF(trackBg, UDim2.new(0,0,1,0), UDim2.new(0,0,0,0), Color3.fromRGB(200,40,40), 99)
    local knob = mkF(trackBg, UDim2.new(0,14,0,14), UDim2.new(0,0,0.5,-7), Color3.fromRGB(255,255,255), 99)
    local trackBtn = Instance.new("TextButton", trackBg)
    trackBtn.Size = UDim2.new(1,0,1,20); trackBtn.Position = UDim2.new(0,0,0,-7)
    trackBtn.BackgroundTransparency = 1; trackBtn.Text = ""; trackBtn.ZIndex = 5

    local currentVal = default
    local dragging = false

    local function applyPos(mouseX)
        local absX = trackBg.AbsolutePosition.X
        local absW = trackBg.AbsoluteSize.X
        if absW == 0 then absW = 1 end
        local t = math.clamp((mouseX - absX) / absW, 0, 1)
        local v = min + t * (max - min)
        v = decimals and math.floor(v*10+0.5)/10 or math.floor(v+0.5)
        v = math.clamp(v, min, max)
        currentVal = v
        local ft = (v - min) / (max - min)
        fill.Size = UDim2.new(ft, 0, 1, 0)
        knob.Position = UDim2.new(ft, -7, 0.5, -7)
        valLbl.Text = tostring(v)
        onChange(v)
    end

    task.spawn(function()
        task.wait()
        applyPos(trackBg.AbsolutePosition.X + (default - min)/(max - min) * trackBg.AbsoluteSize.X)
    end)

    trackBtn.MouseButton1Down:Connect(function()
        dragging = true
        isDraggingSlider = true
        win.Draggable = false
        local mouse = plr:GetMouse()
        applyPos(mouse.X)
    end)

    table.insert(_G.abaConns, RS.Heartbeat:Connect(function()
        if not dragging then return end
        local mouse = plr:GetMouse()
        applyPos(mouse.X)
    end))

    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
            dragging = false
            isDraggingSlider = false
            win.Draggable = true
        end
    end)

    return function(v) 
        applyPos(trackBg.AbsolutePosition.X + (v - min)/(max - min) * trackBg.AbsoluteSize.X) 
    end
end

-- Toggle row
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
-- LOCK-ON ROW WITH CUSTOM BIND + HOLD/TOGGLE MODE
-- ============================================================
local function buildLockOnRow(parent)
    local row=mkF(parent,UDim2.new(1,-10,0,ROW_H),UDim2.new(0,0,0,0),Color3.fromRGB(22,22,22),7)
    Instance.new("UIStroke",row).Color=Color3.fromRGB(40,40,40)
    local dot=mkF(row,UDim2.new(0,8,0,8),UDim2.new(0,10,0.5,-4),Color3.fromRGB(60,60,60),99)

    -- Label
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-200,1,0)
    lbl.Position=UDim2.new(0,24,0,0); lbl.BackgroundTransparency=1; lbl.Text="Lock-On"
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=13; lbl.TextColor3=Color3.fromRGB(210,210,210)
    lbl.TextXAlignment=Enum.TextXAlignment.Left

    -- Bind button (shows current bind, click to rebind)
    -- rightmost: mode btn (56px) + gap(4) + bind btn (60px) + gap(6) = offset 126
    local bindBtn=Instance.new("TextButton",row); bindBtn.Size=UDim2.new(0,60,0,26)
    bindBtn.Position=UDim2.new(1,-130,0.5,-13); bindBtn.BackgroundColor3=Color3.fromRGB(35,35,35)
    bindBtn.BorderSizePixel=0; bindBtn.Text="["..getBindLabel(lockBind).."]"
    bindBtn.TextColor3=Color3.fromRGB(160,160,160); bindBtn.Font=Enum.Font.GothamBold; bindBtn.TextSize=11
    Instance.new("UICorner",bindBtn).CornerRadius=UDim.new(0,5)
    local bstroke=Instance.new("UIStroke",bindBtn); bstroke.Color=Color3.fromRGB(55,55,55); bstroke.Thickness=1

    -- Mode button (HOLD / TOGGLE)
    local modeBtn=Instance.new("TextButton",row); modeBtn.Size=UDim2.new(0,58,0,26)
    modeBtn.Position=UDim2.new(1,-66,0.5,-13); modeBtn.BackgroundColor3=Color3.fromRGB(35,35,35)
    modeBtn.BorderSizePixel=0; modeBtn.Text="HOLD"
    modeBtn.TextColor3=Color3.fromRGB(200,200,200); modeBtn.Font=Enum.Font.GothamBold; modeBtn.TextSize=11
    Instance.new("UICorner",modeBtn).CornerRadius=UDim.new(0,5)
    local mstroke=Instance.new("UIStroke",modeBtn); mstroke.Color=Color3.fromRGB(55,55,55); mstroke.Thickness=1

    local function refreshModeBtn()
        local isToggle = lockMode == "TOGGLE"
        modeBtn.Text = lockMode
        -- same appearance in both modes
        modeBtn.BackgroundColor3 = Color3.fromRGB(35,35,35)
        modeBtn.TextColor3 = Color3.fromRGB(200,200,200)
        if not isToggle and lockActive then stopLock() end
    end

    -- register callback so external code can refresh
    onLockModeChanged = refreshModeBtn

    modeBtn.MouseButton1Click:Connect(function()
        lockMode = lockMode == "HOLD" and "TOGGLE" or "HOLD"
        -- re-apply bind so InputEnded behaviour updates correctly
        applyBind(lockBind)
        refreshModeBtn()
    end)

    -- Listening overlay (shown when waiting for bind input)
    local overlay=mkF(row,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(15,15,15),7)
    overlay.Visible=false; overlay.ZIndex=10
    Instance.new("UICorner",overlay).CornerRadius=UDim.new(0,7)
    local ovLbl=Instance.new("TextLabel",overlay); ovLbl.Size=UDim2.new(1,0,1,0)
    ovLbl.BackgroundTransparency=1; ovLbl.Text="Press any key or mouse button..."
    ovLbl.TextColor3=Color3.fromRGB(255,200,50); ovLbl.Font=Enum.Font.GothamBold; ovLbl.TextSize=11
    ovLbl.TextXAlignment=Enum.TextXAlignment.Center

    local function stopListening()
        if not bindListening then return end
        bindListening = false
        for _, c in ipairs(bindListenConns) do pcall(function() c:Disconnect() end) end
        bindListenConns = {}
        overlay.Visible = false
        bindBtn.TextColor3 = Color3.fromRGB(160,160,160)
        bstroke.Color = Color3.fromRGB(55,55,55)
    end

    local function startListening()
        if bindListening then stopListening(); return end
        bindListening = true
        overlay.Visible = true
        bindBtn.TextColor3 = Color3.fromRGB(255,200,50)
        bstroke.Color = Color3.fromRGB(255,200,50)

        table.insert(bindListenConns, UIS.InputBegan:Connect(function(inp, gpe)
            if not bindListening then return end
            if inp.KeyCode == Enum.KeyCode.Escape then stopListening(); return end
            -- Keyboard key
            if inp.KeyCode ~= Enum.KeyCode.Unknown then
                local bind = { type="key", code=inp.KeyCode }
                applyBind(bind)
                bindBtn.Text = "["..getBindLabel(bind).."]"
                stopListening(); return
            end
            -- Mouse buttons
            local typeName = tostring(inp.UserInputType):gsub("Enum%.UserInputType%.", "")
            local namedMouse = { "MouseButton1", "MouseButton2", "MouseButton3", "MouseButton4", "MouseButton5" }
            for _, name in ipairs(namedMouse) do
                if typeName == name then
                    local bind
                    if name == "MouseButton1" then
                        bind = { type="mouse", inputType=Enum.UserInputType.MouseButton1 }
                    elseif name == "MouseButton2" then
                        bind = { type="mouse", inputType=Enum.UserInputType.MouseButton2 }
                    elseif name == "MouseButton3" then
                        bind = { type="mouse", inputType=Enum.UserInputType.MouseButton3 }
                    else
                        bind = { type="mouse", inputTypeName=name }
                    end
                    applyBind(bind)
                    bindBtn.Text = "["..getBindLabel(bind).."]"
                    stopListening(); return
                end
            end
        end))
    end

    bindBtn.MouseButton1Click:Connect(startListening)
    local ovBtn=Instance.new("TextButton",overlay); ovBtn.Size=UDim2.new(1,0,1,0)
    ovBtn.BackgroundTransparency=1; ovBtn.Text=""; ovBtn.ZIndex=11
    ovBtn.MouseButton1Click:Connect(stopListening)

    -- Keep dot in sync with lockActive for TOGGLE mode (heartbeat checks)
    table.insert(_G.abaConns, RS.Heartbeat:Connect(function()
        if lockMode ~= "TOGGLE" then return end
        local c = lockActive and Color3.fromRGB(80,220,80) or Color3.fromRGB(60,60,60)
        if dot.BackgroundColor3 ~= c then dot.BackgroundColor3 = c end
    end))
end

local tpBindListening = false
local tpBindListenConns = {}
local function buildTpBindRow(parent)
    local row=mkF(parent,UDim2.new(1,-10,0,ROW_H),UDim2.new(0,0,0,0),Color3.fromRGB(22,22,22),7)
    Instance.new("UIStroke",row).Color=Color3.fromRGB(40,40,40)
    
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-100,1,0)
    lbl.Position=UDim2.new(0,10,0,0); lbl.BackgroundTransparency=1; lbl.Text="TP Behind Keybind"
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=13; lbl.TextColor3=Color3.fromRGB(210,210,210)
    lbl.TextXAlignment=Enum.TextXAlignment.Left

    local bindBtn=Instance.new("TextButton",row); bindBtn.Size=UDim2.new(0,60,0,26)
    bindBtn.Position=UDim2.new(1,-70,0.5,-13); bindBtn.BackgroundColor3=Color3.fromRGB(35,35,35)
    bindBtn.BorderSizePixel=0; bindBtn.Text="["..getBindLabel(_G.abaTpKeybind).."]"
    bindBtn.TextColor3=Color3.fromRGB(160,160,160); bindBtn.Font=Enum.Font.GothamBold; bindBtn.TextSize=11
    Instance.new("UICorner",bindBtn).CornerRadius=UDim.new(0,5)
    local bstroke=Instance.new("UIStroke",bindBtn); bstroke.Color=Color3.fromRGB(55,55,55); bstroke.Thickness=1

    local overlay=mkF(row,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(15,15,15),7)
    overlay.Visible=false; overlay.ZIndex=10
    Instance.new("UICorner",overlay).CornerRadius=UDim.new(0,7)
    local ovLbl=Instance.new("TextLabel",overlay); ovLbl.Size=UDim2.new(1,0,1,0)
    ovLbl.BackgroundTransparency=1; ovLbl.Text="Press any key..."
    ovLbl.TextColor3=Color3.fromRGB(255,200,50); ovLbl.Font=Enum.Font.GothamBold; ovLbl.TextSize=11
    
    local function stopListening()
        tpBindListening = false
        for _, c in ipairs(tpBindListenConns) do pcall(function() c:Disconnect() end) end
        tpBindListenConns = {}
        overlay.Visible = false
        bindBtn.TextColor3 = Color3.fromRGB(160,160,160)
        bstroke.Color = Color3.fromRGB(55,55,55)
    end

    local function startListening()
        if tpBindListening then stopListening(); return end
        tpBindListening = true; overlay.Visible = true
        bindBtn.TextColor3 = Color3.fromRGB(255,200,50); bstroke.Color = Color3.fromRGB(255,200,50)

        table.insert(tpBindListenConns, UIS.InputBegan:Connect(function(inp, gpe)
            if not tpBindListening then return end
            if inp.KeyCode == Enum.KeyCode.Escape then stopListening(); return end
            if inp.KeyCode ~= Enum.KeyCode.Unknown then
                _G.abaTpKeybind = { type="key", code=inp.KeyCode }
                bindBtn.Text = "["..getBindLabel(_G.abaTpKeybind).."]"
                stopListening(); return
            end
            local typeName = tostring(inp.UserInputType):gsub("Enum%.UserInputType%.", "")
            local namedMouse = { "MouseButton1", "MouseButton2", "MouseButton3", "MouseButton4", "MouseButton5" }
            for _, name in ipairs(namedMouse) do
                if typeName == name then
                    if name == "MouseButton1" then _G.abaTpKeybind = { type="mouse", inputType=Enum.UserInputType.MouseButton1 }
                    elseif name == "MouseButton2" then _G.abaTpKeybind = { type="mouse", inputType=Enum.UserInputType.MouseButton2 }
                    elseif name == "MouseButton3" then _G.abaTpKeybind = { type="mouse", inputType=Enum.UserInputType.MouseButton3 }
                    else _G.abaTpKeybind = { type="mouse", inputTypeName=name } end
                    bindBtn.Text = "["..getBindLabel(_G.abaTpKeybind).."]"
                    stopListening(); return
                end
            end
        end))
    end

    bindBtn.MouseButton1Click:Connect(startListening)
    local ovBtn=Instance.new("TextButton",overlay); ovBtn.Size=UDim2.new(1,0,1,0)
    ovBtn.BackgroundTransparency=1; ovBtn.Text=""; ovBtn.ZIndex=11
    ovBtn.MouseButton1Click:Connect(stopListening)
end

table.insert(_G.abaConns, UIS.InputBegan:Connect(function(inp, gpe)
    if gpe or tpBindListening then return end
    if not lockActive or not lockTarget then return end
    
    local isMatch = false
    if _G.abaTpKeybind.type == "key" and inp.KeyCode == _G.abaTpKeybind.code then
        isMatch = true
    elseif _G.abaTpKeybind.type == "mouse" then
        if _G.abaTpKeybind.inputType and inp.UserInputType == _G.abaTpKeybind.inputType then
            isMatch = true
        elseif _G.abaTpKeybind.inputTypeName and tostring(inp.UserInputType) == "Enum.UserInputType.".._G.abaTpKeybind.inputTypeName then
            isMatch = true
        end
    end
    
    if isMatch then
        local myChar = plr.Character
        local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        local tHRP = lockTarget:FindFirstChild("HumanoidRootPart")
        if hrp and tHRP and hum then
            local dist = (tHRP.Position - hrp.Position).Magnitude
            if dist <= 30 then
                -- Cooldown: block if already dashing or on cooldown
                local now = os.clock()
                if _G._abaDashCooldown and now - _G._abaDashCooldown < 0.5 then return end
                if _G._abaDashing then return end
                _G._abaDashCooldown = now
                _G._abaDashing = true

                local flatLook = tHRP.CFrame.LookVector
                flatLook = Vector3.new(flatLook.X, 0, flatLook.Z).Unit
                if flatLook.Magnitude < 0.5 then flatLook = hrp.CFrame.LookVector end

                -- Duration scales with distance — matches real ABA dash timing
                -- ~0.2s for close range (5 studs), ~0.35s for max range (30 studs)
                local DASH_DURATION = math.clamp(0.15 + dist * 0.007, 0.2, 0.35)
                local ARC_HEIGHT = 0.4  -- very subtle, just enough to clear small terrain

                local startPos = hrp.Position
                local startTime = os.clock()
                local prevPos = startPos
                local dashConn

                -- Try to play a dash animation to sell it visually
                pcall(function()
                    local animator = hum:FindFirstChildOfClass("Animator")
                    if animator then
                        local dashAnim = Instance.new("Animation")
                        -- Generic Roblox dash/lunge animation
                        dashAnim.AnimationId = "rbxassetid://10469493270"
                        local track = animator:LoadAnimation(dashAnim)
                        track:Play(0.05, 1, 1.5)  -- fast fade-in, normal weight, 1.5x speed
                        -- Auto-cleanup after dash
                        task.delay(DASH_DURATION + 0.1, function()
                            pcall(function() track:Stop(0.1) end)
                            pcall(function() dashAnim:Destroy() end)
                        end)
                    end
                end)

                dashConn = RS.Heartbeat:Connect(function()
                    if not hrp or not hrp.Parent or not tHRP or not tHRP.Parent then
                        _G._abaDashing = false
                        if dashConn then dashConn:Disconnect() end
                        return
                    end

                    -- Re-read target each frame so we track a moving enemy
                    local freshLook = tHRP.CFrame.LookVector
                    freshLook = Vector3.new(freshLook.X, 0, freshLook.Z).Unit
                    if freshLook.Magnitude < 0.5 then freshLook = flatLook end
                    local behindPos = tHRP.Position - freshLook * 4.5
                    local targetCFrame = CFrame.lookAt(behindPos, tHRP.Position)

                    local elapsed = os.clock() - startTime
                    local alpha = math.clamp(elapsed / DASH_DURATION, 0, 1)

                    -- Cubic ease-in-out for natural accel/decel
                    local t = alpha < 0.5
                        and 4 * alpha * alpha * alpha
                        or  1 - (-2 * alpha + 2)^3 / 2

                    -- Tiny parabolic arc
                    local arcY = ARC_HEIGHT * 4 * t * (1 - t)
                    local arcOffset = Vector3.new(0, arcY, 0)

                    local lerpedPos = startPos:Lerp(targetCFrame.Position, t) + arcOffset
                    local lerpedCF = CFrame.lookAt(lerpedPos, tHRP.Position)

                    -- Set velocity to match actual per-frame movement delta (natural to server)
                    local delta = lerpedPos - prevPos
                    local dt = RS.Heartbeat:Wait() -- ~0.016
                    -- Don't divide by zero on first frame
                    if delta.Magnitude > 0.01 then
                        local naturalVel = delta / math.max(dt, 0.001)
                        -- Blend with current Y velocity so we don't fight gravity
                        hrp.AssemblyLinearVelocity = Vector3.new(naturalVel.X, hrp.AssemblyLinearVelocity.Y + arcY * 2, naturalVel.Z)
                    end
                    prevPos = lerpedPos

                    hrp.CFrame = lerpedCF

                    -- Dash complete
                    if alpha >= 1 then
                        hrp.CFrame = targetCFrame
                        -- Bleed off velocity naturally over a few frames instead of zeroing
                        task.spawn(function()
                            for i = 1, 4 do
                                if not hrp or not hrp.Parent then break end
                                local cur = hrp.AssemblyLinearVelocity
                                hrp.AssemblyLinearVelocity = Vector3.new(cur.X * 0.4, cur.Y, cur.Z * 0.4)
                                task.wait()
                            end
                        end)
                        _G._abaDashing = false
                        dashConn:Disconnect()
                    end
                end)
            end
        end
    end
end))

-- ============================================================
-- BUILD ROWS
-- ============================================================
zeroStunSV = buildToggle(combatTab, "Zero Stun",
    function()
        _G.abaStunEnabled = true
        local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed=16; hum.JumpPower=50; hum.PlatformStand=false end
        print("[ABA] Zero Stun ON")
    end,
    function() _G.abaStunEnabled=false; print("[ABA] Zero Stun OFF") end)

buildToggle(combatTab, "Combo Pause",
    function()
        _G.abaComboPauseEnabled = true
        print("[ABA] Combo Pause ON")
    end,
    function()
        _G.abaComboPauseEnabled = false
        print("[ABA] Combo Pause OFF")
    end)



buildToggle(combatTab, "Anti-Fling",
    function()
        _G.abaAntiFlingEnabled = true
        print("[ABA] Anti-Fling ON")
    end,
    function()
        _G.abaAntiFlingEnabled = false
        print("[ABA] Anti-Fling OFF")
    end)

buildToggle(combatTab, "Speed Boost",
    function()
        _G.abaSpeedEnabled = true
        local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed > 0 then hum.WalkSpeed=SPEED end
        print("[ABA] Speed Boost ON")
    end,
    function()
        _G.abaSpeedEnabled = false
        local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed=16 end
        print("[ABA] Speed Boost OFF")
    end)

buildToggle(extrasTab, "Auto Black Flash",
    function()
        _G.abaBlackFlashEnabled = true
        enableBlackFlash()
        print("[ABA] Auto Black Flash ON")
    end,
    function()
        disableBlackFlash()
        print("[ABA] Auto Black Flash OFF")
    end)



buildLockOnRow(extrasTab)
buildTpBindRow(extrasTab)

buildToggle(extrasTab, "Stream Mode",
    function()
        print("[ABA] Stream Mode ON - Hiding Menu (Press RightShift to show)")
        win.Visible = false
    end,
    function()
        print("[ABA] Stream Mode OFF")
    end)

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
hint.Text = "RShift = Toggle Menu Visibility | Click \"–\" to hide menu"
hint.TextColor3 = Color3.fromRGB(58, 58, 58)
hint.Font = Enum.Font.Gotham
hint.TextSize = 10
hint.TextXAlignment = Enum.TextXAlignment.Center

-- RSHIFT / CLOSE
colBtn.MouseButton1Click:Connect(function()
    win.Visible = false
end)

local menuVis=true
UIS.InputBegan:Connect(function(i,g)
    if g then return end
    if i.KeyCode==Enum.KeyCode.RightShift then menuVis=not menuVis; win.Visible=menuVis end
end)

_G.abaInitDone = true
end  -- GUI block

print("[ABA v21] Ready — Zero Stun, Speed, Black Flash, Hitbox, Lock-On, Anti-Fling")
