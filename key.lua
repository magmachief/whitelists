-- Complete replacement script. Run fresh; do not layer over a previous version.
-- What's new in this version:
--  * Shift Lock button and Auto Pass button are both DRAGGABLE (press and drag anywhere on them).
--      A drag never triggers the button; a clean tap/click does.
--  * Auto Pass state is synchronized everywhere: Orion toggle, mobile panel, and the
--      on-screen AUTO button always show the same state no matter which one you use.
--  * Last-second (Late) mode now truly works even when the Bomb tool has no
--      BombStartTime/BombDuration/BombState attributes: a configurable assumed fuse
--      length (default 30s) is counted from the first time each bomb is seen
--      (unequipping and re-equipping the same bomb does not reset the countdown).
--  * Flick is now a camera "glance": look at the receiver for ~0.18s like a quick
--      shift-lock peek, then look back. Your body is never locked or teleported.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local bombName = "Bomb"
local customNormalFriction = 0.7
local customBombFriction = 7
local customAntiSlipperyFriction = 0.7
local customBombAntiSlipperyFriction = 0.9
local fallbackFriction = 0.5
local customHitboxSize = 0.1
local bombPassDistance = 10
local raySpreadAngle = 10
local numRaycasts = 5
local AutoPassEnabled = false
local antiSlippery = false
local RemoveHitboxEnabled = false
local AI_AssistanceEnabled = false
local allUIVisible = true
local originalHitboxSizes = {}
-- Shared state is declared before callbacks; AutoPassButton is declared here so
-- setAutoPassEnabled (defined earlier in the file) can see it as an upvalue.
local autoPassConnection, mobileGui, mobileToggle, mobileModeToggle, flickToggle, mobileStatus
local ShiftLockScreenGui, ShiftLockButton, SL_Active, passCore
local orionAutoPassToggle, orionLatePassToggle, orionFlickToggle
local FaceBombEnabled, faceBombConnection
local AutoPassButton
local refreshMobileButtons = function() end

local FrictionController = {}
FrictionController.__index = FrictionController
function FrictionController.new()
    local self = setmetatable({}, FrictionController)
    self.originalProperties = {}
    self.normalFriction = customNormalFriction
    self.bombFriction = customBombFriction
    self.stateMultipliers = {Running = 1.2, Walking = 1.0, Crouching = 0.8}
    self.enabled = false
    return self
end
function FrictionController:getSurfaceMaterial(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return Enum.Material.Plastic
    end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local rayResult = Workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), rayParams)
    return rayResult and rayResult.Instance.Material or Enum.Material.Plastic
end
function FrictionController:calculateFriction(character)
    local humanoid = character:FindFirstChild("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and hrp) then
        return self.normalFriction
    end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local rayResult = Workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), rayParams)
    if rayResult then
        local floorPart = rayResult.Instance
        if floorPart:IsA("BasePart") and floorPart.Name == "Floor" and floorPart.Friction <= 0.2 then
            return math.clamp(customAntiSlipperyFriction * 0.5, 0.1, 1.0)
        end
    end
    if character:FindFirstChild(bombName) then
        return self.bombFriction
    end
    local stateName = humanoid:GetState()
    local multiplier = self.stateMultipliers[stateName] or 1.0
    return math.clamp(self.normalFriction * multiplier, 0.1, 1.0)
end
function FrictionController:update()
    local character = LocalPlayer.Character
    if not character then
        return
    end
    for _, pn in ipairs({"LeftFoot", "RightFoot", "LeftLeg", "RightLeg"}) do
        local part = character:FindFirstChild(pn)
        if part and part:IsA("BasePart") then
            if not self.originalProperties[part] then
                local elasticity = 0.3
                local frictionWeight = 0.5
                if part.CustomPhysicalProperties then
                    elasticity = part.CustomPhysicalProperties.Elasticity
                    frictionWeight = part.CustomPhysicalProperties.FrictionWeight
                end
                self.originalProperties[part] = PhysicalProperties.new(customNormalFriction, elasticity, frictionWeight)
            end
            local df = self:calculateFriction(character)
            local elasticity = 0.3
            local frictionWeight = 0.5
            if part.CustomPhysicalProperties then
                elasticity = part.CustomPhysicalProperties.Elasticity
                frictionWeight = part.CustomPhysicalProperties.FrictionWeight
            end
            part.CustomPhysicalProperties = PhysicalProperties.new(df, elasticity, frictionWeight)
        end
    end
end
function FrictionController:restore()
    for part, orig in pairs(self.originalProperties) do
        if part and part.Parent then
            part.CustomPhysicalProperties = orig
        end
    end
    self.originalProperties = {}
end
function FrictionController:enable()
    if self.enabled then
        return
    end
    self.enabled = true
    spawn(
        function()
            while self.enabled do
                self:update()
                wait(0.1)
            end
        end
    )
end
function FrictionController:disable()
    self.enabled = false
    self:restore()
end

local function applyAntiSlippery(enabled)
    if enabled then
        spawn(
            function()
                while antiSlippery do
                    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    for _, part in pairs(character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            if character:FindFirstChild(bombName) then
                                local speed = hrp and hrp.Velocity.Magnitude or 0
                                local fric = customBombAntiSlipperyFriction
                                if speed > 10 then
                                    fric = fric * 1.25
                                end
                                part.CustomPhysicalProperties = PhysicalProperties.new(fric, 0.3, 0.5)
                            else
                                part.CustomPhysicalProperties =
                                    PhysicalProperties.new(customAntiSlipperyFriction, 0.3, 0.5)
                            end
                        end
                    end
                    wait(0.5)
                end
            end
        )
    else
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CustomPhysicalProperties = PhysicalProperties.new(fallbackFriction, 0.3, 0.5)
            end
        end
    end
end

local function faceNearestBombHolder()
    if passCore and (passCore:IsFlicking()
        or Workspace:GetServerTimeNow() < passCore.NextFlick) then return end
    local myChar = LocalPlayer.Character
    if not myChar then
        return
    end
    local hrp = myChar:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local nearest, nearestDist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild(bombName) then
            local pHRP = p.Character:FindFirstChild("HumanoidRootPart")
            if pHRP then
                local d = (pHRP.Position - hrp.Position).Magnitude
                if d < nearestDist then
                    nearestDist = d
                    nearest = p
                end
            end
        end
    end
    if nearest and nearest.Character then
        local bombHolderHRP = nearest.Character:FindFirstChild("HumanoidRootPart")
        if bombHolderHRP then
            local cam = Workspace.CurrentCamera
            cam.CameraType = Enum.CameraType.Custom
            cam.CFrame = CFrame.new(cam.CFrame.Position, bombHolderHRP.Position)
        end
    end
end

local CHAR = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HUMANOID = CHAR:WaitForChild("Humanoid")
local HRP = CHAR:WaitForChild("HumanoidRootPart")

local LoggingModule = {}
function LoggingModule.logError(err, ctx)
    warn("[ERROR] Context: " .. tostring(ctx) .. " | " .. tostring(err))
end
function LoggingModule.safeCall(func, ctx)
    local s, r = pcall(func)
    if not s then
        LoggingModule.logError(r, ctx)
    end
    return s, r
end

local TargetingModule = {}
function TargetingModule.getClosestPlayer()
    local closest, md = nil, math.huge
    local myPos = HRP.Position
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local targetHrp = p.Character:FindFirstChild("HumanoidRootPart")
            if targetHrp and not p.Character:FindFirstChild(bombName) then
                local d = (targetHrp.Position - myPos).Magnitude
                if d < md then
                    md = d
                    closest = p
                end
            end
        end
    end
    return closest
end
function TargetingModule.rotateCharacterTowardsTarget(targetPos)
end

local VisualModule = {}
function VisualModule.animateMarker(marker)
    if not marker then
        return
    end
    local tween =
        TweenService:Create(
        marker,
        TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        {Size = UDim2.new(0, 100, 0, 100)}
    )
    tween:Play()
end
function VisualModule.playPassVFX(target)
    if not target or not target.Character then
        return
    end
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxassetid://258128463"
    emitter.Rate = 50
    emitter.Lifetime = NumberRange.new(0.3, 0.5)
    emitter.Speed = NumberRange.new(2, 5)
    emitter.VelocitySpread = 30
    emitter.Parent = hrp
    delay(
        1,
        function()
            emitter:Destroy()
        end
    )
end

local AINotificationsModule = {}
function AINotificationsModule.sendNotification(title, text, dur)
    pcall(
        function()
            StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = dur or 5})
        end
    )
end

local function applyRemoveHitbox(enable)
    local char = LocalPlayer.Character
    if not char then
        return
    end

    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == "Hitbox" then
            if enable then
                if not originalHitboxSizes[part] then
                    originalHitboxSizes[part] = part.Size
                end
                part.Transparency = 1
                part.CanCollide = false
                part.Size = Vector3.new(customHitboxSize, customHitboxSize, customHitboxSize)
            else
                part.Transparency = 0
                part.CanCollide = true
                part.Size = originalHitboxSizes[part] or Vector3.new(1, 1, 1)
            end
        end
    end
end

local currentTargetMarker, currentTargetPlayer = nil, nil
local function createOrUpdateTargetMarker(player, dist)
    if not player or not player.Character then
        return
    end
    local body = player.Character:FindFirstChild("HumanoidRootPart")
    if not body then
        return
    end
    if currentTargetMarker and currentTargetPlayer == player then
        currentTargetMarker:FindFirstChildOfClass("TextLabel").Text =
            player.Name .. "\n" .. math.floor(dist) .. " studs"
        return
    end
    if currentTargetMarker then
        currentTargetMarker:Destroy()
        currentTargetMarker, currentTargetPlayer = nil, nil
    end
    local marker = Instance.new("BillboardGui")
    marker.Name = "BombPassTargetMarker"
    marker.Adornee = body
    marker.Size = UDim2.new(0, 80, 0, 80)
    marker.StudsOffset = Vector3.new(0, 2, 0)
    marker.AlwaysOnTop = true
    marker.Parent = body
    local label = Instance.new("TextLabel", marker)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = player.Name .. "\n" .. math.floor(dist) .. " studs"
    label.TextScaled = true
    label.TextColor3 = Color3.new(1, 0, 0)
    label.Font = Enum.Font.SourceSansBold
    currentTargetMarker, currentTargetPlayer = marker, player
    VisualModule.animateMarker(marker)
end
local function removeTargetMarker()
    if currentTargetMarker then
        currentTargetMarker:Destroy()
        currentTargetMarker, currentTargetPlayer = nil, nil
    end
end

local function isLineOfSightClearMultiple(startPos, endPos, targetPart)
    local spreadRad = math.rad(raySpreadAngle)
    local direction = (endPos - startPos).Unit
    local distance = (endPos - startPos).Magnitude
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    if LocalPlayer.Character then
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end
    local centralResult = Workspace:Raycast(startPos, direction * distance, rayParams)
    if centralResult and not centralResult.Instance:IsDescendantOf(targetPart.Parent) then
        return false
    end
    local raysEachSide = math.floor((numRaycasts - 1) / 2)
    for i = 1, raysEachSide do
        local angleOffset = spreadRad * i / raysEachSide
        local leftDirection = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), angleOffset) * CFrame.new(direction)).p
        local leftResult = Workspace:Raycast(startPos, leftDirection * distance, rayParams)
        if leftResult and not leftResult.Instance:IsDescendantOf(targetPart.Parent) then
            return false
        end
        local rightDirection = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -angleOffset) * CFrame.new(direction)).p
        local rightResult = Workspace:Raycast(startPos, rightDirection * distance, rayParams)
        if rightResult and not rightResult.Instance:IsDescendantOf(targetPart.Parent) then
            return false
        end
    end
    return true
end

-- BEGIN PASS CONTROLLER (plain Lua; also exercised by the local test harness)
local PassController = {}
PassController.__index = PassController

local function finiteNumber(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

function PassController.remaining(bomb, now)
    local state = bomb:GetAttribute("BombState")
    if state ~= "Running" and state ~= "Fused" then
        return nil, "Timer state unavailable"
    end
    local start = bomb:GetAttribute("BombStartTime")
    local duration = bomb:GetAttribute("BombDuration")
    if not finiteNumber(start) or not finiteNumber(duration) or duration <= 0 then
        return nil, "Timer attributes unavailable"
    end
    -- Use the Tool's existing deadline; receiving it must not restart the fuse.
    return start + duration - now
end

function PassController.eligible(mode, remaining, distance, config)
    if not finiteNumber(distance) or distance < 0 then return false end
    if mode == "Late" then
        return finiteNumber(remaining) and remaining > 0
            and remaining <= config.LateWindow and distance <= 6
    end
    if mode ~= "Normal" then return false end
    -- Keep the original immediate mode usable on builds with no timer attributes.
    return (remaining == nil or remaining > 0) and distance <= config.NormalDistance
end

local function isBomb(instance)
    return instance:IsA("Tool")
        and (instance.Name == "Bomb" or instance:GetAttribute("BombClientManaged") == true)
end

local function livingParts(character)
    if not character or not character.Parent then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
        return nil
    end
    return root, humanoid
end

function PassController.new(services, config, hooks)
    return setmetatable({
        Services = services, Config = config, Hooks = hooks,
        Pending = nil, Flick = nil, NextRequest = 0, NextFlick = 0,
        LastStatus = "", HeldBomb = nil, HeldCharacter = nil,
        BombSeenAt = setmetatable({}, {__mode = "k"}),
    }, PassController)
end

function PassController:Status(message)
    if message ~= self.LastStatus then
        self.LastStatus = message
        self.Hooks.status(message)
    end
end

function PassController:GetBomb(character, now)
    local first, earliest, earliestTime
    for _, child in ipairs(character:GetChildren()) do
        if isBomb(child) then
            first = first or child
            local remaining = self.remaining(child, now)
            if remaining and remaining > 0 and (not earliestTime or remaining < earliestTime) then
                earliest, earliestTime = child, remaining
            end
        end
    end
    if self.Config.Mode == "Late" then return earliest or first end
    return first
end

function PassController:GetTarget(root)
    local closest, targetCharacter, closestRoot, collision, minimum = nil, nil, nil, nil, math.huge
    for _, player in ipairs(self.Services.Players:GetPlayers()) do
        if player ~= self.Services.LocalPlayer then
            local character = player.Character
            local targetRoot = livingParts(character)
            local targetCollision = character and character:FindFirstChild("CollisionPart")
            local carrying = false
            if targetRoot and targetCollision and targetCollision:IsA("BasePart") then
                for _, child in ipairs(character:GetChildren()) do
                    if isBomb(child) then carrying = true; break end
                end
                local distance = (root.Position - targetRoot.Position).Magnitude
                if not carrying and distance < minimum then
                    closest, targetCharacter, closestRoot, collision, minimum =
                        player, character, targetRoot, targetCollision, distance
                end
            end
        end
    end
    return closest, targetCharacter, closestRoot, collision, minimum
end

function PassController:ClearPending()
    if self.Pending and self.Pending.Connection then self.Pending.Connection:Disconnect() end
    self.Pending = nil
end

function PassController:ObserveTransfer(pending)
    if self.Pending ~= pending then return end
    -- Disappearance, death, unequipping and respawn are NOT pass confirmation.
    if pending.Target.Character == pending.TargetCharacter
        and pending.Bomb.Parent == pending.TargetCharacter then
        pending.Confirmed = true
    elseif pending.Bomb.Parent ~= pending.Character then
        pending.LeftCharacter = true
    end
end

function PassController:IsFlicking()
    return self.Flick ~= nil
end

-- The flick is a camera glance, like shift-locking for a split second to look at
-- the receiver and then un-shift-locking: the body is never locked, rotated or
-- teleported, and the camera position is never moved -- only where it looks.
function PassController:EndFlick(restoreFacing)
    local flick = self.Flick
    if not flick then return end
    self.Flick = nil
    if flick.Connection then flick.Connection:Disconnect() end
    local camera = flick.Camera
    if restoreFacing and camera and camera.Parent then
        local look = flick.OriginalLook
        if look and look.Magnitude > 0.001 then
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + look.Unit)
        end
    end
end

function PassController:StartFlick(character, root, humanoid, targetRoot, now)
    if not self.Config.FlickEnabled or now < self.NextFlick or self.Flick then return end
    local camera = self.Services.Workspace.CurrentCamera
    if not camera then return end
    local flick = {
        Camera = camera, Started = now,
        OriginalLook = camera.CFrame.LookVector, TargetRoot = targetRoot,
    }
    self.Flick = flick
    self.NextFlick = now + 0.6
    -- Glance at the receiver for about a fifth of a second, then look back.
    flick.Connection = self.Services.RunService.PreSimulation:Connect(function()
        if self.Flick ~= flick then return end
        if not self.Config.Enabled or not self.Config.FlickEnabled
            or not camera.Parent then
            self:EndFlick(true)
            return
        end
        local elapsed = self.Services.Workspace:GetServerTimeNow() - flick.Started
        if elapsed >= 0.18 then self:EndFlick(true); return end
        if targetRoot.Parent then
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, targetRoot.Position)
        end
    end)
end

function PassController:Reset()
    self:ClearPending()
    self:EndFlick(true)
    self.HeldBomb, self.HeldCharacter = nil, nil
    self.NextRequest, self.NextFlick = 0, 0
end

function PassController:Step()
    if not self.Config.Enabled then return end
    local now = self.Services.Workspace:GetServerTimeNow()
    local character = self.Services.LocalPlayer.Character
    local root, humanoid = livingParts(character)
    if not root then self:Reset(); self:Status("Waiting for character"); return end

    local pending = self.Pending
    if pending then
        if character ~= pending.Character then
            self:Reset()
        else
            self:ObserveTransfer(pending)
            if pending.Confirmed then
                self:Status("Transfer observed: " .. pending.Target.Name)
                self:ClearPending()
                return
            elseif now - pending.SentAt < self.Config.AckTimeout then
                self:Status("Pass requested; awaiting transfer")
                return
            else
                self:ClearPending()
            end
        end
    end

    local bomb = self:GetBomb(character, now)
    if not bomb then self.HeldBomb = nil; self:Status("No equipped bomb"); return end
    if self.HeldBomb ~= bomb or self.HeldCharacter ~= character then
        self.HeldBomb, self.HeldCharacter = bomb, character
        self.NextRequest, self.NextFlick = 0, 0
    end
    -- First time this specific bomb tool is seen; re-equipping does not restart it.
    if not self.BombSeenAt[bomb] then self.BombSeenAt[bomb] = now end
    local remaining, timerReason = self.remaining(bomb, now)
    -- Fallback so Late mode works on games whose Bomb tool carries no timer
    -- attributes: count down from when this bomb was first seen using AssumedFuse.
    if remaining == nil and self.Config.Mode == "Late"
        and finiteNumber(self.Config.AssumedFuse) and self.Config.AssumedFuse > 0 then
        local seenAt = self.BombSeenAt[bomb]
        if seenAt then remaining = seenAt + self.Config.AssumedFuse - now end
    end
    local remote = bomb:FindFirstChild("RemoteEvent")
    if not remote or not remote:IsA("RemoteEvent") then
        self:Status("Unsupported: Bomb.RemoteEvent missing")
        return
    end
    if self.Config.Mode == "Late" and remaining == nil then
        self:Status(timerReason)
        return
    end
    if remaining and remaining <= 0 then self:Status("Bomb deadline reached"); return end
    local target, targetCharacter, targetRoot, collision, distance = self:GetTarget(root)
    local timeText = remaining and string.format("%.2fs", math.max(0, remaining)) or "Timer unknown"
    if not target then self:Status(timeText .. " | No valid target"); return end
    self:Status(timeText .. string.format(" | %.1f studs", distance))
    if not self.eligible(self.Config.Mode, remaining, distance, self.Config)
        or now < self.NextRequest then return end

    -- Revalidate identity and range immediately before sending.
    if bomb.Parent ~= character or target.Character ~= targetCharacter
        or not collision:IsDescendantOf(targetCharacter) then return end
    local currentDistance = (root.Position - targetRoot.Position).Magnitude
    if not self.eligible(self.Config.Mode, remaining, currentDistance, self.Config) then return end
    pending = {Bomb = bomb, Character = character, Target = target,
        TargetCharacter = targetCharacter, SentAt = now}
    self.Pending = pending
    pending.Connection = bomb.AncestryChanged:Connect(function() self:ObserveTransfer(pending) end)
    self.NextRequest = now + self.Config.RequestCooldown
    self:StartFlick(character, root, humanoid, targetRoot, now)
    local ok, err = pcall(function() remote:FireServer(targetCharacter, collision) end)
    if not ok then
        self:ClearPending()
        self:EndFlick(true)
        self:Status("Pass request failed (see console)")
        warn("[Auto Pass] " .. tostring(err))
    end
end
-- END PASS CONTROLLER

local passConfig = {
    Enabled = false,
    Mode = "Normal", -- "Normal" = original immediate mode; "Late" = timed, within 6 studs.
    NormalDistance = bombPassDistance,
    LateWindow = 0.60, -- Request when this many seconds remain. This is not arrival time.
    AssumedFuse = 30, -- Used by Late mode when the Bomb tool has no timer attributes.
    FlickEnabled = false,
    RequestCooldown = 0.20,
    AckTimeout = 0.25,
}

passCore = PassController.new({
    Players = Players, LocalPlayer = LocalPlayer,
    Workspace = Workspace, RunService = RunService,
}, passConfig, {
    shiftLocked = function() return SL_Active ~= nil end,
    status = function(message)
        if mobileStatus and mobileStatus.Parent then mobileStatus.Text = message end
    end,
})

local function autoPassBomb()
    passConfig.NormalDistance = bombPassDistance
    local ok, err = pcall(function() passCore:Step() end)
    if not ok then
        -- A failed update is visible and stops further requests.
        AutoPassEnabled, passConfig.Enabled = false, false
        if autoPassConnection then autoPassConnection:Disconnect(); autoPassConnection = nil end
        passCore:Reset()
        if orionAutoPassToggle then
            pcall(function() orionAutoPassToggle:Set(false) end)
        end
        passCore:Status("Auto pass stopped: see console")
        refreshMobileButtons()
        warn("[Auto Pass] " .. tostring(err))
    end
end

local syncingOrion = false
local function syncToggle(toggle, value)
    if toggle and not syncingOrion then
        syncingOrion = true
        local ok, err = pcall(function() toggle:Set(value) end)
        syncingOrion = false
        if not ok then warn("[Auto Pass UI] " .. tostring(err)) end
    end
end

local function updateAutoPassButton()
    if not AutoPassButton then return end
    AutoPassButton.Text = AutoPassEnabled and "AUTO ON" or "AUTO OFF"
    AutoPassButton.BackgroundColor3 = AutoPassEnabled
        and Color3.fromRGB(25, 128, 77) or Color3.fromRGB(115, 52, 64)
end

local function setAutoPassEnabled(value)
    AutoPassEnabled = value == true
    passConfig.Enabled = AutoPassEnabled
    if AutoPassEnabled then
        if not autoPassConnection then
            autoPassConnection = RunService.Heartbeat:Connect(autoPassBomb)
        end
    else
        if autoPassConnection then autoPassConnection:Disconnect(); autoPassConnection = nil end
        passCore:Reset()
        passCore:Status("Auto pass off")
        removeTargetMarker()
    end
    refreshMobileButtons()
    updateAutoPassButton()
    syncToggle(orionAutoPassToggle, AutoPassEnabled)
end

local function setLatePassEnabled(value)
    local mode = value and "Late" or "Normal"
    if passConfig.Mode ~= mode then passCore:Reset(); passConfig.Mode = mode end
    refreshMobileButtons()
    syncToggle(orionLatePassToggle, mode == "Late")
end

local function setPassFlickEnabled(value)
    passConfig.FlickEnabled = value == true
    if not passConfig.FlickEnabled then passCore:EndFlick(true) end
    refreshMobileButtons()
    syncToggle(orionFlickToggle, passConfig.FlickEnabled)
end

LocalPlayer.CharacterRemoving:Connect(function() passCore:Reset() end)

local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()
local Window = OrionLib:MakeWindow({
    Name = "Yon Menu - Advanced (Auto Pass Bomb)",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "YonMenu_Advanced",
    ShowIcon = true
})

-- Create Tabs
local AutomatedTab = Window:MakeTab({
    Name = "Automated Settings",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local AITab = Window:MakeTab({
    Name = "AI Based Settings",
    Icon = "rbxassetid://7072720870",
    PremiumOnly = false
})

local UITab = Window:MakeTab({
    Name = "UI Elements",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Automated Tab Elements
AutomatedTab:AddLabel("== Bomb Passing ==", 15)

orionAutoPassToggle = AutomatedTab:AddToggle({
    Name = "Auto Pass Bomb",
    Default = AutoPassEnabled,
    Flag = "AutoPassBomb",
    Callback = setAutoPassEnabled,
})
orionLatePassToggle = AutomatedTab:AddToggle({
    Name = "Last-second mode (within 6 studs)",
    Default = false,
    Flag = "LastSecondMode",
    Callback = setLatePassEnabled,
})
orionFlickToggle = AutomatedTab:AddToggle({
    Name = "Camera glance on pass",
    Default = false,
    Flag = "BodyFlickOnPass",
    Callback = setPassFlickEnabled,
})
AutomatedTab:AddTextbox({
    Name = "Late request: seconds remaining (0.2 to 2)",
    Default = tostring(passConfig.LateWindow),
    TextDisappear = false,
    Callback = function(value)
        local number = tonumber(value)
        if number and number == number and number > -math.huge and number < math.huge then
            passConfig.LateWindow = math.clamp(number, 0.2, 2)
        end
    end,
})
AutomatedTab:AddTextbox({
    Name = "Assumed fuse length in seconds (fallback)",
    Default = tostring(passConfig.AssumedFuse),
    Flag = "AssumedFuseLength",
    TextDisappear = false,
    Callback = function(value)
        local number = tonumber(value)
        if number and number == number then
            passConfig.AssumedFuse = math.clamp(number, 3, 300)
        end
    end,
})
AutomatedTab:AddLabel("Normal uses your distance setting. Late always uses 6 studs.", 13)
AutomatedTab:AddLabel("If the bomb has no timer, Late counts down the assumed fuse from pickup.", 13)

AutomatedTab:AddLabel("== Character Settings ==", 15)

AutomatedTab:AddToggle({
    Name = "Anti-Slippery",
    Info = "Custom friction: normal (~0.7)/bomb state",
    Default = false,
    Callback = function(v)
        antiSlippery = v
        applyAntiSlippery(v)
    end
})

AutomatedTab:AddTextbox({
    Name = "Custom Anti‑Slippery Friction",
    Default = tostring(customAntiSlipperyFriction),
    Flag = "CustomAntiSlipperyFrict",
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            customAntiSlipperyFriction = num
        end
    end
})

AutomatedTab:AddTextbox({
    Name = "Custom Bomb Anti‑Slippery Friction",
    Default = tostring(customBombAntiSlipperyFriction),
    Flag = "CustomBombAntiSlipperyFrict",
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            customBombAntiSlipperyFriction = num
        end
    end
})

AutomatedTab:AddToggle({
    Name = "Face Bomb",
    Info = "Face nearest bomb holder",
    Default = false,
    Callback = function(v)
        FaceBombEnabled = v
        if v then
            faceBombConnection = RunService.Heartbeat:Connect(faceNearestBombHolder)
        else
            if faceBombConnection then
                faceBombConnection:Disconnect()
                faceBombConnection = nil
            end
        end
    end
})

AutomatedTab:AddToggle({
    Name = "Remove Hitbox",
    Default = RemoveHitboxEnabled,
    Flag = "RemoveHitbox",
    Callback = function(value)
        RemoveHitboxEnabled = value
        applyRemoveHitbox(value)
    end
})

AutomatedTab:AddTextbox({
    Name = "Custom Hitbox Size",
    Default = tostring(customHitboxSize),
    Flag = "CustomHitboxSize",
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            customHitboxSize = num
            if RemoveHitboxEnabled then
                applyRemoveHitbox(true)
            end
        end
    end
})

-- AI Tab Elements
AITab:AddLabel("== Targeting Settings ==", 15)

AITab:AddToggle({
    Name = "AI Assistance",
    Default = false,
    Flag = "AIAssistance",
    Callback = function(value)
        AI_AssistanceEnabled = value
    end
})

AITab:AddTextbox({
    Name = "Bomb Pass Distance",
    Default = tostring(bombPassDistance),
    Flag = "BombPassDistance",
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            bombPassDistance = num
        end
    end
})

AITab:AddTextbox({
    Name = "Ray Spread Angle",
    Default = tostring(raySpreadAngle),
    Flag = "RaySpreadAngle",
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            raySpreadAngle = num
        end
    end
})

AITab:AddTextbox({
    Name = "Number of Raycasts",
    Default = tostring(numRaycasts),
    Flag = "NumberOfRaycasts",
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            numRaycasts = num
        end
    end
})

-- UI Tab Elements
UITab:AddColorpicker({
    Name = "Menu Main Color",
    Default = Color3.fromRGB(255, 0, 0),
    Flag = "MenuMainColor",
    Save = true,
    Callback = function(color)
        OrionLib.Themes[OrionLib.SelectedTheme].Main = color
    end
})
UITab:AddLabel("The shift lock and AUTO buttons on screen can be dragged anywhere.", 13)

-- Initialize the library
OrionLib:Init()
local orionGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("Orion")
local menuIconButton

if orionGui then
    for _, obj in pairs(orionGui:GetDescendants()) do
        if obj:IsA("ImageButton") and obj.Name:lower():find("icon") then
            menuIconButton = obj
            break
        end
    end
end
local myFrictionController = FrictionController.new()
myFrictionController:enable()

local function setUIVisualStealth(enabled)
    -- Hiding a ScreenGui preserves its original transparency and disables its buttons.
    local visible = not enabled
    if mobileGui then mobileGui.Enabled = visible end
    if ShiftLockScreenGui then ShiftLockScreenGui.Enabled = visible end
    local function update(container)
        for _, gui in ipairs(container:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name:match("Orion") then gui.Enabled = visible end
        end
    end
    update(LocalPlayer:WaitForChild("PlayerGui"))
    pcall(function() update(game:GetService("CoreGui")) end)
end

local function createMobileToggle()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MobileToggleGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.DisplayOrder = 50
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Enabled = allUIVisible

    local safeArea = Instance.new("Frame")
    safeArea.Size = UDim2.fromScale(1, 1)
    safeArea.BackgroundTransparency = 1
    safeArea.Parent = gui

    local panel = Instance.new("Frame")
    panel.Name = "TouchPanel"
    panel.Size = UDim2.fromOffset(188, 272)
    panel.Position = UDim2.new(1, -210, 0.42, -136)
    panel.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel = 0
    panel.Parent = safeArea
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = panel

    local handle = Instance.new("TextLabel")
    handle.Name = "DragHandle"
    handle.Size = UDim2.new(1, 0, 0, 38)
    handle.Text = "BOMB PASS  ·  DRAG"
    handle.TextSize = 14
    handle.Font = Enum.Font.GothamBold
    handle.TextColor3 = Color3.fromRGB(204, 214, 230)
    handle.BackgroundTransparency = 1
    handle.Active = true
    handle.Parent = panel

    local function button(name, top)
        local item = Instance.new("TextButton")
        item.Name = name
        item.Size = UDim2.new(1, -16, 0, 52)
        item.Position = UDim2.fromOffset(8, top)
        item.TextSize = 17
        item.Font = Enum.Font.GothamBold
        item.TextColor3 = Color3.new(1, 1, 1)
        item.AutoButtonColor = true
        item.Parent = panel
        local rounding = Instance.new("UICorner")
        rounding.CornerRadius = UDim.new(0, 10)
        rounding.Parent = item
        return item
    end

    local autoButton = button("AutoPassMobileToggle", 38)
    local modeButton = button("PassModeMobileToggle", 98)
    local flickButton = button("PassFlickMobileToggle", 158)
    local status = Instance.new("TextLabel")
    status.Name = "PassStatus"
    status.Size = UDim2.new(1, -16, 0, 48)
    status.Position = UDim2.fromOffset(8, 217)
    status.BackgroundTransparency = 1
    status.TextWrapped = true
    status.TextSize = 13
    status.Font = Enum.Font.Gotham
    status.TextColor3 = Color3.fromRGB(220, 227, 239)
    status.Text = passCore.LastStatus ~= "" and passCore.LastStatus or "Auto pass off"
    status.Parent = panel
    mobileStatus = status

    refreshMobileButtons = function()
        if not gui.Parent then return end
        autoButton.Text = AutoPassEnabled and "AUTO: ON" or "AUTO: OFF"
        autoButton.BackgroundColor3 = AutoPassEnabled
            and Color3.fromRGB(25, 128, 77) or Color3.fromRGB(115, 52, 64)
        modeButton.Text = passConfig.Mode == "Late" and "MODE: LATE · 6" or "MODE: NORMAL"
        modeButton.BackgroundColor3 = passConfig.Mode == "Late"
            and Color3.fromRGB(127, 73, 172) or Color3.fromRGB(51, 80, 122)
        flickButton.Text = passConfig.FlickEnabled and "GLANCE: ON" or "GLANCE: OFF"
        flickButton.BackgroundColor3 = passConfig.FlickEnabled
            and Color3.fromRGB(37, 103, 177) or Color3.fromRGB(63, 70, 84)
    end
    autoButton.Activated:Connect(function() setAutoPassEnabled(not AutoPassEnabled) end)
    modeButton.Activated:Connect(function() setLatePassEnabled(passConfig.Mode ~= "Late") end)
    flickButton.Activated:Connect(function() setPassFlickEnabled(not passConfig.FlickEnabled) end)

    -- Only the handle drags; tapping a toggle cannot accidentally move the panel.
    local dragInput, dragStart, panelStart
    local function place(x, y)
        local bounds = safeArea.AbsoluteSize
        if bounds.X <= 0 or bounds.Y <= 0 then return end
        panel.Position = UDim2.fromOffset(
            math.clamp(x, 8, math.max(8, bounds.X - 196)),
            math.clamp(y, 8, math.max(8, bounds.Y - 280)))
    end
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragInput, dragStart = input, input.Position
            panelStart = panel.AbsolutePosition - safeArea.AbsolutePosition
        end
    end)
    local moveConnection = UserInputService.InputChanged:Connect(function(input)
        if not gui.Enabled or not dragInput then return end
        if input == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            place(panelStart.X + delta.X, panelStart.Y + delta.Y)
        end
    end)
    local endConnection = UserInputService.InputEnded:Connect(function(input)
        if input == dragInput then dragInput = nil end
    end)
    safeArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local position = panel.AbsolutePosition - safeArea.AbsolutePosition
        place(position.X, position.Y)
    end)
    gui.Destroying:Connect(function() moveConnection:Disconnect(); endConnection:Disconnect() end)
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    refreshMobileButtons()
    return gui, autoButton, modeButton, flickButton
end

mobileGui, mobileToggle, mobileModeToggle, flickToggle = createMobileToggle()
LocalPlayer:WaitForChild("PlayerGui").ChildRemoved:Connect(function(child)
    if child == mobileGui then
        task.delay(1, function()
            if not LocalPlayer.PlayerGui:FindFirstChild("MobileToggleGui") then
                mobileGui, mobileToggle, mobileModeToggle, flickToggle = createMobileToggle()
            end
        end)
    end
end)

-- ============================================================================
-- SHIFT LOCK + AUTO PASS BUTTONS
-- Both buttons are freely draggable anywhere on screen. Dragging never
-- activates the button; only a clean tap/click does.
-- ============================================================================

-- Makes a GuiObject draggable. Returns a table whose .moved flag is true when
-- the current/last gesture was a drag (checked and consumed by Activated).
local function makeDraggable(element)
    local state = {dragInput = nil, dragStart = nil, startPos = nil, moved = false}
    local parent = element.Parent
    element.Active = true
    element.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            state.dragInput, state.dragStart, state.moved = input, input.Position, false
            -- Convert to top-left offset positioning in the same frame, using the
            -- position captured before the anchor change, so the button never jumps.
            local topLeft = element.AbsolutePosition - parent.AbsolutePosition
            element.AnchorPoint = Vector2.new(0, 0)
            element.Position = UDim2.fromOffset(topLeft.X, topLeft.Y)
            state.startPos = topLeft
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not state.dragInput or not element.Parent then return end
        if input == state.dragInput or (state.dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - state.dragStart
            if not state.moved and (delta.X * delta.X + delta.Y * delta.Y) > 36 then
                state.moved = true
            end
            local bounds = parent.AbsoluteSize
            local size = element.AbsoluteSize
            local x = math.clamp(state.startPos.X + delta.X, 0, math.max(0, bounds.X - size.X))
            local y = math.clamp(state.startPos.Y + delta.Y, 0, math.max(0, bounds.Y - size.Y))
            element.Position = UDim2.fromOffset(x, y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input == state.dragInput then state.dragInput = nil end
    end)
    return state
end

ShiftLockScreenGui = Instance.new("ScreenGui")
ShiftLockScreenGui.Name = "Shiftlock (CoreGui)"
ShiftLockScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ShiftLockScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ShiftLockScreenGui.ResetOnSpawn = false

-- Shift Lock Button (default near the right edge; drag it wherever you want)
ShiftLockButton = Instance.new("ImageButton")
ShiftLockButton.Parent = ShiftLockScreenGui
ShiftLockButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ShiftLockButton.BackgroundTransparency = 1
ShiftLockButton.AnchorPoint = Vector2.new(1, 0.5)
ShiftLockButton.Position = UDim2.new(1, -120, 0.72, 0)
ShiftLockButton.Size = UDim2.fromOffset(80, 80)
ShiftLockButton.SizeConstraint = Enum.SizeConstraint.RelativeXX
ShiftLockButton.Image = "rbxasset://textures/ui/mouseLock_off@2x.png"
local shiftLockUICorner = Instance.new("UICorner")
shiftLockUICorner.CornerRadius = UDim.new(0.2, 0)
shiftLockUICorner.Parent = ShiftLockButton
local shiftLockUIStroke = Instance.new("UIStroke")
shiftLockUIStroke.Thickness = 2
shiftLockUIStroke.Color = Color3.fromRGB(0, 0, 0)
shiftLockUIStroke.Parent = ShiftLockButton

-- AutoPass Toggle Button (default above the shift lock; also draggable)
AutoPassButton = Instance.new("TextButton")
AutoPassButton.Name = "AutoPassToggle"
AutoPassButton.Parent = ShiftLockScreenGui
AutoPassButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
AutoPassButton.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoPassButton.Font = Enum.Font.GothamBold
AutoPassButton.TextSize = 18
AutoPassButton.AnchorPoint = Vector2.new(1, 0.5)
AutoPassButton.Position = UDim2.new(1, -120, 0.62, 0)
AutoPassButton.Size = UDim2.fromOffset(80, 80)
AutoPassButton.SizeConstraint = Enum.SizeConstraint.RelativeXX
local apCorner = Instance.new("UICorner")
apCorner.CornerRadius = UDim.new(0.2, 0)
apCorner.Parent = AutoPassButton
local apStroke = Instance.new("UIStroke")
apStroke.Thickness = 2
apStroke.Color = Color3.fromRGB(0, 0, 0)
apStroke.Parent = AutoPassButton

local shiftLockDrag = makeDraggable(ShiftLockButton)
local autoPassDrag = makeDraggable(AutoPassButton)
updateAutoPassButton()

-- Click actions: a drag is consumed and never toggles the feature.
AutoPassButton.Activated:Connect(function()
    if autoPassDrag.moved then autoPassDrag.moved = false return end
    setAutoPassEnabled(not AutoPassEnabled)
end)

-- Shift lock cursor
local ShiftlockCursor = Instance.new("ImageLabel")
ShiftlockCursor.Name = "Shiftlock Cursor"
ShiftlockCursor.Parent = ShiftLockScreenGui
ShiftlockCursor.Image = "rbxasset://textures/MouseLockedCursor.png"
ShiftlockCursor.Size = UDim2.new(0.03, 0, 0.03, 0)
ShiftlockCursor.Position = UDim2.new(0.5, 0, 0.5, 0)
ShiftlockCursor.AnchorPoint = Vector2.new(0.5, 0.5)
ShiftlockCursor.SizeConstraint = Enum.SizeConstraint.RelativeXX
ShiftlockCursor.BackgroundTransparency = 1
ShiftlockCursor.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
ShiftlockCursor.Visible = false

-- Shift lock logic
local shiftLockHumanoid
local shiftLockOriginalAutoRotate
local shiftLockRenderName = "YonAdvancedShiftLock"

local function takeShiftLock(humanoid)
    if shiftLockHumanoid ~= humanoid then
        shiftLockHumanoid = humanoid
        shiftLockOriginalAutoRotate = humanoid.AutoRotate
    end
    humanoid.AutoRotate = false
end

ShiftLockButton.Activated:Connect(function()
    if shiftLockDrag.moved then shiftLockDrag.moved = false return end
    if not SL_Active then
        SL_Active = true
        ShiftLockButton.Image = "rbxasset://textures/ui/mouseLock_on@2x.png"
        ShiftlockCursor.Visible = true
        RunService:BindToRenderStep(shiftLockRenderName, Enum.RenderPriority.Camera.Value + 1, function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local camera = Workspace.CurrentCamera
            if not hum or not root or hum.Health <= 0 or not camera then return end
            if camera.CameraType ~= Enum.CameraType.Custom or camera.CameraSubject ~= hum then return end
            takeShiftLock(hum)
            if not passCore:IsFlicking() and not root.Anchored and not hum.Sit
                and not hum.PlatformStand then
                local look = camera.CFrame.LookVector
                local flat = Vector3.new(look.X, 0, look.Z)
                if flat.Magnitude > 0.001 then
                    root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
                end
            end
            -- Apply after the standard camera update so offsets do not accumulate.
            camera.CFrame = camera.CFrame * CFrame.new(1.7, 0, 0)
        end)
    else
        SL_Active = nil
        RunService:UnbindFromRenderStep(shiftLockRenderName)
        if shiftLockHumanoid and shiftLockHumanoid.Parent then
            shiftLockHumanoid.AutoRotate = shiftLockOriginalAutoRotate
        end
        shiftLockHumanoid = nil
        ShiftLockButton.Image = "rbxasset://textures/ui/mouseLock_off@2x.png"
        ShiftlockCursor.Visible = false
    end
end)

-- ============================================================================
-- /e command toggle – hides every UI element including both draggable buttons
-- ============================================================================

LocalPlayer.Chatted:Connect(
    function(msg)
        msg = msg:lower()
        if msg == "/e" then
            allUIVisible = not allUIVisible
            setUIVisualStealth(not allUIVisible)
            AINotificationsModule.sendNotification("UI Toggle", allUIVisible and "UI visible" or "UI hidden", 2)

            if mobileGui then
                mobileGui.Enabled = allUIVisible
                mobileToggle.Visible = allUIVisible
            end
            if ShiftLockButton then
                ShiftLockButton.Visible = allUIVisible
            end
            if AutoPassButton then
                AutoPassButton.Visible = allUIVisible
            end
            if orionGui then
                orionGui.Enabled = allUIVisible
            end
            if menuIconButton then
                menuIconButton.Visible = allUIVisible
            end
        end
    end
)
setUIVisualStealth(not allUIVisible)
print("Auto pass ready: NORMAL / LATE (6 studs, with assumed-fuse fallback), camera glance flick, draggable shift lock + AUTO buttons.")
return {}
