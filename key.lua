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
local bombPassDistance = 10         -- Maximum pass distance (for auto-pass, if used)
local AutoPassEnabled = false       -- (Optional) Toggle auto-pass behavior
local AntiSlipperyEnabled = false   -- (Optional) Toggle anti-slippery feature
local RemoveHitboxEnabled = false   -- (Optional) Toggle hitbox removal
local pathfindingSpeed = 16         -- For potential future use

local lowTimerThreshold = 2         -- When remaining time is <= 2 seconds, warn

-- Global bomb tracking variables
local bombObject = nil            -- Reference to the current bomb object
local bombStartTime = nil         -- When the current bomb timer started
local globalBombTime = defaultBombTimer  -- Global remaining time (this will be adjusted by our AI)
local lastBombPassTime = nil      -- When the bomb was last passed
local isHoldingBomb = false       -- True if LocalPlayer currently holds the bomb

-- Table to store bomb pass data for AI prediction (each entry: {heldTime, remaining})
local bombPassData = {}

-- A table to hold bomb timer UIs by character
local bombTimerUI = {}

-----------------------------------------------------
-- UTILITY FUNCTIONS
-----------------------------------------------------

-- Returns the closest player (for auto-pass targeting)
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

-- Simple AI prediction: Compute the average remaining time from past bomb passes.
local function predictBombTimer()
    if #bombPassData == 0 then
        return defaultBombTimer
    end
    local total = 0
    for _, data in ipairs(bombPassData) do
        total = total + data.remaining
    end
    return total / #bombPassData
end

-----------------------------------------------------
-- BOMB TIMER UI FUNCTIONS
-----------------------------------------------------
-- Creates or updates the Bomb Timer UI for a given bomb object and character.
local function createOrUpdateBombTimerUI(bomb, character)
    if not character or not bomb then return end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return end

    -- Ensure the bomb has a "RemainingTime" NumberValue.
    local remVal = bomb:FindFirstChild("RemainingTime")
    if not remVal then
        remVal = Instance.new("NumberValue")
        remVal.Name = "RemainingTime"
        remVal.Value = globalBombTime  -- Use the global predicted timer
        remVal.Parent = bomb
    end

    -- Update globalBombTime using AI prediction (if available)
    globalBombTime = predictBombTimer() or remVal.Value

    -- Record timer data for this bomb (or update existing data)
    local timerData = bombTimerUI[character]
    if not timerData then
        timerData = {}
        bombTimerUI[character] = timerData
    end
    timerData.startTime = tick()
    timerData.initialTime = remVal.Value

    -- Create a new BillboardGui for the timer.
    if timerData.UI then
        timerData.UI:Destroy()
    end

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

    -- Update loop for the timer UI.
    task.spawn(function()
        local remTime = timerData.initialTime
        while remTime > 0 do
            if not bomb or bomb.Parent ~= character then
                bg:Destroy()
                bombTimerUI[character] = nil
                return
            end
            remTime = math.max(0, timerData.initialTime - (tick() - timerData.startTime))
            label.Text = tostring(math.ceil(remTime))
            remVal.Value = remTime  -- Update the bomb's global remaining time

            if remTime <= lowTimerThreshold then
                print("[BOMB TIMER] Time is almost up on " .. character.Name)
            end

            task.wait(1)
        end
        bg:Destroy()
        bombTimerUI[character] = nil
        print("[BOMB TIMER] Timer expired!")
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
                    -- If this bomb is new or has been passed, update the timer UI.
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
                                    -- Record data from this bomb pass.
                                    table.insert(bombPassData, {heldTime = heldTime, remaining = remaining})
                                    print("[DATA] Bomb pass data recorded. Held time: " .. heldTime .. "s, Remaining: " .. remaining .. "s")
                                end
                                print("[TRACKER] Bomb passed to " .. newPlayer.Name)
                                createOrUpdateBombTimerUI(bomb, ownerChar)
                            end
                        else
                            -- Bomb no longer held by any player; clean up.
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
    if not AutoPassEnabled then return end
    pcall(function()
        local bomb = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Bomb")
        if bomb then
            local BombEvent = bomb:FindFirstChild("RemoteEvent")
            local closestPlayer = getClosestPlayer()
            if closestPlayer and closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local targetPosition = closestPlayer.Character.HumanoidRootPart.Position
                local distance = (targetPosition - LocalPlayer.Character.HumanoidRootPart.Position).magnitude
                if distance <= bombPassDistance then
                    local targetVelocity = closestPlayer.Character.HumanoidRootPart.Velocity or Vector3.new(0,0,0)
                    rotateCharacterTowardsTarget(targetPosition, targetVelocity)
                    task.wait(0.6)
                    BombEvent:FireServer(closestPlayer.Character, closestPlayer.Character:FindFirstChild("CollisionPart"))
                end
            end
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
            -- (Optional) Dynamically apply the theme to OrionLib UI elements.
        else
            warn("Theme not found:", themeName)
        end
    end
})

OrionLib:Init()
print("Yon Menu Script Loaded with Enhanced AI-based Bomb Timer, Anti-Slippery, and Advanced Features")

-----------------------------------------------------
-- START BOMB DETECTION
-----------------------------------------------------
task.spawn(detectBombs)
