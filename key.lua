-----------------------------------------------------
-- SERVICES
-----------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-----------------------------------------------------
-- CONFIGURATION & VARIABLES
-----------------------------------------------------
local bombPassDistance = 10         -- Maximum pass distance (in studs)
local AutoPassEnabled = false       -- Toggle auto-pass behavior
local AntiSlipperyEnabled = false   -- Toggle anti-slippery feature
local RemoveHitboxEnabled = false   -- Toggle hitbox removal
local pathfindingSpeed = 16         -- Used to calculate travel time

-- Auto Pass Cooldown Variables
local autoPassCooldown = 1.0        -- Cooldown time (in seconds) between passes (adjustable via the UI)
local lastAutoPassTime = 0          -- Records the last time a bomb was passed

-----------------------------------------------------
-- UI THEMES
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
        print("Theme changed to:", theme)
    end
end

-----------------------------------------------------
-- VISUAL TARGET MARKER (RED "X") FOR AUTO-PASS
-----------------------------------------------------
-- We use a BillboardGui marker attached to the target's HumanoidRootPart.
local currentTargetMarker = nil
local currentTargetPlayer = nil

local function createOrUpdateTargetMarker(player)
    if not player or not player.Character then return end
    local body = player.Character:FindFirstChild("HumanoidRootPart")
    if not body then return end

    -- If the marker already exists on this player, do nothing.
    if currentTargetMarker and currentTargetPlayer == player then
        return
    end

    -- Remove any previous marker if the target has changed.
    if currentTargetMarker then
        currentTargetMarker:Destroy()
        currentTargetMarker = nil
        currentTargetPlayer = nil
    end

    local marker = Instance.new("BillboardGui")
    marker.Name = "BombPassTargetMarker"
    marker.Adornee = body  -- Attach to the target's body
    marker.Size = UDim2.new(0, 50, 0, 50)
    marker.StudsOffset = Vector3.new(0, 0, 0)  -- Centered on the part
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
-- UTILITY FUNCTIONS
-----------------------------------------------------
-- Optimal auto-pass: Returns the player with the lowest travel time (distance/pathfindingSpeed)
-- provided they are within bombPassDistance.
local function getOptimalPlayer()
    local bestPlayer = nil
    local bestTravelTime = math.huge
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
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

-- Fallback: Returns the closest player within bombPassDistance.
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = bombPassDistance
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
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

-- Rotates LocalPlayer's character toward a target position.
-- Uses target velocity (if available) for prediction.
local function rotateCharacterTowardsTarget(targetPosition, targetVelocity)
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local predictionTime = 0.5
    local predictedPos = targetPosition
    if targetVelocity and targetVelocity.Magnitude > 0 then
        predictedPos = targetPosition + targetVelocity * predictionTime
    end

    local targetCFrame = CFrame.new(hrp.Position, predictedPos)
    local tween = TweenService:Create(hrp, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {CFrame = targetCFrame})
    tween:Play()
    return tween, tween.Completed
end

-----------------------------------------------------
-- (OPTIONAL) ADDITIONAL FEEDBACK FUNCTIONS
-----------------------------------------------------
-- Play a pass sound effect.
local function playPassSound()
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://6026984227"  -- Example asset ID; replace if desired.
    sound.Volume = 1
    sound.Parent = LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character
    sound:Play()
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

-- Flash the screen (a brief white overlay).
local function flashScreen()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local flashGui = Instance.new("ScreenGui", playerGui)
    flashGui.Name = "PassFlash"
    local frame = Instance.new("Frame", flashGui)
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    frame.BackgroundTransparency = 0
    frame.BorderSizePixel = 0
    local tween = TweenService:Create(frame, TweenInfo.new(0.5), {BackgroundTransparency = 1})
    tween:Play()
    tween.Completed:Connect(function()
        flashGui:Destroy()
    end)
end

-----------------------------------------------------
-- (OPTIONAL) MANUAL ANTI-SLIPPERY
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
-- (OPTIONAL) MANUAL REMOVE HITBOX
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
-- AUTO PASS BOMB LOGIC (OPTIMAL PASS ONLY) WITH COOLDOWN, FEEDBACK, AND FALLBACK
-----------------------------------------------------
local function autoPassBomb()
    if not AutoPassEnabled then
        removeTargetMarker()
        return
    end

    local currentTime = tick()
    if currentTime - lastAutoPassTime < autoPassCooldown then
        return
    end

    pcall(function()
        local bomb = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Bomb")
        if bomb then
            local BombEvent = bomb:FindFirstChild("RemoteEvent")
            -- Use optimal auto-pass; if none found, fallback to closest player.
            local targetPlayer = getOptimalPlayer() or getClosestPlayer()
            if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                createOrUpdateTargetMarker(targetPlayer)
                local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
                local myPos = LocalPlayer.Character.HumanoidRootPart.Position
                local distance = (targetPosition - myPos).magnitude
                if distance <= bombPassDistance then
                    local targetVelocity = targetPlayer.Character.HumanoidRootPart.Velocity or Vector3.new(0, 0, 0)
                    local tween, onComplete = rotateCharacterTowardsTarget(targetPosition, targetVelocity)
                    onComplete:Connect(function(status)
                        if status == Enum.PlaybackState.Completed then
                            BombEvent:FireServer(targetPlayer.Character, targetPlayer.Character:FindFirstChild("CollisionPart"))
                            playPassSound()
                            flashScreen()
                            lastAutoPassTime = tick()
                            removeTargetMarker()
                        end
                    end)
                else
                    removeTargetMarker()
                end
            else
                removeTargetMarker()
            end
        else
            removeTargetMarker()
        end
    end)
end

-----------------------------------------------------
-- MANUAL OVERRIDE BUTTON (FOR MOBILE)
-----------------------------------------------------
-- Create an on-screen button (positioned near the jump button) for manual override.
local function createOverrideButton()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local overrideGui = Instance.new("ScreenGui")
    overrideGui.Name = "OverridePassGui"
    overrideGui.ResetOnSpawn = false
    overrideGui.Parent = playerGui

    local overrideButton = Instance.new("TextButton")
    overrideButton.Name = "OverridePassButton"
    overrideButton.Size = UDim2.new(0, 80, 0, 80)
    overrideButton.AnchorPoint = Vector2.new(1, 1)
    overrideButton.Position = UDim2.new(1, -20, 1, -20)
    overrideButton.BackgroundTransparency = 0.5
    overrideButton.BackgroundColor3 = Color3.new(0, 0, 0)
    overrideButton.Text = "Pass"
    overrideButton.TextScaled = true
    overrideButton.Parent = overrideGui

    overrideButton.Activated:Connect(function()
        autoPassBomb()
    end)
end

createOverrideButton()

-----------------------------------------------------
-- APPLY FEATURES ON RESPAWN
-----------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function(char)
    applyAntiSlippery(AntiSlipperyEnabled)
    applyRemoveHitbox(RemoveHitboxEnabled)
end)

-----------------------------------------------------
-- ORIONLIB UI INTERFACE (OPTIONAL)
-----------------------------------------------------
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()
local Window = OrionLib:MakeWindow({
    Name = "Yon Menu - Advanced",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "YonMenu_Advanced"
})
local AutomatedTab = Window:MakeTab({
    Name = "Automated",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

AutomatedTab:AddToggle({
    Name = "Auto Pass Bomb",
    Default = AutoPassEnabled,
    Callback = function(value)
        AutoPassEnabled = value
        if AutoPassEnabled then
            autoPassConnection = RunService.Stepped:Connect(autoPassBomb)
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

AutomatedTab:AddSlider({
    Name = "Bomb Pass Distance",
    Min = 5,
    Max = 30,
    Default = bombPassDistance,
    Increment = 1,
    Callback = function(value)
        bombPassDistance = value
    end
})

AutomatedTab:AddSlider({
    Name = "Auto Pass Cooldown",
    Min = 0.5,
    Max = 5,
    Default = autoPassCooldown,
    Increment = 0.1,
    Callback = function(value)
        autoPassCooldown = value
    end
})

AutomatedTab:AddDropdown({
    Name = "Pathfinding Speed",
    Default = "16",
    Options = {"12", "16", "20"},
    Callback = function(value)
        pathfindingSpeed = tonumber(value)
    end
})

AutomatedTab:AddDropdown({
    Name = "Marker Style",
    Default = "X",
    Options = {"X", "Arrow"},
    Callback = function(value)
        markerStyle = value
    end
})

AutomatedTab:AddDropdown({
    Name = "UI Theme",
    Default = "Dark",
    Options = {"Dark", "Light", "Red"},
    Callback = function(themeName)
        local theme = uiThemes[themeName]
        if theme then
            changeUITheme(theme)
        else
            warn("Theme not found:", themeName)
        end
    end
})

OrionLib:Init()
print("Yon Menu Script Loaded with Optimal Auto Pass Bomb, Anti Slippery, Remove Hitbox, Override Button, and UI Theme Support")
