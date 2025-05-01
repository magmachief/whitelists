-----------------------------------------------------
-- Ultra Advanced Bomb Passing Script (Precision Edition)
-- Client-Side Execution
-----------------------------------------------------

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local bombName = "Bomb"

-- CHARACTER REFERENCES
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

    -- Server-recognized micro-adjustments
    local microMovements = {
        Vector3.new(0.0001, 0, 0.0001),
        Vector3.new(-0.0001, 0, -0.0001)
    }

    for i = 1, 2 do -- Double rotation sequence
        -- Body rotation
        humanoid.AutoRotate = false
        hrp.CFrame = CFrame.lookAt(hrp.Position, targetPos)
        task.wait(0.05)
        
        -- Head emphasis
        local head = char:FindFirstChild("Head")
        if head then
            local weld = head:FindFirstChildOfClass("Weld")
            if weld then
                local angle = ROTATION_ANGLE[i % #ROTATION_ANGLES + 1]
                weld.C0 = weld.C0 * CFrame.Angles(0, math.rad(angle), 0)
                task.delay(0.2, function()
                    weld.C0 = weld.C0 * CFrame.Angles(0, math.rad(-angle), 0)
                end)
            end
        end

        -- Micro-movement sync
        humanoid:MoveTo(hrp.Position + microMovements[i % #microMovements + 1])
        task.wait(0.02)
        humanoid:MoveTo(hrp.Position)
    end
    humanoid.AutoRotate = true
end

-----------------------------------------------------
-- TARGETING MODULE
-----------------------------------------------------
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

-----------------------------------------------------
-- AUTO PASS CORE FUNCTION
-----------------------------------------------------
local AutoPassEnabled = false
local bombPassDistance = 15

local function autoPassBomb()
    if not AutoPassEnabled then return end
    
    pcall(function()
        local bomb = LocalPlayer.Character:FindFirstChild(bombName)
        if not bomb then return end
        
        local bombEvent = bomb:FindFirstChild("RemoteEvent")
        if not bombEvent then return end
        
        local closestPlayer = TargetingModule.getClosestPlayer()
        if not closestPlayer or not closestPlayer.Character then return end
        
        local targetHrp = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetHrp then return end
        
        local distance = (targetHrp.Position - HRP.Position).Magnitude
        if distance <= bombPassDistance then
            -- Execute precision rotation
            executePrecisionRotation(targetHrp.Position)
            
            -- Immediate precise pass
            bombEvent:FireServer(closestPlayer.Character, closestPlayer.Character:FindFirstChild("CollisionPart"))
            
            -- Post-pass stabilization
            task.wait(0.05)
            HUMANOID:MoveTo(HRP.Position)
        end
    end)
end

-----------------------------------------------------
-- UI CONTROL SYSTEM
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
local au = Window:MakeTab({ Name = "Automated Settings", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local AITab = Window:MakeTab({ Name = "AI Based Settings", Icon = "rbxassetid://7072720870", PremiumOnly = false })
local UITab = Window:MakeTab({ Name = "UI Elements", Icon = "rbxassetid://4483345998", PremiumOnly = false })

-- Main Toggle
AutomatedTab:AddLabel("== Bomb Passing ==", 15)
local orionAutoPassToggle = AutomatedTab:AddToggle({
    Name = "Auto Pass Bomb",
    Default = AutoPassEnabled,
    Flag = "AutoPassBomb",
    Callback = function(value)
        AutoPassEnabled = value
        if value then
            RunService.Stepped:Connect(autoPassBomb)
        else
            RunService.Stepped:Disconnect()
        end
    end
})


-- Distance Control
au:AddTextbox({
    Name = "Pass Distance",
    Min = 10,
    Max = 50,
    Default = 15,
    Color = Color3.fromRGB(255,0,0),
    Increment = 1,
    Callback = function(value)
        bombPassDistance = value
    end
})

OrionLib:Init()

-----------------------------------------------------
-- SHIFTLOCK INTEGRATION (Optional)
-----------------------------------------------------
local shiftLockActive = false

local function toggleShiftLock()
    shiftLockActive = not shiftLockActive
    HUMANOID.AutoRotate = not shiftLockActive
end

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        toggleShiftLock()
    end
end)

print("Precision Bomb Pass System Active")