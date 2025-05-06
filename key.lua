-----------------------------------------------------
-- Ultra Advanced AI-Driven Bomb Passing Assistant Script for "Pass the Bomb"
-- Client-Only Version (Local Stats, No DataStore)
-----------------------------------------------------

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local bombName = "Bomb"

-----------------------------------------------------
-- ENHANCED ANTI‑SLIPPERY MODULE WITH SMART TRACTION
-----------------------------------------------------
local FrictionController = {}
FrictionController.__index = FrictionController

function FrictionController.new()
    local self = setmetatable({}, FrictionController)
    self.originalProperties = {}                 -- Cache original physical properties
    self.updateInterval = 0.1                      -- Update interval (in seconds)
    -- Configuration variables:
    self.normalFriction = 0.7                      -- Base friction when not holding the bomb
    self.bombFriction = 0.4                        -- Friction when holding the bomb
    self.movementThreshold = 0.85                  -- Threshold for intentional movement
    self.stateMultipliers = {                      -- Multipliers based on humanoid state
        Running = 1.2,
        Walking = 1.0,
        Crouching = 0.8
    }
    self.enabled = false
    return self
end

-- Optional: Get the surface material beneath the character
function FrictionController:getSurfaceMaterial(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return Enum.Material.Plastic end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local result = Workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), rayParams)
    return result and result.Material or Enum.Material.Plastic
end

-- Calculate dynamic friction based on movement and character state
function FrictionController:calculateFriction(character)
    local humanoid = character:FindFirstChild("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and hrp) then
        return self.normalFriction
    end

    local moveDir = humanoid.MoveDirection
    local velocity = hrp.Velocity
    local velocityDir = velocity.Magnitude > 0 and velocity.Unit or Vector3.new(0, 0, 0)
    local directionSimilarity = moveDir:Dot(velocityDir)
    
    local baseFriction = self.normalFriction
    if character:FindFirstChild(bombName) then
        baseFriction = self.bombFriction
    end
    
    local stateName = humanoid:GetState()         -- e.g., "Running", "Walking", ...
    local multiplier = self.stateMultipliers[stateName] or 1.0
    
    if directionSimilarity > self.movementThreshold then
        return math.clamp(baseFriction * multiplier, 0.1, 1.0)
    else
        return math.clamp(baseFriction * 0.7, 0.1, 1.0)
    end
end

-- Update the character's body parts friction
function FrictionController:update()
    local character = LocalPlayer.Character
    if not character then return end
    
    local parts = {"LeftFoot", "RightFoot", "LeftLeg", "RightLeg"}
    for _, partName in ipairs(parts) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            if not self.originalProperties[part] then
                self.originalProperties[part] = part.CustomPhysicalProperties
            end
            local dynamicFriction = self:calculateFriction(character)
            part.CustomPhysicalProperties = PhysicalProperties.new(
                dynamicFriction,
                part.CustomPhysicalProperties.Elasticity,
                part.CustomPhysicalProperties.FrictionWeight
            )
        end
    end
end

-- Restore original physical properties to the character parts
function FrictionController:restore()
    for part, orig in pairs(self.originalProperties) do
        if part and part.Parent then
            part.CustomPhysicalProperties = orig
        end
    end
    self.originalProperties = {}
end

-- Enable the anti‑slippery system by connecting to the Heartbeat event
function FrictionController:enable()
    if self.enabled then return end
    self.enabled = true
    self.connection = RunService.Heartbeat:Connect(function()
        self:update()
    end)
end

-- Disable the system and restore parts' original properties
function FrictionController:disable()
    if self.connection then
        self.connection:Disconnect()
        self.connection = nil
    end
    self:restore()
    self.enabled = false
end

-----------------------------------------------------
-- CHARACTER SETUP
-----------------------------------------------------
local CHAR = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HUMANOID = CHAR:WaitForChild("Humanoid")
local HRP = CHAR:WaitForChild("HumanoidRootPart")

-----------------------------------------------------
-- PRECISION ROTATION SYSTEM
-----------------------------------------------------
local ROTATION_ANGLES = {5, 10, -5, -10} -- Subtle natural angles
local function executePrecisionRotation(targetPos)
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end
    
    local microMovements = {
        Vector3.new(0.0001, 0, 0.0001),
        Vector3.new(-0.0001, 0, -0.0001)
    }
    for i = 1, 2 do
        humanoid.AutoRotate = false
        hrp.CFrame = CFrame.lookAt(hrp.Position, targetPos)
        task.wait(0.01)
        local head = char:FindFirstChild("Head")
        if head then
            local weld = head:FindFirstChildOfClass("Weld")
            if weld then
                local angle = ROTATION_ANGLES[(i % #ROTATION_ANGLES) + 1]
                weld.C0 = weld.C0 * CFrame.Angles(0, math.rad(angle), 0)
                task.delay(0.2, function()
                    weld.C0 = weld.C0 * CFrame.Angles(0, math.rad(-angle), 0)
                end)
            end
        end
        humanoid:MoveTo(hrp.Position + microMovements[(i % #microMovements) + 1])
        task.wait(0.02)
        humanoid:MoveTo(hrp.Position)
    end
    humanoid.AutoRotate = true
end

-----------------------------------------------------
-- LOGGING & TARGETING MODULES
-----------------------------------------------------
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

local TargetingModule = {}
function TargetingModule.getClosestPlayer()
    local closestPlayer, minDistance = nil, math.huge
    local myPos = HRP.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local targetHrp = player.Character:FindFirstChild("HumanoidRootPart")
            if targetHrp and not player.Character:FindFirstChild(bombName) then
                local distance = (targetHrp.Position - myPos).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    closestPlayer = player
                end
            end
        end
    end
    return closestPlayer
end
function TargetingModule.rotateCharacterTowardsTarget(targetPosition)
    -- Rotation intentionally disabled.
end

-----------------------------------------------------
-- VISUAL MODULE
-----------------------------------------------------
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

-----------------------------------------------------
-- AI NOTIFICATIONS MODULE
-----------------------------------------------------
local AINotificationsModule = {}
function AINotificationsModule.sendNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = duration or 5 })
    end)
end

-----------------------------------------------------
-- LEGACY FRICTION MODULE (FOR REMOVING HITBOX AND OLD ANTI-SLIPPERY)
-----------------------------------------------------
local FrictionModule = {}
do
local originalProps = {}
local SLIPPERY_MATERIALS = {Enum.Material.Ice, Enum.Material.Plastic, Enum.Material.Glass}
function FrictionModule.update()
    local char = LocalPlayer.Character
    if not char then return end
    local HRP = char:FindFirstChild("HumanoidRootPart")
    if not HRP then return end
    for _, partName in pairs({"LeftLeg", "RightLeg", "LeftFoot", "RightFoot"}) do
        local part = char:FindFirstChild(partName)
        if part then
            if not originalProps[part] then
                originalProps[part] = part.CustomPhysicalProperties
            end
            local hasBomb = isHoldingBomb()
            local friction = hasBomb and 8 or customAntiSlipperyFriction
            part.CustomPhysicalProperties = PhysicalProperties.new(friction, 0.3, 0.5)
        end
    end
end
function FrictionModule.restore()
    for part, props in pairs(originalProps) do
        if part and part.Parent then
            part.CustomPhysicalProperties = props
        end
    end
    originalProps = {}
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
local antiSlippery = false
local RemoveHitboxEnabled = false
local AI_AssistanceEnabled = false
local pathfindingSpeed = 16
local lastAIMessageTime = 0
local aiMessageCooldown = 5
local raySpreadAngle = 10
local numRaycasts = 5
local customAntiSlipperyFriction = 0.2    -- Default friction (normal: ~0.2, bomb state: ~0.1)
local customHitboxSize = 0.1

-----------------------------------------------------
-- UPDATE FRICTION EVERY 0.5 SECONDS (Using new module if enabled)
-----------------------------------------------------
task.spawn(function()
    while true do
        if antiSlippery then
            FrictionModule.update()
        end
        wait(0.5)
    end
end)

-----------------------------------------------------
-- VISUAL TARGET MARKER (FOR AUTO PASS)
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
-- MULTIPLE RAYCASTS (LINE-OF-SIGHT CHECKS)
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

local function getClosestPlayer()
    local closestPlayer, shortestDistance = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
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

-----------------------------------------------------
-- AUTO PASS FUNCTION
-----------------------------------------------------
local function autoPassBomb()
    if not AutoPassEnabled then return end
    pcall(function()
        local Bomb = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(bombName)
        if Bomb then
            local BombEvent = Bomb:FindFirstChild("RemoteEvent")
            local closestPlayer = getClosestPlayer()
            local targetHrp = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
            if closestPlayer and closestPlayer.Character then
                local targetPosition = closestPlayer.Character.HumanoidRootPart.Position
                local distance = (targetPosition - LocalPlayer.Character.HumanoidRootPart.Position).magnitude
                if distance <= bombPassDistance then
                    executePrecisionRotation(targetHrp.Position)
                    BombEvent:FireServer(closestPlayer.Character, closestPlayer.Character:FindFirstChild("CollisionPart"))
                    HUMANOID:MoveTo(HRP.Position)
                end
            end
        end
    end)
end

-----------------------------------------------------
-- ORIONLIB MENU CREATION
-----------------------------------------------------
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()
local Window = OrionLib:MakeWindow({
    Name = "Yon Menu - Advanced (Auto Pass Bomb)",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "YonMenu_Advanced",
    ShowIcon = true
})

-- Create Tabs
local AutomatedTab = Window:MakeTab({ Name = "Automated Settings", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local AITab = Window:MakeTab({ Name = "AI Based Settings", Icon = "rbxassetid://7072720870", PremiumOnly = false })
local UITab = Window:MakeTab({ Name = "UI Elements", Icon = "rbxassetid://4483345998", PremiumOnly = false })

-- Automated Settings Tab
AutomatedTab:AddLabel("== Bomb Passing ==", 15)
local orionAutoPassToggle = AutomatedTab:AddToggle({
    Name = "Auto Pass Bomb",
    Default = AutoPassEnabled,
    Flag = "AutoPassBomb",
    Callback = function(value)
        AutoPassEnabled = value
        if value then
            if not autoPassConnection then
                autoPassConnection = RunService.Stepped:Connect(autoPassBomb)
            end
        else
            if autoPassConnection then
                autoPassConnection:Disconnect()
                autoPassConnection = nil
            end
            removeTargetMarker()
        end
        if autoPassMobileToggle and autoPassMobileToggle.Set then
            autoPassMobileToggle:Set(value)
        end
    end
})

AutomatedTab:AddLabel("== Character Settings ==", 15)
AutomatedTab:AddToggle({
    Name = "Anti-Slippery",
    Info = "Uses custom friction value (normal: ~0.2, bomb state: ~0.1)",
    Default = false,
    Callback = function(v)
       antiSlippery = v
       if not v then FrictionModule.restore() end
    end
})
AutomatedTab:AddTextbox({
    Name = "Custom Anti‑Slippery Friction",
    Default = tostring(customAntiSlipperyFriction),
    Flag = "CustomAntiSlipperyFrict",
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            customAntiSlipperyFriction = num
            print("Custom Anti-Slippery Friction updated to: " .. num)
        end
    end
})
AutomatedTab:AddToggle({
    Name = "Remove Hitbox",
    Default = RemoveHitboxEnabled,
    Flag = "RemoveHitbox",
    Callback = function(value)
        RemoveHitboxEnabled = value
        applyRemoveHitbox(value)
    end
})
AutomatedTab:AddTextbox({
    Name = "Custom Hitbox Size",
    Default = tostring(customHitboxSize),
    Flag = "CustomHitboxSize",
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then
            customHitboxSize = num
            print("Custom Hitbox Size updated to: " .. num)
            if RemoveHitboxEnabled then applyRemoveHitbox(true) end
        end
    end
})

-- AI Based Settings Tab
AITab:AddLabel("== Targeting Settings ==", 15)
AITab:AddToggle({
    Name = "AI Assistance",
    Default = false,
    Flag = "AIAssistance",
    Callback = function(value)
        AI_AssistanceEnabled = value
    end
})
AITab:AddTextbox({
    Name = "Bomb Pass Distance",
    Default = tostring(bombPassDistance),
    Flag = "BombPassDistance",
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then bombPassDistance = num end
    end
})
AITab:AddTextbox({
    Name = "Ray Spread Angle",
    Default = tostring(raySpreadAngle),
    Flag = "RaySpreadAngle",
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then raySpreadAngle = num end
    end
})
AITab:AddTextbox({
    Name = "Number of Raycasts",
    Default = tostring(numRaycasts),
    Flag = "NumberOfRaycasts",
    TextDisappear = false,
    Callback = function(value)
        local num = tonumber(value)
        if num then numRaycasts = num end
    end
})
AITab:AddLabel("== Rotation Settings ==", 15)
local orionFlickRotationToggle = AITab:AddToggle({
    Name = "Flick Rotation",
    Default = false,
    Flag = "FlickRotation",
    Callback = function(value)
        useFlickRotation = value
        if value then
            useSmoothRotation = false
            if orionSmoothRotationToggle and orionSmoothRotationToggle.Set then
                orionSmoothRotationToggle:Set(false)
            end
        else
            if not useSmoothRotation then
                useSmoothRotation = true
                if orionSmoothRotationToggle and orionSmoothRotationToggle.Set then
                    orionSmoothRotationToggle:Set(true)
                end
            end
        end
    end
})
local orionSmoothRotationToggle = AITab:AddToggle({
    Name = "Smooth Rotation",
    Default = true,
    Flag = "SmoothRotation",
    Callback = function(value)
        useSmoothRotation = value
        if value then
            useFlickRotation = false
            if orionFlickRotationToggle and orionFlickRotationToggle.Set then
                orionFlickRotationToggle:Set(false)
            end
        else
            if not useFlickRotation then
                useFlickRotation = true
                if orionFlickRotationToggle and orionFlickRotationToggle.Set then
                    orionFlickRotationToggle:Set(true)
                end
            end
        end
    end
})

-- UI Elements Tab
UITab:AddColorpicker({
    Name = "Menu Main Color",
    Default = Color3.fromRGB(255,0,0),
    Flag = "MenuMainColor",
    Save = true,
    Callback = function(color)
        OrionLib.Themes[OrionLib.SelectedTheme].Main = color
    end
})

-----------------------------------------------------
-- INITIALIZE ORIONLIB
-----------------------------------------------------
OrionLib:Init()

-----------------------------------------------------
-- MOBILE TOGGLE BUTTON FOR AUTO PASS (Synchronized with menu)
-----------------------------------------------------
local autoPassMobileToggle = nil
local function createMobileToggle()
    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "MobileToggleGui"
    mobileGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local button = Instance.new("TextButton")
    button.Name = "AutoPassMobileToggle"
    button.Size = UDim2.new(0,50,0,50)
    button.Position = UDim2.new(1,-70,1,-110)
    button.BackgroundColor3 = Color3.fromRGB(255,0,0)
    button.Text = "OFF"
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
            if orionAutoPassToggle and orionAutoPassToggle.Set then
                orionAutoPassToggle:Set(true)
            end
            if not autoPassConnection then
                autoPassConnection = RunService.Stepped:Connect(autoPassBomb)
            end
        else
            button.BackgroundColor3 = Color3.fromRGB(255,0,0)
            button.Text = "OFF"
            if orionAutoPassToggle and orionAutoPassToggle.Set then
                orionAutoPassToggle:Set(false)
            end
            if autoPassConnection then
                autoPassConnection:Disconnect()
                autoPassConnection = nil
            end
        end
    end)
    
    return mobileGui, button
end

local mobileGui, mobileToggle = createMobileToggle()
autoPassMobileToggle = mobileToggle

LocalPlayer:WaitForChild("PlayerGui").ChildRemoved:Connect(function(child)
    if child.Name == "MobileToggleGui" then
        wait(1)
        if not LocalPlayer.PlayerGui:FindFirstChild("MobileToggleGui") then
            mobileGui, mobileToggle = createMobileToggle()
            autoPassMobileToggle = mobileToggle
        end
    end
end)

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

local SL_MaxLength = 900000
local SL_EnabledOffset = CFrame.new(1.7,0,0)
local SL_DisabledOffset = CFrame.new(-1.7,0,0)
local SL_Active = nil

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
                    Workspace.CurrentCamera.CFrame.LookVector.Z * SL_MaxLength))
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

local ShiftLockAction = ContextActionService:BindAction("Shift Lock", function(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        ShiftLockButton.MouseButton1Click:Fire()
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonR2)
ContextActionService:SetPosition("Shift Lock", UDim2.new(0.8,0,0.8,0))

-----------------------------------------------------
-- INITIALIZE ENHANCED ANTI‑SLIPPERY SYSTEM
-----------------------------------------------------
local myFrictionController = FrictionController.new()
myFrictionController:enable()

-----------------------------------------------------
-- FINAL NOTIFICATION
-----------------------------------------------------
print("Final Ultra-Advanced Bomb AI & Anti‑Slippery system loaded. Menu, toggles (synchronized), shiftlock, friction updates, and bomb passing are active.")
return {}