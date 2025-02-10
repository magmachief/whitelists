--// Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

--// Variables
local bombPassDistance = 10
local AutoPassEnabled = false
local AntiSlipperyEnabled = false
local RemoveHitboxEnabled = false
local autoPassConnection = nil
local pathfindingSpeed = 16 -- Default speed

-- UI Themes
local uiThemes = {
    ["Dark"] = { Background = Color3.new(0, 0, 0), Text = Color3.new(1, 1, 1) },
    ["Light"] = { Background = Color3.new(1, 1, 1), Text = Color3.new(0, 0, 0) },
    ["Red"] = { Background = Color3.new(1, 0, 0), Text = Color3.new(1, 1, 1) },
}

--========================--
--    UTILITY FUNCTIONS   --
--========================--

-- Function to get the closest player
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

-- Advanced rotation function with continuous tracking, velocity prediction, adaptive speed, and visual feedback.
local function advancedRotateCharacterTowardsTarget(targetPlayer, duration)
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local targetCharacter = targetPlayer.Character
    if not targetCharacter then return end
    local targetHRP = targetCharacter:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    -- Create visual reticle on target
    local reticle = Instance.new("BillboardGui")
    reticle.Size = UDim2.new(0, 50, 0, 50)
    reticle.Adornee = targetHRP
    reticle.AlwaysOnTop = true
    reticle.Parent = targetHRP

    local reticleLabel = Instance.new("TextLabel")
    reticleLabel.Size = UDim2.new(1, 0, 1, 0)
    reticleLabel.BackgroundTransparency = 1
    reticleLabel.Text = "X"
    reticleLabel.TextScaled = true
    reticleLabel.TextColor3 = Color3.new(1, 0, 0)
    reticleLabel.Parent = reticle

    -- Table to store historical positions for averaging velocity
    local positions = {}
    local startTime = tick()
    local lastUpdate = startTime

    while tick() - startTime < duration do
        local now = tick()
        local dt = now - lastUpdate
        lastUpdate = now

        local currentPos = targetHRP.Position
        table.insert(positions, {pos = currentPos, time = now})
        if #positions > 5 then
            table.remove(positions, 1)
        end

        -- Compute average velocity over the stored positions
        local avgVel = Vector3.new(0,0,0)
        if #positions >= 2 then
            local first = positions[1]
            local last = positions[#positions]
            local deltaT = last.time - first.time
            if deltaT > 0 then
                avgVel = (last.pos - first.pos) / deltaT
            end
        end

        -- Predict target position 0.3 seconds ahead
        local predictedPos = currentPos + avgVel * 0.3

        -- Determine desired CFrame to look at the predicted position
        local desiredCFrame = CFrame.new(hrp.Position, predictedPos)
        local currentLook = hrp.CFrame.LookVector
        local desiredLook = desiredCFrame.LookVector
        local dot = math.clamp(currentLook:Dot(desiredLook), -1, 1)
        local angleDiff = math.acos(dot)
        
        -- Adaptive rotation: faster if angleDiff is small, slower if large.
        local adaptiveFactor = math.clamp(angleDiff / math.pi, 0.1, 0.3)
        
        -- Use Lerp for smooth continuous rotation; update each iteration
        hrp.CFrame = hrp.CFrame:Lerp(desiredCFrame, 0.5 * adaptiveFactor)
        task.wait(0.05)
    end

    reticle:Destroy()
end

-- Auto Pass Bomb Logic with Bomb Pass Distance and Advanced Rotation
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
                    -- Continuously rotate and track the target for 0.5 seconds
                    advancedRotateCharacterTowardsTarget(closestPlayer, 0.5)
                    task.wait(0.6)
                    BombEvent:FireServer(closestPlayer.Character, closestPlayer.Character:FindFirstChild("CollisionPart"))
                end
            end
        end
    end)
end

-- Anti-Slippery: (Working Version)
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

-- Remove Hitbox: Destroy collision parts
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

--========================--
--  APPLY FEATURES ON RESPAWN --
--========================--
LocalPlayer.CharacterAdded:Connect(function()
    if AntiSlipperyEnabled then applyAntiSlippery(true) end
    if RemoveHitboxEnabled then applyRemoveHitbox(true) end
end)

--========================--
--  ORIONLIB INTERFACE    --
--========================--
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
            -- Apply the theme dynamically if desired
        else
            warn("Theme not found:", themeName)
        end
    end
})

OrionLib:Init()
print("Yon Menu Script Loaded with Enhanced Yonkai Menu and Gojo Icon")
