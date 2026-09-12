-- Complete replacement. Run once in a fresh session.
-- Live timer: BombStartTime + BombDuration - Workspace:GetServerTimeNow().
-- Active states: Running/Fused. The dedicated timer stays active with Auto Pass off.
-- Normal keeps your confirmed nearest-player pass call; Late remains <=6 studs.
-- Adaptive flick eases in/out, yields to manual turns, and skips already-aligned targets.
-- Controls start LOCKED. Tap LAYOUT to edit positions, then lock again to save.
-- Other original menu/movement features remain as supplied.

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
local orionAutoPassToggle, orionLatePassToggle, orionFlickToggle, orionLayoutToggle
local mobileTimer
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
        return nil, "State: " .. tostring(state or "missing")
    end
    local startTime = bomb:GetAttribute("BombStartTime")
    local duration = bomb:GetAttribute("BombDuration")
    if not finiteNumber(startTime) then return nil, "BombStartTime missing or invalid" end
    if not finiteNumber(duration) or duration <= 0 then return nil, "BombDuration missing or invalid" end
    if not finiteNumber(now) then return nil, "Server time unavailable" end
    -- Same fractional deadline as the game's BombClient; never round before gating.
    return startTime + duration - now
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
        LastStatus = "", HeldBomb = nil, HeldCharacter = nil, FlickedForPossession = false,
    }, PassController)
end

function PassController:Status(message)
    if message ~= self.LastStatus then
        self.LastStatus = message
        self.Hooks.status(message)
    end
end

function PassController:GetBomb(character, now)
    local named = character:FindFirstChild("Bomb")
    if self.Config.Mode ~= "Late" and named and isBomb(named) then return named end
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
    local player, distance
    if self.Config.Mode == "Late" then
        -- A dead/respawning character may be closer than the live receiver.
        -- Timed mode must not spend the remaining fuse sending to that character.
        distance = math.huge
        for _, candidate in ipairs(self.Services.Players:GetPlayers()) do
            if candidate ~= self.Services.LocalPlayer then
                local targetRoot = livingParts(candidate.Character)
                if targetRoot then
                    local current = (targetRoot.Position - root.Position).Magnitude
                    if current < distance then player, distance = candidate, current end
                end
            end
        end
    else
        player, distance = getClosestPlayer(self.Services.Players, self.Services.LocalPlayer, root)
    end
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
        local flick = self.Flick
        if flick and not flick.ConfirmedAt and flick.Character == pending.Character and flick.Root.Parent then
            flick.ConfirmedAt = self.Services.Workspace:GetServerTimeNow()
        end
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

function PassController:CameraRelative()
    return self.Hooks.shiftLocked()
        or (self.Hooks.cameraRelative and self.Hooks.cameraRelative() == true)
        or false
end

function PassController:ReturnRotation(flick)
    local direction
    if self:CameraRelative() then
        local camera = self.Services.Workspace.CurrentCamera
        if camera and camera.CameraSubject == flick.Humanoid then
            direction = flatDirection(camera.CFrame.LookVector)
        end
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
            -- Never rewind position, velocity, camera or joystick input.
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

-- Pure timing helper: larger turns take a little longer, never a fixed 180-degree snap.
function PassController.flickProfile(turnDegrees, preferredDuration)
    if not finiteNumber(turnDegrees) then turnDegrees = 0 end
    if not finiteNumber(preferredDuration) then preferredDuration = 0.18 end
    local scale = math.clamp(math.abs(turnDegrees) / 90, 0.60, 1.35)
    local total = math.clamp(math.clamp(preferredDuration, 0.10, 0.30) * scale, 0.10, 0.30)
    return {Total = total, Turn = total * 0.40, Follow = total * 0.10, Return = total * 0.50}
end

function PassController:BeginFlickReturn(flick, atTime, duration, rotation)
    flick.ReleaseAt = atTime
    flick.ReleaseDuration = duration
    flick.ReleaseRotation = rotation or flick.Root.CFrame.Rotation
end

function PassController:ManualTurnDetected(flick)
    local cameraRelative = self:CameraRelative()
    if self.Hooks.shiftLocked() ~= flick.InitialShiftLocked
        or cameraRelative ~= flick.InitialCameraRelative then return true end
    if cameraRelative then
        local camera = self.Services.Workspace.CurrentCamera
        if camera ~= flick.Camera then return true end
        local direction = camera and flatDirection(camera.CFrame.LookVector)
        -- Camera translation and pitch alone do not cancel a horizontal body turn.
        return direction ~= nil and flick.InitialCameraDirection ~= nil
            and direction:Dot(flick.InitialCameraDirection) < math.cos(math.rad(10))
    end
    if flick.OriginalAutoRotate then
        local movement = flatDirection(flick.Humanoid.MoveDirection)
        if (movement == nil) ~= (flick.InitialMoveDirection == nil) then return true end
        return movement ~= nil and flick.InitialMoveDirection ~= nil
            and movement:Dot(flick.InitialMoveDirection) < math.cos(math.rad(50))
    end
    return false
end

function PassController:UpdateFlick(flick)
    if self.Flick ~= flick then return end
    local root, humanoid = flick.Root, flick.Humanoid
    if not self.Config.Enabled or not self.Config.FlickEnabled
        or self.Services.LocalPlayer.Character ~= flick.Character or not root.Parent
        or root.Anchored or not humanoid.Parent or not canTurn(humanoid) then
        self:EndFlick(true)
        return
    end
    local now = self.Services.Workspace:GetServerTimeNow()
    local elapsed = math.max(0, now - flick.Started)
    -- Do not replay a stale turn after a large frame hitch.
    if elapsed >= flick.Profile.Total + 0.08 then self:EndFlick(true); return end

    if not flick.InputYielded and self:ManualTurnDetected(flick) then
        flick.InputYielded = true
        self:BeginFlickReturn(flick, now, math.min(0.06, flick.Profile.Return))
    end

    local rotation
    if not flick.ReleaseAt then
        local turnEnd = flick.Started + flick.Profile.Turn
        local releaseAt = turnEnd + flick.Profile.Follow
        if flick.ConfirmedAt then
            -- A fast acknowledgement must not cut the target turn down to one frame.
            releaseAt = math.min(releaseAt, math.max(turnEnd, flick.ConfirmedAt))
        end
        if now < turnEnd then
            local alpha = math.clamp(elapsed / flick.Profile.Turn, 0, 1)
            rotation = flick.OriginalRotation:Lerp(flick.TargetRotation, smoothstep(alpha))
        elseif now < releaseAt then
            local alpha = math.clamp((now - turnEnd) / flick.Profile.Follow, 0, 1)
            rotation = flick.TargetRotation:Lerp(flick.SweepRotation, smoothstep(alpha))
        else
            local alpha = math.clamp((releaseAt - turnEnd) / flick.Profile.Follow, 0, 1)
            local peak = flick.TargetRotation:Lerp(flick.SweepRotation, smoothstep(alpha))
            self:BeginFlickReturn(flick, releaseAt, flick.Profile.Return, peak)
        end
    end
    if flick.ReleaseAt then
        local alpha = math.clamp((now - flick.ReleaseAt) / flick.ReleaseDuration, 0, 1)
        if alpha >= 1 then self:EndFlick(true); return end
        -- Return to LIVE camera/movement intent, not the heading captured at pickup.
        rotation = flick.ReleaseRotation:Lerp(self:ReturnRotation(flick), smoothstep(alpha))
    end
    root.CFrame = CFrame.new(root.Position) * rotation
end

function PassController:StartFlick(character, root, humanoid, targetRoot, now)
    if not self.Config.FlickEnabled or self.FlickedForPossession or now < self.NextFlick or self.Flick
        or root.Anchored or not canTurn(humanoid) then return end
    local direction = flatDirection(targetRoot.Position - root.Position)
    local facing = flatDirection(root.CFrame.LookVector)
    if not direction or not facing then return end
    local camera = self.Services.Workspace.CurrentCamera
    if camera and (camera.CameraType ~= Enum.CameraType.Custom or camera.CameraSubject ~= humanoid) then return end

    local turnDegrees = math.deg(math.acos(math.clamp(facing:Dot(direction), -1, 1)))
    -- Consume this possession's visual attempt even when already facing the target.
    -- Passing retries should not manufacture a new flick after you start moving.
    self.FlickedForPossession = true
    if turnDegrees < 6 then return end

    local flick = {
        Character = character, Root = root, Humanoid = humanoid,
        OriginalAutoRotate = humanoid.AutoRotate, OriginalRotation = root.CFrame.Rotation,
        TargetRotation = CFrame.lookAt(Vector3.zero, direction), Started = now,
        Profile = self.flickProfile(turnDegrees, self.Config.FlickDuration),
        Camera = camera, InitialCameraDirection = camera and flatDirection(camera.CFrame.LookVector),
        InitialMoveDirection = flatDirection(humanoid.MoveDirection),
        InitialShiftLocked = self.Hooks.shiftLocked(), InitialCameraRelative = self:CameraRelative(),
    }
    local resumeDirection = self:ReturnRotation(flick).LookVector
    local crossY = direction.Z * resumeDirection.X - direction.X * resumeDirection.Z
    local sign = crossY < 0 and -1 or 1
    local followAngle = finiteNumber(self.Config.FlickAngle) and self.Config.FlickAngle or 0
    flick.SweepRotation = flick.TargetRotation
        * CFrame.Angles(0, sign * math.rad(math.clamp(followAngle, 0, 60)), 0)
    self.Flick = flick
    self.NextFlick = now + 0.70
    humanoid.AutoRotate = false
    -- No instant target snap and no waiting before the unchanged FireServer call.
    -- Only current-position body rotation is animated; the camera stays under your control.
    flick.Connection = self.Services.RunService.PreSimulation:Connect(function()
        local ok, err = pcall(function() self:UpdateFlick(flick) end)
        if not ok then
            pcall(function() self:EndFlick(false) end)
            warn("[Pass Flick] " .. tostring(err))
        end
    end)
end

function PassController:Reset()
    self:ClearPending()
    self:EndFlick(true)
    self.HeldBomb, self.HeldCharacter = nil, nil
    self.FlickedForPossession = false
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
                self.HeldBomb = nil
                self.FlickedForPossession = false
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
    if not bomb then
        self.HeldBomb = nil
        self.FlickedForPossession = false
        self:Status("No equipped bomb")
        return
    end
    if self.HeldBomb ~= bomb or self.HeldCharacter ~= character then
        self.HeldBomb, self.HeldCharacter = bomb, character
        self.NextRequest = 0
        self.FlickedForPossession = false
        -- Keep NextFlick across possession changes so rapid hand-backs do not spin you.
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
    if not target then self:Status("Waiting for a living target"); return end
    if self.Config.Mode == "Late" then
        if distance > 6 then
            self:Status(string.format("OUT OF RANGE: %.1f / 6 studs", distance))
        elseif remaining > self.Config.LateWindow then
            self:Status(string.format("ARMED: %.2f s > %.2f s | %.1f studs", remaining, self.Config.LateWindow, distance))
        else
            self:Status(string.format("SENDING: %.3f s | %s | %.1f studs", remaining, target.Name, distance))
        end
    else
        self:Status(string.format("NORMAL | %s | %.1f studs", target.Name, distance))
    end
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
    FlickAngle = 0,
    FlickDuration = 0.18, -- Reference duration for a 90-degree turn; scales with angle.
    RequestCooldown = 0.10,
    AckTimeout = 0.10,
}

passCore = PassController.new({
    Players = Players, LocalPlayer = LocalPlayer,
    Workspace = Workspace, RunService = RunService,
}, passConfig, {
    shiftLocked = function() return SL_Active ~= nil end,
    cameraRelative = function()
        -- Read the standard mode only. Never toggle the game's own shift-lock setting.
        local ok, rotationType = pcall(function()
            return UserSettings():GetService("UserGameSettings").RotationType
        end)
        return ok and rotationType == Enum.RotationType.CameraRelative
    end,
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
            -- Evaluate on each simulation frame using the shared fractional timer.
            autoPassConnection = RunService.PreSimulation:Connect(autoPassBomb)
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
    passCore:Status(AutoPassEnabled and (mode == "Late" and "Timed mode armed; waiting for a bomb" or "Normal mode ready")
        or "AUTO IS OFF — enable Auto to pass")
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

-- A passive timer view, independent of Auto Pass, targets, remotes and pass messages.
local timerElapsed = 0
local timerLastError
local timerConnection = RunService.RenderStepped:Connect(function(deltaTime)
    timerElapsed = timerElapsed + deltaTime
    if timerElapsed < 1 / 30 then return end
    timerElapsed = 0
    if not mobileTimer or not mobileTimer.Parent then return end
    local ok, err = pcall(function()
        local now = Workspace:GetServerTimeNow()
        local character = LocalPlayer.Character
        local bomb = character and passCore:GetBomb(character, now)
        local stowed = false
        if not bomb then
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            bomb = backpack and passCore:GetBomb(backpack, now)
            stowed = bomb ~= nil
        end
        if not bomb then
            mobileTimer.Text = "YOUR BOMB: --\nNot carrying a Bomb Tool"
            mobileTimer.TextColor3 = Color3.fromRGB(190, 202, 220)
            return
        end
        local remaining, reason = PassController.remaining(bomb, now)
        if remaining == nil then
            mobileTimer.Text = "BOMB TIMER UNAVAILABLE\n" .. reason
            mobileTimer.TextColor3 = Color3.fromRGB(255, 200, 100)
            return
        end
        local heading = stowed and "STOWED BOMB" or "YOUR BOMB"
        mobileTimer.Text = heading .. string.format(": %.3f s\n", math.max(0, remaining))
            .. tostring(bomb:GetAttribute("BombState"))
        mobileTimer.TextColor3 = remaining <= passConfig.LateWindow
            and Color3.fromRGB(255, 132, 119) or Color3.fromRGB(215, 233, 250)
    end)
    if not ok then
        mobileTimer.Text = "BOMB TIMER: read error"
        if tostring(err) ~= timerLastError then warn("[Bomb Timer] " .. tostring(err)) end
        timerLastError = tostring(err)
    else
        timerLastError = nil
    end
end)

-- Layout edits are opt-in. Gameplay taps never reposition a locked control.
local layoutEditing = false
local layoutPositions = {}
local buttonSizes = {
    auto = UserInputService.TouchEnabled and 72 or 52,
    shift = UserInputService.TouchEnabled and 72 or 52,
}
local layoutBindings = {}
local layoutPlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local layoutHttp = game:GetService("HttpService")
local layoutAttribute = "YonPassLayoutV3"
local layoutFile = "YonMenu_Advanced/ipad-layout-v3.json"

local function decodeLayout(text)
    if type(text) ~= "string" then return false end
    local ok, data = pcall(function() return layoutHttp:JSONDecode(text) end)
    if not ok or type(data) ~= "table" or data.version ~= 3 or type(data.positions) ~= "table" then
        return false
    end
    for _, key in ipairs({"panel", "auto", "shift", "settings"}) do
        local point = data.positions[key]
        if type(point) == "table" and finiteNumber(point.x) and finiteNumber(point.y) then
            layoutPositions[key] = {x = math.clamp(point.x, 0, 1), y = math.clamp(point.y, 0, 1)}
        end
    end
    if type(data.sizes) == "table" then
        for _, key in ipairs({"auto", "shift"}) do
            if finiteNumber(data.sizes[key]) then
                buttonSizes[key] = math.clamp(math.floor(data.sizes[key] + 0.5), 44, 160)
            end
        end
    end
    return true
end

local loadedLayout = decodeLayout(layoutPlayerGui:GetAttribute(layoutAttribute))
if not loadedLayout and type(readfile) == "function" then
    local ok, text = pcall(function() return readfile(layoutFile) end)
    if ok then decodeLayout(text) end
end

local function saveLayout()
    local ok, text = pcall(function()
        return layoutHttp:JSONEncode({
            version = 3,
            positions = layoutPositions,
            sizes = buttonSizes
        })
    end)

    if not ok then return end
    layoutPlayerGui:SetAttribute(layoutAttribute, text)

    if type(writefile) == "function" then
        if type(makefolder) == "function" then
            pcall(makefolder, "YonMenu_Advanced")
        end

        pcall(function()
            writefile(layoutFile, text)
        end)
    end
end

local function setButtonSize(key, value)
    local number = tonumber(value)
    if not finiteNumber(number) then return end
    local size = math.clamp(math.floor(number + 0.5), 44, 160)
    buttonSizes[key] = size
    local button = key == "auto" and AutoPassButton or ShiftLockButton
    if button then
        button.Size = UDim2.fromOffset(size, size)
        if key == "auto" then button.TextSize = math.clamp(math.floor(size * 0.26), 12, 28) end
    end
    saveLayout()
end

local function setLayoutEditing(value)
    layoutEditing = value == true
    if not layoutEditing then
        for binding in pairs(layoutBindings) do binding:CancelGesture() end
        saveLayout()
    end
    refreshMobileButtons()
    syncToggle(orionLayoutToggle, layoutEditing)
end

local function makeDraggable(element, handle, key)
    handle = handle or element
    local state = {dragInput = nil, moved = false}
    local parent = element.Parent
    local screen = element:FindFirstAncestorOfClass("ScreenGui")
    local connections = {}
    local function connect(signal, callback)
        table.insert(connections, signal:Connect(callback))
    end
    local function enabled()
        return element.Parent == parent and parent.Parent and element.Visible
            and (not screen or screen.Enabled)
    end
    local function ranges()
        local bounds, size = parent.AbsoluteSize, element.AbsoluteSize
        if bounds.X <= 0 or bounds.Y <= 0 then return nil end
        return math.max(0, bounds.X - size.X - 8), math.max(0, bounds.Y - size.Y - 8)
    end
    local function place(x, y, remember)
        local maxX, maxY = ranges()
        if not maxX then return end
        x, y = math.clamp(x, 4, 4 + maxX), math.clamp(y, 4, 4 + maxY)
        element.AnchorPoint = Vector2.new(0, 0)
        element.Position = UDim2.fromOffset(x, y)
        if remember then
            layoutPositions[key] = {
                x = maxX > 0 and (x - 4) / maxX or 0,
                y = maxY > 0 and (y - 4) / maxY or 0,
            }
        end
    end
    local function restorePosition()
        if not element.Parent then return end
        local maxX, maxY = ranges()
        if not maxX then return end
        local point = layoutPositions[key]
        if point then
            place(4 + point.x * maxX, 4 + point.y * maxY, false)
        else
            local current = element.AbsolutePosition - parent.AbsolutePosition
            place(current.X, current.Y, true)
        end
    end
    function state:CancelGesture()
        if self.dragInput then self.moved = true end
        self.dragInput = nil
    end
    local function update(input)
        if not layoutEditing or not state.dragInput or not enabled() then return end
        if input ~= state.dragInput and not
            (state.dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement) then return end
        local delta = input.Position - state.dragStart
        if delta.X * delta.X + delta.Y * delta.Y >= 100 then state.moved = true end
        if state.moved then place(state.startPos.X + delta.X, state.startPos.Y + delta.Y, true) end
    end
    handle.Active = true
    connect(handle.InputBegan, function(input)
        if state.dragInput or not enabled() then return end
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            state.moved = false
            -- A locked button still accepts clean taps, but never starts a drag.
            if not layoutEditing then return end
            state.dragInput, state.dragStart = input, input.Position
            state.startPos = element.AbsolutePosition - parent.AbsolutePosition
        end
    end)
    connect(UserInputService.InputChanged, update)
    connect(UserInputService.InputEnded, function(input)
        if input == state.dragInput then
            update(input)
            state.dragInput = nil
        end
    end)
    connect(element:GetPropertyChangedSignal("AbsoluteSize"), restorePosition)
    connect(parent:GetPropertyChangedSignal("AbsoluteSize"), function()
        state:CancelGesture()
        task.defer(restorePosition)
    end)
    if screen then
        connect(screen:GetPropertyChangedSignal("Enabled"), function()
            if not screen.Enabled then state:CancelGesture() end
        end)
    end
    element.Destroying:Connect(function()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        layoutBindings[state] = nil
        state.dragInput = nil
    end)
    function state:ShouldActivate(input)
        if not enabled() then return false end
        if input and input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return true end
        return not self.moved
    end
    layoutBindings[state] = true
    task.defer(restorePosition)
    return state
end


-- Native responsive settings adapter; existing feature callbacks are reused below.
local OrionLib = {Themes={Default={Main=Color3.fromRGB(111,104,244)}},SelectedTheme="Default"}
local function uiNew(class,properties,parent)
    local item=Instance.new(class)
    for key,value in pairs(properties) do item[key]=value end
    item.Parent=parent
    return item
end
local function uiRound(item,radius)
    uiNew("UICorner",{CornerRadius=UDim.new(0,radius or 10)},item)
end
local settingsGui=uiNew("ScreenGui",{Name="OrionBombSettingsV5",ResetOnSpawn=false,
    IgnoreGuiInset=false,DisplayOrder=70,ZIndexBehavior=Enum.ZIndexBehavior.Sibling},LocalPlayer:WaitForChild("PlayerGui"))
local settingsArea=uiNew("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1},settingsGui)
local settingsPanel=uiNew("Frame",{Name="Settings",Size=UDim2.fromOffset(540,540),
    Position=UDim2.fromOffset(24,100),BackgroundColor3=Color3.fromRGB(20,23,34),BorderSizePixel=0,Visible=false},settingsArea)
uiRound(settingsPanel,16)
uiNew("UIStroke",{Color=Color3.fromRGB(70,77,100),Transparency=.3},settingsPanel)
local settingsHeading=uiNew("TextLabel",{Text="BOMB PASS  /  SETTINGS",Font=Enum.Font.GothamBold,
    TextSize=18,TextColor3=Color3.fromRGB(237,240,255),BackgroundTransparency=1,
    TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(18,0),Size=UDim2.new(1,-82,0,54)},settingsPanel)
local closeSettings=uiNew("TextButton",{Text="×",TextSize=26,Font=Enum.Font.Gotham,
    TextColor3=Color3.fromRGB(227,231,248),BackgroundTransparency=1,
    Size=UDim2.fromOffset(48,48),Position=UDim2.new(1,-52,0,3)},settingsPanel)
closeSettings.Activated:Connect(function() settingsPanel.Visible=false end)
local tabStrip=uiNew("Frame",{Position=UDim2.fromOffset(12,58),Size=UDim2.new(1,-24,0,44),BackgroundTransparency=1},settingsPanel)
uiNew("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,6),SortOrder=Enum.SortOrder.LayoutOrder},tabStrip)
local pages={}
local function resizeSettings()
    local size=settingsArea.AbsoluteSize
    if size.X<=0 or size.Y<=0 then return end
    settingsPanel.Size=UDim2.fromOffset(math.min(540,size.X-24),math.min(570,size.Y-28))
    local pos=settingsPanel.Position
    settingsPanel.Position=UDim2.fromOffset(math.clamp(pos.X.Offset,12,math.max(12,size.X-settingsPanel.AbsoluteSize.X-12)),
        math.clamp(pos.Y.Offset,12,math.max(12,size.Y-settingsPanel.AbsoluteSize.Y-12)))
end
settingsArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeSettings)
task.defer(resizeSettings)
makeDraggable(settingsPanel,settingsHeading,"settings")
local function toggleSettings() settingsPanel.Visible=not settingsPanel.Visible;resizeSettings() end
UserInputService.InputBegan:Connect(function(input,processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if input.KeyCode==Enum.KeyCode.RightControl then toggleSettings() end
end)
function OrionLib:MakeWindow(options)
    local window={}
    function window:MakeTab(spec)
        local names={['Automated Settings']='Passing',['AI Based Settings']='Targeting',['UI Elements']='Appearance'}
        local tabButton=uiNew("TextButton",{Text=names[spec.Name] or spec.Name,Font=Enum.Font.GothamMedium,TextSize=14,
            TextColor3=Color3.fromRGB(229,233,247),BackgroundColor3=Color3.fromRGB(35,40,56),BorderSizePixel=0,
            Size=UDim2.new(1/3,-4,1,0),LayoutOrder=#pages+1},tabStrip)
        uiRound(tabButton,9)
        local page=uiNew("ScrollingFrame",{Position=UDim2.fromOffset(12,112),Size=UDim2.new(1,-24,1,-126),
            BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,CanvasSize=UDim2.new(),
            AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,Visible=#pages==0},settingsPanel)
        uiNew("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},page)
        uiNew("UIPadding",{PaddingBottom=UDim.new(0,12),PaddingRight=UDim.new(0,6)},page)
        pages[#pages+1]={page=page,button=tabButton}
        local function selectPage()
            for _,entry in ipairs(pages) do
                entry.page.Visible=entry.page==page
                entry.button.BackgroundColor3=entry.page==page and OrionLib.Themes.Default.Main or Color3.fromRGB(35,40,56)
            end
        end
        tabButton.Activated:Connect(selectPage)
        if #pages==1 then selectPage() end
        local tab={order=0}
        local function row(label)
            tab.order=tab.order+1
            local frame=uiNew("Frame",{Size=UDim2.new(1,0,0,60),BackgroundColor3=Color3.fromRGB(29,34,48),
                BorderSizePixel=0,LayoutOrder=tab.order},page)
            uiRound(frame,10)
            uiNew("TextLabel",{Text=label,Font=Enum.Font.GothamMedium,TextSize=15,TextWrapped=true,
                TextColor3=Color3.fromRGB(231,235,250),TextXAlignment=Enum.TextXAlignment.Left,
                Position=UDim2.fromOffset(12,4),Size=UDim2.new(1,-130,1,-8),BackgroundTransparency=1},frame)
            return frame
        end
        function tab:AddLabel(label)
            tab.order=tab.order+1
            return uiNew("TextLabel",{Text=label:gsub('==',''),Font=Enum.Font.Gotham,TextSize=13,TextWrapped=true,
                TextXAlignment=Enum.TextXAlignment.Left,TextColor3=Color3.fromRGB(165,178,206),BackgroundTransparency=1,
                Size=UDim2.new(1,-8,0,42),LayoutOrder=tab.order},page)
        end
        function tab:AddToggle(specification)
            local frame=row(specification.Name)
            local button=uiNew("TextButton",{Size=UDim2.fromOffset(98,44),Position=UDim2.new(1,-106,.5,-22),
                TextSize=15,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BorderSizePixel=0},frame)
            uiRound(button,9)
            local control={Value=specification.Default==true}
            function control:Set(value)
                self.Value=value==true
                button.Text=self.Value and "ON" or "OFF"
                button.BackgroundColor3=self.Value and OrionLib.Themes.Default.Main or Color3.fromRGB(61,67,85)
            end
            button.Activated:Connect(function()
                control:Set(not control.Value)
                if specification.Callback then specification.Callback(control.Value) end
            end)
            control:Set(control.Value)
            return control
        end
        function tab:AddTextbox(specification)
            local frame=row(specification.Name)
            local box=uiNew("TextBox",{Size=UDim2.fromOffset(98,44),Position=UDim2.new(1,-106,.5,-22),
                Text=tostring(specification.Default or ""),ClearTextOnFocus=false,Font=Enum.Font.GothamMedium,TextSize=16,
                TextColor3=Color3.fromRGB(230,237,255),BackgroundColor3=Color3.fromRGB(43,49,68),BorderSizePixel=0},frame)
            uiRound(box,9)
            box.FocusLost:Connect(function() if specification.Callback then specification.Callback(box.Text) end end)
            return box
        end
        function tab:AddColorpicker(specification)
            return self:AddTextbox({Name=specification.Name.." (HEX)",Default=OrionLib.Themes.Default.Main:ToHex(),Callback=function(value)
                local hex=value:gsub('#','')
                if #hex~=6 or not hex:match('^%x+$') then return end
                local color=Color3.fromHex(hex)
                if specification.Callback then specification.Callback(color) end
                for _,entry in ipairs(pages) do if entry.page.Visible then entry.button.BackgroundColor3=color end end
            end})
        end
        return tab
    end
    return window
end
function OrionLib:Init() end
local Window = OrionLib:MakeWindow({
    Name = "Bomb Pass — PC + iPad",
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
    Name = "Adaptive body flick on pass",
    Default = false,
    Flag = "NaturalBodyFlickV4",
    Callback = setPassFlickEnabled,
})
local timedThresholdSettings = AutomatedTab:AddTextbox({
    Name = "Late request: seconds remaining (0.2 to 2)",
    Default = tostring(passConfig.LateWindow),
    TextDisappear = false,
    Callback = function(value)
        local number = tonumber(value)
        if number and number == number and number > -math.huge and number < math.huge then
            passConfig.LateWindow = math.clamp(number, 0.2, 2)
            refreshMobileButtons()
        end
    end,
})
AutomatedTab:AddTextbox({
    Name = "Optional follow-through (0 to 60 degrees)",
    Default = tostring(passConfig.FlickAngle),
    TextDisappear = false,
    Callback = function(value)
        local number = tonumber(value)
        if finiteNumber(number) then passConfig.FlickAngle = math.clamp(number, 0, 60) end
    end,
})
AutomatedTab:AddTextbox({
    Name = "Flick base duration (0.10 to 0.30 seconds)",
    Default = tostring(passConfig.FlickDuration),
    TextDisappear = false,
    Callback = function(value)
        local number = tonumber(value)
        if finiteNumber(number) then passConfig.FlickDuration = math.clamp(number, 0.10, 0.30) end
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
orionLayoutToggle = UITab:AddToggle({
    Name = "Edit button positions",
    Default = false,
    Callback = setLayoutEditing,
})
UITab:AddLabel("Unlock layout, position the controls, then lock it to save.", 13)
for _, item in ipairs({{key = "auto", name = "Auto Pass button size (44–160 px)"},
    {key = "shift", name = "Shift Lock button size (44–160 px)"}}) do
    local sizeBox
    sizeBox = UITab:AddTextbox({
        Name = item.name,
        Default = tostring(buttonSizes[item.key]),
        Callback = function(value)
            setButtonSize(item.key, value)
            sizeBox.Text = tostring(buttonSizes[item.key])
        end,
    })
end
UITab:AddLabel("Size changes apply immediately and save with your layout. Position locking stays unchanged.")

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
    settingsGui.Enabled=visible
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
    panel.Size = UDim2.fromOffset(280, 378)
    panel.Position = UDim2.new(1, -304, 0.20, 0)
    panel.BackgroundColor3 = Color3.fromRGB(20, 23, 34)
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel = 0
    panel.Parent = safeArea
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = panel

    local handle = Instance.new("TextLabel")
    handle.Name = "DragHandle"
    handle.Size = UDim2.new(1, 0, 0, 44)
    handle.TextSize = 17
    handle.Font = Enum.Font.GothamBold
    handle.TextColor3 = Color3.fromRGB(204, 214, 230)
    handle.BackgroundTransparency = 1
    handle.Parent = panel

    local function button(name, top, height)
        local item = Instance.new("TextButton")
        item.Name = name
        item.Size = UDim2.new(1, -16, 0, height or 52)
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
    uiNew("UIStroke", {Color=Color3.fromRGB(73,80,111),Transparency=.25}, panel)
    local autoButton = button("AutoPassMobileToggle", 116)
    local modeButton = button("PassModeMobileToggle", 116)
    local flickButton = button("PassFlickMobileToggle", 176)
    local layoutButton = button("LayoutLockToggle", 176)
    autoButton.Size=UDim2.new(.5,-12,0,52)
    flickButton.Size=autoButton.Size
    modeButton.Size=autoButton.Size; modeButton.Position=UDim2.new(.5,4,0,116)
    layoutButton.Size=autoButton.Size; layoutButton.Position=UDim2.new(.5,4,0,176)
    modeButton.TextSize=14; modeButton.TextWrapped=true
    layoutButton.TextSize=14
    local settingsButton=button("Settings",236,44)
    settingsButton.Text="Settings  ·  PC / iPad"
    settingsButton.BackgroundColor3=Color3.fromRGB(47,54,76)
    settingsButton.Activated:Connect(toggleSettings)
    local triggerLabel=uiNew("TextLabel",{Text="Pass at ≤ seconds",TextSize=14,Font=Enum.Font.Gotham,
        TextColor3=Color3.fromRGB(200,211,236),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(12,288),Size=UDim2.new(1,-112,0,40)},panel)
    local trigger=uiNew("TextBox",{Text=string.format("%.2f",passConfig.LateWindow),TextSize=18,
        ClearTextOnFocus=false,Font=Enum.Font.GothamBold,TextColor3=Color3.fromRGB(231,235,255),
        BackgroundColor3=Color3.fromRGB(47,54,76),BorderSizePixel=0,
        Position=UDim2.new(1,-94,0,286),Size=UDim2.fromOffset(82,44)},panel)
    uiRound(trigger,9)
    trigger.FocusLost:Connect(function()
        local number=tonumber(trigger.Text)
        if finiteNumber(number) then passConfig.LateWindow=math.clamp(number,.2,2) end
        trigger.Text=string.format("%.2f",passConfig.LateWindow)
        timedThresholdSettings.Text=trigger.Text
        refreshMobileButtons()
    end)
    local function fitPanel()
        local size=safeArea.AbsoluteSize
        if size.X<=0 or size.Y<=0 then return end
        panel.Size=UDim2.fromOffset(math.min(280,size.X-16),378)
        local position=panel.AbsolutePosition-safeArea.AbsolutePosition
        panel.AnchorPoint=Vector2.zero
        panel.Position=UDim2.fromOffset(math.clamp(position.X,8,math.max(8,size.X-panel.AbsoluteSize.X-8)),
            math.clamp(position.Y,8,math.max(8,size.Y-panel.AbsoluteSize.Y-8)))
    end
    safeArea:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanel)
    task.defer(fitPanel)

    local timer = Instance.new("TextLabel")
    timer.Name = "ActualBombTimer"
    timer.Size = UDim2.new(1, -24, 0, 60)
    timer.Position = UDim2.fromOffset(12, 46)
    timer.BackgroundTransparency = 1
    timer.TextWrapped = true
    timer.TextSize = 20
    timer.Font = Enum.Font.GothamBold
    timer.TextColor3 = Color3.fromRGB(215, 233, 250)
    timer.Text = "YOUR BOMB: --"
    timer.Parent = panel
    mobileTimer = timer

    local status = Instance.new("TextLabel")
    status.Name = "PassStatus"
    status.Size = UDim2.new(1, -16, 0, 40)
    status.Position = UDim2.fromOffset(8, 334)
    status.BackgroundTransparency = 1
    status.TextWrapped = true
    status.TextSize = 14
    status.Font = Enum.Font.Gotham
    status.TextColor3 = Color3.fromRGB(190, 202, 220)
    status.Text = passCore.LastStatus ~= "" and passCore.LastStatus or "Auto pass off"
    status.Parent = panel
    mobileStatus = status

    refreshMobileButtons = function()
        if not gui.Parent then return end
        autoButton.Text = AutoPassEnabled and "AUTO ON" or "AUTO OFF"
        autoButton.BackgroundColor3 = AutoPassEnabled
            and Color3.fromRGB(25, 128, 77) or Color3.fromRGB(115, 52, 64)
        modeButton.Text = passConfig.Mode == "Late" and "TIMED / 6 STUDS" or "NORMAL"
        triggerLabel.Text=passConfig.Mode == "Late" and "Pass at ≤ seconds" or "Timed threshold (s)"
        if not trigger:IsFocused() then trigger.Text=string.format("%.2f",passConfig.LateWindow) end
        modeButton.BackgroundColor3 = passConfig.Mode == "Late"
            and Color3.fromRGB(127, 73, 172) or Color3.fromRGB(51, 80, 122)
        flickButton.Text = passConfig.FlickEnabled and "FLICK: ON" or "FLICK: OFF"
        flickButton.BackgroundColor3 = passConfig.FlickEnabled
            and Color3.fromRGB(37, 103, 177) or Color3.fromRGB(63, 70, 84)
        layoutButton.Text = layoutEditing and "UNLOCKED" or "LOCKED"
        layoutButton.BackgroundColor3 = layoutEditing
            and Color3.fromRGB(20, 115, 130) or Color3.fromRGB(63, 70, 84)
        handle.Text = layoutEditing and "DRAG HEADER TO MOVE" or "BOMB PASS"
    end
    autoButton.Activated:Connect(function() setAutoPassEnabled(not AutoPassEnabled) end)
    modeButton.Activated:Connect(function() setLatePassEnabled(passConfig.Mode ~= "Late") end)
    flickButton.Activated:Connect(function() setPassFlickEnabled(not passConfig.FlickEnabled) end)
    layoutButton.Activated:Connect(function() setLayoutEditing(not layoutEditing) end)
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    makeDraggable(panel, handle, "panel")
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
ShiftLockButton.Size = UDim2.fromOffset(UserInputService.TouchEnabled and 72 or 52, UserInputService.TouchEnabled and 72 or 52)
ShiftLockButton.Size = UDim2.fromOffset(buttonSizes.shift, buttonSizes.shift)
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
AutoPassButton.Position = UDim2.new(1, -120, 0.72, UserInputService.TouchEnabled and -86 or -66)
AutoPassButton.Size = ShiftLockButton.Size
AutoPassButton.Size = UDim2.fromOffset(buttonSizes.auto, buttonSizes.auto)
AutoPassButton.TextSize = math.clamp(math.floor(buttonSizes.auto * 0.26), 12, 28)
AutoPassButton.SizeConstraint = Enum.SizeConstraint.RelativeXX
local apCorner = Instance.new("UICorner")
apCorner.CornerRadius = UDim.new(0.2, 0)
apCorner.Parent = AutoPassButton
local apStroke = Instance.new("UIStroke")
apStroke.Thickness = 2
apStroke.Color = Color3.fromRGB(0, 0, 0)
apStroke.Parent = AutoPassButton

local shiftLockDrag = makeDraggable(ShiftLockButton, nil, "shift")
local autoPassDrag = makeDraggable(AutoPassButton, nil, "auto")
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
print("Bomb Pass v5 ready: PC + iPad controls. Choose TIMED, enable AUTO, and enter the countdown threshold. Timed range: 6 studs.")
return {}
