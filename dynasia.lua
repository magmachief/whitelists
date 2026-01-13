local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Core Variables
local bombName = "Bomb"
local customNormalFriction = 0.7
local customBombFriction = 7
local customAntiSlipperyFriction = 0.7
local customBombAntiSlipperyFriction = 0.9
local fallbackFriction = 0.5
local customHitboxSize = 0.1
local bombPassDistance = 10
local raySpreadAngle = 10
local numRaycasts = 5

-- Feature Toggles
local AutoPassEnabled = false
local antiSlippery = false
local RemoveHitboxEnabled = false
local AI_AssistanceEnabled = false
local LeftClickAutoPassEnabled = false
local FaceBombEnabled = false
local originalHitboxSizes = {}

-- Store connections
local autoPassConnection = nil
local faceBombConnection = nil
local leftClickConnection = nil
local menuVisible = true
local myFrictionController = nil

-- Initialize character variables when character loads
local CHAR, HUMANOID, HRP

local function initializeCharacter()
    CHAR = LocalPlayer.Character
    if CHAR then
        HUMANOID = CHAR:WaitForChild("Humanoid")
        HRP = CHAR:WaitForChild("HumanoidRootPart")
    end
end

-- Wait for initial character
if LocalPlayer.Character then
    initializeCharacter()
end

LocalPlayer.CharacterAdded:Connect(function(character)
    CHAR = character
    HUMANOID = character:WaitForChild("Humanoid")
    HRP = character:WaitForChild("HumanoidRootPart")
    
    -- Re-apply features to new character
    if RemoveHitboxEnabled then
        applyRemoveHitbox(true)
    end
    if antiSlippery then
        applyAntiSlippery(true)
    end
    if myFrictionController then
        myFrictionController:enable()
    end
end)

-- Friction Controller
local FrictionController = {}
FrictionController.__index = FrictionController

function FrictionController.new()
    local self = setmetatable({}, FrictionController)
    self.originalProperties = {}
    self.normalFriction = customNormalFriction
    self.bombFriction = customBombFriction
    self.stateMultipliers = {Running = 1.2, Walking = 1.0, Crouching = 0.8}
    self.enabled = false
    return self
end

function FrictionController:getSurfaceMaterial(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return Enum.Material.Plastic
    end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local rayResult = Workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), rayParams)
    return rayResult and rayResult.Instance.Material or Enum.Material.Plastic
end

function FrictionController:calculateFriction(character)
    local humanoid = character:FindFirstChild("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and hrp) then
        return self.normalFriction
    end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local rayResult = Workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), rayParams)
    if rayResult then
        local floorPart = rayResult.Instance
        if floorPart:IsA("BasePart") and floorPart.Name == "Floor" and floorPart.Friction <= 0.2 then
            return math.clamp(customAntiSlipperyFriction * 0.5, 0.1, 1.0)
        end
    end
    if character:FindFirstChild(bombName) then
        return self.bombFriction
    end
    local stateName = humanoid:GetState()
    local multiplier = self.stateMultipliers[stateName] or 1.0
    return math.clamp(self.normalFriction * multiplier, 0.1, 1.0)
end

function FrictionController:update()
    local character = LocalPlayer.Character
    if not character then
        return
    end
    for _, pn in ipairs({"LeftFoot", "RightFoot", "LeftLeg", "RightLeg"}) do
        local part = character:FindFirstChild(pn)
        if part and part:IsA("BasePart") then
            if not self.originalProperties[part] then
                local elasticity = 0.3
                local frictionWeight = 0.5
                if part.CustomPhysicalProperties then
                    elasticity = part.CustomPhysicalProperties.Elasticity
                    frictionWeight = part.CustomPhysicalProperties.FrictionWeight
                end
                self.originalProperties[part] = PhysicalProperties.new(customNormalFriction, elasticity, frictionWeight)
            end
            local df = self:calculateFriction(character)
            local elasticity = 0.3
            local frictionWeight = 0.5
            if part.CustomPhysicalProperties then
                elasticity = part.CustomPhysicalProperties.Elasticity
                frictionWeight = part.CustomPhysicalProperties.FrictionWeight
            end
            part.CustomPhysicalProperties = PhysicalProperties.new(df, elasticity, frictionWeight)
        end
    end
end

function FrictionController:restore()
    for part, orig in pairs(self.originalProperties) do
        if part and part.Parent then
            part.CustomPhysicalProperties = orig
        end
    end
    self.originalProperties = {}
end

function FrictionController:enable()
    if self.enabled then
        return
    end
    self.enabled = true
    spawn(
        function()
            while self.enabled and wait(0.1) do
                self:update()
            end
        end
    )
end

function FrictionController:disable()
    self.enabled = false
    self:restore()
end

local function applyAntiSlippery(enabled)
    if enabled then
        spawn(
            function()
                while antiSlippery and wait(0.5) do
                    local character = LocalPlayer.Character
                    if character then
                        local hrp = character:FindFirstChild("HumanoidRootPart")
                        for _, part in pairs(character:GetDescendants()) do
                            if part:IsA("BasePart") then
                                if character:FindFirstChild(bombName) then
                                    local speed = hrp and hrp.Velocity.Magnitude or 0
                                    local fric = customBombAntiSlipperyFriction
                                    if speed > 10 then
                                        fric = fric * 1.25
                                    end
                                    part.CustomPhysicalProperties = PhysicalProperties.new(fric, 0.3, 0.5)
                                else
                                    part.CustomPhysicalProperties =
                                        PhysicalProperties.new(customAntiSlipperyFriction, 0.3, 0.5)
                                end
                            end
                        end
                    end
                end
            end
        )
    else
        local character = LocalPlayer.Character
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CustomPhysicalProperties = PhysicalProperties.new(fallbackFriction, 0.3, 0.5)
                end
            end
        end
    end
end

local function faceNearestBombHolder()
    local myChar = LocalPlayer.Character
    if not myChar then
        return
    end
    local hrp = myChar:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local nearest, nearestDist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild(bombName) then
            local pHRP = p.Character:FindFirstChild("HumanoidRootPart")
            if pHRP then
                local d = (pHRP.Position - hrp.Position).Magnitude
                if d < nearestDist then
                    nearestDist = d
                    nearest = p
                end
            end
        end
    end
    if nearest and nearest.Character then
        local bombHolderHRP = nearest.Character:FindFirstChild("HumanoidRootPart")
        if bombHolderHRP then
            local cam = Workspace.CurrentCamera
            cam.CameraType = Enum.CameraType.Custom
            cam.CFrame = CFrame.new(cam.CFrame.Position, bombHolderHRP.Position)
        end
    end
end

local AINotificationsModule = {}
function AINotificationsModule.sendNotification(title, text, dur)
    pcall(
        function()
            StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = dur or 5})
        end
    )
end

local function applyRemoveHitbox(enable)
    local char = LocalPlayer.Character
    if not char then
        return
    end

    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == "Hitbox" then
            if enable then
                if not originalHitboxSizes[part] then
                    originalHitboxSizes[part] = part.Size
                end
                part.Transparency = 1
                part.CanCollide = false
                part.Size = Vector3.new(customHitboxSize, customHitboxSize, customHitboxSize)
            else
                part.Transparency = 0
                part.CanCollide = true
                part.Size = originalHitboxSizes[part] or Vector3.new(1, 1, 1)
            end
        end
    end
end

local function getClosestPlayer()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return nil
    end
    
    local closest, nd = nil, math.huge
    local myPos = hrp.Position
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local targetHrp = p.Character:FindFirstChild("HumanoidRootPart")
            if targetHrp then
                local d = (targetHrp.Position - myPos).Magnitude
                if d < nd then
                    nd = d
                    closest = p
                end
            end
        end
    end
    return closest
end

-- Auto Pass Bomb Function
local function autoPassBomb()
    if not AutoPassEnabled then
        return
    end
    
    local character = LocalPlayer.Character
    if not character then
        return
    end
    
    pcall(function()
        local Bomb = character:FindFirstChild(bombName)
        if Bomb then
            local BombEvent = Bomb:FindFirstChild("RemoteEvent")
            local closestPlayer = getClosestPlayer()
            if closestPlayer and closestPlayer.Character then
                local targetHrp = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
                local myHrp = character:FindFirstChild("HumanoidRootPart")
                
                if targetHrp and myHrp then
                    local targetPos = targetHrp.Position
                    local dist = (targetPos - myHrp.Position).Magnitude
                    if dist <= bombPassDistance then
                        BombEvent:FireServer(
                            closestPlayer.Character,
                            closestPlayer.Character:FindFirstChild("CollisionPart")
                        )
                    end
                end
            end
        end
    end)
end

-- Left Click triggers normal auto pass
local function handleLeftClickAutoPass(input)
    if not LeftClickAutoPassEnabled or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    autoPassBomb()
end

-- =====================================================================
-- CUSTOM PC MENU CREATION
-- =====================================================================

local menuGui = Instance.new("ScreenGui")
menuGui.Name = "YonMenuPC"
menuGui.ResetOnSpawn = false
menuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
menuGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 400, 0, 500)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false  -- Hidden by default
mainFrame.Parent = menuGui

-- Add corner rounding
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Add drop shadow
local shadow = Instance.new("UIStroke")
shadow.Thickness = 2
shadow.Color = Color3.fromRGB(0, 0, 0)
shadow.Transparency = 0.7
shadow.Parent = mainFrame

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

local titleText = Instance.new("TextLabel")
titleText.Name = "Title"
titleText.Size = UDim2.new(1, -40, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "Yon Menu - PC Edition"
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.TextSize = 18
titleText.Font = Enum.Font.SourceSansBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

-- Close Button
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 16
closeButton.Font = Enum.Font.SourceSansBold
closeButton.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

closeButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    AINotificationsModule.sendNotification("Menu", "Press RightShift to reopen", 2)
end)

-- Minimize Button
local minimizeButton = Instance.new("TextButton")
minimizeButton.Name = "MinimizeButton"
minimizeButton.Size = UDim2.new(0, 30, 0, 30)
minimizeButton.Position = UDim2.new(1, -70, 0, 5)
minimizeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
minimizeButton.Text = "_"
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.TextSize = 16
minimizeButton.Font = Enum.Font.SourceSansBold
minimizeButton.Parent = titleBar

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0, 6)
minimizeCorner.Parent = minimizeButton

minimizeButton.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

-- Make window draggable
local dragging = false
local dragInput, dragStart, startPos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Content Frame
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, -20, 1, -60)
contentFrame.Position = UDim2.new(0, 10, 0, 50)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- Scroll Frame
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ScrollFrame"
scrollFrame.Size = UDim2.new(1, 0, 1, 0)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 8
scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
scrollFrame.Parent = contentFrame

-- Create UI List Layout
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- Function to create toggle button
local function createToggle(labelText, defaultValue, callback)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(1, 0, 0, 35)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.LayoutOrder = #scrollFrame:GetChildren()
    
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 60, 0, 30)
    toggleButton.Position = UDim2.new(1, -65, 0.5, -15)
    toggleButton.AnchorPoint = Vector2.new(1, 0.5)
    toggleButton.BackgroundColor3 = defaultValue and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
    toggleButton.Text = defaultValue and "ON" or "OFF"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextSize = 14
    toggleButton.Font = Enum.Font.SourceSansBold
    toggleButton.Parent = toggleFrame
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 16
    label.Font = Enum.Font.SourceSans
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = toggleFrame
    
    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 6)
    buttonCorner.Parent = toggleButton
    
    toggleButton.MouseButton1Click:Connect(function()
        local newValue = not defaultValue
        defaultValue = newValue
        toggleButton.BackgroundColor3 = newValue and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
        toggleButton.Text = newValue and "ON" or "OFF"
        callback(newValue)
    end)
    
    toggleFrame.Parent = scrollFrame
    return toggleButton
end

-- Function to create text box
local function createTextBox(labelText, defaultValue, callback)
    local textFrame = Instance.new("Frame")
    textFrame.Size = UDim2.new(1, 0, 0, 50)
    textFrame.BackgroundTransparency = 1
    textFrame.LayoutOrder = #scrollFrame:GetChildren()
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 25)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 14
    label.Font = Enum.Font.SourceSans
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = textFrame
    
    local textBox = Instance.new("TextBox")
    textBox.Size = UDim2.new(1, 0, 0, 25)
    textBox.Position = UDim2.new(0, 0, 0, 25)
    textBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textBox.TextSize = 14
    textBox.Text = tostring(defaultValue)
    textBox.ClearTextOnFocus = false
    textBox.Parent = textFrame
    
    local textBoxCorner = Instance.new("UICorner")
    textBoxCorner.CornerRadius = UDim.new(0, 4)
    textBoxCorner.Parent = textBox
    
    local textBoxStroke = Instance.new("UIStroke")
    textBoxStroke.Thickness = 1
    textBoxStroke.Color = Color3.fromRGB(100, 100, 100)
    textBoxStroke.Parent = textBox
    
    textBox.FocusLost:Connect(function()
        local value = textBox.Text
        if callback then
            callback(value)
        end
    end)
    
    textFrame.Parent = scrollFrame
end

-- Function to create section header
local function createSectionHeader(text)
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, 0, 0, 30)
    headerFrame.BackgroundTransparency = 1
    headerFrame.LayoutOrder = #scrollFrame:GetChildren()
    
    local headerLabel = Instance.new("TextLabel")
    headerLabel.Size = UDim2.new(1, 0, 1, 0)
    headerLabel.BackgroundTransparency = 1
    headerLabel.Text = text
    headerLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
    headerLabel.TextSize = 18
    headerLabel.Font = Enum.Font.SourceSansBold
    headerLabel.TextXAlignment = Enum.TextXAlignment.Left
    headerLabel.Parent = headerFrame
    
    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 2)
    line.Position = UDim2.new(0, 0, 1, -2)
    line.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    line.BorderSizePixel = 0
    line.Parent = headerFrame
    
    headerFrame.Parent = scrollFrame
end

-- =====================================================================
-- CREATE MENU CONTENT
-- =====================================================================

-- Bomb Passing Section
createSectionHeader("BOMB PASSING")

-- Auto Pass Bomb Toggle
local autoPassToggleBtn = createToggle("Auto Pass Bomb", AutoPassEnabled, function(value)
    AutoPassEnabled = value
    if value then
        if not autoPassConnection then
            autoPassConnection = RunService.Stepped:Connect(autoPassBomb)
        end
        AINotificationsModule.sendNotification("Auto Pass", "Enabled", 2)
    else
        if autoPassConnection then
            autoPassConnection:Disconnect()
            autoPassConnection = nil
        end
        AINotificationsModule.sendNotification("Auto Pass", "Disabled", 2)
    end
end)

-- Left Click Auto Pass Toggle
local leftClickToggleBtn = createToggle("Left Click Auto Pass", LeftClickAutoPassEnabled, function(value)
    LeftClickAutoPassEnabled = value
    if value then
        if leftClickConnection then
            leftClickConnection:Disconnect()
        end
        leftClickConnection = UserInputService.InputBegan:Connect(handleLeftClickAutoPass)
        AINotificationsModule.sendNotification("Left Click Pass", "Enabled - Left click to pass bomb", 3)
    else
        if leftClickConnection then
            leftClickConnection:Disconnect()
            leftClickConnection = nil
        end
        AINotificationsModule.sendNotification("Left Click Pass", "Disabled", 2)
    end
end)

-- Bomb Pass Distance
createTextBox("Bomb Pass Distance", bombPassDistance, function(value)
    local num = tonumber(value)
    if num then
        bombPassDistance = num
        AINotificationsModule.sendNotification("Settings", "Bomb pass distance set to " .. num, 2)
    end
end)

-- Character Settings Section
createSectionHeader("CHARACTER SETTINGS")

-- Anti-Slippery Toggle
createToggle("Anti-Slippery", antiSlippery, function(value)
    antiSlippery = value
    applyAntiSlippery(value)
    AINotificationsModule.sendNotification("Anti-Slippery", value and "Enabled" or "Disabled", 2)
end)

-- Anti-Slippery Friction
createTextBox("Anti-Slippery Friction", customAntiSlipperyFriction, function(value)
    local num = tonumber(value)
    if num then
        customAntiSlipperyFriction = num
        AINotificationsModule.sendNotification("Settings", "Anti-slippery friction set to " .. num, 2)
    end
end)

-- Bomb Anti-Slippery Friction
createTextBox("Bomb Anti-Slippery Friction", customBombAntiSlipperyFriction, function(value)
    local num = tonumber(value)
    if num then
        customBombAntiSlipperyFriction = num
        AINotificationsModule.sendNotification("Settings", "Bomb anti-slippery friction set to " .. num, 2)
    end
end)

-- Face Bomb Toggle
createToggle("Face Bomb Holder", FaceBombEnabled, function(value)
    FaceBombEnabled = value
    if value then
        if faceBombConnection then
            faceBombConnection:Disconnect()
        end
        faceBombConnection = RunService.Heartbeat:Connect(faceNearestBombHolder)
        AINotificationsModule.sendNotification("Face Bomb", "Enabled", 2)
    else
        if faceBombConnection then
            faceBombConnection:Disconnect()
            faceBombConnection = nil
        end
        AINotificationsModule.sendNotification("Face Bomb", "Disabled", 2)
    end
end)

-- Remove Hitbox Toggle
createToggle("Remove Hitbox", RemoveHitboxEnabled, function(value)
    RemoveHitboxEnabled = value
    applyRemoveHitbox(value)
    AINotificationsModule.sendNotification("Remove Hitbox", value and "Enabled" or "Disabled", 2)
end)

-- Hitbox Size
createTextBox("Hitbox Size", customHitboxSize, function(value)
    local num = tonumber(value)
    if num then
        customHitboxSize = num
        if RemoveHitboxEnabled then
            applyRemoveHitbox(true)
        end
        AINotificationsModule.sendNotification("Settings", "Hitbox size set to " .. num, 2)
    end
end)

-- AI Settings Section
createSectionHeader("AI SETTINGS")

-- AI Assistance Toggle
createToggle("AI Assistance", AI_AssistanceEnabled, function(value)
    AI_AssistanceEnabled = value
    AINotificationsModule.sendNotification("AI Assistance", value and "Enabled" or "Disabled", 2)
end)

-- Ray Spread Angle
createTextBox("Ray Spread Angle", raySpreadAngle, function(value)
    local num = tonumber(value)
    if num then
        raySpreadAngle = num
        AINotificationsModule.sendNotification("Settings", "Ray spread angle set to " .. num, 2)
    end
end)

-- Number of Raycasts
createTextBox("Number of Raycasts", numRaycasts, function(value)
    local num = tonumber(value)
    if num then
        numRaycasts = num
        AINotificationsModule.sendNotification("Settings", "Number of raycasts set to " .. num, 2)
    end
end)

-- UI Settings Section
createSectionHeader("UI SETTINGS")

-- Add a Hide Menu button
local hideMenuBtn = Instance.new("TextButton")
hideMenuBtn.Name = "HideMenuButton"
hideMenuBtn.Size = UDim2.new(1, 0, 0, 40)
hideMenuBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
hideMenuBtn.Text = "HIDE MENU"
hideMenuBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hideMenuBtn.TextSize = 16
hideMenuBtn.Font = Enum.Font.SourceSansBold
hideMenuBtn.LayoutOrder = #scrollFrame:GetChildren()

local hideMenuCorner = Instance.new("UICorner")
hideMenuCorner.CornerRadius = UDim.new(0, 6)
hideMenuCorner.Parent = hideMenuBtn

hideMenuBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    AINotificationsModule.sendNotification("Menu", "Press Equal to reopen", 2)
end)

hideMenuBtn.Parent = scrollFrame

-- =====================================================================
-- KEYBINDS AND INITIALIZATION
-- =====================================================================

-- Initialize Friction Controller
myFrictionController = FrictionController.new()
myFrictionController:enable()

-- Change from RightShift to Equals key (=)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Equals then
        mainFrame.Visible = not mainFrame.Visible
        if mainFrame.Visible then
            AINotificationsModule.sendNotification("Menu", "Menu Opened", 2)
        end
    end
end)

-- Update scroll frame size
spawn(function()
    wait(0.5)
    local totalHeight = 0
    for _, child in pairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            totalHeight = totalHeight + child.Size.Y.Offset
        end
    end
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 20)
end)

-- Cleanup function
local function cleanup()
    if autoPassConnection then
        autoPassConnection:Disconnect()
        autoPassConnection = nil
    end
    
    if faceBombConnection then
        faceBombConnection:Disconnect()
        faceBombConnection = nil
    end
    
    if leftClickConnection then
        leftClickConnection:Disconnect()
        leftClickConnection = nil
    end
    
    if myFrictionController then
        myFrictionController:disable()
    end
    
    AINotificationsModule.sendNotification("Cleanup", "All features disabled", 2)
end

-- Auto-cleanup on character removal
LocalPlayer.CharacterRemoving:Connect(function()
    cleanup()
end)

-- Auto-cleanup on game leave
game:GetService("Players").PlayerRemoving:Connect(function(player)
    if player == LocalPlayer then
        cleanup()
    end
end)

print("=== YON MENU PC EDITION LOADED ===")
print("Features:")
print("- Auto Pass Bomb: Automatically passes bomb to closest player")
print("- Left Click Auto Pass: Click to pass bomb (PC Exclusive)")
print("- Anti-Slippery: Adjust character friction")
print("- Face Bomb: Automatically face bomb holder")
print("- Remove Hitbox: Make hitboxes smaller")
print("- AI Assistance: Smart targeting system")
print("")
print("Controls:")
print("- RightShift: Toggle Menu")
print("- Left Click: Pass bomb (if enabled)")
print("")
print("Menu is fully clickable and draggable!")

AINotificationsModule.sendNotification("Yon Menu PC", "Loaded Successfully! Press RightShift to open/close", 5)

-- Add a test to verify menu works
spawn(function()
    wait(2)
    print("Menu test: Press RightShift to open menu")
    print("Menu GUI exists:", menuGui and "Yes" or "No")
    print("Main Frame exists:", mainFrame and "Yes" or "No")
    print("Menu is currently:", mainFrame.Visible and "Visible" or "Hidden")
end)

return {}
