-- ABA Script v13 — pasted edition
-- RShift = toggle menu visibility
-- Features: Zero Stun, Combo Escape, Auto Block, Hitbox Dodge, Lock-On, TP Behind, Black Flash, Speed, Anti-Fling

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
    _G.abaComboEscapeEnabled = false
    _G.abaAutoBlockEnabled = false
    _G.abaHitboxDodgeEnabled = false
    _G.abaSkillPauseDuration = 0.8
    _G.abaClickPauseDuration = 0.4
    _G.abaTpKeybind = _G.abaTpKeybind or { type="key", code=Enum.KeyCode.T }
end
SPEED = 22
local lastSkillTime = 0
local lastClickTime = 0
local zeroStunSV = nil

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
        if STUN_CLASSES[v.ClassName] then pcall(function() v:Destroy() end) end
    end
end

local function restoreHumanoid(hum)
    if not hum then return end
    hum.WalkSpeed = _G.abaSpeedEnabled and SPEED or 16
    hum.JumpPower = 50
    hum.PlatformStand = false
    hum.Sit = false
end

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
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local name = string.lower(track.Name or "")
            local animId = track.Animation and tostring(track.Animation.AnimationId) or ""
            if string.find(animId, "1461128166") or string.find(animId, "7324112923") or name == "animation" then return true end
            local isMovement = string.find(name, "idle") or string.find(name, "walk") or string.find(name, "run") or string.find(name, "jump") 
                or string.find(name, "fall") or string.find(name, "climb") or string.find(name, "swim") or string.find(name, "sit") 
                or string.find(name, "toolnone")
            if not isMovement and track.Length > 0 then return true end
        end
    end
    return false
end

-- ============================================================
-- COMBO ESCAPE SLIDE
-- ============================================================
local function triggerDesyncSlide(hrp, intensity)
    if not hrp then return end
    pcall(function()
        if hrp:FindFirstChild("LagDesync") then return end

        -- Find direction AWAY from nearest enemy
        local myPos = hrp.Position
        local myTeam = plr.Team
        local live = workspace:FindFirstChild("Live")
        local nearestEnemy, nearestDist = nil, math.huge
        if live then
            for _, c in ipairs(live:GetChildren()) do
                local cp = game.Players:GetPlayerFromCharacter(c)
                if cp and cp ~= plr and (not myTeam or cp.Team ~= myTeam) then
                    local ehrp = c:FindFirstChild("HumanoidRootPart")
                    if ehrp then
                        local d = (ehrp.Position - myPos).Magnitude
                        if d < nearestDist then nearestDist = d; nearestEnemy = ehrp end
                    end
                end
            end
        end

        -- Push AWAY from nearest enemy (or backward if no enemy found)
        local awayDir
        if nearestEnemy then
            awayDir = (myPos - nearestEnemy.Position) * Vector3.new(1, 0, 1)
            if awayDir.Magnitude < 0.1 then awayDir = hrp.CFrame.LookVector end
            awayDir = awayDir.Unit
        else
            awayDir = -hrp.CFrame.LookVector
        end

        -- Add slight diagonal randomness so it doesn't look perfectly scripted
        local sideJitter = hrp.CFrame.RightVector * (math.random(-4, 4) / 10)
        awayDir = (awayDir + sideJitter).Unit

        local bp = Instance.new("BodyVelocity")
        bp.Name = "LagDesync"; bp.MaxForce = Vector3.new(500000, 0, 500000)
        bp.Velocity = awayDir * (18 + intensity * 5)  -- faster, further away
        bp.Parent = hrp
        task.spawn(function()
            task.wait(0.10 + intensity * 0.06)
            pcall(function() bp:Destroy() end)
        end)
    end)
end

-- ============================================================
-- AUTO BLOCK
-- ============================================================
local lastAutoBlock = 0
local function autoBlock()
    if not _G.abaAutoBlockEnabled then return end
    local now = os.clock()
    if now - lastAutoBlock < 0.5 then return end
    lastAutoBlock = now
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.F, false, nil)
        task.wait(0.05)
        VIM:SendKeyEvent(false, Enum.KeyCode.F, false, nil)
    end)
end

-- ============================================================
-- HITBOX DODGE
-- ============================================================
local lastHitboxDodge = 0
local function hitboxDodge(hrp)
    if not _G.abaHitboxDodgeEnabled then return end
    if not hrp then return end
    local now = os.clock()
    if now - lastHitboxDodge < 0.3 then return end
    lastHitboxDodge = now

    -- Dodge AWAY from nearest enemy
    local myPos = hrp.Position
    local myTeam = plr.Team
    local live = workspace:FindFirstChild("Live")
    local nearestEnemy = nil
    if live then
        local nearestDist = math.huge
        for _, c in ipairs(live:GetChildren()) do
            local cp = game.Players:GetPlayerFromCharacter(c)
            if cp and cp ~= plr and (not myTeam or cp.Team ~= myTeam) then
                local ehrp = c:FindFirstChild("HumanoidRootPart")
                if ehrp then
                    local d = (ehrp.Position - myPos).Magnitude
                    if d < nearestDist then nearestDist = d; nearestEnemy = ehrp end
                end
            end
        end
    end

    local dodgeDir
    if nearestEnemy then
        dodgeDir = ((myPos - nearestEnemy.Position) * Vector3.new(1,0,1)).Unit
    else
        dodgeDir = hrp.CFrame.RightVector * (math.random() > 0.5 and 1 or -1)
    end
    -- Add slight random jitter
    dodgeDir = (dodgeDir + Vector3.new(math.random(-2,2)/10, 0, math.random(-2,2)/10)).Unit

    local original = hrp.CFrame
    hrp.CFrame = hrp.CFrame + dodgeDir * 1.2  -- further nudge away
    task.delay(0.15, function() if hrp and hrp.Parent then pcall(function() hrp.CFrame = original end) end end)
end

-- ============================================================
-- SMART STUN BYPASS
-- ============================================================
local function checkAndRecoverStun(hum, hrp)
    if not _G.abaStunEnabled then return end
    if isMoveAnimationPlaying() then return end
    if _G.abaComboPauseEnabled and (os.clock() - lastSkillTime < _G.abaSkillPauseDuration or os.clock() - lastClickTime < _G.abaClickPauseDuration) then return end
    
    local now = os.clock()
    if _G.stunReleaseTime and now < _G.stunReleaseTime then return end
    
    local isTryingToAct = false
    if hum.MoveDirection.Magnitude > 0 then isTryingToAct = true
    elseif UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.F) then isTryingToAct = true
    elseif now - lastClickTime < 0.6 or now - lastSkillTime < 1.0 then isTryingToAct = true end
    
    if _G.comboHits and _G.comboHits >= 2 then isTryingToAct = true end
    
    if isTryingToAct then
        local wasStunned = (hum.WalkSpeed < 5) or hum.PlatformStand or hum.Sit
        restoreHumanoid(hum)
        if hrp then
            for _, v in ipairs(hrp:GetChildren()) do
                if STUN_CLASSES[v.ClassName] and v.Name ~= "LagDesync" then pcall(function() v:Destroy() end) end
            end
        end
        if wasStunned and _G.comboHits and _G.comboHits >= 2 then
            if _G.abaComboEscapeEnabled then triggerDesyncSlide(hrp, _G.comboHits >= 4 and 3 or 2) end
            if _G.abaAutoBlockEnabled then autoBlock() end
            if _G.abaHitboxDodgeEnabled then hitboxDodge(hrp) end
            _G.comboHits = 0
        end
    end
end

local function setupStunBypass()
    clearCharConns(); clearActiveMoveAnimations()
    local char = plr.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    local animator = hum:FindFirstChildOfClass("Animator") or hum
    table.insert(charConns, animator.AnimationPlayed:Connect(function(track)
        local now = os.clock()
        local name = string.lower(track.Name or "")
        local isSkillKeyPress = (now - lastSkillTime < 1.0) or (now - lastClickTime < 1.0)
        local isExplicitMove = string.find(name, "dash") or string.find(name, "barrage") or string.find(name, "rush")
            or string.find(name, "m1") or string.find(name, "combo") or string.find(name, "attack")
            or string.find(name, "punch") or string.find(name, "kick") or string.find(name, "slash")
            or string.find(name, "hit") or string.find(name, "swing") or string.find(name, "strike") or string.find(name, "animation")
        if isSkillKeyPress or isExplicitMove then
            local ignoreNames = {"idle","walk","run","jump","fall","climb","swim","sit","toolnone"}
            local skip = false; for _,ign in ipairs(ignoreNames) do if string.find(name,ign) then skip=true;break end end
            if not skip then
                activeMoveAnimations[track] = true
                local sc; sc = track.Stopped:Connect(function() activeMoveAnimations[track]=nil; if sc then sc:Disconnect() end end)
                table.insert(charConns, sc)
            end
        end
    end))

    local lastHealth = hum.Health
    table.insert(charConns, hum.HealthChanged:Connect(function(health)
        if health < lastHealth then
            local now = os.clock()
            _G.comboHits = (now - (_G.lastDamageTime or 0) < 1.5) and ((_G.comboHits or 0) + 1) or 1
            _G.lastDamageTime = now
            if not _G.stunReleaseTime or now > _G.stunReleaseTime then _G.stunReleaseTime = now + (math.random(15,25)/100) end
            if _G.comboHits >= 2 then
                if _G.abaComboEscapeEnabled then triggerDesyncSlide(hrp, 2) end
                if _G.abaHitboxDodgeEnabled then hitboxDodge(hrp) end
            end
        end
        lastHealth = health
    end))

    local function onStunDetected()
        local now = os.clock()
        if not _G.stunReleaseTime or now > _G.stunReleaseTime then _G.stunReleaseTime = now + (math.random(15,25)/100) end
        checkAndRecoverStun(hum, hrp)
    end

    table.insert(charConns, hum.Changed:Connect(function(p)
        if not _G.abaStunEnabled then return end
        if isMoveAnimationPlaying() then return end
        if p == "WalkSpeed" or p == "JumpPower" or p == "PlatformStand" or p == "Sit" then
            if hum.WalkSpeed < 5 or hum.PlatformStand or hum.Sit then onStunDetected() end
        end
    end))
    table.insert(charConns, hrp.ChildAdded:Connect(function(v)
        if not _G.abaStunEnabled then return end
        if isMoveAnimationPlaying() then return end
        if STUN_CLASSES[v.ClassName] and v.Name ~= "LagDesync" then onStunDetected() end
    end))
end

local function hookTimeStop()
    for _, name in ipairs({"TimeStop","TimeStopSDio"}) do
        local r = game.ReplicatedStorage:FindFirstChild(name)
        if r then table.insert(_G.abaConns, r.OnClientEvent:Connect(function()
            local char = plr.Character; local hum = char and char:FindFirstChildOfClass("Humanoid"); local hrp = char and char:FindFirstChild("HumanoidRootPart")
            restoreHumanoid(hum); nukeHRP(hrp)
        end)) end
    end
end

local MOVER_NAMES = {"StunBV","FlingFloat","DownerFloat","SuperUpFoat","downer","upper"}
local PHYSICS_CLASSES = {BodyVelocity=true,BodyPosition=true,BodyGyro=true,BodyAngularVelocity=true,BodyForce=true,LinearVelocity=true,AngularVelocity=true,VectorForce=true,AlignPosition=true,AlignOrientation=true}

local function stripAllStunPhysics(hrp)
    if not hrp then return end
    for _, mn in ipairs(MOVER_NAMES) do
        local m = hrp:FindFirstChild(mn)
        if m then for _,c in ipairs(m:GetChildren()) do if PHYSICS_CLASSES[c.ClassName] then pcall(function() c:Destroy() end) end end end
    end
    for _,c in ipairs(hrp:GetChildren()) do if PHYSICS_CLASSES[c.ClassName] then pcall(function() c:Destroy() end) end end
end

local lastSafeCFrame = nil
table.insert(_G.abaConns, RS.Heartbeat:Connect(function()
    local char = plr.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid"); local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if _G.abaAntiFlingEnabled and not isMoveAnimationPlaying() then
        local vel = hrp.AssemblyLinearVelocity; local ang = hrp.AssemblyAngularVelocity
        if vel.Magnitude > 150 or ang.Magnitude > 150 then
            hrp.AssemblyLinearVelocity = Vector3.zero; hrp.AssemblyAngularVelocity = Vector3.zero
            if lastSafeCFrame then hrp.CFrame = lastSafeCFrame end
        elseif vel.Magnitude < 70 and ang.Magnitude < 70 then lastSafeCFrame = hrp.CFrame end
    end
    checkAndRecoverStun(hum, hrp)
end))

local function hookMatchEnd()
    local pwm = game.ReplicatedStorage:FindFirstChild("PlayWinMusic")
    if pwm then table.insert(_G.abaConns, pwm.OnClientEvent:Connect(function() _G.abaStunEnabled = false end)) end
end

setupStunBypass(); hookTimeStop(); hookMatchEnd()
table.insert(_G.abaConns, plr.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart",10); char:WaitForChild("Humanoid",10)
    setupStunBypass()
    if _G.abaStunEnabled or _G.abaSpeedEnabled then local hum = char:FindFirstChildOfClass("Humanoid"); if hum then restoreHumanoid(hum) end end
end))

table.insert(_G.abaConns, RS.Heartbeat:Connect(function()
    if not _G.abaSpeedEnabled then return end
    local char = plr.Character; if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed > 0 and hum.WalkSpeed ~= SPEED then hum.WalkSpeed = SPEED end
end))

-- ============================================================
-- AUTO BLACK FLASH
-- ============================================================
local _bfHooked = false
local function enableBlackFlash()
    if _bfHooked then return end
    local bfc = game.ReplicatedStorage:FindFirstChild("BlackFlashCheck")
    if not bfc then return end
    bfc.OnClientInvoke = function(...) if _G.abaBlackFlashEnabled then return true else return false end end
    _bfHooked = true
end
local function disableBlackFlash() _G.abaBlackFlashEnabled = false end

-- ============================================================
-- LOCK-ON (FULL — with GUI row)
-- ============================================================
_G.abaLockHL = nil
local lockTarget, lockActive, lockMode = nil, false, "HOLD"
local lockBind = nil
local bindListening, bindListenConns = false, {}
local onLockModeChanged = nil

local function clearHL()
    if _G.abaLockHL then pcall(function() _G.abaLockHL:Destroy() end); _G.abaLockHL = nil end
end

local function getNearestToMouse()
    local live = workspace:FindFirstChild("Live"); if not live then return nil end
    local myChar = plr.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart"); if not myHRP then return nil end
    local myTeam = plr.Team; local mouse = plr:GetMouse()
    local ray = cam:ScreenPointToRay(mouse.X, mouse.Y)
    local best, bestScore = nil, math.huge
    for _, c in ipairs(live:GetChildren()) do
        if c ~= myChar then
            local cp = game.Players:GetPlayerFromCharacter(c); if not cp then continue end
            if myTeam and cp.Team == myTeam then continue end
            local hrp = c:FindFirstChild("HumanoidRootPart"); local hum = c:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local toC = hrp.Position - ray.Origin; local dot = toC:Dot(ray.Direction)
                local near = ray.Origin + ray.Direction * math.max(0, dot)
                local score = (hrp.Position - near).Magnitude + (hrp.Position - myHRP.Position).Magnitude * 0.05
                if score < bestScore then bestScore = score; best = c end
            end
        end
    end
    return best
end

local function setLockTarget(t)
    clearHL(); lockTarget = t
    if lockTarget then
        _G.abaLockHL = Instance.new("Highlight"); _G.abaLockHL.OutlineColor = Color3.fromRGB(220,50,50)
        _G.abaLockHL.FillTransparency = 1; _G.abaLockHL.OutlineTransparency = 0
        _G.abaLockHL.Adornee = lockTarget; _G.abaLockHL.Parent = lockTarget
    end
end

local function startLock()
    if not lockActive then setLockTarget(getNearestToMouse()) end
    lockActive = true
end

local function stopLock()
    lockActive = false; clearHL(); lockTarget = nil; cam.CameraType = Enum.CameraType.Custom
end

table.insert(_G.abaConns, RS.Heartbeat:Connect(function()
    if not lockActive then return end
    local myChar = plr.Character; local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
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
    for _,c in ipairs(bindConns) do pcall(function() c:Disconnect() end) end; bindConns = {}
end

local function inputMatchesBind(inp, bind)
    if not bind then return false end
    if bind.type == "key" then return inp.KeyCode == bind.code
    elseif bind.type == "mouse" then
        local tn = tostring(inp.UserInputType):gsub("Enum%.UserInputType%.", "")
        if bind.inputTypeName then return tn == bind.inputTypeName else return inp.UserInputType == bind.inputType end
    end
    return false
end

local function applyBind(bind)
    clearBindConns(); lockBind = bind
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

applyBind({type="key", code=Enum.KeyCode.E})

local mouseTypeNames = {
    [Enum.UserInputType.MouseButton1] = "LMB", [Enum.UserInputType.MouseButton2] = "RMB",
    [Enum.UserInputType.MouseButton3] = "MMB", ["MouseButton4"] = "MB4", ["MouseButton5"] = "MB5",
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

-- TP Behind with Lock-On
local tpBindListening, tpBindListenConns = false, {}
table.insert(_G.abaConns, UIS.InputBegan:Connect(function(inp, gpe)
    if gpe or tpBindListening then return end
    if not lockActive or not lockTarget then return end
    local match = false
    if _G.abaTpKeybind.type == "key" and inp.KeyCode == _G.abaTpKeybind.code then match = true
    elseif _G.abaTpKeybind.type == "mouse" then
        if _G.abaTpKeybind.inputType and inp.UserInputType == _G.abaTpKeybind.inputType then match = true
        elseif _G.abaTpKeybind.inputTypeName and tostring(inp.UserInputType) == "Enum.UserInputType.".._G.abaTpKeybind.inputTypeName then match = true end
    end
    if match then
        local myChar = plr.Character; local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local hum = myChar and myChar:FindFirstChildOfClass("Humanoid"); local tHRP = lockTarget:FindFirstChild("HumanoidRootPart")
        if hrp and tHRP and hum then
            local dist = (tHRP.Position - hrp.Position).Magnitude
            if dist <= 30 then
                local now = os.clock()
                if _G._abaDashCooldown and now - _G._abaDashCooldown < 0.5 then return end
                if _G._abaDashing then return end
                _G._abaDashCooldown = now; _G._abaDashing = true
                local flatLook = tHRP.CFrame.LookVector
                flatLook = Vector3.new(flatLook.X,0,flatLook.Z).Unit
                if flatLook.Magnitude < 0.5 then flatLook = hrp.CFrame.LookVector end
                local DASH_DURATION = math.clamp(0.15 + dist * 0.007, 0.2, 0.35)
                local ARC_HEIGHT = 0.4
                local startPos = hrp.Position; local startTime = os.clock(); local prevPos = startPos
                local dashConn
                pcall(function()
                    local animator = hum:FindFirstChildOfClass("Animator")
                    if animator then
                        local dashAnim = Instance.new("Animation"); dashAnim.AnimationId = "rbxassetid://10469493270"
                        local track = animator:LoadAnimation(dashAnim); track:Play(0.05,1,1.5)
                        task.delay(DASH_DURATION+0.1, function() pcall(function() track:Stop(0.1) end); pcall(function() dashAnim:Destroy() end) end)
                    end
                end)
                dashConn = RS.Heartbeat:Connect(function()
                    if not hrp or not hrp.Parent or not tHRP or not tHRP.Parent then _G._abaDashing = false; if dashConn then dashConn:Disconnect() end; return end
                    local freshLook = tHRP.CFrame.LookVector; freshLook = Vector3.new(freshLook.X,0,freshLook.Z).Unit
                    if freshLook.Magnitude < 0.5 then freshLook = flatLook end
                    local behindPos = tHRP.Position - freshLook * 4.5
                    local targetCFrame = CFrame.lookAt(behindPos, tHRP.Position)
                    local elapsed = os.clock() - startTime; local alpha = math.clamp(elapsed / DASH_DURATION, 0, 1)
                    local t = alpha < 0.5 and 4*alpha*alpha*alpha or 1 - (-2*alpha+2)^3/2
                    local arcY = ARC_HEIGHT * 4 * t * (1-t); local arcOffset = Vector3.new(0, arcY, 0)
                    local lerpedPos = startPos:Lerp(targetCFrame.Position, t) + arcOffset
                    local lerpedCF = CFrame.lookAt(lerpedPos, tHRP.Position)
                    local delta = lerpedPos - prevPos
                    if delta.Magnitude > 0.01 then
                        local naturalVel = delta / math.max(RS.Heartbeat:Wait() or 0.016, 0.001)
                        hrp.AssemblyLinearVelocity = Vector3.new(naturalVel.X, hrp.AssemblyLinearVelocity.Y + arcY*2, naturalVel.Z)
                    end
                    prevPos = lerpedPos; hrp.CFrame = lerpedCF
                    if alpha >= 1 then
                        hrp.CFrame = targetCFrame
                        task.spawn(function() for i=1,4 do if not hrp or not hrp.Parent then break end; local cur = hrp.AssemblyLinearVelocity; hrp.AssemblyLinearVelocity = Vector3.new(cur.X*0.4,cur.Y,cur.Z*0.4); task.wait() end end)
                        _G._abaDashing = false; dashConn:Disconnect()
                    end
                end)
            end
        end
    end
end))

-- ============================================================
-- GUI
-- ============================================================
local W=460; local TITLE_H=40; local ROW_H=40; local SLIDER_H=28
do
local TW=TweenInfo.new(0.15, Enum.EasingStyle.Quad)
local function mkF(p,sz,pos,col,r)
    local f=Instance.new("Frame",p); f.Size=sz; f.Position=pos; f.BackgroundColor3=col; f.BorderSizePixel=0
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,r or 8); return f
end

local sg = Instance.new("ScreenGui"); sg.Name="ABAMenu"; sg.ResetOnSpawn=false
sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.Parent=playerGui

local H = TITLE_H + 48 + 10*(ROW_H+6) + 16 + 22
local win = mkF(sg,UDim2.new(0,W,0,H),UDim2.new(0.5,-W/2,0.5,-H/2),Color3.fromRGB(12,12,12),10)
win.Active=true; win.Draggable=true
Instance.new("UIStroke",win).Color=Color3.fromRGB(48,48,48); Instance.new("UIStroke",win).Thickness=1

local tbar=mkF(win,UDim2.new(1,0,0,TITLE_H),UDim2.new(0,0,0,0),Color3.fromRGB(18,18,18),10)
local tp_=Instance.new("Frame",tbar); tp_.Size=UDim2.new(1,0,0,10); tp_.Position=UDim2.new(0,0,1,-10)
tp_.BackgroundColor3=Color3.fromRGB(18,18,18); tp_.BorderSizePixel=0
local tl=Instance.new("TextLabel",tbar); tl.Size=UDim2.new(1,-50,1,0); tl.Position=UDim2.new(0,14,0,0)
tl.BackgroundTransparency=1; tl.Text="✦  ABA pasted v13"; tl.Font=Enum.Font.GothamBold
tl.TextSize=14; tl.TextColor3=Color3.fromRGB(255,255,255); tl.TextXAlignment=Enum.TextXAlignment.Left
local colBtn=Instance.new("TextButton",tbar); colBtn.Size=UDim2.new(0,26,0,26)
colBtn.Position=UDim2.new(1,-34,0.5,-13); colBtn.BackgroundColor3=Color3.fromRGB(35,35,35); colBtn.BorderSizePixel=0
colBtn.Text="–"; colBtn.TextColor3=Color3.fromRGB(180,180,180); colBtn.Font=Enum.Font.GothamBold; colBtn.TextSize=15
Instance.new("UICorner",colBtn).CornerRadius=UDim.new(0,5)

local tabsBar = mkF(win, UDim2.new(1, -20, 0, 32), UDim2.new(0, 10, 0, TITLE_H + 8), Color3.fromRGB(18, 18, 18), 6)
local tLayout = Instance.new("UIListLayout", tabsBar)
tLayout.FillDirection = Enum.FillDirection.Horizontal; tLayout.Padding = UDim.new(0, 4)
tLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center; tLayout.VerticalAlignment = Enum.VerticalAlignment.Center

local tabButtons = {}; local tabFrames = {}

local function createTabFrame(parent)
    local sf = Instance.new("ScrollingFrame"); sf.Size = UDim2.new(1, 0, 1, 0); sf.Position = UDim2.new(0, 0, 0, 0)
    sf.BackgroundTransparency = 1; sf.BorderSizePixel = 0; sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.ScrollBarThickness = 4; sf.ScrollBarImageColor3 = Color3.fromRGB(60,60,60); sf.Parent = parent
    local ll = Instance.new("UIListLayout", sf); ll.Padding = UDim.new(0, 6); ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
    local pad = Instance.new("UIPadding", sf); pad.PaddingTop = UDim.new(0,6); pad.PaddingBottom = UDim.new(0,6)
    pad.PaddingLeft = UDim.new(0,6); pad.PaddingRight = UDim.new(0,6)
    ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() sf.CanvasSize = UDim2.new(0,0,0,ll.AbsoluteContentSize.Y+12) end)
    return sf
end

local function addTab(name, width)
    local btn = Instance.new("TextButton", tabsBar)
    btn.Size = UDim2.new(0, width or 85, 0, 24); btn.BackgroundColor3 = Color3.fromRGB(24,24,24); btn.BorderSizePixel = 0
    btn.Text = name; btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.TextColor3 = Color3.fromRGB(140,140,140)
    Instance.new("UICorner",btn).CornerRadius = UDim.new(0,5)
    Instance.new("UIStroke",btn).Color = Color3.fromRGB(35,35,35); Instance.new("UIStroke",btn).Thickness = 1
    local container = mkF(win, UDim2.new(1,-20,1,-TITLE_H-78), UDim2.new(0,10,0,TITLE_H+48), Color3.fromRGB(12,12,12), 0)
    container.BackgroundTransparency = 1; container.Visible = false
    local sf = createTabFrame(container)
    btn.MouseButton1Click:Connect(function()
        for tn, tb in pairs(tabButtons) do tb.BackgroundColor3=Color3.fromRGB(24,24,24); tb.TextColor3=Color3.fromRGB(140,140,140); tabFrames[tn].Visible=false end
        btn.BackgroundColor3=Color3.fromRGB(200,40,40); btn.TextColor3=Color3.fromRGB(255,255,255); container.Visible=true
    end)
    tabButtons[name]=btn; tabFrames[name]=container; return sf
end

local combatTab = addTab("Combat", 72)
local defenseTab = addTab("Defense", 74)
local extrasTab = addTab("Extras", 68)
local settingsTab = addTab("Settings", 78)

tabButtons["Combat"].BackgroundColor3 = Color3.fromRGB(200,40,40); tabButtons["Combat"].TextColor3 = Color3.fromRGB(255,255,255)
tabFrames["Combat"].Visible = true

local isDraggingSlider = false

local function buildSlider(parent, label, mn, mx, def, dec, onChange)
    local row=mkF(parent,UDim2.new(1,-10,0,SLIDER_H),UDim2.new(0,0,0,0),Color3.fromRGB(16,16,16),7)
    Instance.new("UIStroke",row).Color=Color3.fromRGB(35,35,35)
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(0,115,1,0); lbl.Position=UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.Font=Enum.Font.Gotham; lbl.TextSize=11; lbl.TextColor3=Color3.fromRGB(160,160,160); lbl.TextXAlignment=Enum.TextXAlignment.Left
    local vl=Instance.new("TextLabel",row); vl.Size=UDim2.new(0,38,1,0); vl.Position=UDim2.new(1,-44,0,0)
    vl.BackgroundTransparency=1; vl.Font=Enum.Font.GothamBold; vl.TextSize=11; vl.TextColor3=Color3.fromRGB(220,220,220); vl.TextXAlignment=Enum.TextXAlignment.Right
    local tbg=mkF(row,UDim2.new(1,-179,0,6),UDim2.new(0,125,0.5,-3),Color3.fromRGB(35,35,35),99)
    local fill=mkF(tbg,UDim2.new(0,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(200,40,40),99)
    local knob=mkF(tbg,UDim2.new(0,14,0,14),UDim2.new(0,0,0.5,-7),Color3.fromRGB(255,255,255),99)
    local tbn=Instance.new("TextButton",tbg); tbn.Size=UDim2.new(1,0,1,20); tbn.Position=UDim2.new(0,0,0,-7)
    tbn.BackgroundTransparency=1; tbn.Text=""; tbn.ZIndex=5
    local cur=def; local dragging=false
    local function ap(mx_)
        local ax=tbg.AbsolutePosition.X; local aw=math.max(tbg.AbsoluteSize.X,1)
        local t=math.clamp((mx_-ax)/aw,0,1)
        local v=math.clamp(dec and math.floor((mn+t*(mx-mn))*10+0.5)/10 or math.floor(mn+t*(mx-mn)+0.5),mn,mx)
        cur=v; local ft=(v-mn)/(mx-mn)
        fill.Size=UDim2.new(ft,0,1,0); knob.Position=UDim2.new(ft,-7,0.5,-7); vl.Text=tostring(v); onChange(v)
    end
    task.spawn(function() task.wait(); ap(tbg.AbsolutePosition.X+(def-mn)/(mx-mn)*tbg.AbsoluteSize.X) end)
    tbn.MouseButton1Down:Connect(function() dragging=true; isDraggingSlider=true; win.Draggable=false; ap(plr:GetMouse().X) end)
    table.insert(_G.abaConns, RS.Heartbeat:Connect(function() if not dragging then return end; ap(plr:GetMouse().X) end))
    UIS.InputEnded:Connect(function(inp) if inp.UserInputType==Enum.UserInputType.MouseButton1 and dragging then dragging=false;isDraggingSlider=false;win.Draggable=true end end)
    return function(v) ap(tbg.AbsolutePosition.X+(v-mn)/(mx-mn)*tbg.AbsoluteSize.X) end
end

local function buildToggle(parent, label, onE, onD)
    local row=mkF(parent,UDim2.new(1,-10,0,ROW_H),UDim2.new(0,0,0,0),Color3.fromRGB(22,22,22),7)
    Instance.new("UIStroke",row).Color=Color3.fromRGB(40,40,40)
    local dot=mkF(row,UDim2.new(0,8,0,8),UDim2.new(0,10,0.5,-4),Color3.fromRGB(60,60,60),99)
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-76,1,0); lbl.Position=UDim2.new(0,24,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.Font=Enum.Font.Gotham; lbl.TextSize=13; lbl.TextColor3=Color3.fromRGB(210,210,210); lbl.TextXAlignment=Enum.TextXAlignment.Left
    local pill=mkF(row,UDim2.new(0,46,0,24),UDim2.new(1,-54,0.5,-12),Color3.fromRGB(45,45,45),99)
    local knob=mkF(pill,UDim2.new(0,18,0,18),UDim2.new(0,3,0.5,-9),Color3.fromRGB(140,140,140),99)
    local btn=Instance.new("TextButton",row); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""
    local state=false
    local function sv(s)
        state=s
        TS:Create(pill,TW,{BackgroundColor3=s and Color3.fromRGB(200,40,40) or Color3.fromRGB(45,45,45)}):Play()
        TS:Create(knob,TW,{BackgroundColor3=s and Color3.fromRGB(255,255,255) or Color3.fromRGB(140,140,140), Position=s and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)}):Play()
        TS:Create(dot,TW,{BackgroundColor3=s and Color3.fromRGB(80,220,80) or Color3.fromRGB(60,60,60)}):Play()
        lbl.TextColor3=s and Color3.fromRGB(255,255,255) or Color3.fromRGB(210,210,210)
    end
    btn.MouseButton1Click:Connect(function() sv(not state); if state then onE() else onD() end end)
    return sv
end

-- ============================================================
-- LOCK-ON GUI ROW
-- ============================================================
local function buildLockOnRow(parent)
    local row=mkF(parent,UDim2.new(1,-10,0,ROW_H),UDim2.new(0,0,0,0),Color3.fromRGB(22,22,22),7)
    Instance.new("UIStroke",row).Color=Color3.fromRGB(40,40,40)
    local dot=mkF(row,UDim2.new(0,8,0,8),UDim2.new(0,10,0.5,-4),Color3.fromRGB(60,60,60),99)
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-200,1,0); lbl.Position=UDim2.new(0,24,0,0)
    lbl.BackgroundTransparency=1; lbl.Text="Lock-On"; lbl.Font=Enum.Font.Gotham; lbl.TextSize=13; lbl.TextColor3=Color3.fromRGB(210,210,210); lbl.TextXAlignment=Enum.TextXAlignment.Left
    local bindBtn=Instance.new("TextButton",row); bindBtn.Size=UDim2.new(0,60,0,26)
    bindBtn.Position=UDim2.new(1,-130,0.5,-13); bindBtn.BackgroundColor3=Color3.fromRGB(35,35,35); bindBtn.BorderSizePixel=0
    bindBtn.Text="["..getBindLabel(lockBind).."]"; bindBtn.TextColor3=Color3.fromRGB(160,160,160); bindBtn.Font=Enum.Font.GothamBold; bindBtn.TextSize=11
    Instance.new("UICorner",bindBtn).CornerRadius=UDim.new(0,5)
    local bstroke=Instance.new("UIStroke",bindBtn); bstroke.Color=Color3.fromRGB(55,55,55); bstroke.Thickness=1
    local modeBtn=Instance.new("TextButton",row); modeBtn.Size=UDim2.new(0,58,0,26)
    modeBtn.Position=UDim2.new(1,-66,0.5,-13); modeBtn.BackgroundColor3=Color3.fromRGB(35,35,35); modeBtn.BorderSizePixel=0
    modeBtn.Text="HOLD"; modeBtn.TextColor3=Color3.fromRGB(200,200,200); modeBtn.Font=Enum.Font.GothamBold; modeBtn.TextSize=11
    Instance.new("UICorner",modeBtn).CornerRadius=UDim.new(0,5)
    Instance.new("UIStroke",modeBtn).Color=Color3.fromRGB(55,55,55); Instance.new("UIStroke",modeBtn).Thickness=1

    local overlay=mkF(row,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(15,15,15),7)
    overlay.Visible=false; overlay.ZIndex=10
    Instance.new("UICorner",overlay).CornerRadius=UDim.new(0,7)
    local ovl=Instance.new("TextLabel",overlay); ovl.Size=UDim2.new(1,0,1,0)
    ovl.BackgroundTransparency=1; ovl.Text="Press any key or mouse button..."; ovl.TextColor3=Color3.fromRGB(255,200,50); ovl.Font=Enum.Font.GothamBold; ovl.TextSize=11

    local function refreshMode()
        modeBtn.Text = lockMode
        if lockMode == "TOGGLE" and not lockActive then stopLock() end
    end
    onLockModeChanged = refreshMode

    modeBtn.MouseButton1Click:Connect(function()
        lockMode = lockMode == "HOLD" and "TOGGLE" or "HOLD"; applyBind(lockBind); refreshMode()
    end)

    local function stopListen()
        if not bindListening then return end; bindListening=false
        for _,c in ipairs(bindListenConns) do pcall(function() c:Disconnect() end) end; bindListenConns={}
        overlay.Visible=false; bindBtn.TextColor3=Color3.fromRGB(160,160,160); bstroke.Color=Color3.fromRGB(55,55,55)
    end

    local function startListen()
        if bindListening then stopListen(); return end; bindListening=true; overlay.Visible=true
        bindBtn.TextColor3=Color3.fromRGB(255,200,50); bstroke.Color=Color3.fromRGB(255,200,50)
        table.insert(bindListenConns, UIS.InputBegan:Connect(function(inp, gpe)
            if not bindListening then return end
            if inp.KeyCode == Enum.KeyCode.Escape then stopListen(); return end
            if inp.KeyCode ~= Enum.KeyCode.Unknown then
                applyBind({type="key", code=inp.KeyCode}); bindBtn.Text="["..getBindLabel(lockBind).."]"; stopListen(); return
            end
            local tn = tostring(inp.UserInputType):gsub("Enum%.UserInputType%.", "")
            for _, name in ipairs({"MouseButton1","MouseButton2","MouseButton3","MouseButton4","MouseButton5"}) do
                if tn == name then
                    local bd
                    if name == "MouseButton1" then bd={type="mouse",inputType=Enum.UserInputType.MouseButton1}
                    elseif name == "MouseButton2" then bd={type="mouse",inputType=Enum.UserInputType.MouseButton2}
                    elseif name == "MouseButton3" then bd={type="mouse",inputType=Enum.UserInputType.MouseButton3}
                    else bd={type="mouse",inputTypeName=name} end
                    applyBind(bd); bindBtn.Text="["..getBindLabel(bd).."]"; stopListen(); return
                end
            end
        end))
    end

    bindBtn.MouseButton1Click:Connect(startListen)
    local ovBtn=Instance.new("TextButton",overlay); ovBtn.Size=UDim2.new(1,0,1,0); ovBtn.BackgroundTransparency=1; ovBtn.Text=""; ovBtn.ZIndex=11
    ovBtn.MouseButton1Click:Connect(stopListen)

    table.insert(_G.abaConns, RS.Heartbeat:Connect(function()
        if lockMode ~= "TOGGLE" then return end
        local c = lockActive and Color3.fromRGB(80,220,80) or Color3.fromRGB(60,60,60)
        if dot.BackgroundColor3 ~= c then dot.BackgroundColor3 = c end
    end))
end

-- ============================================================
-- TP BEHIND BIND GUI ROW
-- ============================================================
local function buildTpBindRow(parent)
    local row=mkF(parent,UDim2.new(1,-10,0,ROW_H),UDim2.new(0,0,0,0),Color3.fromRGB(22,22,22),7)
    Instance.new("UIStroke",row).Color=Color3.fromRGB(40,40,40)
    local lbl=Instance.new("TextLabel",row); lbl.Size=UDim2.new(1,-100,1,0); lbl.Position=UDim2.new(0,10,0,0)
    lbl.BackgroundTransparency=1; lbl.Text="TP Behind Keybind"; lbl.Font=Enum.Font.Gotham; lbl.TextSize=13; lbl.TextColor3=Color3.fromRGB(210,210,210); lbl.TextXAlignment=Enum.TextXAlignment.Left
    local bindBtn=Instance.new("TextButton",row); bindBtn.Size=UDim2.new(0,60,0,26)
    bindBtn.Position=UDim2.new(1,-70,0.5,-13); bindBtn.BackgroundColor3=Color3.fromRGB(35,35,35); bindBtn.BorderSizePixel=0
    bindBtn.Text="["..getBindLabel(_G.abaTpKeybind).."]"; bindBtn.TextColor3=Color3.fromRGB(160,160,160); bindBtn.Font=Enum.Font.GothamBold; bindBtn.TextSize=11
    Instance.new("UICorner",bindBtn).CornerRadius=UDim.new(0,5)
    local bstroke=Instance.new("UIStroke",bindBtn); bstroke.Color=Color3.fromRGB(55,55,55); bstroke.Thickness=1
    local overlay=mkF(row,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(15,15,15),7)
    overlay.Visible=false; overlay.ZIndex=10; Instance.new("UICorner",overlay).CornerRadius=UDim.new(0,7)
    local ovl=Instance.new("TextLabel",overlay); ovl.Size=UDim2.new(1,0,1,0)
    ovl.BackgroundTransparency=1; ovl.Text="Press any key..."; ovl.TextColor3=Color3.fromRGB(255,200,50); ovl.Font=Enum.Font.GothamBold; ovl.TextSize=11

    local function stopListen()
        tpBindListening=false; for _,c in ipairs(tpBindListenConns) do pcall(function() c:Disconnect() end) end; tpBindListenConns={}
        overlay.Visible=false; bindBtn.TextColor3=Color3.fromRGB(160,160,160); bstroke.Color=Color3.fromRGB(55,55,55)
    end

    local function startListen()
        if tpBindListening then stopListen(); return end; tpBindListening=true; overlay.Visible=true
        bindBtn.TextColor3=Color3.fromRGB(255,200,50); bstroke.Color=Color3.fromRGB(255,200,50)
        table.insert(tpBindListenConns, UIS.InputBegan:Connect(function(inp, gpe)
            if not tpBindListening then return end
            if inp.KeyCode == Enum.KeyCode.Escape then stopListen(); return end
            if inp.KeyCode ~= Enum.KeyCode.Unknown then
                _G.abaTpKeybind = {type="key", code=inp.KeyCode}; bindBtn.Text="["..getBindLabel(_G.abaTpKeybind).."]"; stopListen(); return
            end
            local tn = tostring(inp.UserInputType):gsub("Enum%.UserInputType%.", "")
            for _, name in ipairs({"MouseButton1","MouseButton2","MouseButton3","MouseButton4","MouseButton5"}) do
                if tn == name then
                    if name=="MouseButton1" then _G.abaTpKeybind={type="mouse",inputType=Enum.UserInputType.MouseButton1}
                    elseif name=="MouseButton2" then _G.abaTpKeybind={type="mouse",inputType=Enum.UserInputType.MouseButton2}
                    elseif name=="MouseButton3" then _G.abaTpKeybind={type="mouse",inputType=Enum.UserInputType.MouseButton3}
                    else _G.abaTpKeybind={type="mouse",inputTypeName=name} end
                    bindBtn.Text="["..getBindLabel(_G.abaTpKeybind).."]"; stopListen(); return
                end
            end
        end))
    end

    bindBtn.MouseButton1Click:Connect(startListen)
    local ovBtn=Instance.new("TextButton",overlay); ovBtn.Size=UDim2.new(1,0,1,0); ovBtn.BackgroundTransparency=1; ovBtn.Text=""; ovBtn.ZIndex=11
    ovBtn.MouseButton1Click:Connect(stopListen)
end

-- ============================================================
-- BUILD ALL ROWS
-- ============================================================

-- COMBAT
zeroStunSV = buildToggle(combatTab, "Zero Stun",
    function() _G.abaStunEnabled=true; local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed=16;hum.JumpPower=50;hum.PlatformStand=false end end,
    function() _G.abaStunEnabled=false end)

buildToggle(combatTab, "Combo Pause", function() _G.abaComboPauseEnabled=true end, function() _G.abaComboPauseEnabled=false end)

buildToggle(combatTab, "Speed Boost",
    function() _G.abaSpeedEnabled=true; local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if hum and hum.WalkSpeed>0 then hum.WalkSpeed=SPEED end end,
    function() _G.abaSpeedEnabled=false; local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if hum then hum.WalkSpeed=16 end end)

-- DEFENSE (NEW)
buildToggle(defenseTab, "Combo Escape", function() _G.abaComboEscapeEnabled=true end, function() _G.abaComboEscapeEnabled=false end)
buildToggle(defenseTab, "Auto Block", function() _G.abaAutoBlockEnabled=true end, function() _G.abaAutoBlockEnabled=false end)
buildToggle(defenseTab, "Hitbox Dodge", function() _G.abaHitboxDodgeEnabled=true end, function() _G.abaHitboxDodgeEnabled=false end)

-- EXTRAS (LOCK-ON + TP BEHIND + BLACK FLASH + ANTI-FLING + STREAM)
buildLockOnRow(extrasTab)
buildTpBindRow(extrasTab)
buildToggle(extrasTab, "Auto Black Flash", function() _G.abaBlackFlashEnabled=true; enableBlackFlash() end, function() disableBlackFlash() end)
buildToggle(extrasTab, "Anti-Fling", function() _G.abaAntiFlingEnabled=true end, function() _G.abaAntiFlingEnabled=false end)
buildToggle(extrasTab, "Stream Mode", function() win.Visible=false end, function() end)

-- SETTINGS
buildSlider(settingsTab, "Speed (ws)", 16, 150, SPEED, false, function(v) SPEED=v; if _G.abaSpeedEnabled then local char=plr.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if hum and hum.WalkSpeed>0 then hum.WalkSpeed=SPEED end end end)
buildSlider(settingsTab, "Skill Pause (s)", 0, 2, _G.abaSkillPauseDuration, true, function(v) _G.abaSkillPauseDuration=v end)
buildSlider(settingsTab, "Click Pause (s)", 0, 1, _G.abaClickPauseDuration, true, function(v) _G.abaClickPauseDuration=v end)

local hint = Instance.new("TextLabel", win)
hint.Size = UDim2.new(1, -20, 0, 16); hint.Position = UDim2.new(0, 10, 1, -22)
hint.BackgroundTransparency = 1; hint.Text = "RShift = Toggle | pasted edition"
hint.TextColor3 = Color3.fromRGB(58, 58, 58); hint.Font = Enum.Font.Gotham; hint.TextSize = 10; hint.TextXAlignment = Enum.TextXAlignment.Center

colBtn.MouseButton1Click:Connect(function() win.Visible = false end)

local menuVis=true
UIS.InputBegan:Connect(function(i,g) if g then return end; if i.KeyCode==Enum.KeyCode.RightShift then menuVis=not menuVis; win.Visible=menuVis end end)

_G.abaInitDone = true
end

print("[ABA v13 pasted] — Zero Stun, Combo Escape, Auto Block, Hitbox Dodge, Lock-On, TP Behind, Black Flash, Speed, Anti-Fling")
