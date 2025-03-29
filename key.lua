-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StatsService = game:GetService("Stats")

-- LOCAL PLAYER & CHARACTER
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-----------------------------------------------------
-- PERFORMANCE GUI (FPS & MS with Blur Effect)
local perfGui = Instance.new("ScreenGui")
perfGui.Name = "PerformanceGui"
perfGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local FpsPingFrame = Instance.new("Frame")
FpsPingFrame.Name = "FpsPingFrame"
FpsPingFrame.Parent = perfGui
FpsPingFrame.Position = UDim2.new(0,10,0,10)
FpsPingFrame.Size = UDim2.new(0,150,0,50)
FpsPingFrame.BackgroundColor3 = Color3.fromRGB(29,29,29)
FpsPingFrame.BackgroundTransparency = 0.2
FpsPingFrame.BorderSizePixel = 0

local UICorner_FpsPing = Instance.new("UICorner")
UICorner_FpsPing.CornerRadius = UDim.new(0,8)
UICorner_FpsPing.Parent = FpsPingFrame

local Blur_FpsPing = Instance.new("ImageLabel")
Blur_FpsPing.Name = "Blur_FpsPing"
Blur_FpsPing.Parent = FpsPingFrame
Blur_FpsPing.BackgroundTransparency = 1
Blur_FpsPing.BorderSizePixel = 0
Blur_FpsPing.Size = UDim2.new(1,0,1,0)
Blur_FpsPing.Image = "http://www.roblox.com/asset/?id=6758962034"
Blur_FpsPing.ImageTransparency = 0.55

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Name = "FPSLabel"
fpsLabel.Parent = FpsPingFrame
fpsLabel.BackgroundTransparency = 1
fpsLabel.Position = UDim2.new(0.1,0,0.1,0)
fpsLabel.Size = UDim2.new(0.8,0,0.35,0)
fpsLabel.Font = Enum.Font.JosefinSans
fpsLabel.Text = "FPS: 0"
fpsLabel.TextColor3 = Color3.fromRGB(93,255,255)
fpsLabel.TextSize = 14
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left

local msLabel = Instance.new("TextLabel")
msLabel.Name = "MSLabel"
msLabel.Parent = FpsPingFrame
msLabel.BackgroundTransparency = 1
msLabel.Position = UDim2.new(0.1,0,0.55,0)
msLabel.Size = UDim2.new(0.8,0,0.35,0)
msLabel.Font = Enum.Font.JosefinSans
msLabel.Text = "MS: 0"
msLabel.TextColor3 = Color3.fromRGB(93,255,255)
msLabel.TextSize = 14
msLabel.TextXAlignment = Enum.TextXAlignment.Left

local updateInterval = 1
local accumulatedTime = 0
local frameCount = 0
RunService.RenderStepped:Connect(function(dt)
    accumulatedTime = accumulatedTime + dt
    frameCount = frameCount + 1
    if accumulatedTime >= updateInterval then
        local avgFps = math.floor(frameCount / accumulatedTime)
        local avgMs = math.floor((accumulatedTime / frameCount) * 1000)
        fpsLabel.Text = "FPS: " .. avgFps
        msLabel.Text = "MS: " .. avgMs
        accumulatedTime = 0
        frameCount = 0
    end
end)

-----------------------------------------------------
-- CONFIGURATION VARIABLES
local bombPassDistance = 10
local AutoPassEnabled = false
local AntiSlipperyEnabled = false
local RemoveHitboxEnabled = false
local AI_AssistanceEnabled = false
local pathfindingSpeed = 16
local raySpreadAngle = 10
local numRaycasts = 5
local customAntiSlipperyFriction = 0.7
local customHitboxSize = 0.1

local autoFarmCoinsEnabled = false
local coinFarmInterval = 1

local autoCrateOpenEnabled = false
local crateOpenInterval = 2
local crateName = "Rainbow Crate"

local aiMessageCooldown = 5
local lastAIMessageTime = 0

-----------------------------------------------------
-- CRATE FARMING (Updated)
local crateOpenConnection = nil
local CrateRemote = ReplicatedStorage:FindFirstChild("CrateRemote") or ReplicatedStorage:FindFirstChild("OpenCrate")
if not CrateRemote then
    warn("CrateRemote not found! Please check the remote's name in ReplicatedStorage.")
    crateName = "Unknown Crate"
else
    crateName = "Rainbow Crate"  -- update if needed
end

local function startCrateFarm()
    crateOpenConnection = task.spawn(function()
        while autoCrateOpenEnabled and CrateRemote do
            pcall(function()
                CrateRemote:FireServer(crateName)
            end)
            task.wait(crateOpenInterval)
        end
    end)
end

local function stopCrateFarm()
    if crateOpenConnection then
        task.cancel(crateOpenConnection)
        crateOpenConnection = nil
    end
end

-----------------------------------------------------
-- ORIONLIB MENU (CONFIG SAVING)
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Orion/main/source"))()
local Window = OrionLib:MakeWindow({
    Name = "Yon Menu (Full)",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "YonMenu_Advanced"
})

-- AUTOMATED SETTINGS TAB
local AutomatedTab = Window:MakeTab({
    Name = "Automated Settings",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

AutomatedTab:AddLabel("Bomb Passing")
local AutoPassToggle = AutomatedTab:AddToggle({
    Name = "Auto Pass Bomb (Enhanced)",
    Flag = "AutoPassBomb",
    Default = AutoPassEnabled,
    Callback = function(value)
        AutoPassEnabled = value
        if value then
            if not autoPassConnection then
                autoPassConnection = RunService.Stepped:Connect(autoPassBombEnhanced)
            end
        else
            if autoPassConnection then
                autoPassConnection:Disconnect()
                autoPassConnection = nil
            end
        end
    end
})

AutomatedTab:AddLabel("Character Settings")
local AntiSlipperyToggle = AutomatedTab:AddToggle({
    Name = "Anti Slippery",
    Flag = "AntiSlippery",
    Default = AntiSlipperyEnabled,
    Callback = function(value)
        AntiSlipperyEnabled = value
        FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
    end
})

local AntiSlipFrictionBox = AutomatedTab:AddTextbox({
    Name = "Custom Anti‑Slippery Friction",
    Flag = "AntiSlipFriction",
    Default = tostring(customAntiSlipperyFriction),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            customAntiSlipperyFriction = num
            FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
        end
    end
})

local RemoveHitboxToggle = AutomatedTab:AddToggle({
    Name = "Remove Hitbox",
    Flag = "RemoveHitbox",
    Default = RemoveHitboxEnabled,
    Callback = function(value)
        RemoveHitboxEnabled = value
        applyRemoveHitbox(value)
    end
})

local HitboxSizeBox = AutomatedTab:AddTextbox({
    Name = "Custom Hitbox Size",
    Flag = "HitboxSize",
    Default = tostring(customHitboxSize),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            customHitboxSize = num
            if RemoveHitboxEnabled then applyRemoveHitbox(true) end
        end
    end
})

-- AI BASED SETTINGS TAB
local AITab = Window:MakeTab({
    Name = "AI Based Settings",
    Icon = "rbxassetid://7072720870",
    PremiumOnly = false
})

AITab:AddLabel("Targeting Settings")
local AIAssistanceToggle = AITab:AddToggle({
    Name = "AI Assistance",
    Flag = "AIAssistance",
    Default = AI_AssistanceEnabled,
    Callback = function(value)
        AI_AssistanceEnabled = value
    end
})

local BombPassDistBox = AITab:AddTextbox({
    Name = "Bomb Pass Distance",
    Flag = "BombPassDist",
    Default = tostring(bombPassDistance),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then bombPassDistance = num end
    end
})

local RaySpreadBox = AITab:AddTextbox({
    Name = "Ray Spread Angle",
    Flag = "RaySpread",
    Default = tostring(raySpreadAngle),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then raySpreadAngle = num end
    end
})

local RaycastsNumBox = AITab:AddTextbox({
    Name = "Number of Raycasts",
    Flag = "RaycastsNum",
    Default = tostring(numRaycasts),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then numRaycasts = num end
    end
})

-- FARMING TAB
local FarmingTab = Window:MakeTab({
    Name = "Farming",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

FarmingTab:AddLabel("Coin Farming")
local CoinFarmToggle = FarmingTab:AddToggle({
    Name = "Auto Farm Coins",
    Flag = "CoinFarm",
    Default = autoFarmCoinsEnabled,
    Callback = function(value)
        autoFarmCoinsEnabled = value
        if value then startCoinFarm() else stopCoinFarm() end
    end
})

local CoinFarmIntervalBox = FarmingTab:AddTextbox({
    Name = "Coin Farm Interval (sec)",
    Flag = "CoinFarmInterval",
    Default = tostring(coinFarmInterval),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then coinFarmInterval = num end
    end
})

FarmingTab:AddLabel("Crate Farming")
local CrateFarmToggle = FarmingTab:AddToggle({
    Name = "Auto Open Crates",
    Flag = "CrateFarm",
    Default = autoCrateOpenEnabled,
    Callback = function(value)
        autoCrateOpenEnabled = value
        if value then startCrateFarm() else stopCrateFarm() end
    end
})

local CrateOpenIntervalBox = FarmingTab:AddTextbox({
    Name = "Crate Open Interval (sec)",
    Flag = "CrateOpenInterval",
    Default = tostring(crateOpenInterval),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then crateOpenInterval = num end
    end
})

local CrateNameBox = FarmingTab:AddTextbox({
    Name = "Crate Type",
    Flag = "CrateName",
    Default = crateName,
    TextDisappear = false,
    Callback = function(value)
        crateName = value
    end
})

-- Initialize the library
OrionLib:Init()

-----------------------------------------------------
-- MOBILE TOGGLE BUTTON FOR AUTO PASS (Always Visible via CoreGui)
local autoPassMobileButton = nil
local function createMobileToggle()
    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "MobileToggleGui"
    mobileGui.Parent = game:GetService("CoreGui")
    mobileGui.ResetOnSpawn = false
    mobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local button = Instance.new("TextButton")
    button.Name = "AutoPassMobileToggle"
    button.Size = UDim2.new(0, 80, 0, 80)  -- Increased size for better visibility
    button.Position = UDim2.new(1, -90, 1, -130)  -- Adjusted position
    button.BackgroundColor3 = AutoPassEnabled and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    button.Text = AutoPassEnabled and "ON" or "OFF"
    button.TextScaled = true
    button.Font = Enum.Font.SourceSansBold
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.ZIndex = 100
    button.Parent = mobileGui
    
    local uicorner = Instance.new("UICorner")
    uicorner.CornerRadius = UDim.new(1, 0)
    uicorner.Parent = button
    
    local uistroke = Instance.new("UIStroke")
    uistroke.Thickness = 2
    uistroke.Color = Color3.fromRGB(0, 0, 0)
    uistroke.Parent = button
    
    button.MouseButton1Click:Connect(function()
        AutoPassEnabled = not AutoPassEnabled
        if AutoPassEnabled then
            button.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            button.Text = "ON"
            if OrionLib.Flags["AutoPassBomb"] then
                OrionLib.Flags["AutoPassBomb"]:Set(true)
            end
            if not autoPassConnection then
                autoPassConnection = RunService.Stepped:Connect(autoPassBombEnhanced)
            end
        else
            button.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            button.Text = "OFF"
            if OrionLib.Flags["AutoPassBomb"] then
                OrionLib.Flags["AutoPassBomb"]:Set(false)
            end
            if autoPassConnection then
                autoPassConnection:Disconnect()
                autoPassConnection = nil
            end
        end
    end)
    
    return button
end

-- Create the mobile button after OrionLib is initialized
autoPassMobileButton = createMobileToggle()

-----------------------------------------------------
-- CHARACTER EVENT HANDLERS
LocalPlayer.CharacterAdded:Connect(function(character)
    Character = character
    if AntiSlipperyEnabled then
        FrictionModule.updateSlidingProperties(true)
    end
    if RemoveHitboxEnabled then
        applyRemoveHitbox(true)
    end
end)

-- Initial setup
if AntiSlipperyEnabled then
    FrictionModule.updateSlidingProperties(true)
end
if RemoveHitboxEnabled then
    applyRemoveHitbox(true)
end
if AutoPassEnabled and not autoPassConnection then
    autoPassConnection = RunService.Stepped:Connect(autoPassBombEnhanced)
end
if autoFarmCoinsEnabled then
    startCoinFarm()
end
if autoCrateOpenEnabled then
    startCrateFarm()
end

-----------------------------------------------------
-- END OF SCRIPT
print("Full script loaded with mobile auto pass button, coin collector, shiftlock, and all features. Enjoy!")
