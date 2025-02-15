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
-- MODULES
-----------------------------------------------------

-- 5. Robust Error Handling & Debug Logging Module
local LoggingModule = {}

function LoggingModule.logError(err, context)
    warn("[ERROR] Context: " .. tostring(context) .. " | Error: " .. tostring(err))
end

function LoggingModule.safeCall(func, context)
    local success, result = pcall(func)
    if not success then
        LoggingModule.logError(result, context)
    end
    return success, result
end

-- 4. Targeting Module (Modular Code Structure)
local TargetingModule = {}

function TargetingModule.getOptimalPlayer(bombPassDistance, pathfindingSpeed)
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
            local distance = (targetPos - myPos).Magnitude
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
    local adjustedTargetPos = Vector3.new(targetPosition.X, hrp.Position.Y, targetPosition.Z)
    local targetCFrame = CFrame.new(hrp.Position, adjustedTargetPos)
    local tween = TweenService:Create(hrp, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = targetCFrame})
    tween:Play()
    return tween
end

-- 3. Enhanced Visual Feedback Module
local VisualModule = {}

function VisualModule.animateMarker(marker)
    if not marker then return end
    local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    local goal = {Size = UDim2.new(0, 100, 0, 100)}
    local tween = TweenService:Create(marker, tweenInfo, goal)
    tween:Play()
end

function VisualModule.playPassVFX(target)
    if not target or not target.Character then return end
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxassetid://258128463"  -- Replace with your preferred VFX texture.
    emitter.Rate = 50
    emitter.Lifetime = NumberRange.new(0.3, 0.5)
    emitter.Speed = NumberRange.new(2, 5)
    emitter.VelocitySpread = 30
    emitter.Parent = hrp
    delay(1, function()
        emitter:Destroy()
    end)
end

-- 6. Smart AI Notifications Module
local AINotificationsModule = {}

function AINotificationsModule.sendNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 5
        })
    end)
end

-- 2. Dynamic Friction Adjustment Module
local FrictionModule = {}

function FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
    local char = LocalPlayer.Character
    if not char then return end
    local bomb = char:FindFirstChild("Bomb")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local frictionAdjustment = 0.5  -- default friction

    if bomb then
        -- When holding the bomb, adjust friction based on how aligned your movement is with your facing.
        local velocity = hrp.Velocity
        local horizontalVel = Vector3.new(velocity.X, 0, velocity.Z)
        local forward = hrp.CFrame.LookVector
        local alignment = 1  -- assume perfect alignment by default
        if horizontalVel.Magnitude > 0 then
            alignment = horizontalVel:Dot(forward) / horizontalVel.Magnitude
        end
        -- Misalignment is 0 if you're moving straight (forward/backward) and 1 if moving completely sideways.
        local misalignment = 1 - math.abs(alignment)
        -- Increase friction proportionally (0.5 to 0.7) when misaligned.
        frictionAdjustment = 0.5 + misalignment * 0.2
    else
        -- When not holding the bomb, use standard dynamic friction if anti-slippery is enabled.
        frictionAdjustment = AntiSlipperyEnabled and math.clamp(0.5 + hrp.Velocity.Magnitude * 0.001, 0.5, 0.65) or 0.5
    end

    local newProps = PhysicalProperties.new(frictionAdjustment, 0.3, 0.5)
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CustomPhysicalProperties = newProps
        end
    end
end

-----------------------------------------------------
-- CONFIGURATION & VARIABLES
-----------------------------------------------------
local bombPassDistance = 10             -- Maximum pass distance for bomb passing (studs)
local AutoPassEnabled = false           -- Toggle auto-pass bomb behavior
local AntiSlipperyEnabled = false       -- Toggle smart anti-slippery feature
local RemoveHitboxEnabled = false       -- Toggle hitbox removal
local AI_AssistanceEnabled = false      -- Toggle AI Assistance notifications
local pathfindingSpeed = 16             -- For auto-pass bomb target selection
local lastAIMessageTime = 0
local aiMessageCooldown = 5             -- Seconds between AI notifications

local raySpreadAngle = 10               -- Angle for multiple raycasts (degrees)
local numRaycasts = 3                   -- Number of rays (prefer odd numbers)
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

    -- Enhanced visual feedback: animate the marker.
    VisualModule.animateMarker(marker)
end

local function removeTargetMarker()
    if currentTargetMarker then
        currentTargetMarker:Destroy()
        currentTargetMarker = nil
        currentTargetPlayer = nil
    end
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
-- ENHANCED AUTO PASS BOMB FUNCTION (with AI Notifications, Dynamic Friction, & Visual Feedback)
-----------------------------------------------------
local function autoPassBombEnhanced()
    LoggingModule.safeCall(function()
        local bomb = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Bomb")
        if not bomb then
            removeTargetMarker()
            return
        end

        local BombEvent = bomb:FindFirstChild("RemoteEvent")
        local targetPlayer = TargetingModule.getOptimalPlayer(bombPassDistance, pathfindingSpeed) or TargetingModule.getClosestPlayer(bombPassDistance)
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if targetPlayer.Character:FindFirstChild("Bomb") then
                removeTargetMarker()
                return
            end

            local targetPos = targetPlayer.Character.HumanoidRootPart.Position
            local myPos = LocalPlayer.Character.HumanoidRootPart.Position
            local distance = (targetPos - myPos).Magnitude

            if distance > bombPassDistance then
                print("Target out of range. Pass aborted.")
                removeTargetMarker()
                return
            end

            local targetCollision = targetPlayer.Character:FindFirstChild("CollisionPart") or targetPlayer.Character.HumanoidRootPart
            if not isLineOfSightClearMultiple(myPos, targetPos, targetCollision) then
                print("Line of sight blocked. Bomb pass aborted.")
                AINotificationsModule.sendNotification("AI Alert", "Line-of-sight blocked! Adjust your position.")
                removeTargetMarker()
                return
            end

            createOrUpdateTargetMarker(targetPlayer, distance)
            VisualModule.playPassVFX(targetPlayer)
            TargetingModule.rotateCharacterTowardsTarget(targetPos)
            if AI_AssistanceEnabled and tick() - lastAIMessageTime >= aiMessageCooldown then
                AINotificationsModule.sendNotification("AI Assistance", "Passing bomb to " .. targetPlayer.Name .. " (" .. math.floor(distance) .. " studs).")
                lastAIMessageTime = tick()
            end
            BombEvent:FireServer(targetPlayer.Character, targetPlayer.Character:FindFirstChild("CollisionPart"))
            print("Bomb passed to:", targetPlayer.Name, "Distance:", distance)
            removeTargetMarker()
        else
            removeTargetMarker()
        end
    end, "autoPassBombEnhanced function")
end

-----------------------------------------------------
-- REMOVE HITBOX FUNCTION
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

LocalPlayer.CharacterAdded:Connect(function(char)
    FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
    applyRemoveHitbox(RemoveHitboxEnabled)
end)

-----------------------------------------------------
-- ORIONLIB INTERFACE (Using Advanced Orion UI Library v2.0)
-----------------------------------------------------
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()
local Window = OrionLib:MakeWindow({
    Name = "Yon Menu - Advanced (Auto Pass Bomb Enhanced)",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "YonMenu_Advanced",
    ShowIcon = true  -- Enables dragging the menu icon
})

-- Create two tabs: Automated and AI-Based
local AutomatedTab = Window:MakeTab({
    Name = "Automated",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})
local AITab = Window:MakeTab({
    Name = "AI Based",
    Icon = "rbxassetid://7072720870",
    PremiumOnly = false
})

-- Toggle for Auto Pass Bomb Enhanced
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

-- Toggle for Smart Anti‑Slippery
AutomatedTab:AddToggle({
    Name = "Anti Slippery",
    Default = AntiSlipperyEnabled,
    Callback = function(value)
        AntiSlipperyEnabled = value
        FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
    end
})

-- Toggle for Remove Hitbox
AutomatedTab:AddToggle({
    Name = "Remove Hitbox",
    Default = RemoveHitboxEnabled,
    Callback = function(value)
        RemoveHitboxEnabled = value
        applyRemoveHitbox(value)
    end
})

-- AI Assistance Toggle
AITab:AddToggle({
    Name = "AI Assistance",
    Default = false,
    Callback = function(value)
        AI_AssistanceEnabled = value
        print("AI Assistance " .. (AI_AssistanceEnabled and "enabled." or "disabled."))
    end
})

-- Sliders for various settings
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

-----------------------------------------------------
-- UI ELEMENT: Colorpicker for Menu Main Color
-----------------------------------------------------
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
        -- Update theme using our changeUITheme function if needed.
        print("Menu main color updated to:", color)
    end,
    Flag = "MenuMainColor",
    Save = true
})

-----------------------------------------------------
-- CONTINUOUS DYNAMIC FRICTION UPDATE
-----------------------------------------------------
task.spawn(function()
    while true do
        FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
        task.wait(0.1)
    end
end)

-----------------------------------------------------
-- INITIALIZE UI
-----------------------------------------------------
OrionLib:Init()
print("Yon Menu Script Loaded with Enhanced AI Smart Auto Pass Bomb, Dynamic Friction, Remove Hitbox, UI Theme Support, and AI Assistance")

-----------------------------------------------------
-- MOBILE TOGGLE BUTTON FOR AUTO PASS BOMB
-----------------------------------------------------
-- Updated mobile GUI: Parent to PlayerGui and set high ZIndex for visibility.
local mobileGui = Instance.new("ScreenGui")
mobileGui.Name = "MobileToggleGui"
mobileGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local autoPassMobileToggle = Instance.new("TextButton")
autoPassMobileToggle.Name = "AutoPassMobileToggle"
autoPassMobileToggle.Size = UDim2.new(0, 50, 0, 50)
-- Position near the bottom-right; adjust if necessary.
autoPassMobileToggle.Position = UDim2.new(1, -70, 1, -110)
autoPassMobileToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)  -- Red for OFF
autoPassMobileToggle.Text = "OFF"
autoPassMobileToggle.TextScaled = true
autoPassMobileToggle.Font = Enum.Font.SourceSansBold
autoPassMobileToggle.ZIndex = 100  -- High ZIndex to ensure it shows on top.
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
