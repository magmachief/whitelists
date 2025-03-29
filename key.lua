-----------------------------------------------------
-- Ultra Advanced AI-Driven Bomb Passing Assistant
-- Full Script (Local Stats Removed)
-- Features:
-- • Auto Pass Bomb (Enhanced) using default mobile thumbstick
-- • Anti‑Slippery with custom friction (updates every 0.5s)
-- • Remove Hitbox with custom size
-- • Auto Farm Coins (touch events) & Auto Open Crates (fires remote in ReplicatedStorage)
-- • OrionLib menu with config saving (using addToggle/addTextbox, no AddSection/Slider)
-- • Shiftlock
-- • Performance GUI (stable averaged FPS & MS with blur effect)
-----------------------------------------------------

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-----------------------------------------------------
-- CONFIG & VARIABLES
-----------------------------------------------------
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
-- PERFORMANCE GUI (FPS & MS with Blur Effect)
local perfGui = Instance.new("ScreenGui")
perfGui.Name = "PerformanceGui"
perfGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
perfGui.ResetOnSpawn = false

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

local AINotificationsModule = {}
function AINotificationsModule.sendNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = duration or 5 })
    end)
end

-- Friction Module
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

-- Continuous friction update (every 0.5 sec)
task.spawn(function()
    while true do
        task.wait(0.5)
        if AntiSlipperyEnabled then
            FrictionModule.updateSlidingProperties(true)
        end
    end
end)

-- Remove Hitbox
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
-- TARGETING MODULE
-----------------------------------------------------
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

-----------------------------------------------------
-- AUTO PASS BOMB (Enhanced)
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

            local targetCollision = targetPlayer.Character:FindFirstChild("CollisionPart") or targetPlayer.Character.HumanoidRootPart
            if not isLineOfSightClearMultiple(myPos, targetPos, targetCollision) then
                AINotificationsModule.sendNotification("AI Alert", "Line-of-sight blocked! Adjust your position.")
                removeTargetMarker()
                return
            end

            createOrUpdateTargetMarker(targetPlayer, distance)
            VisualModule.playPassVFX(targetPlayer)
            -- If you're not actively moving, perform a full rotation.
            local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
            if hum and hum.MoveDirection.Magnitude < 0.2 then
                TargetingModule.rotateCharacterTowardsTarget(targetPos)
            else
                -- Otherwise, assist rotation with a softer correction.
                local currentCF = LocalPlayer.Character.HumanoidRootPart.CFrame
                local currentLook = currentCF.LookVector
                local desiredDir = (Vector3.new(targetPos.X, LocalPlayer.Character.HumanoidRootPart.Position.Y, targetPos.Z) - LocalPlayer.Character.HumanoidRootPart.Position).Unit
                local currentAngle = math.atan2(currentLook.Z, currentLook.X)
                local desiredAngle = math.atan2(desiredDir.Z, desiredDir.X)
                local angleDiff = desiredAngle - currentAngle
                while angleDiff > math.pi do angleDiff = angleDiff - 2*math.pi end
                while angleDiff < -math.pi do angleDiff = angleDiff + 2*math.pi end
                local correctionFactor = 0.3
                local newAngle = currentAngle + angleDiff * correctionFactor
                local newDir = Vector3.new(math.cos(newAngle), 0, math.sin(newAngle))
                LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(LocalPlayer.Character.HumanoidRootPart.Position, LocalPlayer.Character.HumanoidRootPart.Position + newDir)
            end

            if AI_AssistanceEnabled and tick() - lastAIMessageTime >= aiMessageCooldown then
                AINotificationsModule.sendNotification("AI Assistance", "Passing bomb to " .. targetPlayer.Name .. " (" .. math.floor(distance) .. " studs).")
                lastAIMessageTime = tick()
            end

            if BombEvent then
                BombEvent:FireServer(targetPlayer.Character, targetCollision)
                wait(0.1)
                if bomb.Parent ~= targetPlayer.Character then
                    bomb.Parent = targetPlayer.Character
                end
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
-- TARGET MARKER FUNCTIONS
-----------------------------------------------------
local currentTargetMarker, currentTargetPlayer = nil, nil
local function removeTargetMarker()
    if currentTargetMarker then
        currentTargetMarker:Destroy()
        currentTargetMarker, currentTargetPlayer = nil, nil
    end
end

local function createOrUpdateTargetMarker(player, distance)
    if not player or not player.Character then return end
    local body = player.Character:FindFirstChild("HumanoidRootPart")
    if not body then return end

    if currentTargetMarker and currentTargetPlayer == player then
        local lbl = currentTargetMarker:FindFirstChildOfClass("TextLabel")
        if lbl then
            lbl.Text = player.Name .. "\n" .. math.floor(distance) .. " studs"
        end
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

-----------------------------------------------------
-- COIN FARMING (Fixed)
-----------------------------------------------------
local coinFarmConnection = nil
local function autoFarmCoins()
    local hrp = Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("coin") then
            pcall(function()
                firetouchinterest(hrp, obj, 0)
                firetouchinterest(hrp, obj, 1)
            end)
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
    if coinFarmConnection then
        task.cancel(coinFarmConnection)
        coinFarmConnection = nil
    end
end

-----------------------------------------------------
-- CRATE FARMING
-----------------------------------------------------
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
    if crateOpenConnection then
        task.cancel(crateOpenConnection)
        crateOpenConnection = nil
    end
end

-----------------------------------------------------
-- SHIFTLOCK CODE (Single Block)
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

-----------------------------------------------------
-- ORIONLIB MENU (CONFIG SAVING)
-----------------------------------------------------
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()
local Window = OrionLib:MakeWindow({
    Name = "Yon Menu (Full)",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "YonMenu_Advanced"
})

-- Automated Settings Tab
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
            removeTargetMarker()
        end

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

-- AI Based Settings Tab
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
AITab:AddLabel("Rotation Settings")
local FlickRotationToggle = AITab:AddToggle({
    Name = "Use Flick Rotation",
    Flag = "UseFlickRotation",
    Default = useFlickRotation,
    Callback = function(value)
        useFlickRotation = value
        if value then
            useSmoothRotation = false
            if OrionLib.Flags["UseSmoothRotation"] then
                OrionLib.Flags["UseSmoothRotation"]:Set(false)
            end
        end
    end
})
local SmoothRotationToggle = AITab:AddToggle({
    Name = "Use Smooth Rotation",
    Flag = "UseSmoothRotation",
    Default = useSmoothRotation,
    Callback = function(value)
        useSmoothRotation = value
        if value then
            useFlickRotation = false
            if OrionLib.Flags["UseFlickRotation"] then
                OrionLib.Flags["UseFlickRotation"]:Set(false)
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
local MainColorPicker = UITab:AddColorpicker({
    Name = "Menu Main Color",
    Flag = "MainColor",
    Default = Color3.fromRGB(255,0,0),
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

OrionLib:Init()

-----------------------------------------------------
-- MOBILE TOGGLE BUTTON FOR AUTO PASS (Synced with OrionLib "AutoPassBomb")
-----------------------------------------------------
local function createMobileToggle()
    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "MobileToggleGui"
    mobileGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    mobileGui.ResetOnSpawn = false
    mobileGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local button = Instance.new("TextButton")
    button.Name = "AutoPassMobileToggle"
    button.Size = UDim2.new(0,80,0,80)
    button.Position = UDim2.new(1,-90,1,-130)
    button.BackgroundColor3 = AutoPassEnabled and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
    button.Text = AutoPassEnabled and "ON" or "OFF"
    button.TextScaled = true
    button.Font = Enum.Font.SourceSansBold
    button.TextColor3 = Color3.fromRGB(255,255,255)
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
            removeTargetMarker()
        end
    end)
    
    return mobileGui, button
end

local mobileGui, mobileButton = createMobileToggle()

-----------------------------------------------------
-- CHARACTER EVENT HANDLERS
LocalPlayer.CharacterAdded:Connect(function(character)
    Character = character
    if AntiSlipperyEnabled then
        FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
    end
    if RemoveHitboxEnabled then
        applyRemoveHitbox(true)
    end
end)

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
print("Full script loaded with mobile auto pass button (always visible), coin collector, shiftlock, and all features. Enjoy!")