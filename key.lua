-- Get required services
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-- Define API endpoint and bomb script URL
local API_ENDPOINT = "https://71b8fa55-8e89-4098-a719-757f59aea6f7-00-1p2su3ncp5b66.riker.replit.dev:5000"
local BOMB_SCRIPT_URL = "https://raw.githubusercontent.com/magmachief/Passthebomb/refs/heads/main/pass%20the%20bom%20lua"

-- Returns a unique hardware identifier
local function getHWID()
    local userId = Players.LocalPlayer.UserId
    local hwid = game:GetService("RbxAnalyticsService"):GetClientId() -- Unique per device
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

-- Handle redeem button click
redeemButton.MouseButton1Click:Connect(function()
    local userKey = keyBox.Text
    local isValid = verifyKey(userKey)

    if isValid then
        errorLabel.Text = ""
        local tween = TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
        tween:Play()
        tween.Completed:Wait()
        mainFrame:Destroy()
        screenGui:Destroy()

        print("Key and HWID verified! Loading bomb script...")
        loadstring(game:HttpGet(BOMB_SCRIPT_URL))()
    else
        errorLabel.Text = "Invalid or HWID mismatch!"
    end
end)
