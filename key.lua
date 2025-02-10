--[[
    Combined Script with:
      • Bomb Passing (with distance check) – loaded later via your bomb script
      • Anti-Slippery & Remove Hitbox features – in your bomb script (loaded later)
      • A simple Key System (demo keys, runtime variables, killswitch check)
      • A custom key redemption UI (non-Orion) that appears for the user
      • Once key redemption is successful, the key UI vanishes and the bomb script is loaded via loadstring

    Adjust demo keys, URLs, and other parameters as needed.
]]--

-----------------------------------------------------
--// SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-----------------------------------------------------
--// KEY SYSTEM MODULE
local KeySystem = {}

local validKeys = {
    ["ABC123"] = {
        type = "lifetime",
        discordId = "123456789",
        note = "Test lifetime key",
        expiry = nil,
    },
    ["DAY456"] = {
        type = "day",
        discordId = "987654321",
        note = "Demo day key",
        expiry = os.time() + 86400,  -- expires in 1 day
    },
}

local function checkKillswitch()
    -- For demonstration, always return false (no killswitch active)
    return false
end

function KeySystem:RedeemKey(key)
    if checkKillswitch() then
        return false, "Script disabled by developer."
    end
    local keyData = validKeys[key]
    if keyData then
        if keyData.type == "day" and keyData.expiry and os.time() > keyData.expiry then
            return false, "Key has expired."
        end
        return true, keyData
    else
        return false, "Invalid key."
    end
end

function KeySystem:ResetHWID()
    print("HWID has been reset (placeholder).")
    return true
end

-----------------------------------------------------
--// CUSTOM KEY REDEMPTION UI (Non-Orion)
-----------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KeyRedemptionUI"
screenGui.Parent = game:GetService("CoreGui")  -- Or LocalPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Size = UDim2.new(0, 300, 0, 200)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
mainFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
mainFrame.BorderSizePixel = 0

local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Enter Your Key"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 24

local keyBox = Instance.new("TextBox", mainFrame)
keyBox.Size = UDim2.new(0.8, 0, 0, 30)
keyBox.Position = UDim2.new(0.1, 0, 0.3, 0)
keyBox.PlaceholderText = "Enter key here"
keyBox.Text = ""
keyBox.TextColor3 = Color3.new(1, 1, 1)
keyBox.ClearTextOnFocus = false
keyBox.Font = Enum.Font.GothamBold
keyBox.TextSize = 18

local redeemButton = Instance.new("TextButton", mainFrame)
redeemButton.Size = UDim2.new(0.5, 0, 0, 30)
redeemButton.Position = UDim2.new(0.25, 0, 0.6, 0)
redeemButton.Text = "Redeem Key"
redeemButton.Font = Enum.Font.GothamBold
redeemButton.TextSize = 20
redeemButton.TextColor3 = Color3.new(1, 1, 1)
redeemButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
redeemButton.BorderSizePixel = 0

local errorLabel = Instance.new("TextLabel", mainFrame)
errorLabel.Size = UDim2.new(1, 0, 0, 30)
errorLabel.Position = UDim2.new(0, 0, 0.8, 0)
errorLabel.BackgroundTransparency = 1
errorLabel.Text = ""
errorLabel.TextColor3 = Color3.new(1, 0, 0)
errorLabel.Font = Enum.Font.GothamBold
errorLabel.TextSize = 18

local discordLabel = Instance.new("TextLabel", mainFrame)
discordLabel.Size = UDim2.new(1, 0, 0, 20)
discordLabel.Position = UDim2.new(0, 0, 0.9, 0)
discordLabel.BackgroundTransparency = 1
discordLabel.Text = "Join our Discord: discord.gg/YOUR_DISCORD_LINK"
discordLabel.TextColor3 = Color3.new(1, 1, 1)
discordLabel.Font = Enum.Font.GothamBold
discordLabel.TextSize = 16

-----------------------------------------------------
--// KEY REDEMPTION LOGIC
-----------------------------------------------------
redeemButton.MouseButton1Click:Connect(function()
    local userKey = keyBox.Text
    local success, dataOrError = KeySystem:RedeemKey(userKey)
    if success then
        errorLabel.Text = ""
        -- Fade out the UI before removal
        local tween = TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
        tween:Play()
        tween.Completed:Wait()
        mainFrame:Destroy()
        screenGui:Destroy()
        print("Key redeemed successfully!")
        print("Key Data:", dataOrError)
        -- Load the bomb script after key redemption is successful
        loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Passthebomb/refs/heads/main/pass%20the%20bom%20.lua"))()
    else
        errorLabel.Text = dataOrError
    end
end)

print("Key Redemption UI loaded. Awaiting user input...")
