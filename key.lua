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
local defaultBombTimer = 20       -- Default bomb timer duration (in seconds)
local bombPassDistance = 10         -- Maximum distance to pass the bomb
local AutoPassEnabled = false       -- Toggle for auto-pass bomb (if desired)
local AntiSlipperyEnabled = false   -- Toggle for manual anti-slippery (if desired)
local RemoveHitboxEnabled = false   -- Toggle for manual hitbox removal (if desired)
local autoPassConnection = nil      -- Will hold the connection for auto-pass logic
local pathfindingSpeed = 16         -- (For potential future use)

-- Timer thresholds
local lowTimerThreshold = 2         -- Warn when remaining time is ≤ 2 seconds

-- UI Themes for OrionLib (for toggles, etc.)
local uiThemes = {
    Dark = { Background = Color3.new(0, 0, 0), Text = Color3.new(1, 1, 1) },
    Light = { Background = Color3.new(1, 1, 1), Text = Color3.new(0, 0, 0) },
    Red = { Background = Color3.new(1, 0, 0), Text = Color3.new(1, 1, 1) },
}

-- Bomb tracking variables
local bombObject = nil          -- Reference to the bomb object in the character
local bombStartTime = nil       -- The time when the current bomb timer started
local globalBombTime = defaultBombTimer  -- Global remaining time (inherited on pass)
local lastBombPassTime = nil    -- Time when the bomb was last passed
local isHoldingBomb = false     -- True if LocalPlayer is currently holding the bomb

-- Table to keep track of active timer UIs by character
local bombTimerUI = {}

-----------------------------------------------------
-- UTILITY FUNCTIONS
-----------------------------------------------------

-- Returns the closest player (this function is available for auto-pass targeting)
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

-- Rotates LocalPlayer's character smoothly toward a target position.
-- If targetVelocity is provided, predicts the target’s position 0.5 seconds ahead.
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

-- Creates (or updates) a Bomb Timer UI attached to the character's Head (or HRP).
-- The timer uses a NumberValue named "RemainingTime" on the bomb object to store its global countdown.
local function createBombTimerUI(character, bomb)
    if not character or not bomb then return end

    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return end

    -- Ensure the bomb object has a "RemainingTime" NumberValue.
    local remVal = bomb:FindFirstChild("RemainingTime")
    if not remVal then
        remVal = Instance.new("NumberValue")
        remVal.Name = "RemainingTime"
        remVal.Value = defaultBombTimer
        remVal.Parent = bomb
    end

    -- Use the bomb's remaining time as the starting value.
    local startingTime = remVal.Value

    -- Remove any existing UI for this character.
    if bombTimerUI[character] then
        bombTimerUI[character]:Destroy()
    end

    local timerUI = Instance.new("BillboardGui")
    timerUI.Name = "BombTimerUI"
    timerUI.Adornee = head
    timerUI.Size = UDim2.new(0, 100, 0, 50)
    timerUI.StudsOffset = Vector3.new(0, 3, 0)
    timerUI.AlwaysOnTop = true
    timerUI.Parent = head

    local label = Instance.new("TextLabel", timerUI)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextScaled = true
    label.TextColor3 = Color3.new(1, 0, 0)
    label.Font = Enum.Font.SourceSansBold
    label.Text = tostring(startingTime)

    bombTimerUI[character] = timerUI
    bombStartTime = tick()

    task.spawn(function()
        local remTime = startingTime
        while remTime > 0 do
            if not bomb or bomb.Parent ~= character then
                timerUI:Destroy()
                bombTimerUI[character] = nil
                return
            end

            remTime = math.max(0, startingTime - (tick() - bombStartTime))
            label.Text = tostring(math.ceil(remTime))
            remVal.Value = remTime  -- Update the bomb's global remaining time

            if remTime <= lowTimerThreshold then
                print("[BOMB TIMER] Time is almost up: " .. remTime .. " seconds!")
                -- Optionally, you could trigger auto-pass here
            end

            task.wait(1)
        end

        timerUI:Destroy()
        bombTimerUI[character] = nil
        print("[BOMB TIMER] Timer expired!")
    end)
end

-----------------------------------------------------
-- BOMB DETECTION & TIMER MANAGEMENT
-----------------------------------------------------
-- Continuously check all players to see who holds the bomb.
local function detectBomb()
    while true do
        for _, player in pairs(Players:GetPlayers()) do
            if player.Character then
                local bomb = player.Character:FindFirstChild("Bomb")  -- Adjust name if necessary
                if bomb and bomb ~= bombObject then
                    bombObject = bomb
                    isHoldingBomb = (player == LocalPlayer)
                    print("[TRACKER] Bomb received by " .. player.Name .. "!")
                    
                    -- Inherit remaining time if the bomb was passed before.
                    if lastBombPassTime then
                        local elapsed = tick() - lastBombPassTime
                        local currentRem = bomb:FindFirstChild("RemainingTime")
                        if currentRem then
                            currentRem.Value = math.max(0, currentRem.Value - elapsed)
                        else
                            currentRem = Instance.new("NumberValue")
                            currentRem.Name = "RemainingTime"
                            currentRem.Value = math.max(0, defaultBombTimer - elapsed)
                            currentRem.Parent = bomb
                        end
                        globalBombTime = currentRem.Value
                    else
                        -- No previous pass: start at default.
                        local currentRem = bomb:FindFirstChild("RemainingTime")
                        if not currentRem then
                            currentRem = Instance.new("NumberValue")
                            currentRem.Name = "RemainingTime"
                            currentRem.Value = defaultBombTimer
                            currentRem.Parent = bomb
                        end
                        globalBombTime = currentRem.Value
                    end

                    bombStartTime = tick()
                    createBombTimerUI(player.Character, bomb)
                    lastBombPassTime = tick()

                    -- Listen for bomb passing (when the bomb's Parent changes).
                    bomb:GetPropertyChangedSignal("Parent"):Connect(function()
                        if bomb.Parent ~= player.Character then
                            print("[TRACKER] Bomb passed from " .. player.Name)
                            bombObject = nil
                            isHoldingBomb = false
                            lastBombPassTime = tick()
                            if bombTimerUI[player.Character] then
                                bombTimerUI[player.Character]:Destroy()
                                bombTimerUI[player.Character] = nil
                            end
                        end
                    end)
                end
            end
        end
        task.wait(0.1)
    end
end

-----------------------------------------------------
-- AUTO PASS BOMB LOGIC (OPTIONAL)
-----------------------------------------------------
local function autoPassBomb()
    if not AutoPassEnabled or not isHoldingBomb then return end
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
-- OPTIONAL: MANUAL ANTI-SLIPPERY
-----------------------------------------------------
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

-----------------------------------------------------
-- OPTIONAL: MANUAL REMOVE HITBOX
-----------------------------------------------------
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

-----------------------------------------------------
-- APPLY FEATURES ON RESPAWN
-----------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function()
    if AntiSlipperyEnabled then applyAntiSlippery(true) end
    if RemoveHitboxEnabled then applyRemoveHitbox(true) end
end)

-----------------------------------------------------
-- ORIONLIB UI INTERFACE
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
            -- Optionally, apply the theme to OrionLib UI elements here.
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
task.spawn(detectBomb)
