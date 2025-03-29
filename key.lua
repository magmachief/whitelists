-----------------------------------------------------
-- Ultra Advanced AI-Driven Bomb Passing Assistant Script for "Pass the Bomb"
-- Client-Only Version (Local Stats Removed, No DataStore)
-- Features:
-- • Auto Pass Bomb (Enhanced) with synchronized mobile & menu toggles
-- • Anti‑Slippery with custom friction applied (updated every 0.5 seconds)
-- • Remove Hitbox with custom hitbox size applied immediately
-- • Extra Farming:
--      - Auto Farm Coins Invisibly (simulate touch events on coins)
--      - Auto Open Crates (fires a remote to open crates)
-- • OrionLib menu with four tabs (Automated, AI Based, UI Elements, Farming)
-- • Shiftlock functionality
--
-- [NOTE] This version uses only:
--    • AddLabel
--    • AddToggle
--    • AddTextbox
--    • AddColorpicker
-- to avoid errors in older OrionLib forks.
-----------------------------------------------------

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-----------------------------------------------------
-- CHARACTER SETUP
-----------------------------------------------------
local CHAR = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HUMANOID = CHAR:WaitForChild("Humanoid")
local HRP = CHAR:WaitForChild("HumanoidRootPart")

-----------------------------------------------------
-- MODULES & UTILITY FUNCTIONS
-----------------------------------------------------
local LoggingModule = {}
function LoggingModule.logError(err, context)
    warn("[ERROR] Context: " .. tostring(context) .. " | Error: " .. tostring(err))
end
function LoggingModule.safeCall(func, context)
    local success, result = pcall(func)
    if not success then LoggingModule.logError(result, context) end
    return success, result
end

local TargetingModule = {}
local useFlickRotation = false
local useSmoothRotation = true

function TargetingModule.getOptimalPlayer(bombPassDistance, pathfindingSpeed)
    local bestPlayer, bestTravelTime = nil, math.huge
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
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
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
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
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local adjPos = Vector3.new(targetPosition.X, hrp.Position.Y, targetPosition.Z)
    if useFlickRotation then
        hrp.CFrame = CFrame.new(hrp.Position, adjPos)
    elseif useSmoothRotation then
        local targetCFrame = CFrame.new(hrp.Position, adjPos)
        local tween = TweenService:Create(hrp, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = targetCFrame})
        tween:Play()
        return tween
    else
        hrp.CFrame = CFrame.new(hrp.Position, adjPos)
    end
end

local VisualModule = {}
function VisualModule.animateMarker(marker)
    if not marker then return end
    local tween = TweenService:Create(marker, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = UDim2.new(0,100,0,100)})
    tween:Play()
end
function VisualModule.playPassVFX(target)
    if not target or not target.Character then return end
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxassetid://258128463"
    emitter.Rate = 50
    emitter.Lifetime = NumberRange.new(0.3, 0.5)
    emitter.Speed = NumberRange.new(2, 5)
    emitter.VelocitySpread = 30
    emitter.Parent = hrp
    delay(1, function() emitter:Destroy() end)
end

local AINotificationsModule = {}
function AINotificationsModule.sendNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = duration or 5 })
    end)
end

local FrictionModule = {}
-- Update friction properties every 0.5 seconds
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

-----------------------------------------------------
-- REMOVE HITBOX FUNCTIONALITY
-----------------------------------------------------
local function applyRemoveHitbox(enable)
    local char = LocalPlayer.Character
    if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == "Hitbox" then
            if enable then
                part.Transparency = 1
                part.CanCollide = false
                part.Size = Vector3.new(customHitboxSize, customHitboxSize, customHitboxSize)
            else
                part.Transparency = 0
                part.CanCollide = true
                part.Size = Vector3.new(1,1,1)
            end
        end
    end
end

-----------------------------------------------------
-- CONFIGURATION VARIABLES
-----------------------------------------------------
local bombPassDistance = 10
local AutoPassEnabled = false
local AntiSlipperyEnabled = false
local RemoveHitboxEnabled = false
local AI_AssistanceEnabled = false
local pathfindingSpeed = 16
local lastAIMessageTime = 0
local aiMessageCooldown = 5
local raySpreadAngle = 10
local numRaycasts = 5
local customAntiSlipperyFriction = 0.7
local customHitboxSize = 0.1

-----------------------------------------------------
-- Update Friction Every 0.5 Seconds
-----------------------------------------------------
task.spawn(function()
    while true do
        if AntiSlipperyEnabled then
            FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
        end
        wait(0.5)
    end
end)

-----------------------------------------------------
-- VISUAL TARGET MARKER (For Bomb Passing)
-----------------------------------------------------
local currentTargetMarker, currentTargetPlayer = nil, nil
local function createOrUpdateTargetMarker(player, distance)
    if not player or not player.Character then return end
    local body = player.Character:FindFirstChild("HumanoidRootPart")
    if not body then return end
    if currentTargetMarker and currentTargetPlayer == player then
        currentTargetMarker:FindFirstChildOfClass("TextLabel").Text = player.Name .. "\n" .. math.floor(distance) .. " studs"
        return
    end
    if currentTargetMarker then
        currentTargetMarker:Destroy()
        currentTargetMarker, currentTargetPlayer = nil, nil
    end
    local marker = Instance.new("BillboardGui")
    marker.Name = "BombPassTargetMarker"
    marker.Adornee = body
    marker.Size = UDim2.new(0,80,0,80)
    marker.StudsOffset = Vector3.new(0,2,0)
    marker.AlwaysOnTop = true
    marker.Parent = body
    local label = Instance.new("TextLabel", marker)
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.Text = player.Name .. "\n" .. math.floor(distance) .. " studs"
    label.TextScaled = true
    label.TextColor3 = Color3.new(1,0,0)
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

-----------------------------------------------------
-- MULTIPLE RAYCASTS (Line-of-Sight Checks)
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
-- AUTO PASS FUNCTION (Bomb Passing)
-----------------------------------------------------
local autoPassConnection = nil
local function autoPassBombEnhanced()
    if not AutoPassEnabled then return end
    LoggingModule.safeCall(function()
        local bomb = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Bomb")
        if not bomb then
            removeTargetMarker()
            return
        end
        local BombEvent = bomb:FindFirstChild("RemoteEvent")
        local targetPlayer = TargetingModule.getOptimalPlayer(bombPassDistance, pathfindingSpeed)
                           or TargetingModule.getClosestPlayer(bombPassDistance)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if targetPlayer.Character:FindFirstChild("Bomb") then
                removeTargetMarker()
                return
            end
            local targetPos = targetPlayer.Character.HumanoidRootPart.Position
            local myPos = LocalPlayer.Character.HumanoidRootPart.Position
            local distance = (targetPos - myPos).Magnitude
            if distance > bombPassDistance then
                removeTargetMarker()
                return
            end
            local targetCollision = targetPlayer.Character:FindFirstChild("CollisionPart")
                                  or targetPlayer.Character.HumanoidRootPart
            if not isLineOfSightClearMultiple(myPos, targetPos, targetCollision) then
                AINotificationsModule.sendNotification("AI Alert", "Line-of-sight blocked! Adjust your position.")
                removeTargetMarker()
                return
            end
            createOrUpdateTargetMarker(targetPlayer, distance)
            VisualModule.playPassVFX(targetPlayer)
            TargetingModule.rotateCharacterTowardsTarget(targetPos)
            if AI_AssistanceEnabled and tick() - lastAIMessageTime >= aiMessageCooldown then
                AINotificationsModule.sendNotification("AI Assistance",
                    "Passing bomb to " .. targetPlayer.Name .. " (" .. math.floor(distance) .. " studs).")
                lastAIMessageTime = tick()
            end
            if BombEvent then
                BombEvent:FireServer(targetPlayer.Character, targetCollision)
            else
                bomb.Parent = targetPlayer.Character
            end
            removeTargetMarker()
        else
            removeTargetMarker()
        end
    end, "autoPassBombEnhanced function")
end

-----------------------------------------------------
-- EXTRA FARMING FEATURES
-----------------------------------------------------
local autoFarmCoinsEnabled = false
local coinFarmInterval = 1  -- seconds between collection attempts
local coinFarmConnection = nil

local function autoFarmCoins()
    local coinsFolder = Workspace:FindFirstChild("Coins") or Workspace:FindFirstChild("CoinSpawns")
    if coinsFolder then
        for _, coin in ipairs(coinsFolder:GetDescendants()) do
            if coin:IsA("BasePart") and coin.Name == "Coin" then
                pcall(function()
                    firetouchinterest(HRP, coin, 0)
                    firetouchinterest(HRP, coin, 1)
                end)
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

local autoCrateOpenEnabled = false
local crateOpenInterval = 2  -- seconds between crate openings
local crateOpenConnection = nil
local crateName = "Rainbow Crate"  -- default crate type

local CrateRemote = ReplicatedStorage:FindFirstChild("CrateRemote") or ReplicatedStorage:FindFirstChild("OpenCrate")

local function autoOpenCrates()
    if CrateRemote then
        pcall(function()
            CrateRemote:FireServer(crateName)
        end)
    else
        print("CrateRemote not found! Check the remote's name in ReplicatedStorage.")
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

-----------------------------------------------------
-- ORIONLIB MENU (No AddSection, No AddSlider)
-----------------------------------------------------
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()
local Window = OrionLib:MakeWindow({
    Name = "Yon Menu - No Sliders/Sections",
    HidePremium = false
})

-- Automated Settings Tab
local AutomatedTab = Window:MakeTab({
    Name = "Automated Settings",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

AutomatedTab:AddLabel("Bomb Passing")
AutomatedTab:AddToggle({
    Name = "Auto Pass Bomb (Enhanced)",
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
            removeTargetMarker()
        end
    end
})

AutomatedTab:AddLabel("Character Settings")
AutomatedTab:AddToggle({
    Name = "Anti Slippery",
    Default = AntiSlipperyEnabled,
    Callback = function(value)
        AntiSlipperyEnabled = value
        FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
    end
})
AutomatedTab:AddTextbox({
    Name = "Custom Anti‑Slippery Friction",
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
    Default = RemoveHitboxEnabled,
    Callback = function(value)
        RemoveHitboxEnabled = value
        applyRemoveHitbox(value)
    end
})
AutomatedTab:AddTextbox({
    Name = "Custom Hitbox Size",
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

-- AI Based Settings Tab
local AITab = Window:MakeTab({
    Name = "AI Based Settings",
    Icon = "rbxassetid://7072720870",
    PremiumOnly = false
})

AITab:AddLabel("Targeting Settings")
AITab:AddToggle({
    Name = "AI Assistance",
    Default = AI_AssistanceEnabled,
    Callback = function(value)
        AI_AssistanceEnabled = value
    end
})
AITab:AddTextbox({
    Name = "Bomb Pass Distance",
    Default = tostring(bombPassDistance),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then bombPassDistance = num end
    end
})
AITab:AddTextbox({
    Name = "Ray Spread Angle",
    Default = tostring(raySpreadAngle),
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then raySpreadAngle = num end
    end
})
AITab:AddTextbox({
    Name = "Number of Raycasts",
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

-- UI Elements Tab
local UITab = Window:MakeTab({
    Name = "UI Elements",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})
UITab:AddColorpicker({
    Name = "Menu Main Color",
    Default = Color3.fromRGB(255, 0, 0),
    Callback = function(color)
        OrionLib.Themes[OrionLib.SelectedTheme].Main = color
    end
})

-- Farming Tab
local FarmingTab = Window:MakeTab({
    Name = "Farming",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

FarmingTab:AddLabel("Coin Farming")
FarmingTab:AddToggle({
    Name = "Auto Farm Coins",
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
    Default = crateName,
    TextDisappear = false,
    Callback = function(value)
        crateName = value
    end
})

-----------------------------------------------------
-- INITIALIZE ORIONLIB
-----------------------------------------------------
OrionLib:Init()

-----------------------------------------------------
-- SHIFTLOCK CODE
-----------------------------------------------------
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
        if hum then
            hum.AutoRotate = true
        end
        ShiftLockButton.Image = "rbxasset://textures/ui/mouseLock_off@2x.png"
        Workspace.CurrentCamera.CFrame = Workspace.CurrentCamera.CFrame * SL_DisabledOffset
        ShiftlockCursor.Visible = false
        if SL_Active then
            SL_Active:Disconnect()
            SL_Active = nil
        end
    end
end)

ContextActionService:BindAction("ShiftLock", function(actionName, inputState)
    if inputState == Enum.UserInputState.Begin then
        ShiftLockButton:MouseButton1Click()
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonR2)

print("Cleaned-up script loaded. No AddSection, no AddSlider, uses textboxes for intervals. Enjoy!")