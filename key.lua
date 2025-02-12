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
-- CONFIGURATION & VARIABLES
-----------------------------------------------------
-- Auto Dodge Bomb configuration
local bombDodgeThreshold = 15         -- If a bomb is within this many studs, initiate dodge
local bombDodgeDistance = 20            -- How far to dodge (in studs)
local AutoDodgeEnabled = false          -- Toggle auto-dodge behavior

-- Auto Pass Bomb configuration
local bombPassDistance = 10             -- Maximum pass distance for bomb passing
local AutoPassEnabled = false           -- Toggle auto-pass bomb behavior

-- Global features and notifications
local AntiSlipperyEnabled = false       -- Toggle anti-slippery feature
local RemoveHitboxEnabled = false       -- Toggle hitbox removal
local AI_AssistanceEnabled = false      -- Toggle AI Assistance notifications
local pathfindingSpeed = 16             -- Used for auto-pass bomb target selection calculations
local lastAIMessageTime = 0
local aiMessageCooldown = 5             -- Seconds between AI notifications

-----------------------------------------------------
-- UI THEMES (for OrionLib)
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
    end
end

-----------------------------------------------------
-- VISUAL TARGET MARKER (for Auto Pass Bomb)
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
-- UTILITY FUNCTIONS FOR AUTO PASS BOMB
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
            if player.Character:FindFirstChild("Bomb") then
                continue
            end
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
            if player.Character:FindFirstChild("Bomb") then
                continue
            end
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
-- AUTO PASS BOMB FUNCTION
-----------------------------------------------------
local function autoPassBomb()
    if not AutoPassEnabled then
        removeTargetMarker()
        return
    end

    pcall(function()
        local bomb = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Bomb")
        if not bomb then
            removeTargetMarker()
            return
        end

        local BombEvent = bomb:FindFirstChild("RemoteEvent")
        local targetPlayer = getOptimalPlayer() or getClosestPlayer()
        if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            if targetPlayer.Character:FindFirstChild("Bomb") then
                removeTargetMarker()
                return
            end

            createOrUpdateTargetMarker(targetPlayer)
            local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
            local myPos = LocalPlayer.Character.HumanoidRootPart.Position
            local distance = (targetPosition - myPos).magnitude
            if distance <= bombPassDistance then
                local targetVelocity = targetPlayer.Character.HumanoidRootPart.Velocity or Vector3.new(0, 0, 0)
                rotateCharacterTowardsTarget(targetPosition, targetVelocity)
                task.wait(0.1)
                if AI_AssistanceEnabled and tick() - lastAIMessageTime >= aiMessageCooldown then
                    pcall(function()
                        StarterGui:SetCore("SendNotification", {
                            Title = "AI Assistance",
                            Text = "Passing bomb safely.",
                            Duration = 5
                        })
                    end)
                    lastAIMessageTime = tick()
                end
                BombEvent:FireServer(targetPlayer.Character, targetPlayer.Character:FindFirstChild("CollisionPart"))
                removeTargetMarker()
            else
                removeTargetMarker()
            end
        else
            removeTargetMarker()
        end
    end)
end

-----------------------------------------------------
-- GROUND CHECK FUNCTION (for dodge)
-----------------------------------------------------
local function isGrounded(position)
    local rayOrigin = position + Vector3.new(0, 5, 0)
    local rayDirection = Vector3.new(0, -50, 0)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    if LocalPlayer.Character then
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end
    local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if result then
        return true, result.Position
    end
    return false, nil
end

-----------------------------------------------------
-- ENHANCED AUTO DODGE BOMBS (SMART AI)
-----------------------------------------------------
local function autoDodgeBombsEnhanced()
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") or not character:FindFirstChild("Humanoid") then
        return
    end
    local hrp = character.HumanoidRootPart
    local humanoid = character.Humanoid
    local myPos = hrp.Position

    local closestBomb = nil
    local closestDistance = math.huge
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj.Name == "Bomb" and obj:IsA("BasePart") and not obj:IsDescendantOf(LocalPlayer.Character) then
            local bombPos = obj.Position
            local distance = (bombPos - myPos).Magnitude
            if distance < closestDistance then
                closestDistance = distance
                closestBomb = obj
            end
        end
    end

    -- Debug print to verify bomb detection (remove once testing is complete)
    if closestBomb then
        print("Detected bomb at distance:", closestDistance)
    end

    if closestBomb and closestDistance < bombDodgeThreshold then
        local bombPos = closestBomb.Position
        local dodgeDirection = (myPos - bombPos).Unit
        local desiredPos = myPos + dodgeDirection * bombDodgeDistance

        -- Ensure the destination is on solid ground (adjust upward if needed)
        local grounded, groundPos = isGrounded(desiredPos)
        if not grounded then
            local attempt = 0
            while not grounded and attempt < 5 do
                desiredPos = Vector3.new(desiredPos.X, desiredPos.Y + 2, desiredPos.Z)
                grounded, groundPos = isGrounded(desiredPos)
                attempt = attempt + 1
            end
            if not grounded then
                return
            end
        end

        local pathParams = {
            AgentRadius = 2,
            AgentHeight = 5,
            AgentCanJump = true,
            AgentJumpHeight = 7,
            AgentMaxSlope = 45
        }
        local path = PathfindingService:CreatePath(pathParams)
        path:ComputeAsync(myPos, desiredPos)
        if path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            for _, waypoint in ipairs(waypoints) do
                humanoid:MoveTo(waypoint.Position)
                local reached = humanoid.MoveToFinished:Wait(2)
                if not reached then
                    break
                end
            end
        else
            local tween = TweenService:Create(hrp, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {CFrame = CFrame.new(desiredPos)})
            tween:Play()
        end

        if AI_AssistanceEnabled and tick() - lastAIMessageTime >= aiMessageCooldown then
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = "AI Assistance",
                    Text = "Dodging bomb safely!",
                    Duration = 5
                })
            end)
            lastAIMessageTime = tick()
        end
    end
end

-----------------------------------------------------
-- ANTI-SLIPPERY
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
-- REMOVE HITBOX
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
-- APPLY FEATURES ON RESPAWN
-----------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function(char)
    applyAntiSlippery(AntiSlipperyEnabled)
    applyRemoveHitbox(RemoveHitboxEnabled)
end)

-----------------------------------------------------
-- ORIONLIB INTERFACE
-----------------------------------------------------
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()
local Window = OrionLib:MakeWindow({
    Name = "Yon Menu - Advanced (Auto Dodge & Pass Bomb)",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "YonMenu_Advanced"
})

-- Create two tabs: one for automated features and one for AI-based settings.
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

local autoDodgeConnection
local autoPassConnection

-- Automated features go in the Automated tab.
AutomatedTab:AddToggle({
    Name = "Auto Dodge Bombs (Enhanced)",
    Default = AutoDodgeEnabled,
    Callback = function(value)
        AutoDodgeEnabled = value
        if AutoDodgeEnabled then
            autoDodgeConnection = RunService.Stepped:Connect(autoDodgeBombsEnhanced)
        else
            if autoDodgeConnection then
                autoDodgeConnection:Disconnect()
                autoDodgeConnection = nil
            end
        end
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
            removeTargetMarker()
        end
    end
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

-- AI-based settings go in the AI Based tab.
AITab:AddToggle({
    Name = "AI Assistance",
    Default = false,
    Callback = function(value)
        AI_AssistanceEnabled = value
        if AI_AssistanceEnabled then
            print("AI Assistance enabled.")
        else
            print("AI Assistance disabled.")
        end
    end
})

AITab:AddSlider({
    Name = "Bomb Dodge Threshold",
    Min = 5,
    Max = 30,
    Default = bombDodgeThreshold,
    Increment = 1,
    Callback = function(value)
        bombDodgeThreshold = value
    end
})

AITab:AddSlider({
    Name = "Bomb Dodge Distance",
    Min = 10,
    Max = 50,
    Default = bombDodgeDistance,
    Increment = 1,
    Callback = function(value)
        bombDodgeDistance = value
    end
})

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

OrionLib:Init()
print("Yon Menu Script Loaded with Enhanced AI Smart Auto Dodge Bombs & Auto Pass Bomb, Anti Slippery, Remove Hitbox, UI Theme Support, and AI Assistance")
