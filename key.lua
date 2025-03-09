--// Ultra Advanced AI-Driven Bomb Passing Assistant Script for "Pass the Bomb"
--// Fully Automatic Mode with separate toggles for AI Auto Pass, Manual Auto Pass, Auto Dodge, and Anti Slippery.
--// This version does NOT auto-teleport you if you fall off the map.

-----------------------------------------------------
-- SERVICES
-----------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-----------------------------------------------------
-- LOCAL PLAYER SETUP
-----------------------------------------------------
local CHAR = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HUMANOID = CHAR:WaitForChild("Humanoid")
local HRP = CHAR:WaitForChild("HumanoidRootPart")

-----------------------------------------------------
-- CONFIGURATION VARIABLES
-----------------------------------------------------
local PASS_DISTANCE = 15           -- Maximum range for passing the bomb
local DODGE_DISTANCE = 12          -- Distance to trigger dodge
local DODGE_COOLDOWN = 1.5         -- Time between dodge maneuvers
local THREAT_CHECK_INTERVAL = 0.1  -- Seconds between threat scans
local PASS_CHECK_INTERVAL = 0.2    -- Seconds between target reevaluations
local MAX_PREDICTION_TIME = 0.5    -- Prediction time for target movement
local BEZIER_RESOLUTION = 20       -- Points on predicted pass path

-- AI decision thresholds (menu adjustable)
local AI_DodgeThreshold = 0.5      -- Dot product threshold to trigger dodge
local AI_PassDistanceThreshold = 5 -- If target is closer than this, pass immediately

local INITIAL_BOMB_TIMER = 15      -- Bomb timer countdown

-----------------------------------------------------
-- TOGGLE VARIABLES (Set via OrionLib Menu)
-----------------------------------------------------
local AIAutoPassEnabled = true     -- AI Auto Pass enabled
local ManualAutoPassEnabled = false-- Manual Auto Pass toggle (separate)
local AutoDodgeEnabled = true      -- Auto Dodge enabled
local AntiSlipperyEnabled = false  -- When enabled with AI Auto Pass, friction is forced normal

-----------------------------------------------------
-- OTHER VARIABLES
-----------------------------------------------------
local pathfindingSpeed = 16
local lastAIMessageTime = 0
local aiMessageCooldown = 5

local raySpreadAngle = 10          -- for line-of-sight raycasts
local numRaycasts = 3

-----------------------------------------------------
-- PERSISTENT LEARNING STORAGE
-----------------------------------------------------
local playerStats = {}  -- keyed by UserId

-----------------------------------------------------
-- HUD UI ELEMENTS
-----------------------------------------------------
local screenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
screenGui.Name = "BombAI_HUD"

local timerLabel = Instance.new("TextLabel", screenGui)
timerLabel.Size = UDim2.new(0,200,0,50)
timerLabel.Position = UDim2.new(0.5, -100, 0.1, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.TextScaled = true
timerLabel.Font = Enum.Font.SourceSansBold
timerLabel.TextColor3 = Color3.new(0,1,0)
timerLabel.Visible = false

local targetHighlight = Instance.new("Highlight", Workspace)
targetHighlight.Enabled = false
targetHighlight.FillColor = Color3.new(0,1,0)
targetHighlight.OutlineColor = Color3.new(0,1,0)
targetHighlight.FillTransparency = 1
targetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

local warningLabel = Instance.new("TextLabel", screenGui)
warningLabel.Size = UDim2.new(0,300,0,50)
warningLabel.Position = UDim2.new(0.5, -150, 0.2, 0)
warningLabel.BackgroundTransparency = 0.5
warningLabel.BackgroundColor3 = Color3.new(1,0,0)
warningLabel.TextScaled = true
warningLabel.Font = Enum.Font.ArialBold
warningLabel.TextColor3 = Color3.new(1,1,1)
warningLabel.Text = ">> INCOMING BOMB <<"
warningLabel.Visible = false

local dodgeArrow = Instance.new("BillboardGui", screenGui)
dodgeArrow.Name = "DodgeArrow"
dodgeArrow.Size = UDim2.new(0,50,0,50)
dodgeArrow.StudsOffset = Vector3.new(0,3,0)
dodgeArrow.AlwaysOnTop = true
dodgeArrow.Enabled = false
local arrowImg = Instance.new("ImageLabel", dodgeArrow)
arrowImg.Size = UDim2.new(1,0,1,0)
arrowImg.BackgroundTransparency = 1
arrowImg.Image = "rbxassetid://12345678"  -- Replace with your arrow asset ID
arrowImg.ImageColor3 = Color3.new(1,1,0)

local bezierPathGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
bezierPathGui.Name = "PassPathViz"
local pathFrame = Instance.new("Frame", bezierPathGui)
pathFrame.BackgroundTransparency = 1
pathFrame.Size = UDim2.new(1,0,1,0)

-----------------------------------------------------
-- STATE VARIABLES
-----------------------------------------------------
local hasBomb = false
local currentBomb = nil
local currentTarget = nil
local bombTimer = 0

-----------------------------------------------------
-- UTILITY FUNCTIONS
-----------------------------------------------------
local function getDistSq(pos1, pos2)
    local dx = pos1.X - pos2.X
    local dy = pos1.Y - pos2.Y
    local dz = pos1.Z - pos2.Z
    return dx*dx + dy*dy + dz*dz
end

local function predictPosition(player, deltaTime)
    if not player.Character then return nil end
    local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not rootPart or not humanoid then return rootPart and rootPart.Position or nil end
    local pos = rootPart.Position
    local moveDir = humanoid.MoveDirection
    local speed = rootPart.Velocity.Magnitude
    return pos + (moveDir * speed * deltaTime)
end

local function hasLineOfSight(origin, targetPosition)
    local direction = targetPosition - origin
    local rayResult = Workspace:Raycast(origin, direction)
    if not rayResult then
        return true
    end
    if (rayResult.Position - origin).Magnitude >= direction.Magnitude - 1e-3 then
        return true
    end
    return false
end

local function getQuadraticBezierPoint(p0, p1, p2, t)
    local a = p0:Lerp(p1, t)
    local b = p1:Lerp(p2, t)
    return a:Lerp(b, t)
end

local function drawPassPath(startPos, controlPos, endPos)
    for _, child in pairs(pathFrame:GetChildren()) do child:Destroy() end
    for i = 0, BEZIER_RESOLUTION do
        local t = i / BEZIER_RESOLUTION
        local point = getQuadraticBezierPoint(startPos, controlPos, endPos, t)
        local dot = Instance.new("Frame", pathFrame)
        dot.BackgroundColor3 = Color3.new(0,1,0)
        dot.BorderSizePixel = 0
        dot.Size = UDim2.new(0, 5, 0, 5)
        local screenPoint, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(point)
        if onScreen then
            dot.Position = UDim2.new(0, screenPoint.X, 0, screenPoint.Y)
        end
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        game:GetService("Debris"):AddItem(dot, 1)
    end
end

-----------------------------------------------------
-- TARGET SELECTION & BOMB PASSING FUNCTIONS
-----------------------------------------------------
local function selectBestTarget()
    local bestTarget = nil
    local bestScore = math.huge  -- using distance as score (lower is better)
    local myPos = HRP.Position

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            if player.Character:FindFirstChild("Bomb") or player.Character:FindFirstChild("BombTool") then
                continue
            end
            local targetPos = player.Character.HumanoidRootPart.Position
            local distance = (targetPos - myPos).Magnitude
            if distance < PASS_DISTANCE and distance < bestScore then
                bestScore = distance
                bestTarget = player
            end
        end
    end
    return bestTarget
end

local function passBombTo(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return end
    print("[AI] Passing bomb to:", targetPlayer.Name)
    local bombEvent = currentBomb and currentBomb:FindFirstChild("RemoteEvent")
    if bombEvent then
        bombEvent:FireServer(targetPlayer.Character, targetPlayer.Character:FindFirstChild("HumanoidRootPart"))
    else
        currentBomb.Parent = targetPlayer.Character
    end
end

-----------------------------------------------------
-- DYNAMIC FRICTION OVERRIDE FOR AI AUTO PASS
-----------------------------------------------------
local function updateFrictionForAIAutoPass()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local newProps = PhysicalProperties.new(0.5, 0.3, 0.5)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CustomPhysicalProperties = newProps
        end
    end
end

-----------------------------------------------------
-- AUTO DODGE FUNCTION
-----------------------------------------------------
local function performFakeDodge()
    HUMANOID:Move(Vector3.new(0,0,0), false)
    wait(0.1)
end

local function performDodge(fromPlayer)
    if not fromPlayer or not fromPlayer.Character then return end
    if not HUMANOID or not HRP then return end
    local fromRoot = fromPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not fromRoot then return end
    local directionVec = HRP.Position - fromRoot.Position
    directionVec = Vector3.new(directionVec.X, 0, directionVec.Z)
    if directionVec.Magnitude == 0 then return end
    directionVec = directionVec.Unit
    local perpendicular = Vector3.new(-directionVec.Z, 0, directionVec.X)
    if math.random() < 0.5 then
        perpendicular = perpendicular * -1
    end
    performFakeDodge()
    HUMANOID:Move(perpendicular * 10, false)
    if math.random() < 0.5 then HUMANOID.Jump = true end
    warningLabel.Visible = false
    local uid = fromPlayer.UserId
    if uid then
        playerStats[uid] = playerStats[uid] or {}
        playerStats[uid].dodgeActions = playerStats[uid].dodgeActions or {total = 0, successful = 0}
        playerStats[uid].dodgeActions.total = playerStats[uid].dodgeActions.total + 1
    end
    lastDodgeTime = tick()
    local arrowAngle = math.deg(math.atan2(perpendicular.Z, perpendicular.X))
    arrowImg.Rotation = arrowAngle
    dodgeArrow.Enabled = true
    delay(0.5, function() dodgeArrow.Enabled = false end)
end

-----------------------------------------------------
-- AUTO PASS LOOP (AI Auto Pass)
-----------------------------------------------------
coroutine.wrap(function()
    while true do
        if AIAutoPassEnabled and hasBomb and currentBomb and currentBomb.Parent == CHAR then
            updateFrictionForAIAutoPass()  -- Set friction to normal when AI auto pass is on
            local target = selectBestTarget()
            if target then
                createOrUpdateTargetMarker(target, (target.Character.HumanoidRootPart.Position - HRP.Position).Magnitude)
                local startPos = HRP.Position
                local controlPos = startPos + (target.Character.HumanoidRootPart.Position - startPos)*0.5 + Vector3.new(0,10,0)
                local endPos = target.Character.HumanoidRootPart.Position
                if _G.ShowPassPath then
                    drawPassPath(startPos, controlPos, endPos)
                end
                if (HRP.Position - target.Character.HumanoidRootPart.Position).Magnitude < AI_PassDistanceThreshold or bombTimer < 2 then
                    passBombTo(target)
                end
            else
                removeTargetMarker()
            end
        end
        wait(PASS_CHECK_INTERVAL)
    end
end)()

-----------------------------------------------------
-- AUTO DODGE LOOP
-----------------------------------------------------
coroutine.wrap(function()
    while true do
        if AutoDodgeEnabled and not hasBomb then
            local closestThreat = nil
            local closestDist = math.huge
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    if player.Character:FindFirstChild("Bomb") or player.Character:FindFirstChild("BombTool") then
                        local dist = (player.Character.HumanoidRootPart.Position - HRP.Position).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            closestThreat = player
                        end
                    end
                end
            end
            if closestThreat and closestDist <= DODGE_DISTANCE then
                local threatHum = closestThreat.Character:FindFirstChild("Humanoid")
                local threatHRP = closestThreat.Character:FindFirstChild("HumanoidRootPart")
                if threatHum and threatHRP then
                    local threatDir = threatHum.MoveDirection
                    local toMe = (HRP.Position - threatHRP.Position).Unit
                    local approachRate = threatDir:Dot(toMe)
                    if approachRate > AI_DodgeThreshold and tick() - lastDodgeTime > DODGE_COOLDOWN then
                        warningLabel.Visible = true
                        performDodge(closestThreat)
                    end
                end
            else
                warningLabel.Visible = false
            end
        else
            warningLabel.Visible = false
        end
        wait(THREAT_CHECK_INTERVAL)
    end
end)()

-----------------------------------------------------
-- EVENT: BOMB POSSESSION DETECTION
-----------------------------------------------------
CHAR.ChildAdded:Connect(function(child)
    if child.Name:lower():find("bomb") then
        hasBomb = true
        currentBomb = child
        bombTimer = INITIAL_BOMB_TIMER
        timerLabel.Visible = true
        timerLabel.TextColor3 = Color3.new(0,1,0)
    end
end)

CHAR.ChildRemoved:Connect(function(child)
    if child == currentBomb then
        hasBomb = false
        currentBomb = nil
        currentTarget = nil
        timerLabel.Visible = false
        targetHighlight.Enabled = false
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if hasBomb and bombTimer > 0 then
        bombTimer = bombTimer - dt
        if bombTimer < 0 then bombTimer = 0 end
    end
end)

-----------------------------------------------------
-- ORIONLIB MENU INTEGRATION
-----------------------------------------------------
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()
local Window = OrionLib:MakeWindow({
    Name = "Yon Menu - Ultra Advanced Bomb AI",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "YonMenu_UltraAdvanced",
    ShowIcon = true
})

local AutomatedTab = Window:MakeTab({
    Name = "Automated",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

local AITab = Window:MakeTab({
    Name = "AI Settings",
    Icon = "rbxassetid://7072720870",
    PremiumOnly = false
})

local VisualTab = Window:MakeTab({
    Name = "Visuals",
    Icon = "rbxassetid://12345678",  -- Replace if needed
    PremiumOnly = false
})

AITab:AddToggle({
    Name = "Enable AI Auto Pass",
    Default = true,
    Callback = function(value)
        AIAutoPassEnabled = value
    end
})

AITab:AddToggle({
    Name = "Enable Manual Auto Pass",
    Default = false,
    Callback = function(value)
        ManualAutoPassEnabled = value
    end
})

AITab:AddToggle({
    Name = "Enable Auto Dodge",
    Default = true,
    Callback = function(value)
        AutoDodgeEnabled = value
    end
})

AITab:AddToggle({
    Name = "Enable Anti Slippery (AI Auto Pass)",
    Default = false,
    Callback = function(value)
        AntiSlipperyEnabled = value
    end
})

AITab:AddSlider({
    Name = "Bomb Pass Distance",
    Min = 5,
    Max = 30,
    Default = PASS_DISTANCE,
    Increment = 1,
    Callback = function(value)
        PASS_DISTANCE = value
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

VisualTab:AddToggle({
    Name = "Show Predicted Pass Path",
    Default = true,
    Callback = function(value)
        _G.ShowPassPath = value
    end
})

VisualTab:AddSlider({
    Name = "Bezier Resolution",
    Min = 10,
    Max = 50,
    Default = BEZIER_RESOLUTION,
    Increment = 1,
    Callback = function(value)
        BEZIER_RESOLUTION = value
    end
})

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
        if AIAutoPassEnabled then
            updateFrictionForAIAutoPass()
        else
            FrictionModule.updateSlidingProperties(AntiSlipperyEnabled)
        end
        task.wait(0.1)
    end
end)

-----------------------------------------------------
-- INITIALIZE ORIONLIB UI
-----------------------------------------------------
OrionLib:Init()
print("Yon Menu Script Loaded with Ultra Advanced Bomb AI (Auto Pass, Auto Dodge, ShiftLock, Mobile Toggle)")

-----------------------------------------------------
-- MOBILE TOGGLE GUI (for Manual Auto Pass)
-----------------------------------------------------
local function createMobileToggle()
    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "MobileToggleGui"
    mobileGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local autoPassMobileToggle = Instance.new("TextButton")
    autoPassMobileToggle.Name = "AutoPassMobileToggle"
    autoPassMobileToggle.Size = UDim2.new(0, 50, 0, 50)
    autoPassMobileToggle.Position = UDim2.new(1, -70, 1, -110)
    autoPassMobileToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    autoPassMobileToggle.Text = "MANUAL OFF"
    autoPassMobileToggle.TextScaled = true
    autoPassMobileToggle.Font = Enum.Font.SourceSansBold
    autoPassMobileToggle.ZIndex = 100
    autoPassMobileToggle.Parent = mobileGui

    local uicorner = Instance.new("UICorner")
    uicorner.CornerRadius = UDim.new(1, 0)
    uicorner.Parent = autoPassMobileToggle

    autoPassMobileToggle.MouseButton1Click:Connect(function()
        ManualAutoPassEnabled = not ManualAutoPassEnabled
        if ManualAutoPassEnabled then
            autoPassMobileToggle.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
            autoPassMobileToggle.Text = "MANUAL ON"
        else
            autoPassMobileToggle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            autoPassMobileToggle.Text = "MANUAL OFF"
        end
    end)
    
    return mobileGui, autoPassMobileToggle
end

local mobileGui, autoPassMobileToggle = createMobileToggle()
LocalPlayer:WaitForChild("PlayerGui").ChildRemoved:Connect(function(child)
    if child.Name == "MobileToggleGui" then
        wait(1)
        if not LocalPlayer.PlayerGui:FindFirstChild("MobileToggleGui") then
            mobileGui, autoPassMobileToggle = createMobileToggle()
            print("Recreated mobile toggle GUI")
        end
    end
end)

-----------------------------------------------------
-- SHIFTLOCK CODE (CoreGui-based)
-----------------------------------------------------
local ShiftLockScreenGui = Instance.new("ScreenGui")
local ShiftLockButton = Instance.new("ImageButton")
local ShiftlockCursor = Instance.new("ImageLabel")
local CoreGui = game:GetService("CoreGui")
local ShiftStates = {
    Off = "rbxasset://textures/ui/mouseLock_off@2x.png",
    On = "rbxasset://textures/ui/mouseLock_on@2x.png",
    Lock = "rbxasset://textures/MouseLockedCursor.png",
    Lock2 = "rbxasset://SystemCursors/Cross"
}
local SL_MaxLength = 900000
local SL_EnabledOffset = CFrame.new(1.7, 0, 0)
local SL_DisabledOffset = CFrame.new(-1.7, 0, 0)
local SL_Active

ShiftLockScreenGui.Name = "Shiftlock (CoreGui)"
ShiftLockScreenGui.Parent = CoreGui
ShiftLockScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ShiftLockScreenGui.ResetOnSpawn = false

ShiftLockButton.Parent = ShiftLockScreenGui
ShiftLockButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ShiftLockButton.BackgroundTransparency = 1
ShiftLockButton.Position = UDim2.new(0.7, 0, 0.75, 0)
ShiftLockButton.Size = UDim2.new(0.0636, 0, 0.06613, 0)
ShiftLockButton.SizeConstraint = Enum.SizeConstraint.RelativeXX
ShiftLockButton.Image = ShiftStates.Off

ShiftlockCursor.Name = "Shiftlock Cursor"
ShiftlockCursor.Parent = ShiftLockScreenGui
ShiftlockCursor.Image = ShiftStates.Lock
ShiftlockCursor.Size = UDim2.new(0.03, 0, 0.03, 0)
ShiftlockCursor.Position = UDim2.new(0.5, 0, 0.5, 0)
ShiftlockCursor.AnchorPoint = Vector2.new(0.5, 0.5)
ShiftlockCursor.SizeConstraint = Enum.SizeConstraint.RelativeXX
ShiftlockCursor.BackgroundTransparency = 1
ShiftlockCursor.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
ShiftlockCursor.Visible = false

ShiftLockButton.MouseButton1Click:Connect(function()
    if not SL_Active then
        SL_Active = RunService.RenderStepped:Connect(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChild("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if hum and root then
                hum.AutoRotate = false
                ShiftLockButton.Image = ShiftStates.On
                ShiftlockCursor.Visible = true
                root.CFrame = CFrame.new(
                    root.Position,
                    Vector3.new(
                        Workspace.CurrentCamera.CFrame.LookVector.X * SL_MaxLength,
                        root.Position.Y,
                        Workspace.CurrentCamera.CFrame.LookVector.Z * SL_MaxLength
                    )
                )
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
        ShiftLockButton.Image = ShiftStates.Off
        Workspace.CurrentCamera.CFrame = Workspace.CurrentCamera.CFrame * SL_DisabledOffset
        ShiftlockCursor.Visible = false
        pcall(function()
            SL_Active:Disconnect()
            SL_Active = nil
        end)
    end
end)

local ShiftLockAction = ContextActionService:BindAction("Shift Lock", function(actionName, inputState, inputObject)
    if inputState == Enum.UserInputState.Begin then
        ShiftLockButton.MouseButton1Click:Fire()
    end
    return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonR2)
ContextActionService:SetPosition("Shift Lock", UDim2.new(0.8, 0, 0.8, 0))

-----------------------------------------------------
-- FINAL INITIALIZATION
-----------------------------------------------------
print("Ultra Advanced Bomb Passing AI Loaded with AI Auto Pass, Manual Auto Pass, Auto Dodge, and ShiftLock")
return {}