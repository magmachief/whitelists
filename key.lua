--------------------------------------------------------------------------------
-- Minimal Custom GUI Version (No OrionLib)
--------------------------------------------------------------------------------

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- GLOBAL VARS
local bombPassDistance = 10
local AutoPassEnabled = false
local AntiSlipperyEnabled = false
local RemoveHitboxEnabled = false
local AI_AssistanceEnabled = false
local pathfindingSpeed = 16
local raySpreadAngle = 10
local numRaycasts = 5
local customAntiSlipperyFriction = 0.7
local customHitboxSize = 0.1
local autoFarmCoinsEnabled = false
local coinFarmInterval = 1
local autoCrateOpenEnabled = false
local crateOpenInterval = 2
local crateName = "Rainbow Crate"

--------------------------------------------------------------------------------
-- CORE LOGIC (AutoPass, AntiSlippery, Farming, etc.) 
-- (same logic as before, just shortened)
--------------------------------------------------------------------------------

-- We'll keep the logic extremely short to demonstrate:
local function autoPassBomb() end  -- pretend function
local function updateFriction() end -- pretend function
local function removeHitbox(value) end -- pretend
local function autoFarmCoins() end -- pretend
local function autoFarmCrates() end -- pretend

-- SHIFTLOCK
local ShiftLockGui = Instance.new("ScreenGui")
ShiftLockGui.Name = "ShiftLockGui"
ShiftLockGui.Parent = game.CoreGui
ShiftLockGui.ResetOnSpawn = false

local ShiftLockBtn = Instance.new("TextButton")
ShiftLockBtn.Size = UDim2.new(0,80,0,30)
ShiftLockBtn.Position = UDim2.new(0, 10, 0.8, 0)
ShiftLockBtn.BackgroundColor3 = Color3.fromRGB(255,0,0)
ShiftLockBtn.Text = "ShiftLock OFF"
ShiftLockBtn.Parent = ShiftLockGui

local SL_Active = false
ShiftLockBtn.MouseButton1Click:Connect(function()
    SL_Active = not SL_Active
    ShiftLockBtn.Text = SL_Active and "ShiftLock ON" or "ShiftLock OFF"
    -- Shiftlock logic can be done here
end)

--------------------------------------------------------------------------------
-- CUSTOM GUI (No OrionLib)
--------------------------------------------------------------------------------

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CustomMenuGui"
ScreenGui.Parent = game.CoreGui  -- or LocalPlayer.PlayerGui if you prefer

-- MAIN FRAME
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 250, 0, 350)
MainFrame.Position = UDim2.new(0, 20, 0, 20)
MainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
MainFrame.BorderSizePixel = 2
MainFrame.Parent = ScreenGui

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1,0,0,30)
TitleLabel.BackgroundColor3 = Color3.fromRGB(60,60,60)
TitleLabel.Text = "Minimal Bomb Menu"
TitleLabel.TextColor3 = Color3.fromRGB(255,255,255)
TitleLabel.Parent = MainFrame

--------------------------------------------------------------------------------
-- 1) AUTO PASS BOMB TOGGLE
--------------------------------------------------------------------------------
local AutoPassToggle = Instance.new("TextButton")
AutoPassToggle.Size = UDim2.new(1, -10, 0, 30)
AutoPassToggle.Position = UDim2.new(0, 5, 0, 40)
AutoPassToggle.BackgroundColor3 = Color3.fromRGB(100,0,0)
AutoPassToggle.TextColor3 = Color3.fromRGB(255,255,255)
AutoPassToggle.Text = "Auto Pass: OFF"
AutoPassToggle.Parent = MainFrame

AutoPassToggle.MouseButton1Click:Connect(function()
    AutoPassEnabled = not AutoPassEnabled
    AutoPassToggle.Text = AutoPassEnabled and "Auto Pass: ON" or "Auto Pass: OFF"
    AutoPassToggle.BackgroundColor3 = AutoPassEnabled and Color3.fromRGB(0,150,0) or Color3.fromRGB(100,0,0)
    -- If ON, connect your auto pass logic
    if AutoPassEnabled then
        print("Auto pass bomb is ON")
    else
        print("Auto pass bomb is OFF")
    end
end)

--------------------------------------------------------------------------------
-- 2) ANTI SLIPPERY TOGGLE
--------------------------------------------------------------------------------
local AntiSlipToggle = Instance.new("TextButton")
AntiSlipToggle.Size = UDim2.new(1, -10, 0, 30)
AntiSlipToggle.Position = UDim2.new(0, 5, 0, 80)
AntiSlipToggle.BackgroundColor3 = Color3.fromRGB(100,0,0)
AntiSlipToggle.TextColor3 = Color3.fromRGB(255,255,255)
AntiSlipToggle.Text = "Anti Slippery: OFF"
AntiSlipToggle.Parent = MainFrame

AntiSlipToggle.MouseButton1Click:Connect(function()
    AntiSlipperyEnabled = not AntiSlipperyEnabled
    AntiSlipToggle.Text = AntiSlipperyEnabled and "Anti Slippery: ON" or "Anti Slippery: OFF"
    AntiSlipToggle.BackgroundColor3 = AntiSlipperyEnabled and Color3.fromRGB(0,150,0) or Color3.fromRGB(100,0,0)
    -- connect friction logic
end)

--------------------------------------------------------------------------------
-- 3) REMOVE HITBOX TOGGLE
--------------------------------------------------------------------------------
local RemoveHitboxToggle = Instance.new("TextButton")
RemoveHitboxToggle.Size = UDim2.new(1, -10, 0, 30)
RemoveHitboxToggle.Position = UDim2.new(0, 5, 0, 120)
RemoveHitboxToggle.BackgroundColor3 = Color3.fromRGB(100,0,0)
RemoveHitboxToggle.TextColor3 = Color3.fromRGB(255,255,255)
RemoveHitboxToggle.Text = "Remove Hitbox: OFF"
RemoveHitboxToggle.Parent = MainFrame

RemoveHitboxToggle.MouseButton1Click:Connect(function()
    RemoveHitboxEnabled = not RemoveHitboxEnabled
    RemoveHitboxToggle.Text = RemoveHitboxEnabled and "Remove Hitbox: ON" or "Remove Hitbox: OFF"
    RemoveHitboxToggle.BackgroundColor3 = RemoveHitboxEnabled and Color3.fromRGB(0,150,0) or Color3.fromRGB(100,0,0)
    -- connect removeHitbox logic
end)

--------------------------------------------------------------------------------
-- 4) FARMING COINS TOGGLE
--------------------------------------------------------------------------------
local FarmCoinsToggle = Instance.new("TextButton")
FarmCoinsToggle.Size = UDim2.new(1, -10, 0, 30)
FarmCoinsToggle.Position = UDim2.new(0, 5, 0, 160)
FarmCoinsToggle.BackgroundColor3 = Color3.fromRGB(100,0,0)
FarmCoinsToggle.TextColor3 = Color3.fromRGB(255,255,255)
FarmCoinsToggle.Text = "Farm Coins: OFF"
FarmCoinsToggle.Parent = MainFrame

FarmCoinsToggle.MouseButton1Click:Connect(function()
    autoFarmCoinsEnabled = not autoFarmCoinsEnabled
    FarmCoinsToggle.Text = autoFarmCoinsEnabled and "Farm Coins: ON" or "Farm Coins: OFF"
    FarmCoinsToggle.BackgroundColor3 = autoFarmCoinsEnabled and Color3.fromRGB(0,150,0) or Color3.fromRGB(100,0,0)
    if autoFarmCoinsEnabled then
        print("Coin farming on")
    else
        print("Coin farming off")
    end
end)

--------------------------------------------------------------------------------
-- 5) FARMING CRATES TOGGLE
--------------------------------------------------------------------------------
local FarmCratesToggle = Instance.new("TextButton")
FarmCratesToggle.Size = UDim2.new(1, -10, 0, 30)
FarmCratesToggle.Position = UDim2.new(0, 5, 0, 200)
FarmCratesToggle.BackgroundColor3 = Color3.fromRGB(100,0,0)
FarmCratesToggle.TextColor3 = Color3.fromRGB(255,255,255)
FarmCratesToggle.Text = "Farm Crates: OFF"
FarmCratesToggle.Parent = MainFrame

FarmCratesToggle.MouseButton1Click:Connect(function()
    autoCrateOpenEnabled = not autoCrateOpenEnabled
    FarmCratesToggle.Text = autoCrateOpenEnabled and "Farm Crates: ON" or "Farm Crates: OFF"
    FarmCratesToggle.BackgroundColor3 = autoCrateOpenEnabled and Color3.fromRGB(0,150,0) or Color3.fromRGB(100,0,0)
end)

--------------------------------------------------------------------------------
print("Minimal Custom GUI loaded. No external library used.")