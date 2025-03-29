-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- LOCAL PLAYER
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- CONFIG & VARIABLES
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

-- GUI
local GUI = Instance.new("ScreenGui")
GUI.Name = "AnimeGUI"
GUI.Parent = LocalPlayer.PlayerGui

local FPSLabel = Instance.new("TextLabel")
FPSLabel.Name = "FPSLabel"
FPSLabel.Text = "FPS: 0"
FPSLabel.Font = Enum.Font.SourceSansBold
FPSLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
FPSLabel.BackgroundTransparency = 1
FPSLabel.Size = UDim2.new(0, 100, 0, 20)
FPSLabel.Position = UDim2.new(0, 10, 0, 10)
FPSLabel.Parent = GUI

local MSLabel = Instance.new("TextLabel")
MSLabel.Name = "MSLabel"
MSLabel.Text = "MS: 0"
MSLabel.Font = Enum.Font.SourceSansBold
MSLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
MSLabel.BackgroundTransparency = 1
MSLabel.Size = UDim2.new(0, 100, 0, 20)
MSLabel.Position = UDim2.new(0, 10, 0, 30)
MSLabel.Parent = GUI

-- MODULES & FUNCTIONS
local LoggingModule = {}
function LoggingModule.logError(err, context)
    warn("[ERROR] Context: " .. tostring(context) .. " | Error: " .. tostring(err))
end
function LoggingModule.safeCall(func, context)
    local success, result = pcall(func)
    if not success then LoggingModule.logError(result, context) end
    return success, result
end

local AINotificationsModule = {}
function AINotificationsModule.sendNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = duration or 5 })
    end)
end

local FrictionModule = {}
function FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local bomb = char:FindFirstChild("Bomb")
    local NORMAL_FRICTION = 0.5
    local frictionValue = (AntiSlipperyEnabled and not bomb) and customAntiSlipperyFriction or NORMAL_FRICTION

    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CustomPhysicalProperties = PhysicalProperties.new(frictionValue, 0.3, 0.5)
        end
    end
end

local TargetingModule = {}
local useFlickRotation = false
local useSmoothRotation = true

function TargetingModule.getOptimalPlayer(bombPassDistance, pathfindingSpeed)
    local bestPlayer, bestTravelTime = nil, math.huge
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local myPos = hrp.Position
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if player.Character:FindFirstChild("Bomb") then continue end
            local targetPos = player.Character.HumanoidRootPart.Position
            local distance = (targetPos - myPos).Magnitude
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

function TargetingModule.getClosestPlayer(bombPassDistance)
    local closestPlayer, shortestDistance = nil, bombPassDistance
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local myPos = hrp.Position
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if player.Character:FindFirstChild("Bomb") then continue end
            local distance = (player.Character.HumanoidRootPart.Position - myPos).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestPlayer = player
            end
        end
    end
    return closestPlayer
end

function TargetingModule.rotateCharacterTowardsTarget(targetPosition)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local adjPos = Vector3.new(targetPosition.X, hrp.Position.Y, targetPosition.Z)
    if useFlickRotation then
        hrp.CFrame = CFrame.new(hrp.Position, adjPos)
    elseif useSmoothRotation then
        local targetCFrame = CFrame.new(hrp.Position, adjPos)
        local tween = TweenService:Create(hrp, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = targetCFrame})
        tween:Play()
    else
        hrp.CFrame = CFrame.new(hrp.Position, adjPos)
    end
end

-- AUTO PASS BOMB (Enhanced)
local autoPassConnection = nil
local function autoPassBombEnhanced()
    if not AutoPassEnabled then return end

    LoggingModule.safeCall(function()
        local bomb = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Bomb")
        if not bomb then
            return
        end

        local BombEvent = bomb:FindFirstChild("RemoteEvent")
        local targetPlayer = TargetingModule.getOptimalPlayer(bombPassDistance, pathfindingSpeed)
                           or TargetingModule.getClosestPlayer(bombPassDistance)

        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if targetPlayer.Character:FindFirstChild("Bomb") then
                return
            end
            local targetPos = targetPlayer.Character.HumanoidRootPart.Position
            local myPos = LocalPlayer.Character.HumanoidRootPart.Position
            local distance = (targetPos - myPos).Magnitude
            if distance > bombPassDistance then
                return
            end

            local targetCollision = targetPlayer.Character:FindFirstChild("CollisionPart")
                                   or targetPlayer.Character.HumanoidRootPart
            if not isLineOfSightClearMultiple(myPos, targetPos, targetCollision) then
                AINotificationsModule.sendNotification("AI Alert", "Line-of-sight blocked! Adjust your position.")
                return
            end

            TargetingModule.rotateCharacterTowardsTarget(targetPos)

            if AI_AssistanceEnabled then
                AINotificationsModule.sendNotification("AI Assistance", "Passing bomb to " .. targetPlayer.Name)
            end

            -- Attempt to fire remote
            if BombEvent then
                BombEvent:FireServer(targetPlayer.Character, targetCollision)
            else
                -- fallback
                bomb.Parent = targetPlayer.Character
            end
        end
    end, "autoPassBombEnhanced function")
end

-- COIN FARMING
local coinFarmConnection = nil
local function autoFarmCoins()
    local coinsFolder = Workspace:FindFirstChild("Coins") or Workspace:FindFirstChild("CoinSpawns")
    if coinsFolder then
        for _, coin in ipairs(coinsFolder:GetDescendants()) do
            if coin:IsA("BasePart") and coin.Name == "Coin" then
                local clone = coin:Clone()
                clone.CFrame = LocalPlayer.Character.HumanoidRootPart.CFrame
                clone.Parent = Workspace
                wait(0.1)
                clone:Destroy()
            end
        end
    end
end

local function startCoinFarm()
    coinFarmConnection = task.spawn(function()
        while autoFarmCoinsEnabled do
            autoFarmCoins()
            task.wait(coinFarmInterval)
        end
    end)
end

local function stopCoinFarm()
    coinFarmConnection = nil
end


-- CRATE FARMING
local crateOpenConnection = nil
local CrateRemote = ReplicatedStorage:FindFirstChild("CrateRemote") or ReplicatedStorage:FindFirstChild("OpenCrate")

local function autoOpenCrates()
    if CrateRemote then
        pcall(function()
            CrateRemote:FireServer(crateName)
        end)
    else
        warn("CrateRemote not found! Check the remote's name in ReplicatedStorage.")
    end
end

local function startCrateFarm()
    crateOpenConnection = task.spawn(function()
        while autoCrateOpenEnabled do
            autoOpenCrates()
            task.wait(crateOpenInterval)
        end
    end)
end

local function stopCrateFarm()
    crateOpenConnection = nil
end

-- PERIODIC FRICTION UPDATE
task.spawn(function()
    while true do
        if AntiSlipperyEnabled then
            FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
        end
        task.wait(0.5)
    end
end)

-- ORIONLIB MENU (Config Saving)
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()
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
local orionAutoPassToggle = AutomatedTab:AddToggle({
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

        -- If the mobile toggle button exists, update it
        if autoPassMobileButton then
            if value then
                autoPassMobileButton.BackgroundColor3 = Color3.fromRGB(0,255,0)
                autoPassMobileButton.Text = "ON"
            else
                autoPassMobileButton.BackgroundColor3 = Color3.fromRGB(255,0,0)
                autoPassMobileButton.Text = "OFF"
            end
        end
    end
})

AutomatedTab:AddLabel("Character Settings")
AutomatedTab:AddToggle({
    Name = "Anti Slippery",
    Flag = "AntiSlippery",
    Default = AntiSlipperyEnabled,
    Callback = function(value)
        AntiSlipperyEnabled = value
        FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
    end
})
AutomatedTab:AddTextbox({
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
AutomatedTab:AddToggle({
    Name = "Remove Hitbox",
    Flag = "RemoveHitbox",
    Default = RemoveHitboxEnabled,
    Callback = function(value)
        RemoveHitboxEnabled = value
        applyRemoveHitbox(value)
    end
})
AutomatedTab:AddTextbox({
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
AITab:AddToggle({
    Name = "AI Assistance",
    Flag = "AIAssistance",
    Default = AI_AssistanceEnabled,
    Callback = function(value)
        AI_AssistanceEnabled = value
    end
})
AITab:AddTextbox({
    Name = "Bomb Pass Distance",
    Flag = "BombPassDist",
    Default = tostring(bombPassDistance),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then bombPassDistance = num end
    end
})
AITab:AddTextbox({
    Name = "Ray Spread Angle",
    Flag = "RaySpread",
    Default = tostring(raySpreadAngle),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then raySpreadAngle = num end
    end
})
AITab:AddTextbox({
    Name = "Number of Raycasts",
    Flag = "RaycastsNum",
    Default = tostring(numRaycasts),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then numRaycasts = num end
    end
})

AITab:AddLabel("Rotation Settings")
AITab:AddToggle({
    Name = "Flick Rotation",
    Flag = "FlickRotation",
    Default = false,
    Callback = function(value)
        useFlickRotation = value
        if value then
            useSmoothRotation = false
        else
            if not useSmoothRotation then
                useSmoothRotation = true
            end
        end
    end
})
AITab:AddToggle({
    Name = "Smooth Rotation",
    Flag = "SmoothRotation",
    Default = true,
    Callback = function(value)
        useSmoothRotation = value
        if value then
            useFlickRotation = false
        else
            if not useFlickRotation then
                useFlickRotation = true
            end
        end
    end
})

-- UI ELEMENTS TAB
local UITab = Window:MakeTab({
    Name = "UI Elements",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})
UITab:AddColorpicker({
    Name = "Menu Main Color",
    Flag = "MainColor",
    Default = Color3.fromRGB(255,0,0),
    Callback = function(color)
        OrionLib.Themes[OrionLib.SelectedTheme].Main = color
    end
})

-- FARMING TAB
local FarmingTab = Window:MakeTab({
    Name = "Farming",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

FarmingTab:AddLabel("Coin Farming")
FarmingTab:AddToggle({
    Name = "Auto Farm Coins",
    Flag = "CoinFarm",
    Default = autoFarmCoinsEnabled,
    Callback = function(value)
        autoFarmCoinsEnabled = value
        if value then
            startCoinFarm()
        else
            stopCoinFarm()
        end
    end
})
FarmingTab:AddTextbox({
    Name = "Coin Farm Interval (sec)",
    Flag = "CoinFarmInterval",
    Default = tostring(coinFarmInterval),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            coinFarmInterval = num
        end
    end
})

FarmingTab:AddLabel("Crate Farming")
FarmingTab:AddToggle({
    Name = "Auto Open Crates",
    Flag = "CrateFarm",
    Default = autoCrateOpenEnabled,
    Callback = function(value)
        autoCrateOpenEnabled = value
        if value then
            startCrateFarm()
        else
            stopCrateFarm()
        end
    end
})
FarmingTab:AddTextbox({
    Name = "Crate Open Interval (sec)",
    Flag = "CrateOpenInterval",
    Default = tostring(crateOpenInterval),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            crateOpenInterval = num
        end
    end
})
FarmingTab:AddTextbox({
    Name = "Crate Type",
    Flag = "CrateName",
    Default = crateName,
    TextDisappear = false,
    Callback = function(value)
        crateName = value
    end
})

-- INIT ORIONLIB
OrionLib:Init()

-- MOBILE TOGGLE BUTTON (Synced with OrionLib "AutoPassBomb")
local autoPassMobileButton = nil

local function createMobileToggle()
    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "MobileToggleGui"
    mobileGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local button = Instance.new("TextButton")
    button.Name = "AutoPassMobileToggle"
    button.Size = UDim2.new(0,50,0,50)
    button.Position = UDim2.new(1,-70,1,-110)
    button.BackgroundColor3 = AutoPassEnabled and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
    button.Text = AutoPassEnabled and "ON" or "OFF"
    button.TextScaled = true
    button.Font = Enum.Font.SourceSansBold
    button.ZIndex = 100
    button.Parent = mobileGui
    
    local uicorner = Instance.new("UICorner")
    uicorner.CornerRadius = UDim.new(1,0)
    uicorner.Parent = button
    
    local uistroke = Instance.new("UIStroke")
    uistroke.Thickness = 2
    uistroke.Color = Color3.fromRGB(0,0,0)
    uistroke.Parent = button
    
    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255,100,100)}):Play()
    end)
    button.MouseLeave:Connect(function()
        if AutoPassEnabled then
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(0,255,0)}):Play()
        else
            TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255,0,0)}):Play()
        end
    end)
    
    button.MouseButton1Click:Connect(function()
        AutoPassEnabled = not AutoPassEnabled
        if AutoPassEnabled then
            button.BackgroundColor3 = Color3.fromRGB(0,255,0)
            button.Text = "ON"
            if OrionLib.Flags["AutoPassBomb"] then
                OrionLib.Flags["AutoPassBomb"]:Set(true)
            end
            if not autoPassConnection then
                autoPassConnection = RunService.Stepped:Connect(autoPassBombEnhanced)
            end
        else
            button.BackgroundColor3 = Color3.fromRGB(255,0,0)
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
    
    return mobileGui, button
end

local mobileGui, mobileButton = createMobileToggle()
autoPassMobileButton = mobileButton

-- If the user’s PlayerGui resets, recreate the mobile toggle
LocalPlayer:WaitForChild("PlayerGui").ChildRemoved:Connect(function(child)
    if child.Name == "MobileToggleGui" then
        wait(1)
        if not LocalPlayer.PlayerGui:FindFirstChild("MobileToggleGui") then
            mobileGui, mobileButton = createMobileToggle()
            autoPassMobileButton = mobileButton
        end
    end
end)

-- SHIFTLOCK CODE
local ShiftLockScreenGui = Instance.new("ScreenGui")
ShiftLockScreenGui.Name = "Shiftlock (CoreGui)"
ShiftLockScreenGui.Parent = game:GetService("CoreGui")
ShiftLockScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ShiftLockScreenGui.ResetOnSpawn = false

local ShiftLockButton = Instance.new("ImageButton")
ShiftLockButton.Parent = ShiftLockScreenGui
ShiftLockButton.BackgroundColor3 = Color3.fromRGB(255,255,255)
ShiftLockButton.BackgroundTransparency = 1
ShiftLockButton.Position = UDim2.new(0.7,0,0.75,0)
ShiftLockButton.Size = UDim2.new(0.0636,0,0.0661,0)
ShiftLockButton.SizeConstraint = Enum.SizeConstraint.RelativeXX
ShiftLockButton.Image = "rbxasset://textures/ui/mouseLock_off@2x.png"

local shiftLockUICorner = Instance.new("UICorner")
shiftLockUICorner.CornerRadius = UDim.new(0.2,0)
shiftLockUICorner.Parent = ShiftLockButton

local shiftLockUIStroke = Instance.new("UIStroke")
shiftLockUIStroke.Thickness = 2
shiftLockUIStroke.Color = Color3.fromRGB(0,0,0)
shiftLockUIStroke.Parent = ShiftLockButton

local ShiftlockCursor = Instance.new("ImageLabel")
ShiftlockCursor.Name = "Shiftlock Cursor"
ShiftlockCursor.Parent = ShiftLockScreenGui
ShiftlockCursor.Image = "rbxasset://textures/MouseLockedCursor.png"
ShiftlockCursor.Size = UDim2.new(0.03,0,0.03,0)
ShiftlockCursor.Position = UDim2.new(0.5,0,0.5,0)
ShiftlockCursor.AnchorPoint = Vector2.new(0.5,0.5)
ShiftlockCursor.SizeConstraint = Enum.SizeConstraint.RelativeXX
ShiftlockCursor.BackgroundTransparency = 1
ShiftlockCursor.BackgroundColor3 = Color3.fromRGB(255,0,0)
ShiftlockCursor.Visible = false

local SL_Active = nil
local SL_MaxLength = 900000
local SL_EnabledOffset = CFrame.new(1.7,0,0)
local SL_DisabledOffset = CFrame.new(-1.7,0,0)

ShiftLockButton.MouseButton1Click:Connect(function()
    if not SL_Active then
        SL_Active = RunService.RenderStepped:Connect(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if hum and root then
                hum.AutoRotate = false
                ShiftLockButton.Image = "rbxasset://textures/ui/mouseLock_on@2x.png"
                ShiftlockCursor.Visible = true

                root.CFrame = CFrame.new(root.Position, Vector3.new(
                    Workspace.CurrentCamera.CFrame.LookVector.X * SL_MaxLength,
                    root.Position.Y,
                    Workspace.CurrentCamera.CFrame.LookVector.Z * SL_MaxLength
                ))
                Workspace.CurrentCamera.CFrame = Workspace.CurrentCamera.CFrame * SL_EnabledOffset
                Workspace.CurrentCamera.Focus = CFrame.fromMatrix(
                    Workspace.CurrentCamera.Focus.Position,
                    Workspace.CurrentCamera.CFrame.RightVector,
                    Workspace.CurrentCamera.CFrame.UpVector
                ) * SL_EnabledOffset
            end
        end)
    else
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum then hum.AutoRotate = true end
        ShiftLockButton.Image = "rbxasset://textures/ui/mouseLock_off@2x.png"
        Workspace.CurrentCamera.CFrame = Workspace.CurrentCamera.CFrame * SL_DisabledOffset
        ShiftlockCursor.Visible = false
        if SL_Active then
            SL_Active:Disconnect()
            SL_Active = nil
        end
    end
end)

ContextActionService:BindAction("ShiftLock", function(_, inputState)
    if inputState == Enum.UserInputState.Begin then
        ShiftLockButton:MouseButton1Click()
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonR2)

print("Full script loaded with config saving, mobile toggle, shiftlock, and all features. Enjoy!")
