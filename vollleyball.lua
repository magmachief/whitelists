-- Volleyball Legends Auto-Hit & Prediction Script
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Configuration
local Config = {
    AutoHit = true,
    PredictTrajectory = true,
    AutoPosition = true,
    HitRange = 15, -- studs
    JumpPower = 50,
    PredictionTime = 0.5, -- seconds to look ahead
    HitCooldown = 0.3, -- seconds between hits
    HitKey = Enum.KeyCode.E,
    DebugMode = false
}

-- Variables
local ball = nil
local lastHitTime = 0
local predictedPosition = nil
local hitConnection = nil
local ballVelocityHistory = {}
local maxHistorySize = 10
local courtBoundaries = {
    MinX = -50,
    MaxX = 50,
    MinZ = -25,
    MaxZ = 25
}

-- UI Setup
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/shlexware/Orion/main/source"))()
local Window = OrionLib:MakeWindow({
    Name = "Volleyball Legends AI",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "VolleyballAI"
})

-- Functions
local function findBall()
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj.Name:lower():find("ball") or obj.Name:lower():find("volley") then
            return obj
        end
    end
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Part") and (obj.Name:lower():find("ball") or obj.Name:lower():find("volley")) then
            return obj
        end
    end
    return nil
end

local function calculateTrajectory(ballPart, timeAhead)
    if not ballPart or not ballPart:IsA("BasePart") then
        return nil
    end
    
    local position = ballPart.Position
    local velocity = ballPart.Velocity
    
    -- Add current velocity to history
    table.insert(ballVelocityHistory, 1, velocity)
    if #ballVelocityHistory > maxHistorySize then
        table.remove(ballVelocityHistory, maxHistorySize + 1)
    end
    
    -- Calculate average velocity for smoother prediction
    local avgVelocity = Vector3.new(0, 0, 0)
    for _, v in ipairs(ballVelocityHistory) do
        avgVelocity = avgVelocity + v
    end
    avgVelocity = avgVelocity / #ballVelocityHistory
    
    -- Use gravity constant (workspace.Gravity)
    local gravity = Workspace.Gravity
    local time = timeAhead
    
    -- Projectile motion equations
    local predictedX = position.X + avgVelocity.X * time
    local predictedY = position.Y + avgVelocity.Y * time - 0.5 * gravity * time * time
    local predictedZ = position.Z + avgVelocity.Z * time
    
    -- Check if ball will hit ground
    local groundY = 0 -- Adjust based on court height
    if predictedY < groundY then
        predictedY = groundY
        -- Calculate bounce (simplified)
        local bounceFactor = 0.7
        local newTime = time - (-avgVelocity.Y + math.sqrt(avgVelocity.Y^2 + 2 * gravity * position.Y)) / gravity
        if newTime > 0 then
            predictedY = groundY + math.abs(avgVelocity.Y * bounceFactor) * newTime - 0.5 * gravity * newTime * newTime
        end
    end
    
    -- Constrain to court boundaries
    predictedX = math.clamp(predictedX, courtBoundaries.MinX, courtBoundaries.MaxX)
    predictedZ = math.clamp(predictedZ, courtBoundaries.MinZ, courtBoundaries.MaxZ)
    
    return Vector3.new(predictedX, predictedY, predictedZ)
end

local function isBallOnMySide(ballPos)
    -- Assuming court is divided by net at Z=0
    -- My side is negative Z, opponent side is positive Z
    return ballPos.Z <= 0
end

local function getOptimalHitPosition(predictedPos)
    local myPosition = rootPart.Position
    local targetPosition = predictedPos
    
    -- Adjust for better hitting angle
    local netPosition = Vector3.new(0, 5, 0) -- Net at center
    local directionToNet = (netPosition - predictedPos).Unit
    
    -- Move back a bit for better approach
    local approachDistance = 5
    local optimalPosition = predictedPos - directionToNet * approachDistance
    
    -- Ensure we stay on our side
    optimalPosition = Vector3.new(
        math.clamp(optimalPosition.X, courtBoundaries.MinX, courtBoundaries.MaxX),
        optimalPosition.Y,
        math.clamp(optimalPosition.Z, courtBoundaries.MinZ, 0) -- Stay on our side (negative Z)
    )
    
    return optimalPosition
end

local function moveToPosition(targetPos)
    if not Config.AutoPosition or not humanoid then
        return
    end
    
    local distance = (targetPos - rootPart.Position).Magnitude
    if distance > 2 then
        humanoid:MoveTo(targetPos)
    end
end

local function shouldHitBall()
    if not Config.AutoHit then
        return false
    end
    
    if tick() - lastHitTime < Config.HitCooldown then
        return false
    end
    
    if not ball or not ball:IsA("BasePart") then
        return false
    end
    
    local ballPos = ball.Position
    local myPos = rootPart.Position
    local distance = (ballPos - myPos).Magnitude
    
    -- Check if ball is on our side
    if not isBallOnMySide(ballPos) then
        return false
    end
    
    -- Check if ball is within hit range
    if distance > Config.HitRange then
        return false
    end
    
    -- Check if ball is at good height for hitting
    if ballPos.Y < 5 then -- Too low
        return false
    end
    
    return true
end

local function simulateHit()
    if not shouldHitBall() then
        return
    end
    
    -- Calculate hit direction (towards opponent's side)
    local hitDirection = Vector3.new(
        math.random(-10, 10),  -- Some randomness in X
        20,                     -- Upward force
        math.random(15, 30)     -- Forward to opponent side
    )
    
    -- Jump before hitting
    humanoid.JumpPower = Config.JumpPower
    humanoid.Jump = true
    
    -- Simulate hit key press
    wait(0.1) -- Small delay for jump
    game:GetService("VirtualInputManager"):SendKeyEvent(true, Config.HitKey, false, game)
    game:GetService("VirtualInputManager"):SendKeyEvent(false, Config.HitKey, false, game)
    
    lastHitTime = tick()
    
    if Config.DebugMode then
        print("Hit attempted at:", tick())
    end
end

local function createDebugVisual(predictedPos)
    if not Config.DebugMode then
        return
    end
    
    -- Remove old debug parts
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj.Name == "PredictionDebug" then
            obj:Destroy()
        end
    end
    
    -- Create new debug sphere at predicted position
    local sphere = Instance.new("Part")
    sphere.Name = "PredictionDebug"
    sphere.Shape = Enum.PartType.Ball
    sphere.Size = Vector3.new(2, 2, 2)
    sphere.Position = predictedPos
    sphere.Material = Enum.Material.Neon
    sphere.Color = Color3.fromRGB(255, 0, 255)
    sphere.Transparency = 0.5
    sphere.Anchored = true
    sphere.CanCollide = false
    sphere.Parent = Workspace
end

local function drawTrajectory(startPos, predictedPos)
    if not Config.DebugMode then
        return
    end
    
    -- Remove old trajectory
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj.Name == "TrajectoryLine" then
            obj:Destroy()
        end
    end
    
    -- Create trajectory line
    local line = Instance.new("Part")
    line.Name = "TrajectoryLine"
    line.Size = Vector3.new(0.2, 0.2, (startPos - predictedPos).Magnitude)
    line.Position = (startPos + predictedPos) / 2
    line.Orientation = Vector3.new(
        0,
        0,
        math.deg(math.atan2(predictedPos.Y - startPos.Y, (Vector2.new(predictedPos.X, predictedPos.Z) - Vector2.new(startPos.X, startPos.Z)).Magnitude))
    )
    line.Anchored = true
    line.CanCollide = false
    line.Color = Color3.fromRGB(0, 255, 0)
    line.Transparency = 0.3
    line.Parent = Workspace
    
    -- Look at predicted position
    line.CFrame = CFrame.lookAt(line.Position, predictedPos) * CFrame.new(0, 0, -line.Size.Z/2)
end

-- Main loop
local function mainLoop()
    -- Find ball
    ball = findBall()
    
    if ball and Config.PredictTrajectory then
        -- Calculate predicted position
        predictedPosition = calculateTrajectory(ball, Config.PredictionTime)
        
        if predictedPosition then
            -- Create debug visuals
            createDebugVisual(predictedPosition)
            drawTrajectory(ball.Position, predictedPosition)
            
            -- Get optimal position to hit from
            local optimalPos = getOptimalHitPosition(predictedPosition)
            
            -- Move to optimal position
            moveToPosition(optimalPos)
            
            -- Check if we should hit now
            local distanceToBall = (ball.Position - rootPart.Position).Magnitude
            local distanceToOptimal = (optimalPos - rootPart.Position).Magnitude
            
            -- Hit if we're close enough to optimal position
            if distanceToOptimal < 3 and distanceToBall < Config.HitRange then
                simulateHit()
            end
        end
    end
end

-- Initialize UI
local MainTab = Window:MakeTab({
    Name = "Main Controls",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

MainTab:AddToggle({
    Name = "Auto Hit Ball",
    Default = Config.AutoHit,
    Callback = function(value)
        Config.AutoHit = value
    end
})

MainTab:AddToggle({
    Name = "Ball Prediction",
    Default = Config.PredictTrajectory,
    Callback = function(value)
        Config.PredictTrajectory = value
    end
})

MainTab:AddToggle({
    Name = "Auto Positioning",
    Default = Config.AutoPosition,
    Callback = function(value)
        Config.AutoPosition = value
    end
})

MainTab:AddToggle({
    Name = "Debug Mode",
    Default = Config.DebugMode,
    Callback = function(value)
        Config.DebugMode = value
    end
})

MainTab:AddSlider({
    Name = "Hit Range",
    Min = 5,
    Max = 30,
    Default = Config.HitRange,
    Color = Color3.fromRGB(255, 0, 0),
    Increment = 1,
    ValueName = "studs",
    Callback = function(value)
        Config.HitRange = value
    end
})

MainTab:AddSlider({
    Name = "Prediction Time",
    Min = 0.1,
    Max = 2.0,
    Default = Config.PredictionTime,
    Color = Color3.fromRGB(0, 255, 0),
    Increment = 0.1,
    ValueName = "seconds",
    Callback = function(value)
        Config.PredictionTime = value
    end
})

MainTab:AddSlider({
    Name = "Hit Cooldown",
    Min = 0.1,
    Max = 1.0,
    Default = Config.HitCooldown,
    Color = Color3.fromRGB(0, 0, 255),
    Increment = 0.1,
    ValueName = "seconds",
    Callback = function(value)
        Config.HitCooldown = value
    end
})

local VisualTab = Window:MakeTab({
    Name = "Visuals",
    Icon = "rbxassetid://7072720870",
    PremiumOnly = false
})

VisualTab:AddLabel("Ball Tracking")
VisualTab:AddToggle({
    Name = "Show Prediction Point",
    Default = true,
    Callback = function(value)
        -- Toggle debug visuals
    end
})

VisualTab:AddToggle({
    Name = "Show Trajectory Line",
    Default = true,
    Callback = function(value)
        -- Toggle trajectory line
    end
})

VisualTab:AddColorpicker({
    Name = "Prediction Color",
    Default = Color3.fromRGB(255, 0, 255),
    Callback = function(color)
        -- Update debug color
    end
})

-- Hotkeys
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.RightShift then
        Config.AutoHit = not Config.AutoHit
        OrionLib:MakeNotification({
            Name = "Auto-Hit",
            Content = Config.AutoHit and "ENABLED" or "DISABLED",
            Image = "rbxassetid://4483345998",
            Time = 2
        })
    end
    
    if input.KeyCode == Enum.KeyCode.Insert then
        OrionLib:Destroy()
    end
end)

-- Character setup
LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:WaitForChild("HumanoidRootPart")
end)

-- Start main loop
RunService.Heartbeat:Connect(mainLoop)

OrionLib:Init()

-- Mobile GUI (optional)
local function createMobileGUI()
    local mobileGui = Instance.new("ScreenGui")
    mobileGui.Name = "VolleyballMobileUI"
    mobileGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleAutoHit"
    toggleButton.Size = UDim2.new(0, 100, 0, 50)
    toggleButton.Position = UDim2.new(1, -110, 1, -60)
    toggleButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    toggleButton.Text = "Auto: OFF"
    toggleButton.TextScaled = true
    toggleButton.Parent = mobileGui
    
    toggleButton.MouseButton1Click:Connect(function()
        Config.AutoHit = not Config.AutoHit
        toggleButton.Text = "Auto: " .. (Config.AutoHit and "ON" or "OFF")
        toggleButton.BackgroundColor3 = Config.AutoHit and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    end)
end

createMobileGUI()

-- Notify user
OrionLib:MakeNotification({
    Name = "Volleyball AI Loaded",
    Content = "Right Shift: Toggle Auto-Hit\nInsert: Close GUI",
    Image = "rbxassetid://4483345998",
    Time = 5
})

print("Volleyball Legends AI loaded successfully!")
