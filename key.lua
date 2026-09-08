-- Complete replacement based on your latest attached script; run once in a fresh session.
-- Preserves the supplied nearest-player selection and Bomb.RemoteEvent pass arguments.
-- NORMAL passes immediately in the configured range; LATE requires a real fuse and <=6 studs.
-- Optional FLICK: face target, short sideways follow-through, resume movement/shift-lock facing.
-- Flick never directly writes camera, movement input, speed, or velocity; body contacts can change.
-- Uses real bomb attributes only. No assumed fuse from pickup time.
-- Retains your draggable AUTO/shift-lock buttons and other existing menu features.

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
local updateAutoPassButton = function() end

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
    -- Normal mode preserves the supplied immediate method; only Late gates on fuse time.
    return distance <= config.NormalDistance
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

-- Preserve the supplied nearest-root selection. Do not silently choose a farther
-- target because the nearest player has a bomb or a missing CollisionPart.
local function getClosestPlayer(players, localPlayer, root)
    local closest, nd = nil, math.huge
    for _, p in ipairs(players:GetPlayers()) do
        if p ~= localPlayer and p.Character then
            local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot and targetRoot:IsA("BasePart") then
                local d = (targetRoot.Position - root.Position).Magnitude
                if d < nd then closest, nd = p, d end
            end
        end
    end
    return closest, nd
end

function PassController:GetTarget(root)
    local player, distance = getClosestPlayer(self.Services.Players, self.Services.LocalPlayer, root)
    local character = player and player.Character
    local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return nil, nil, nil, nil, math.huge end
    return player, character, targetRoot, character:FindFirstChild("CollisionPart"), distance
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

local function flatDirection(vector)
    local flat = Vector3.new(vector.X, 0, vector.Z)
    return flat.Magnitude > 0.001 and flat.Unit or nil
end

local function canTurn(humanoid)
    if humanoid.Health <= 0 or humanoid.Sit or humanoid.PlatformStand then return false end
    local state = humanoid:GetState()
    return state ~= Enum.HumanoidStateType.Dead and state ~= Enum.HumanoidStateType.Physics
        and state ~= Enum.HumanoidStateType.Ragdoll and state ~= Enum.HumanoidStateType.Swimming
        and state ~= Enum.HumanoidStateType.Climbing
end

function PassController:IsFlicking()
    return self.Flick ~= nil
end

function PassController:ReturnRotation(flick)
    local direction
    if self.Hooks.shiftLocked() then
        local camera = self.Services.Workspace.CurrentCamera
        direction = camera and flatDirection(camera.CFrame.LookVector)
    elseif flick.OriginalAutoRotate then
        direction = flatDirection(flick.Humanoid.MoveDirection)
    end
    return direction and CFrame.lookAt(Vector3.zero, direction) or flick.OriginalRotation
end

function PassController:EndFlick(restoreFacing)
    local flick = self.Flick
    if not flick then return end
    self.Flick = nil
    if flick.Connection then flick.Connection:Disconnect() end
    if flick.Humanoid.Parent then
        if restoreFacing and self.Services.LocalPlayer.Character == flick.Character
            and flick.Root.Parent and not flick.Root.Anchored and canTurn(flick.Humanoid) then
            -- Always retain the current position. Never restore an old position or velocity.
            flick.Root.CFrame = CFrame.new(flick.Root.Position) * self:ReturnRotation(flick)
        end
        if self.Hooks.shiftLocked() then
            flick.Humanoid.AutoRotate = false
        else
            flick.Humanoid.AutoRotate = flick.OriginalAutoRotate
        end
    end
end

local function smoothstep(alpha)
    return alpha * alpha * (3 - 2 * alpha)
end

function PassController:StartFlick(character, root, humanoid, targetRoot, now)
    if not self.Config.FlickEnabled or now < self.NextFlick or self.Flick
        or root.Anchored or not canTurn(humanoid) then return end
    local direction = flatDirection(targetRoot.Position - root.Position)
    if not direction then return end
    local flick = {
        Character = character, Root = root, Humanoid = humanoid,
        OriginalAutoRotate = humanoid.AutoRotate, OriginalRotation = root.CFrame.Rotation,
        TargetRotation = CFrame.lookAt(Vector3.zero, direction), Started = now,
        Duration = math.clamp(self.Config.FlickDuration, 0.14, 0.4),
    }
    local resumeDirection = self:ReturnRotation(flick).LookVector
    local crossY = direction.Z * resumeDirection.X - direction.X * resumeDirection.Z
    local sign = crossY < 0 and -1 or 1
    flick.SweepRotation = flick.TargetRotation
        * CFrame.Angles(0, sign * math.rad(math.clamp(self.Config.FlickAngle, 30, 140)), 0)
    self.Flick = flick
    self.NextFlick = now + math.max(0.6, flick.Duration + 0.15)
    humanoid.AutoRotate = false
    -- Face, sweep sideways, then give facing back. Keep existing position/input.
    -- No delay before FireServer, and no camera writes in this controller.
    root.CFrame = CFrame.new(root.Position) * flick.TargetRotation
    flick.Connection = self.Services.RunService.PreSimulation:Connect(function()
        if self.Flick ~= flick then return end
        if not self.Config.Enabled or not self.Config.FlickEnabled
            or self.Services.LocalPlayer.Character ~= character or not root.Parent
            or root.Anchored or not humanoid.Parent or not canTurn(humanoid) then
            self:EndFlick(true)
            return
        end
        local elapsed = self.Services.Workspace:GetServerTimeNow() - flick.Started
        local progress = math.max(0, elapsed / flick.Duration)
        if progress >= 1 then self:EndFlick(true); return end
        local rotation
        if progress < 0.20 then
            rotation = flick.TargetRotation
        elseif progress < 0.55 then
            rotation = flick.TargetRotation:Lerp(flick.SweepRotation,
                smoothstep((progress - 0.20) / 0.35))
        else
            rotation = flick.SweepRotation:Lerp(self:ReturnRotation(flick),
                smoothstep((progress - 0.55) / 0.45))
        end
        root.CFrame = CFrame.new(root.Position) * rotation
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
    local remaining, timerReason = self.remaining(bomb, now)
    local remote = bomb:FindFirstChild("RemoteEvent")
    if not remote or not remote:IsA("RemoteEvent") then
        self:Status("Unsupported: Bomb.RemoteEvent missing")
        return
    end
    if self.Config.Mode == "Late" and remaining == nil then
        self:Status(timerReason)
        return
    end
    if self.Config.Mode == "Late" and remaining and remaining <= 0 then
        self:Status("Bomb deadline reached"); return
    end
    local target, targetCharacter, targetRoot, collision, distance = self:GetTarget(root)
    local timeText = remaining and string.format("%.2fs", math.max(0, remaining)) or "Timer unknown"
    if not target then self:Status(timeText .. " | No valid target"); return end
    self:Status(timeText .. string.format(" | %.1f studs", distance))
    if not self.eligible(self.Config.Mode, remaining, distance, self.Config)
        or now < self.NextRequest then return end

    -- Revalidate identity and range immediately before sending.
    if bomb.Parent ~= character or target.Character ~= targetCharacter
        or targetCharacter:FindFirstChild("HumanoidRootPart") ~= targetRoot then return end
    local currentDistance = (root.Position - targetRoot.Position).Magnitude
    -- Read the deadline again at the final gate; earlier work may have taken time.
    remaining = self.remaining(bomb, self.Services.Workspace:GetServerTimeNow())
    if not self.eligible(self.Config.Mode, remaining, currentDistance, self.Config) then return end
    pending = {Bomb = bomb, Character = character, Target = target,
        TargetCharacter = targetCharacter, SentAt = now}
    self.Pending = pending
    pending.Connection = bomb.AncestryChanged:Connect(function() self:ObserveTransfer(pending) end)
    self.NextRequest = now + self.Config.RequestCooldown
    local flickOK, flickError = pcall(function()
        self:StartFlick(character, root, humanoid, targetRoot, now)
    end)
    if not flickOK then
        pcall(function() self:EndFlick(false) end)
        warn("[Pass Flick] " .. tostring(flickError))
    end
    -- This is the same passing endpoint and argument lookup supplied by the user.
    local ok, err = pcall(function()
        remote:FireServer(targetCharacter, targetCharacter:FindFirstChild("CollisionPart"))
    end)
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
    FlickEnabled = false,
    FlickAngle = 90,
    FlickDuration = 0.22,
    RequestCooldown = 0.10,
    AckTimeout = 0.10,
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
        updateAutoPassButton()
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

updateAutoPassButton = function()
    if not AutoPassButton then return end
    AutoPassButton.Text = AutoPassEnabled and "AUTO\nON" or "AUTO\nOFF"
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
    Name = "Body sweep flick on pass",
    Default = false,
    Flag = "BodySweepOnPassV2",
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
    Name = "Flick sweep angle (30 to 140 degrees)",
    Default = tostring(passConfig.FlickAngle),
    TextDisappear = false,
    Callback = function(value)
        local number = tonumber(value)
        if finiteNumber(number) then passConfig.FlickAngle = math.clamp(number, 30, 140) end
    end,
})
AutomatedTab:AddTextbox({
    Name = "Flick duration (0.14 to 0.4 seconds)",
    Default = tostring(passConfig.FlickDuration),
    TextDisappear = false,
    Callback = function(value)
        local number = tonumber(value)
        if finiteNumber(number) then passConfig.FlickDuration = math.clamp(number, 0.14, 0.4) end
    end,
})

AutomatedTab:AddLabel("Normal uses your distance setting. Late always uses 6 studs.", 13)
AutomatedTab:AddLabel("Late requires real bomb timer attributes; no guessed pickup timer.", 13)

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
        if finiteNumber(num) and num > 0 then
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
        flickButton.Text = passConfig.FlickEnabled and "FLICK: ON" or "FLICK: OFF"
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

local function makeDraggable(element)
    local state = {dragInput = nil, moved = false}
    local parent = element.Parent -- a real Frame with explicit safe-area bounds
    local screen = element:FindFirstAncestorOfClass("ScreenGui")
    local connections = {}
    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        table.insert(connections, connection)
    end
    local function enabled()
        return element.Parent == parent and parent.Parent
            and element.Visible and (not screen or screen.Enabled)
    end
    local function place(x, y)
        local bounds, size = parent.AbsoluteSize, element.AbsoluteSize
        if bounds.X <= 0 or bounds.Y <= 0 then return end
        element.AnchorPoint = Vector2.new(0, 0)
        element.Position = UDim2.fromOffset(
            math.clamp(x, 4, math.max(4, bounds.X - size.X - 4)),
            math.clamp(y, 4, math.max(4, bounds.Y - size.Y - 4)))
    end
    local function clampPosition()
        if not element.Parent then return end
        local position = element.AbsolutePosition - parent.AbsolutePosition
        place(position.X, position.Y)
    end
    local function update(input)
        if not state.dragInput or not enabled() then return end
        if input ~= state.dragInput and not
            (state.dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement) then return end
        local delta = input.Position - state.dragStart
        if delta.X * delta.X + delta.Y * delta.Y >= 100 then state.moved = true end
        -- Finger jitter during a tap must not move the button.
        if state.moved then place(state.startPos.X + delta.X, state.startPos.Y + delta.Y) end
    end
    element.Active = true
    connect(element.InputBegan, function(input)
        if state.dragInput or not enabled() then return end
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            state.dragInput, state.dragStart, state.moved = input, input.Position, false
            state.startPos = element.AbsolutePosition - parent.AbsolutePosition
        end
    end)
    connect(UserInputService.InputChanged, update)
    connect(UserInputService.InputEnded, function(input)
        if input == state.dragInput then
            update(input)
            state.dragInput = nil
            -- Keep moved until the next pointer-down: Activated may run after InputEnded.
        end
    end)
    connect(parent:GetPropertyChangedSignal("AbsoluteSize"), function() task.defer(clampPosition) end)
    if screen then
        connect(screen:GetPropertyChangedSignal("Enabled"), function()
            if not screen.Enabled then state.dragInput = nil; state.moved = true end
        end)
    end
    element.Destroying:Connect(function()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        state.dragInput = nil
    end)
    function state:ShouldActivate(input)
        if not enabled() then return false end
        if input and input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return true end
        return not self.moved
    end
    task.defer(clampPosition)
    return state
end

ShiftLockScreenGui = Instance.new("ScreenGui")
ShiftLockScreenGui.Name = "Shiftlock (CoreGui)"
ShiftLockScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ShiftLockScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ShiftLockScreenGui.ResetOnSpawn = false
ShiftLockScreenGui.IgnoreGuiInset = false
ShiftLockScreenGui.DisplayOrder = 51
local touchButtonArea = Instance.new("Frame")
touchButtonArea.Name = "TouchButtonSafeArea"
touchButtonArea.Size = UDim2.fromScale(1, 1)
touchButtonArea.BackgroundTransparency = 1
touchButtonArea.Parent = ShiftLockScreenGui

-- Shift Lock Button (default near the right edge; drag it wherever you want)
ShiftLockButton = Instance.new("ImageButton")
ShiftLockButton.Parent = touchButtonArea
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
AutoPassButton.Parent = touchButtonArea
AutoPassButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
AutoPassButton.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoPassButton.Font = Enum.Font.GothamBold
AutoPassButton.TextSize = 18
AutoPassButton.AnchorPoint = Vector2.new(1, 0.5)
AutoPassButton.Position = UDim2.new(1, -120, 0.72, -94)
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
AutoPassButton.Activated:Connect(function(input)
    if not autoPassDrag:ShouldActivate(input) then return end
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
        if passCore.Flick and passCore.Flick.Humanoid == humanoid then
            shiftLockOriginalAutoRotate = passCore.Flick.OriginalAutoRotate
        end
    end
    humanoid.AutoRotate = false
end

ShiftLockButton.Activated:Connect(function(input)
    if not shiftLockDrag:ShouldActivate(input) then return end
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
            if passCore.Flick and passCore.Flick.Humanoid == shiftLockHumanoid then
                passCore.Flick.OriginalAutoRotate = shiftLockOriginalAutoRotate
            else
                shiftLockHumanoid.AutoRotate = shiftLockOriginalAutoRotate
            end
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
print("Auto pass ready: confirmed nearest-player method, NORMAL/LATE (6 studs), body sweep flick, draggable iPad controls.")
return {}
