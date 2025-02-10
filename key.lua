-- Get required services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-----------------------------------------------------
-- Create the UI elements for login
-----------------------------------------------------

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LoginGui"
screenGui.Parent = playerGui

-- Create main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 280)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -140)
mainFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
mainFrame.Parent = screenGui

-- Create a label for username
local usernameLabel = Instance.new("TextLabel")
usernameLabel.Name = "UsernameLabel"
usernameLabel.Size = UDim2.new(0, 280, 0, 30)
usernameLabel.Position = UDim2.new(0, 10, 0, 10)
usernameLabel.BackgroundTransparency = 1
usernameLabel.Text = "Enter your username:"
usernameLabel.TextColor3 = Color3.new(1, 1, 1)
usernameLabel.Font = Enum.Font.SourceSans
usernameLabel.TextScaled = true
usernameLabel.Parent = mainFrame

-- Create a TextBox for username input
local usernameBox = Instance.new("TextBox")
usernameBox.Name = "UsernameBox"
usernameBox.Size = UDim2.new(0, 280, 0, 40)
usernameBox.Position = UDim2.new(0, 10, 0, 50)
usernameBox.PlaceholderText = "Username"
usernameBox.Text = ""
usernameBox.TextScaled = true
usernameBox.Font = Enum.Font.SourceSans
usernameBox.Parent = mainFrame

-- Create a label for password
local passwordLabel = Instance.new("TextLabel")
passwordLabel.Name = "PasswordLabel"
passwordLabel.Size = UDim2.new(0, 280, 0, 30)
passwordLabel.Position = UDim2.new(0, 10, 0, 100)
passwordLabel.BackgroundTransparency = 1
passwordLabel.Text = "Enter your password:"
passwordLabel.TextColor3 = Color3.new(1, 1, 1)
passwordLabel.Font = Enum.Font.SourceSans
passwordLabel.TextScaled = true
passwordLabel.Parent = mainFrame

-- Create a TextBox for password input
local passwordBox = Instance.new("TextBox")
passwordBox.Name = "PasswordBox"
passwordBox.Size = UDim2.new(0, 280, 0, 40)
passwordBox.Position = UDim2.new(0, 10, 0, 140)
passwordBox.PlaceholderText = "Password"
passwordBox.Text = ""
passwordBox.TextScaled = true
passwordBox.Font = Enum.Font.SourceSans
-- Optionally, implement text masking for a password (this example leaves the text as-is)
passwordBox.Parent = mainFrame

-- Create a button for login
local loginButton = Instance.new("TextButton")
loginButton.Name = "LoginButton"
loginButton.Size = UDim2.new(0, 280, 0, 40)
loginButton.Position = UDim2.new(0, 10, 0, 190)
loginButton.Text = "Login"
loginButton.TextScaled = true
loginButton.Font = Enum.Font.SourceSans
loginButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
loginButton.Parent = mainFrame

-- Create an error/feedback label
local errorLabel = Instance.new("TextLabel")
errorLabel.Name = "ErrorLabel"
errorLabel.Size = UDim2.new(0, 280, 0, 30)
errorLabel.Position = UDim2.new(0, 10, 0, 240)
errorLabel.BackgroundTransparency = 1
errorLabel.Text = ""
errorLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
errorLabel.Font = Enum.Font.SourceSans
errorLabel.TextScaled = true
errorLabel.Parent = mainFrame

-----------------------------------------------------
-- Setup Bomb Script URL and valid credentials
-----------------------------------------------------

local BOMB_SCRIPT_URL = "https://raw.githubusercontent.com/magmachief/Passthebomb/refs/heads/main/finalpassbomb.lua"

-- Set your valid credentials (change these values as needed)
local VALID_USERNAME = "Jiwoo"
local VALID_PASSWORD = "Koreans2007"

-----------------------------------------------------
-- Connect login button event
-----------------------------------------------------

loginButton.MouseButton1Click:Connect(function()
    local enteredUsername = usernameBox.Text
    local enteredPassword = passwordBox.Text

    if enteredUsername == VALID_USERNAME and enteredPassword == VALID_PASSWORD then
        errorLabel.Text = "Login successful! Loading script..."
        wait(1)  -- Brief pause to display the confirmation message
        
        -- Tween the mainFrame out (fade out)
        local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(mainFrame, tweenInfo, { BackgroundTransparency = 1 })
        tween:Play()
        tween.Completed:Wait()
        
        -- Remove the UI
        mainFrame:Destroy()
        screenGui:Destroy()
        
        print("Login successful! Loading bomb script...")
        loadstring(game:HttpGet(BOMB_SCRIPT_URL))()
    else
        errorLabel.Text = "Invalid credentials. You are blacklisted."
        wait(1)
        -- Kick the player from the game
        player:Kick("Invalid credentials. You have been blacklisted.")
    end
end)
