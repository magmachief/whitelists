-- Get required services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RbxAnalyticsService = game:GetService("RbxAnalyticsService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-----------------------------------------------------
-- Create the UI elements for key input
-----------------------------------------------------

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "KeyRedeemGui"
screenGui.Parent = playerGui

-- Create main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 200)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
mainFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
mainFrame.Parent = screenGui

-- Create an instruction label for key entry
local instructionLabel = Instance.new("TextLabel")
instructionLabel.Name = "InstructionLabel"
instructionLabel.Size = UDim2.new(0, 280, 0, 40)
instructionLabel.Position = UDim2.new(0, 10, 0, 10)
instructionLabel.BackgroundTransparency = 1
instructionLabel.Text = "Enter your key:"
instructionLabel.TextColor3 = Color3.new(1, 1, 1)
instructionLabel.Font = Enum.Font.SourceSans
instructionLabel.TextScaled = true
instructionLabel.Parent = mainFrame

-- Create a TextBox for key input
local keyBox = Instance.new("TextBox")
keyBox.Name = "KeyBox"
keyBox.Size = UDim2.new(0, 280, 0, 50)
keyBox.Position = UDim2.new(0, 10, 0, 60)
keyBox.PlaceholderText = "Enter key here..."
keyBox.Text = ""
keyBox.TextScaled = true
keyBox.Font = Enum.Font.SourceSans
keyBox.Parent = mainFrame

-- Create a button to redeem the key
local redeemButton = Instance.new("TextButton")
redeemButton.Name = "RedeemButton"
redeemButton.Size = UDim2.new(0, 280, 0, 40)
redeemButton.Position = UDim2.new(0, 10, 0, 120)
redeemButton.Text = "Redeem Key"
redeemButton.TextScaled = true
redeemButton.Font = Enum.Font.SourceSans
redeemButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
redeemButton.Parent = mainFrame

-- Create an error/feedback label
local errorLabel = Instance.new("TextLabel")
errorLabel.Name = "ErrorLabel"
errorLabel.Size = UDim2.new(0, 280, 0, 30)
errorLabel.Position = UDim2.new(0, 10, 0, 170)
errorLabel.BackgroundTransparency = 1
errorLabel.Text = ""
errorLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
errorLabel.Font = Enum.Font.SourceSans
errorLabel.TextScaled = true
errorLabel.Parent = mainFrame

-----------------------------------------------------
-- Setup API and Bomb Script URL
-----------------------------------------------------

local API_ENDPOINT = "https://71b8fa55-8e89-4098-a719-757f59aea6f7-00-1p2su3ncp5b66.riker.replit.dev:5000"
local BOMB_SCRIPT_URL = "https://raw.githubusercontent.com/magmachief/Passthebomb/refs/heads/main/pass%20the%20bom%20lua"

-- Returns a unique hardware identifier
local function getHWID()
    local userId = player.UserId
    local hwid = RbxAnalyticsService:GetClientId() -- Unique per device
    return userId .. "-" .. hwid
end

-- Verifies the key and registers HWID with the server
local function verifyKey(userKey)
    local hwid = getHWID()
    local url = API_ENDPOINT .. "/api/register_hwid"
    local payload = HttpService:JSONEncode({ key = userKey, hwid = hwid })
    
    local success, response = pcall(function()
        return HttpService:PostAsync(url, payload, Enum.HttpContentType.ApplicationJson, false)
    end)
    
    if success then
        local data = HttpService:JSONDecode(response)
        return data["success"] == true
    end
    
    return false
end

-----------------------------------------------------
-- Connect button events
-----------------------------------------------------

redeemButton.MouseButton1Click:Connect(function()
    local userKey = keyBox.Text
    local isValid = verifyKey(userKey)
    
    if isValid then
        errorLabel.Text = ""
        -- Tween the mainFrame out (fade out)
        local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(mainFrame, tweenInfo, { BackgroundTransparency = 1 })
        tween:Play()
        tween.Completed:Wait()
        
        -- Remove the entire UI (Redeem Key option)
        mainFrame:Destroy()
        screenGui:Destroy()
        
        print("Key verified! Loading bomb script...")
        loadstring(game:HttpGet(BOMB_SCRIPT_URL))()
    else
        errorLabel.Text = "Key expired or invalid. Please request a new key from your provider."
        keyBox.Text = ""
    end
end)
