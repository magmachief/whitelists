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

-- Advanced line-of-sight settings
local raySpreadAngle = 10               -- Spread angle (in degrees) for multiple raycasts
local numRaycasts = 3                   -- Number of rays to cast for line-of-sight (odd number recommended)

-- Global features and notifications
local AntiSlipperyEnabled = false       -- Toggle anti-slippery feature
local RemoveHitboxEnabled = false       -- Toggle hitbox removal
local AI_AssistanceEnabled = false      -- Toggle AI Assistance notifications
local pathfindingSpeed = 16             -- Used for auto-pass bomb target selection calculations
local lastAIMessageTime = 0
local aiMessageCooldown = 5             -- Seconds between AI notifications

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

local function createOrUpdateTargetMarker(player, distance)
    if not player or not player.Character then return end
    local body = player.Character:FindFirstChild("HumanoidRootPart")
    if not body then return end

    if currentTargetMarker and currentTargetPlayer == player then
        -- Update marker text with current distance
        currentTargetMarker:FindFirstChildOfClass("TextLabel").Text = player.Name .. "\n" .. math.floor(distance) .. " studs"
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
    marker.Size = UDim2.new(0, 80, 0, 80)
    marker.StudsOffset = Vector3.new(0, 2, 0)
    marker.AlwaysOnTop = true
    marker.Parent = body

    local label = Instance.new("TextLabel", marker)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = player.Name .. "\n" .. math.floor(distance) .. " studs"
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

-- Old behavior: rotate directly toward the target’s current position,
-- but adjusted so that the character's Y remains the same (avoiding looking down).
local function rotateCharacterTowardsTarget(targetPosition)
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local adjustedTargetPos = Vector3.new(targetPosition.X, hrp.Position.Y, targetPosition.Z)
    local targetCFrame = CFrame.new(hrp.Position, adjustedTargetPos)
    local tween = TweenService:Create(hrp, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = targetCFrame})
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
    pcall(function()
        local bomb = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Bomb")
        if not bomb then
            removeTargetMarker()
            return
        end

        local BombEvent = bomb:FindFirstChild("RemoteEvent")
        local targetPlayer = getOptimalPlayer() or getClosestPlayer()
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if targetPlayer.Character:FindFirstChild("Bomb") then
                removeTargetMarker()
                return
            end

            local targetPos = targetPlayer.Character.HumanoidRootPart.Position
            local myPos = LocalPlayer.Character.HumanoidRootPart.Position
            local distance = (targetPos - myPos).magnitude

            if distance > bombPassDistance then
                print("Target out of range. Pass aborted.")
                removeTargetMarker()
                return
            end

            local targetCollision = targetPlayer.Character:FindFirstChild("CollisionPart") or targetPlayer.Character.HumanoidRootPart
            if not isLineOfSightClearMultiple(myPos, targetPos, targetCollision) then
                print("Line of sight blocked. Bomb pass aborted.")
                removeTargetMarker()
                return
            end

            createOrUpdateTargetMarker(targetPlayer, distance)
            -- VFX effect: confined around the target.
            local function playPassVFX(target)
                if not target or not target.Character then return end
                local hrp = target.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local emitter = Instance.new("ParticleEmitter")
                emitter.Texture = "rbxassetid://258128463"  -- Replace with your preferred VFX texture
                emitter.Rate = 50                -- Lower rate for confined effect
                emitter.Lifetime = NumberRange.new(0.3, 0.5)  -- Shorter lifetime
                emitter.Speed = NumberRange.new(2, 5)         -- Lower speed
                emitter.VelocitySpread = 30      -- Narrow spread
                emitter.Parent = hrp
                delay(1, function()
                    emitter:Destroy()
                end)
            end

            playPassVFX(targetPlayer)
            rotateCharacterTowardsTarget(targetPos)
            task.wait(0.05)  -- Short wait for smoother rotation
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
        else
            removeTargetMarker()
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
-- Create a tab for UI elements
local Tab = Window:MakeTab({
    Name = "UI Elements",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})
-- Add a Colorpicker to the tab
Tab:AddColorpicker({
    Name = "Menu Main Color",                      -- Label for the color picker
    Default = Color3.fromRGB(255, 0, 0),          -- Starting color (red)
    Callback = function(color)
        OrionLib.Themes[OrionLib.SelectedTheme].Main = color
        SetTheme()  
    end,
    Flag = "MenuMainColor",                        -- Optional flag for saving config
    Save = true                                   -- Optional: save this setting
})

-- Store the OrionLib toggle reference for Auto Pass Bomb.
local orionAutoPassToggle = AutomatedTab:AddToggle({
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

local autoPassConnection

-- (Other toggles)
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

-----------------------------------------------------
-- MOBILE TOGGLE BUTTON FOR AUTO PASS BOMB
-----------------------------------------------------
local mobileGui = Instance.new("ScreenGui")
mobileGui.Name = "MobileToggleGui"
if gethui then
    mobileGui.Parent = gethui()
else
    mobileGui.Parent = game:GetService("CoreGui")
end

local autoPassMobileToggle = Instance.new("TextButton")
autoPassMobileToggle.Name = "AutoPassMobileToggle"
autoPassMobileToggle.Size = UDim2.new(0, 50, 0, 50)
-- Position near the bottom-right; adjust as needed
autoPassMobileToggle.Position = UDim2.new(1, -70, 1, -110)
autoPassMobileToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)  -- Red for OFF
autoPassMobileToggle.Text = "OFF"
autoPassMobileToggle.TextScaled = true
autoPassMobileToggle.Font = Enum.Font.SourceSansBold
autoPassMobileToggle.Parent = mobileGui

local uicorner = Instance.new("UICorner")
uicorner.CornerRadius = UDim.new(1, 0)
uicorner.Parent = autoPassMobileToggle

autoPassMobileToggle.MouseButton1Click:Connect(function()
    AutoPassEnabled = not AutoPassEnabled
    if AutoPassEnabled then
        autoPassMobileToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 0)  -- Green for ON
        autoPassMobileToggle.Text = "ON"
    else
        autoPassMobileToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)  -- Red for OFF
        autoPassMobileToggle.Text = "OFF"
    end
    -- Update the OrionLib toggle to match.
    if orionAutoPassToggle and orionAutoPassToggle.Set then
        orionAutoPassToggle:Set(AutoPassEnabled)
    elseif orionAutoPassToggle then
        orionAutoPassToggle.Value = AutoPassEnabled
    end
end)
