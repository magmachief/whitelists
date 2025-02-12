-----------------------------------------------------
-- SERVICES
-----------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-----------------------------------------------------
-- CONFIGURATION & VARIABLES
-----------------------------------------------------
-- Auto Pass Bomb configuration
local bombPassDistance = 10             -- Maximum pass distance for bomb passing
local AutoPassEnabled = false           -- Toggle auto-pass bomb behavior

-- (Prediction time removed; we now use the target’s current position.)
-- Advanced line-of-sight settings remain:
local raySpreadAngle = 10               -- Spread angle (in degrees) for multiple raycasts
local numRaycasts = 3                   -- Number of rays to cast for line-of-sight (odd number recommended)

-- Global features and notifications
local AntiSlipperyEnabled = false       -- Toggle anti-slippery feature
local RemoveHitboxEnabled = false       -- Toggle hitbox removal
local AI_AssistanceEnabled = false      -- Toggle AI Assistance notifications
local pathfindingSpeed = 16             -- Used for auto-pass bomb target selection calculations
local lastAIMessageTime = 0
local aiMessageCooldown = 5             -- Seconds between AI notifications

-- New cooldown to prevent rapid pass attempts
local lastPassAttemptTime = 0
local passAttemptCooldown = 0.5         -- Seconds to wait between pass attempts

-----------------------------------------------------
-- UI THEMES (for OrionLib)
-----------------------------------------------------
local uiThemes = {
    Dark = {
        MainColor = Color3.fromRGB(30, 30, 30),
        AccentColor = Color3.fromRGB(255, 0, 0),
        TextColor = Color3.fromRGB(255, 255, 255)
    },
    Light = {
        MainColor = Color3.fromRGB(255, 255, 255),
        AccentColor = Color3.fromRGB(255, 0, 0),
        TextColor = Color3.fromRGB(0, 0, 0)
    },
    Red = {
        MainColor = Color3.fromRGB(150, 0, 0),
        AccentColor = Color3.fromRGB(255, 255, 255),
        TextColor = Color3.fromRGB(255, 255, 255)
    }
}

local function changeUITheme(theme)
    if OrionLib.ChangeTheme then
        OrionLib:ChangeTheme(theme)
    else
        OrionLib.Config = OrionLib.Config or {}
        OrionLib.Config.MainColor = theme.MainColor
        OrionLib.Config.AccentColor = theme.AccentColor
        OrionLib.Config.TextColor = theme.TextColor
    end
end

-----------------------------------------------------
-- VISUAL TARGET MARKER (for Auto Pass Bomb)
-----------------------------------------------------
local currentTargetMarker = nil
local currentTargetPlayer = nil

local function createOrUpdateTargetMarker(player)
    if not player or not player.Character then return end
    local body = player.Character:FindFirstChild("HumanoidRootPart")
    if not body then return end

    if currentTargetMarker and currentTargetPlayer == player then
        return
    end

    if currentTargetMarker then
        currentTargetMarker:Destroy()
        currentTargetMarker = nil
        currentTargetPlayer = nil
    end

    local marker = Instance.new("BillboardGui")
    marker.Name = "BombPassTargetMarker"
    marker.Adornee = body
    marker.Size = UDim2.new(0, 50, 0, 50)
    marker.StudsOffset = Vector3.new(0, 0, 0)
    marker.AlwaysOnTop = true
    marker.Parent = body

    local label = Instance.new("TextLabel", marker)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "X"
    label.TextScaled = true
    label.TextColor3 = Color3.new(1, 0, 0)
    label.Font = Enum.Font.SourceSansBold

    currentTargetMarker = marker
    currentTargetPlayer = player
end

local function removeTargetMarker()
    if currentTargetMarker then
        currentTargetMarker:Destroy()
        currentTargetMarker = nil
        currentTargetPlayer = nil
    end
end

-----------------------------------------------------
-- UTILITY FUNCTIONS FOR AUTO PASS BOMB
-----------------------------------------------------
local function getOptimalPlayer()
    local bestPlayer = nil
    local bestTravelTime = math.huge
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if player.Character:FindFirstChild("Bomb") then
                continue
            end
            local targetPos = player.Character.HumanoidRootPart.Position
            local distance = (targetPos - myPos).magnitude
            if distance <= bombPassDistance then
                local travelTime = distance / pathfindingSpeed
                if travelTime < bestTravelTime then
                    bestTravelTime = travelTime
                    bestPlayer = player
                end
            end
        end
    end
    return bestPlayer
end

local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = bombPassDistance
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if player.Character:FindFirstChild("Bomb") then
                continue
            end
            local targetPos = player.Character.HumanoidRootPart.Position
            local distance = (targetPos - myPos).magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestPlayer = player
            end
        end
    end
    return closestPlayer
end

-- The old behavior: rotate directly toward the target’s current position.
local function rotateCharacterTowardsTarget(targetPosition, _targetVelocity)
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local targetCFrame = CFrame.new(hrp.Position, targetPosition)
    local tween = TweenService:Create(hrp, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {CFrame = targetCFrame})
    tween:Play()
    return tween
end

-----------------------------------------------------
-- MULTIPLE RAYCASTS FOR LINE-OF-SIGHT CHECK
-----------------------------------------------------
local function isLineOfSightClearMultiple(startPos, endPos, targetPart)
    local spreadRad = math.rad(raySpreadAngle)
    local direction = (endPos - startPos).Unit
    local distance = (endPos - startPos).Magnitude

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    if LocalPlayer.Character then
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end

    -- Central ray
    local centralResult = Workspace:Raycast(startPos, direction * distance, rayParams)
    if centralResult and not centralResult.Instance:IsDescendantOf(targetPart.Parent) then
        return false
    end

    local raysEachSide = math.floor((numRaycasts - 1) / 2)
    for i = 1, raysEachSide do
        local angleOffset = spreadRad * i / raysEachSide
        local leftDirection = (CFrame.fromAxisAngle(Vector3.new(0,1,0), angleOffset) * CFrame.new(direction)).p
        local leftResult = Workspace:Raycast(startPos, leftDirection * distance, rayParams)
        if leftResult and not leftResult.Instance:IsDescendantOf(targetPart.Parent) then
            return false
        end
        local rightDirection = (CFrame.fromAxisAngle(Vector3.new(0,1,0), -angleOffset) * CFrame.new(direction)).p
        local rightResult = Workspace:Raycast(startPos, rightDirection * distance, rayParams)
        if rightResult and not rightResult.Instance:IsDescendantOf(targetPart.Parent) then
            return false
        end
    end
    return true
end

-----------------------------------------------------
-- ENHANCED AUTO PASS BOMB FUNCTION (WITH ENHANCEMENTS)
-----------------------------------------------------
local function autoPassBombEnhanced()
    -- Prevent repeated pass attempts that may freeze movement.
    if tick() - lastPassAttemptTime < passAttemptCooldown then
        return
    end

    pcall(function()
        local bomb = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Bomb")
        if not bomb then
            removeTargetMarker()
            lastPassAttemptTime = tick()
            return
        end

        local BombEvent = bomb:FindFirstChild("RemoteEvent")
        local targetPlayer = getOptimalPlayer() or getClosestPlayer()
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if targetPlayer.Character:FindFirstChild("Bomb") then
                removeTargetMarker()
                lastPassAttemptTime = tick()
                return
            end

            createOrUpdateTargetMarker(targetPlayer)
            local targetPos = targetPlayer.Character.HumanoidRootPart.Position
            local myPos = LocalPlayer.Character.HumanoidRootPart.Position
            local distance = (targetPos - myPos).magnitude

            if distance > bombPassDistance then
                print("Target out of range. Pass aborted.")
                removeTargetMarker()
                lastPassAttemptTime = tick()
                return
            end

            local targetCollision = targetPlayer.Character:FindFirstChild("CollisionPart") or targetPlayer.Character.HumanoidRootPart
            if not isLineOfSightClearMultiple(myPos, targetPos, targetCollision) then
                print("Line of sight blocked. Bomb pass aborted.")
                removeTargetMarker()
                lastPassAttemptTime = tick()
                return
            end

            local targetVelocity = targetPlayer.Character.HumanoidRootPart.Velocity or Vector3.new(0, 0, 0)
            rotateCharacterTowardsTarget(targetPos, targetVelocity)
            task.wait(0.05)  -- Short wait for smoother rotation without blocking movement
            if AI_AssistanceEnabled and tick() - lastAIMessageTime >= aiMessageCooldown then
                pcall(function()
                    StarterGui:SetCore("SendNotification", {
                        Title = "AI Assistance",
                        Text = "Passing bomb to " .. targetPlayer.Name .. " (Distance: " .. math.floor(distance) .. " studs).",
                        Duration = 5
                    })
                end)
                lastAIMessageTime = tick()
            end
            BombEvent:FireServer(targetPlayer.Character, targetPlayer.Character:FindFirstChild("CollisionPart"))
            print("Bomb passed to:", targetPlayer.Name, "Distance:", distance)
            removeTargetMarker()
            lastPassAttemptTime = tick()
        else
            removeTargetMarker()
            lastPassAttemptTime = tick()
        end
    end)
end

-----------------------------------------------------
-- ANTI-SLIPPERY
-----------------------------------------------------
local function applyAntiSlippery(enabled)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    if enabled then
        task.spawn(function()
            while AntiSlipperyEnabled do
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
                    end
                end
                task.wait(0.1)
            end
        end)
    else
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.5)
            end
        end
    end
end

-----------------------------------------------------
-- REMOVE HITBOX
-----------------------------------------------------
local function applyRemoveHitbox(enable)
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == "Hitbox" then
            if enable then
                part.Transparency = 1
                part.CanCollide = false
            else
                part.Transparency = 0
                part.CanCollide = true
            end
        end
    end
end

-----------------------------------------------------
-- APPLY FEATURES ON RESPAWN
-----------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function(char)
    applyAntiSlippery(AntiSlipperyEnabled)
    applyRemoveHitbox(RemoveHitboxEnabled)
end)

-----------------------------------------------------
-- ORIONLIB INTERFACE
-----------------------------------------------------
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()
local Window = OrionLib:MakeWindow({
    Name = "Yon Menu - Advanced (Auto Pass Bomb Enhanced)",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "YonMenu_Advanced"
})

-- Create two tabs: one for automated features and one for AI-based settings.
local AutomatedTab = Window:MakeTab({
    Name = "Automated",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})
local AITab = Window:MakeTab({
    Name = "AI Based",
    Icon = "rbxassetid://7072720870",  -- Change to your preferred asset id
    PremiumOnly = false
})

local autoPassConnection

-- Automated features go in the Automated tab.
AutomatedTab:AddToggle({
    Name = "Auto Pass Bomb (Enhanced)",
    Default = AutoPassEnabled,
    Callback = function(value)
        AutoPassEnabled = value
        if AutoPassEnabled then
            autoPassConnection = RunService.Stepped:Connect(autoPassBombEnhanced)
        else
            if autoPassConnection then
                autoPassConnection:Disconnect()
                autoPassConnection = nil
            end
            removeTargetMarker()
        end
    end
})

AutomatedTab:AddToggle({
    Name = "Anti Slippery",
    Default = AntiSlipperyEnabled,
    Callback = function(value)
        AntiSlipperyEnabled = value
        applyAntiSlippery(value)
    end
})

AutomatedTab:AddToggle({
    Name = "Remove Hitbox",
    Default = RemoveHitboxEnabled,
    Callback = function(value)
        RemoveHitboxEnabled = value
        applyRemoveHitbox(value)
    end
})

-- AI-based settings go in the AI Based tab.
AITab:AddToggle({
    Name = "AI Assistance",
    Default = false,
    Callback = function(value)
        AI_AssistanceEnabled = value
        if AI_AssistanceEnabled then
            print("AI Assistance enabled.")
        else
            print("AI Assistance disabled.")
        end
    end
})

AITab:AddSlider({
    Name = "Bomb Pass Distance",
    Min = 5,
    Max = 30,
    Default = bombPassDistance,
    Increment = 1,
    Callback = function(value)
        bombPassDistance = value
    end
})

AITab:AddSlider({
    Name = "Ray Spread Angle",
    Min = 5,
    Max = 20,
    Default = raySpreadAngle,
    Increment = 1,
    Callback = function(value)
        raySpreadAngle = value
    end
})

AITab:AddSlider({
    Name = "Number of Raycasts",
    Min = 1,
    Max = 5,
    Default = numRaycasts,
    Increment = 1,
    Callback = function(value)
        numRaycasts = value
    end
})

OrionLib:Init()
print("Yon Menu Script Loaded with Enhanced AI Smart Auto Pass Bomb, Anti Slippery, Remove Hitbox, UI Theme Support, and AI Assistance")
