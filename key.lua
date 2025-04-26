-----------------------------------------------------
-- Ultra Advanced Bomb Passing Assistant v4 (Stealth Edition)
-- Client-Only | All Features Pre-Configured
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

-- CHARACTER SETUP
local CHAR = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HUMANOID = CHAR:WaitForChild("Humanoid")
local HRP = CHAR:WaitForChild("HumanoidRootPart")

-- MODULES
local LoggingModule = {
    logError = function(err, context)
        warn("[ERROR] "..context..": "..err)
    end,
    safeCall = function(func, context)
        local s, r = pcall(func)
        if not s then LoggingModule.logError(r, context) end
        return s, r
    end
}

local TargetingModule = {
    getOptimalPlayer = function(maxDist, speed)
        local bestPlayer, bestTime = nil, math.huge
        local myPos = LocalPlayer.Character.HumanoidRootPart.Position
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and not p.Character:FindFirstChild("Bomb") then
                local dist = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
                if dist <= maxDist then
                    local t = dist/speed
                    if t < bestTime then
                        bestTime = t
                        bestPlayer = p
                    end
                end
            end
        end
        return bestPlayer
    end,
    getClosestPlayer = function(maxDist)
        local closest, dist = nil, maxDist
        local myPos = LocalPlayer.Character.HumanoidRootPart.Position
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and not p.Character:FindFirstChild("Bomb") then
                local d = (p.Character.HumanoidRootPart.Position - myPos).Magnitude
                if d < dist then
                    dist = d
                    closest = p
                end
            end
        end
        return closest
    end,
    rotateCharacterTowardsTarget = function() end -- Disabled
}

local VisualModule = {
    animateMarker = function(marker)
        TweenService:Create(marker, TweenInfo.new(0.5), {Size = UDim2.new(0,100,0,100)}):Play()
    end,
    playPassVFX = function(target)
        if target and target.Character then
            local p = Instance.new("Part")
            p.Anchored = true
            p.Transparency = 1
            p.CFrame = target.Character.HumanoidRootPart.CFrame
            local e = Instance.new("ParticleEmitter", p)
            e.Texture = "rbxassetid://258128463"
            game.Debris:AddItem(p, 1)
        end
    end
}

local FrictionModule = {}
do
    local originalProps = {}
    local SLIPPERY_MATERIALS = {Enum.Material.Ice, Enum.Material.Plastic, Enum.Material.Glass}

    function FrictionModule.update()
        local char = LocalPlayer.Character
        if not char then return end
        
        -- Surface check
        local ray = workspace:Raycast(HRP.Position, Vector3.new(0,-3,0), RaycastParams.new())
        if not ray or not table.find(SLIPPERY_MATERIALS, ray.Material) then return end

        -- Stealth modification
        for _, partName in pairs({"LeftLeg", "RightLeg", "LeftFoot", "RightFoot"}) do
            local part = char:FindFirstChild(partName)
            if part then
                if not originalProps[part] then
                    originalProps[part] = part.CustomPhysicalProperties
                end
                local friction = 0.18 + (math.random() * 0.03)
                if char:FindFirstChild("Bomb") then
                    friction = 0.09 + (math.random() * 0.02)
                end
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

-- MAIN FUNCTIONALITY
local config = {
    bombPassDistance = 25,
    autoPass = false,
    antiSlippery = false,
    removeHitbox = false,
    hitboxSize = 0.1
}

local function manageHitbox()
    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == "Hitbox" then
            part.Transparency = config.removeHitbox and 1 or 0
            part.CanCollide = not config.removeHitbox
            part.Size = config.removeHitbox and Vector3.new(0.1,0.1,0.1) or Vector3.new(1,1,1)
        end
    end
end

local function autoPass()
    if not config.autoPass then return end
    local bomb = LocalPlayer.Character:FindFirstChild("Bomb")
    if bomb then
        local target = TargetingModule.getOptimalPlayer(config.bombPassDistance, 16)
                      or TargetingModule.getClosestPlayer(config.bombPassDistance)
        if target then
            bomb:FindFirstChildWhichIsA("RemoteEvent"):FireServer(target.Character)
        end
    end
end

-- UI SETUP
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()
local Window = OrionLib:MakeWindow({Name = "Bomb Assistant v4", HidePremium = false})

Window:MakeTab({
    Name = "Main",
    Icon = "rbxassetid://4483345998"
}):AddToggle({
    Name = "Auto Pass",
    Default = false,
    Callback = function(v)
        config.autoPass = v
        if v then
            autoPassConnection = RunService.Stepped:Connect(autoPass)
        elseif autoPassConnection then
            autoPassConnection:Disconnect()
        end
    end
}):AddToggle({
    Name = "Anti-Slippery",
    Info = "0.18-0.21 (Normal) | 0.09-0.11 (Bomb)",
    Default = false,
    Callback = function(v)
        config.antiSlippery = v
        if not v then FrictionModule.restore() end
    end
}):AddToggle({
    Name = "Remove Hitbox",
    Default = false,
    Callback = function(v)
        config.removeHitbox = v
        manageHitbox()
    end
})

OrionLib:Init()

-- AUTOMATED SYSTEMS
task.spawn(function()
    while true do
        if config.antiSlippery then
            FrictionModule.update()
        end
        wait(0.5 + math.random())
    end
end)

RunService.Stepped:Connect(function()
    if config.autoPass then autoPass() end
    if config.removeHitbox then manageHitbox() end
end)

print("Stealth Bomb Assistant Loaded - All Systems Operational")