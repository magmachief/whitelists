-----------------------------------------------------
-- SERVICES
-----------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-----------------------------------------------------
-- CONFIGURATION & VARIABLES
-----------------------------------------------------
local defaultBombTimer = 20       -- Default bomb timer (in seconds)
local bombPassDistance = 10         -- Maximum pass distance (for both auto-pass modes)
local AutoPassEnabled = false       -- Toggle auto-pass behavior
local AntiSlipperyEnabled = false   -- Toggle anti-slippery feature
local RemoveHitboxEnabled = false   -- Toggle hitbox removal
local pathfindingSpeed = 16         -- For potential future use

local lowTimerThreshold = 2         -- When remaining time is <= 2 seconds, warn

-- New toggle: Choose between Optimal Auto Pass (true) or Normal Auto Pass (false)
local UseOptimalAutoPass = true

-- Global bomb tracking variables
local bombObject = nil            -- Reference to the current bomb object
local bombStartTime = nil         -- When the current bomb timer started
local globalBombTime = defaultBombTimer  -- Global remaining time (adjusted by our AI)
local lastBombPassTime = nil      -- When the bomb was last passed
local isHoldingBomb = false       -- True if LocalPlayer currently holds the bomb

-- Table to store bomb pass data (for AI prediction)
local bombPassData = {}
local maxBombPassDataEntries = 10  -- Maximum bomb pass records for AI prediction

-- A table to hold bomb timer UIs by character (keyed by character)
local bombTimerUI = {}

-- AI prediction variables (Exponential Moving Average)
local emaBombTimer = defaultBombTimer  -- Our adaptive bomb timer value
local alpha = 0.3                      -- Smoothing factor (0 < alpha < 1)

-----------------------------------------------------
-- UI THEMES
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

-- Function to update OrionLib's theme.
-- (This is a sample implementation. Replace it with your OrionLib's built-in method if available.)
local function changeUITheme(theme)
    -- For example, if OrionLib supported dynamic theme changing:
    if OrionLib.ChangeTheme then
        OrionLib:ChangeTheme(theme)
    else
        -- Otherwise, you might update some global configuration.
        OrionLib.Config = OrionLib.Config or {}
        OrionLib.Config.MainColor = theme.MainColor
        OrionLib.Config.AccentColor = theme.AccentColor
        OrionLib.Config.TextColor = theme.TextColor
        print("Theme changed to:", theme)
    end
end

-----------------------------------------------------
-- VISUAL TARGET MARKER (RED "X") FOR AUTO-PASS
-----------------------------------------------------
local currentTargetMarker = nil
local currentTargetPlayer = nil

-- Now attaches the marker to the target's body (HumanoidRootPart) instead of the head.
local function createOrUpdateTargetMarker(player)
    if not player or not player.Character then return end
    local body = player.Character:FindFirstChild("HumanoidRootPart")
    if not body then return end

    -- If the marker already exists on this player, do nothing.
    if currentTargetMarker and currentTargetPlayer == player then
        return
    end

    -- Remove any previous marker if the target has changed.
    if currentTargetMarker then
        currentTargetMarker:Destroy()
        currentTargetMarker = nil
        currentTargetPlayer = nil
    end

    local marker = Instance.new("BillboardGui")
    marker.Name = "BombPassTargetMarker"
    marker.Adornee = body  -- Attach to the target's body
    marker.Size = UDim2.new(0, 50, 0, 50)
    marker.StudsOffset = Vector3.new(0, 3, 0)
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
-- UTILITY FUNCTIONS
-----------------------------------------------------

-- Normal auto-pass: Returns the closest player (within bombPassDistance).
local function getClosestPlayer()
    local closestPlayer = nil
    local shortestDistance = math.huge
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = player.Character.HumanoidRootPart.Position
            local distance = (targetPos - myPos).magnitude
            if distance < shortestDistance and distance <= bombPassDistance then
                shortestDistance = distance
                closestPlayer = player
            end
        end
    end
    return closestPlayer
end

-- Optimal auto-pass: Returns the best player based on travel time versus the predicted bomb timer and within bombPassDistance.
local function getOptimalPlayer()
    local bestPlayer = nil
    local bestTravelTime = math.huge
    local predictedTime = emaBombTimer  -- current prediction
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    local myPos = LocalPlayer.Character.HumanoidRootPart.Position
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = player.Character.HumanoidRootPart.Position
            local distance = (targetPos - myPos).magnitude
            local travelTime = distance / pathfindingSpeed
            if travelTime < bestTravelTime and travelTime <= predictedTime and distance <= bombPassDistance then
                bestTravelTime = travelTime
                bestPlayer = player
            end
        end
    end
    return bestPlayer
end

-- Rotates LocalPlayer's character toward a target position.
-- Uses target velocity (if available) to predict the target's future position.
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
    local currentLook = hrp.CFrame.LookVector
    local desiredLook = targetCFrame.LookVector
    local dot = math.clamp(currentLook:Dot(desiredLook), -1, 1)
    local angleDiff = math.acos(dot)
    local duration = math.clamp(angleDiff / math.pi, 0.2, 0.5)

    local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {CFrame = targetCFrame})
    tween:Play()
    return tween
end

-- Returns the current predicted bomb timer (using our EMA).
local function predictBombTimer()
    return emaBombTimer
end

-----------------------------------------------------
-- BOMB TIMER UI FUNCTIONS
-----------------------------------------------------
-- Creates or updates the Bomb Timer UI for a given bomb object and character.
-- This function now only creates the UI if one doesn't already exist.
local function createOrUpdateBombTimerUI(bomb, character)
    if not character or not bomb then return end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return end

    -- Ensure the bomb has a "RemainingTime" NumberValue.
    local remVal = bomb:FindFirstChild("RemainingTime")
    if not remVal then
        remVal = Instance.new("NumberValue")
        remVal.Name = "RemainingTime"
        remVal.Value = globalBombTime  -- Use the global predicted timer initially
        remVal.Parent = bomb
    end

    globalBombTime = predictBombTimer() or remVal.Value

    -- Only create the timer UI if one does not already exist for this character.
    if bombTimerUI[character] and bombTimerUI[character].UI then
        return
    end

    local timerData = {}
    timerData.startTime = tick()
    timerData.initialTime = remVal.Value
    bombTimerUI[character] = timerData

    local bg = Instance.new("BillboardGui")
    bg.Name = "BombTimerUI"
    bg.Adornee = head
    bg.Size = UDim2.new(0, 100, 0, 50)
    bg.StudsOffset = Vector3.new(0, 3, 0)
    bg.AlwaysOnTop = true
    bg.Parent = head

    local label = Instance.new("TextLabel", bg)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.TextColor3 = Color3.new(1, 0, 0)
    label.Font = Enum.Font.SourceSansBold
    label.Text = tostring(math.ceil(timerData.initialTime))

    timerData.UI = bg

    task.spawn(function()
        while true do
            if not bomb or bomb.Parent ~= character then
                bg:Destroy()
                bombTimerUI[character] = nil
                return
            end
            local predictedDuration = predictBombTimer()
            local elapsed = tick() - timerData.startTime
            local remTime = math.max(0, predictedDuration - elapsed)
            label.Text = tostring(math.ceil(remTime))
            remVal.Value = remTime
            
            if remTime <= lowTimerThreshold then
                print("[BOMB TIMER] Time is almost up on " .. character.Name)
            end
            if remTime <= 0 then
                bg:Destroy()
                bombTimerUI[character] = nil
                print("[BOMB TIMER] Timer expired!")
                break
            end
            task.wait(1)
        end
    end)
end

-----------------------------------------------------
-- BOMB DETECTION & DATA COLLECTION
-----------------------------------------------------
-- Continuously detect bomb holders and update their timers.
local function detectBombs()
    while true do
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character then
                local bomb = player.Character:FindFirstChild("Bomb")
                if bomb then
                    createOrUpdateBombTimerUI(bomb, player.Character)
                    
                    -- Listen for when the bomb is passed.
                    bomb:GetPropertyChangedSignal("Parent"):Connect(function()
                        local ownerChar = bomb.Parent
                        if ownerChar and ownerChar:IsA("Model") then
                            local newPlayer = Players:GetPlayerFromCharacter(ownerChar)
                            if newPlayer then
                                local remVal = bomb:FindFirstChild("RemainingTime")
                                if remVal then
                                    local heldTime = tick() - (bombTimerUI[player.Character] and bombTimerUI[player.Character].startTime or tick())
                                    local remaining = remVal.Value
                                    table.insert(bombPassData, {heldTime = heldTime, remaining = remaining})
                                    if #bombPassData > maxBombPassDataEntries then
                                        table.remove(bombPassData, 1)
                                    end
                                    -- Update our EMA prediction with the new remaining time.
                                    emaBombTimer = alpha * remaining + (1 - alpha) * emaBombTimer
                                    print("[DATA] Bomb pass data recorded. Held time: " .. heldTime .. "s, Remaining: " .. remaining .. "s")
                                end
                                print("[TRACKER] Bomb passed to " .. newPlayer.Name)
                                createOrUpdateBombTimerUI(bomb, ownerChar)
                            end
                        else
                            bombTimerUI[player.Character] = nil
                        end
                    end)
                end
            end
        end
        task.wait(0.1)
    end
end

-----------------------------------------------------
-- (OPTIONAL) AUTO PASS BOMB LOGIC
-----------------------------------------------------
local function autoPassBomb()
    if not AutoPassEnabled then
        removeTargetMarker()
        return
    end
    pcall(function()
        local bomb = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Bomb")
        if bomb then
            local BombEvent = bomb:FindFirstChild("RemoteEvent")
            local targetPlayer = nil
            if UseOptimalAutoPass then
                targetPlayer = getOptimalPlayer()
            else
                targetPlayer = getClosestPlayer()
            end
            if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                createOrUpdateTargetMarker(targetPlayer)
                local targetPosition = targetPlayer.Character.HumanoidRootPart.Position
                local myPos = LocalPlayer.Character.HumanoidRootPart.Position
                local distance = (targetPosition - myPos).magnitude
                if UseOptimalAutoPass then
                    local travelTime = distance / pathfindingSpeed
                    local predictedTime = predictBombTimer()
                    -- Both travelTime vs. predictedTime AND distance within bombPassDistance must be met
                    if travelTime <= predictedTime and distance <= bombPassDistance then
                        local targetVelocity = targetPlayer.Character.HumanoidRootPart.Velocity or Vector3.new(0, 0, 0)
                        rotateCharacterTowardsTarget(targetPosition, targetVelocity)
                        task.wait(0.6)
                        BombEvent:FireServer(targetPlayer.Character, targetPlayer.Character:FindFirstChild("CollisionPart"))
                        removeTargetMarker()
                    end
                else
                    if distance <= bombPassDistance then
                        local targetVelocity = targetPlayer.Character.HumanoidRootPart.Velocity or Vector3.new(0, 0, 0)
                        rotateCharacterTowardsTarget(targetPosition, targetVelocity)
                        task.wait(0.6)
                        BombEvent:FireServer(targetPlayer.Character, targetPlayer.Character:FindFirstChild("CollisionPart"))
                        removeTargetMarker()
                    end
                end
            else
                removeTargetMarker()
            end
        else
            removeTargetMarker()
        end
    end)
end

-----------------------------------------------------
-- (OPTIONAL) MANUAL ANTI-SLIPPERY
-----------------------------------------------------
local function applyAntiSlippery(enabled)
    if enabled then
        task.spawn(function()
            while AntiSlipperyEnabled do
                local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5)
                    end
                end
                task.wait(0.1)
            end
        end)
    else
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.5)
            end
        end
    end
end

-----------------------------------------------------
-- (OPTIONAL) MANUAL REMOVE HITBOX
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
LocalPlayer.CharacterAdded:Connect(function()
    if AntiSlipperyEnabled then applyAntiSlippery(true) end
    if RemoveHitboxEnabled then applyRemoveHitbox(true) end
end)

-----------------------------------------------------
-- ORIONLIB UI INTERFACE (OPTIONAL)
-----------------------------------------------------
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
            removeTargetMarker()
        end
    end
})

AutomatedTab:AddToggle({
    Name = "Use Optimal Auto Pass",
    Default = UseOptimalAutoPass,
    Callback = function(value)
        UseOptimalAutoPass = value
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
            changeUITheme(theme)
        else
            warn("Theme not found:", themeName)
        end
    end
})

OrionLib:Init()
print("Yon Menu Script Loaded with AI-based Bomb Timer, Optimal/Normal Auto Pass Toggle, and a Red 'X' Visual Marker (attached to the body) for Auto-Pass")

-----------------------------------------------------
-- START BOMB DETECTION
-----------------------------------------------------
task.spawn(detectBombs)
