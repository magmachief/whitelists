-----------------------------------------------------
-- SERVICES
-----------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-----------------------------------------------------
-- CONFIGURATION & VARIABLES
-----------------------------------------------------
local bombPassDistance = 10
local AutoPassEnabled = false
local AntiSlipperyEnabled = false
local RemoveHitboxEnabled = false
local autoPassConnection = nil
local pathfindingSpeed = 16
local bombTimerDuration = 20      -- Default bomb timer (seconds)
local lowTimerThreshold = 2       -- When time left is less than this, warn the player

-- UI Themes (for OrionLib)
local uiThemes = {
    Dark = { Background = Color3.new(0, 0, 0), Text = Color3.new(1, 1, 1) },
    Light = { Background = Color3.new(1, 1, 1), Text = Color3.new(0, 0, 0) },
    Red = { Background = Color3.new(1, 0, 0), Text = Color3.new(1, 1, 1) },
}

-- Bomb tracking variables
local bombObject = nil      -- Reference to the bomb object in your character
local bombStartTime = nil   -- When you received the bomb
local bombTimerUI = nil     -- Reference to the bomb timer UI

-----------------------------------------------------
-- UTILITY FUNCTIONS
-----------------------------------------------------

-- Returns the closest player to LocalPlayer
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local distance = (player.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestPlayer = player
            end
        end
    end
    return closestPlayer
end

-- Rotates LocalPlayer's character toward a target position.
-- If targetVelocity is provided, it predicts the target's future position.
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
    local currentLook = hrp.CFrame.LookVector
    local desiredLook = targetCFrame.LookVector
    local dot = math.clamp(currentLook:Dot(desiredLook), -1, 1)
    local angleDiff = math.acos(dot)
    local duration = math.clamp(angleDiff / math.pi, 0.2, 0.5)

    local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {CFrame = targetCFrame})
    tween:Play()
    return tween
end

-- Creates a Bomb Timer UI attached to the character's Head or HumanoidRootPart.
local function createBombTimerUI(character, duration)
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return end
    if bombTimerUI then bombTimerUI:Destroy() end

    bombTimerUI = Instance.new("BillboardGui")
    bombTimerUI.Name = "BombTimerUI"
    bombTimerUI.Adornee = head
    bombTimerUI.Size = UDim2.new(0, 100, 0, 50)
    bombTimerUI.StudsOffset = Vector3.new(0, 3, 0)
    bombTimerUI.AlwaysOnTop = true
    bombTimerUI.Parent = head

    local label = Instance.new("TextLabel", bombTimerUI)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.TextColor3 = Color3.new(1, 0, 0)
    label.Font = Enum.Font.SourceSansBold
    label.Text = tostring(duration)

    bombStartTime = tick()
    local timeLeft = duration

    while timeLeft > 0 do
        if not bombObject or bombObject.Parent ~= LocalPlayer.Character then
            bombTimerUI:Destroy()
            bombTimerUI = nil
            return
        end
        timeLeft = math.max(0, duration - (tick() - bombStartTime))
        label.Text = tostring(math.ceil(timeLeft))
        if timeLeft <= lowTimerThreshold then
            print("[BOMB TIMER] Time is almost up: " .. timeLeft .. " seconds!")
            -- Optionally, you can auto-trigger bomb pass here
            -- autoPassBomb()
        end
        task.wait(1)
    end

    bombTimerUI:Destroy()
    bombTimerUI = nil
    print("[BOMB TIMER] Timer expired!")
end

-----------------------------------------------------
-- BOMB DETECTION & TIMER MANAGEMENT
-----------------------------------------------------

local function detectBomb()
    while true do
        local character = LocalPlayer.Character
        if character then
            local bomb = character:FindFirstChild("Bomb")  -- Adjust if your bomb has a different name
            if bomb and bomb ~= bombObject then
                bombObject = bomb
                bombStartTime = tick()
                print("[TRACKER] Bomb received!")
                createBombTimerUI(character, bombTimerDuration)
                bomb:GetPropertyChangedSignal("Parent"):Connect(function()
                    if bomb.Parent ~= character then
                        print("[TRACKER] Bomb passed!")
                        bombObject = nil
                        if bombTimerUI then
                            bombTimerUI:Destroy()
                            bombTimerUI = nil
                        end
                    end
                end)
            end
        end
        task.wait(0.1)
    end
end

-----------------------------------------------------
-- AUTO PASS BOMB LOGIC
-----------------------------------------------------
local function autoPassBomb()
    if not AutoPassEnabled then return end
    pcall(function()
        local Bomb = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Bomb")
        if Bomb then
            local BombEvent = Bomb:FindFirstChild("RemoteEvent")
            local closestPlayer = getClosestPlayer()
            if closestPlayer and closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local targetPosition = closestPlayer.Character.HumanoidRootPart.Position
                local distance = (targetPosition - LocalPlayer.Character.HumanoidRootPart.Position).magnitude
                if distance <= bombPassDistance then
                    local targetVelocity = closestPlayer.Character.HumanoidRootPart.Velocity or Vector3.new(0,0,0)
                    rotateCharacterTowardsTarget(targetPosition, targetVelocity)
                    task.wait(0.6)
                    BombEvent:FireServer(closestPlayer.Character, closestPlayer.Character:FindFirstChild("CollisionPart"))
                end
            end
        end
    end)
end

-----------------------------------------------------
-- MANUAL ANTI-SLIPPERY (if desired)
-----------------------------------------------------
local function applyAntiSlippery(enabled)
    if enabled then
        task.spawn(function()
            while AntiSlipperyEnabled do
                local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
                    end
                end
                task.wait(0.1)
            end
        end)
    else
        local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.5)
            end
        end
    end
end

-----------------------------------------------------
-- MANUAL REMOVE HITBOX (if desired)
-----------------------------------------------------
local function applyRemoveHitbox(enable)
    local character = LocalPlayer.Character
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
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
LocalPlayer.CharacterAdded:Connect(function()
    if AntiSlipperyEnabled then applyAntiSlippery(true) end
    if RemoveHitboxEnabled then applyRemoveHitbox(true) end
end)

-----------------------------------------------------
-- ORIONLIB UI INTERFACE
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
        end
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

AutomatedTab:AddDropdown({
    Name = "Pathfinding Speed",
    Default = "16",
    Options = {"12", "16", "20"},
    Callback = function(value)
        pathfindingSpeed = tonumber(value)
    end
})

AutomatedTab:AddDropdown({
    Name = "UI Theme",
    Default = "Dark",
    Options = {"Dark", "Light", "Red"},
    Callback = function(themeName)
        local theme = uiThemes[themeName]
        if theme then
            -- (Optional) Apply the theme dynamically to OrionLib UI elements.
        else
            warn("Theme not found:", themeName)
        end
    end
})

OrionLib:Init()
print("Yon Menu Script Loaded with Enhanced AI-based Bomb Timer, Anti-Slippery, and Advanced Features")

-----------------------------------------------------
-- START BOMB DETECTION
-----------------------------------------------------
task.spawn(detectBomb)
