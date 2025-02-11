-----------------------------------------------------
-- SERVICES
-----------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-----------------------------------------------------
-- CONFIGURATION & VARIABLES
-----------------------------------------------------
local bombPassDistance = 10         -- Maximum pass distance (in studs)
local AutoPassEnabled = false       -- Toggle auto-pass behavior
local AntiSlipperyEnabled = false   -- Toggle anti-slippery feature
local RemoveHitboxEnabled = false   -- Toggle hitbox removal
local pathfindingSpeed = 16         -- Used to calculate travel time

-----------------------------------------------------
-- UI THEMES (for auto–pass UI toggles)
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
-- UTILITY FUNCTIONS (Auto-pass related)
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
    return tween
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
-- AUTO PASS BOMB LOGIC (OPTIMAL PASS ONLY) WITH FEEDBACK & FALLBACK
-----------------------------------------------------
local function autoPassBomb()
    if not AutoPassEnabled then
        removeTargetMarker()
        return
    end

    pcall(function()
        local bomb = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Bomb")
        if bomb then
            local BombEvent = bomb:FindFirstChild("RemoteEvent")
            local targetPlayer = getOptimalPlayer() or getClosestPlayer()
            if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                createOrUpdateTargetMarker(targetPlayer)
                local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
                local myPos = LocalPlayer.Character.HumanoidRootPart.Position
                local distance = (targetPosition - myPos).magnitude
                if distance <= bombPassDistance then
                    local targetVelocity = targetPlayer.Character.HumanoidRootPart.Velocity or Vector3.new(0, 0, 0)
                    rotateCharacterTowardsTarget(targetPosition, targetVelocity)
                    task.wait(0.1)
                    BombEvent:FireServer(targetPlayer.Character, targetPlayer.Character:FindFirstChild("CollisionPart"))
                    print("Bomb passed to:", targetPlayer.Name)
                    removeTargetMarker()
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
-- APPLY FEATURES ON RESPAWN
-----------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function(char)
    applyAntiSlippery(AntiSlipperyEnabled)
    applyRemoveHitbox(RemoveHitboxEnabled)
end)

-----------------------------------------------------
-- LOAD ORION LIBRARY
-----------------------------------------------------
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()

-----------------------------------------------------
-- ADD WINDOW & EXTENDED TABS TO YOUR LOCAL SCRIPT
-----------------------------------------------------
local Window = OrionLib:MakeWindow({
    Name = "Advanced Orion UI",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "AdvancedOrion",
    IntroEnabled = true,
    IntroIcon = "rbxassetid://8834748103",
    IntroText = "Park Ji-woo"
})

-- Run the advanced load sequence on the main window.
AdvancedLoadSequence(Window, {
    IntroEnabled = true,
    IntroIcon = "rbxassetid://8834748103",
    IntroText = "Park Ji-woo"
})

-- Add the extra configurable tabs.
local ThemeConfigTab = Window:MakeThemeConfigTab({
    Name = "Theme Config",
    Icon = "rbxassetid://8834748103",
    PremiumOnly = false
})
local ConsoleTab = Window:MakeConsoleTab({
    Name = "Console",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Create the Automated tab.
local AutomatedTab = Window:MakeTab({
    Name = "Automated",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- (Ensure the tab’s container is used as the parent for added elements.)
if AutomatedTab.Container then
    AutomatedTab.ItemParent = AutomatedTab.Container
end

-----------------------------------------------------
-- DECLARE MISSING GLOBALS
-----------------------------------------------------
local autoPassConnection = nil
local markerStyle = "X"  -- Default marker style

-----------------------------------------------------
-- ADD YOUR TOGGLES AND OTHER ELEMENTS TO THE AUTOMATED TAB
-----------------------------------------------------
AutomatedTab:AddToggle({
    Name = "Auto Pass Bomb",
    Default = AutoPassEnabled,
    Callback = function(value)
        AutoPassEnabled = value
        print("Auto Pass Bomb toggled:", value)
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
        print("Anti Slippery toggled:", value)
        applyAntiSlippery(value)
    end
})

AutomatedTab:AddToggle({
    Name = "Remove Hitbox",
    Default = RemoveHitboxEnabled,
    Callback = function(value)
        RemoveHitboxEnabled = value
        print("Remove Hitbox toggled:", value)
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
        print("Bomb Pass Distance set to:", value)
    end
})

AutomatedTab:AddDropdown({
    Name = "Pathfinding Speed",
    Default = "16",
    Options = {"12", "16", "20"},
    Callback = function(value)
        pathfindingSpeed = tonumber(value)
        print("Pathfinding Speed set to:", pathfindingSpeed)
    end
})

AutomatedTab:AddDropdown({
    Name = "Marker Style",
    Default = "X",
    Options = {"X", "Arrow"},
    Callback = function(value)
        markerStyle = value
        print("Marker Style set to:", markerStyle)
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
            print("UI Theme changed to:", themeName)
        else
            warn("Theme not found:", themeName)
        end
    end
})

OrionLib:Init()
print("Yon Menu Script Loaded with Optimal Auto Pass Bomb, Anti Slippery, Remove Hitbox, UI Theme Support, Theme Config, and Console")
