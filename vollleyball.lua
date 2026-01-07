-- 修复后的完整脚本
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

-- 等待角色加载（这是关键修复！）
local character = LocalPlayer.Character
if not character then
    character = LocalPlayer.CharacterAdded:Wait()
end

local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- 改进的配置
local Config = {
    AutoHit = true,
    PredictTrajectory = true,
    AutoPosition = true,
    HitRange = 20, -- 增加到20（更实用）
    JumpPower = 50,
    PredictionTime = 0.8, -- 增加到0.8秒（更长的预测）
    HitCooldown = 0.5, -- 增加到0.5秒（防止连续击球）
    HitKey = Enum.KeyCode.E,
    DebugMode = true -- 暂时设为true以便调试
}

-- 变量
local ball = nil
local lastHitTime = 0
local predictedPosition = nil
local ballVelocityHistory = {}
local maxHistorySize = 8 -- 减小历史记录大小

-- 修复：更可靠的球场边界检测
local function detectCourtBoundaries()
    -- 尝试自动检测球场
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj.Name:find("Court") or obj.Name:find("court") or obj.Name:find("Floor") then
            local size = obj.Size
            local position = obj.Position
            return {
                MinX = position.X - size.X/2,
                MaxX = position.X + size.X/2,
                MinZ = position.Z - size.Z/2,
                MaxZ = position.Z + size.Z/2
            }
        end
    end
    -- 如果找不到，使用默认值
    return {
        MinX = -50,
        MaxX = 50,
        MinZ = -30,
        MaxZ = 30
    }
end

local courtBoundaries = detectCourtBoundaries()

-- 修复：使用Roblox原生命令栏UI而非外部库
local function createSimpleUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "VolleyballAIGUI"
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    -- 状态显示
    local StatusFrame = Instance.new("Frame")
    StatusFrame.Name = "StatusFrame"
    StatusFrame.Size = UDim2.new(0, 200, 0, 100)
    StatusFrame.Position = UDim2.new(0, 10, 0, 10)
    StatusFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    StatusFrame.BackgroundTransparency = 0.3
    StatusFrame.BorderSizePixel = 0
    StatusFrame.Parent = ScreenGui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = StatusFrame
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Name = "StatusLabel"
    StatusLabel.Size = UDim2.new(1, 0, 1, 0)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "Volleyball AI\nStatus: LOADING"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    StatusLabel.TextSize = 14
    StatusLabel.Font = Enum.Font.SourceSansBold
    StatusLabel.TextYAlignment = Enum.TextYAlignment.Center
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Center
    StatusLabel.Parent = StatusFrame
    
    return ScreenGui, StatusLabel
end

-- 创建简单的UI
local gui, statusLabel = createSimpleUI()

-- 修复：更好的球检测函数
local function findBall()
    -- 先检查常见名称
    local ballNames = {"Ball", "ball", "Volleyball", "volleyball", "Sphere", "MainBall"}
    
    for _, name in ipairs(ballNames) do
        local ballObj = Workspace:FindFirstChild(name)
        if ballObj and ballObj:IsA("BasePart") then
            return ballObj
        end
    end
    
    -- 搜索所有部件
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            -- 检查形状和大小
            if obj.Shape == Enum.PartType.Ball or 
               (obj.Name:lower():find("ball") and obj.Size.Magnitude < 10) then
                print("找到球: " .. obj.Name)
                return obj
            end
        end
    end
    
    -- 检查模型
    for _, model in pairs(Workspace:GetChildren()) do
        if model:IsA("Model") and (model.Name:lower():find("ball") or model.Name:lower():find("volley")) then
            for _, part in pairs(model:GetChildren()) do
                if part:IsA("BasePart") then
                    print("在模型中找到球: " .. model.Name)
                    return part
                end
            end
        end
    end
    
    return nil
end

-- 修复：简化的轨迹计算
local function calculateTrajectory(ballPart, timeAhead)
    if not ballPart or not ballPart:IsA("BasePart") then
        return nil
    end
    
    local position = ballPart.Position
    local velocity = ballPart.Velocity
    
    -- 更简单的预测，仅使用当前速度
    local gravity = Workspace.Gravity
    local time = timeAhead
    
    -- 基本抛物线运动
    local predictedX = position.X + velocity.X * time
    local predictedY = position.Y + velocity.Y * time - 0.5 * gravity * time * time
    local predictedZ = position.Z + velocity.Z * time
    
    -- 确保球不会预测到地底
    if predictedY < 2 then
        predictedY = 2
    end
    
    -- 保持在球场内
    predictedX = math.clamp(predictedX, courtBoundaries.MinX, courtBoundaries.MaxX)
    predictedZ = math.clamp(predictedZ, courtBoundaries.MinZ, courtBoundaries.MaxZ)
    
    return Vector3.new(predictedX, predictedY, predictedZ)
end

-- 简化：判断是否在我方半场
local function isBallOnMySide(ballPos)
    -- 基于角色位置判断
    local myPos = rootPart.Position
    return ballPos.Z <= myPos.Z + 5  -- 灵活边界
end

-- 简化：移动函数
local function moveToPosition(targetPos)
    if not Config.AutoPosition or not humanoid then
        return
    end
    
    local distance = (targetPos - rootPart.Position).Magnitude
    if distance > 3 then
        humanoid:MoveTo(targetPos)
        return true
    end
    return false
end

-- 修复：击球条件检查
local function shouldHitBall()
    if not Config.AutoHit then
        return false
    end
    
    -- 冷却时间检查
    local currentTime = tick()
    if currentTime - lastHitTime < Config.HitCooldown then
        return false
    end
    
    if not ball or not ball:IsA("BasePart") then
        return false
    end
    
    local ballPos = ball.Position
    local myPos = rootPart.Position
    local distance = (ballPos - myPos).Magnitude
    
    -- 球是否在我方半场
    if not isBallOnMySide(ballPos) then
        return false
    end
    
    -- 是否在击球范围内
    if distance > Config.HitRange then
        return false
    end
    
    -- 球的高度是否合适（不在地面）
    if ballPos.Y < 3 then
        return false
    end
    
    -- 球是否在上升或下降的合适阶段
    if ball.Velocity.Y > 30 then  -- 上升太快
        return false
    end
    
    return true
end

-- 修复：击球函数
local function simulateHit()
    if not shouldHitBall() then
        return
    end
    
    print("尝试击球...")
    
    -- 轻微延迟以便定位
    wait(0.05)
    
    -- 尝试按下击球键
    local success, errorMsg = pcall(function()
        game:GetService("VirtualInputManager"):SendKeyEvent(true, Config.HitKey, false, nil)
        wait(0.05)
        game:GetService("VirtualInputManager"):SendKeyEvent(false, Config.HitKey, false, nil)
    end)
    
    if not success then
        print("击球失败: " .. tostring(errorMsg))
    else
        print("击球成功!")
    end
    
    lastHitTime = tick()
end

-- 修复：简化的主循环
local function mainLoop()
    -- 更新球引用
    if not ball or not ball.Parent then
        ball = findBall()
        if ball then
            statusLabel.Text = "Volleyball AI\n球已找到!\n状态: ACTIVE"
        else
            statusLabel.Text = "Volleyball AI\n寻找球中...\n状态: SEARCHING"
        end
    end
    
    if ball and Config.PredictTrajectory then
        -- 计算预测位置
        predictedPosition = calculateTrajectory(ball, Config.PredictionTime)
        
        if predictedPosition then
            -- 移动到最佳位置
            if Config.AutoPosition then
                local moved = moveToPosition(predictedPosition)
                
                -- 如果靠近球且球在合适位置，尝试击球
                local distanceToBall = (ball.Position - rootPart.Position).Magnitude
                if distanceToBall < Config.HitRange and Config.AutoHit then
                    simulateHit()
                end
            end
        end
    end
end

-- 创建控制按钮
local function createControlButtons()
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Name = "ControlButtons"
    buttonFrame.Size = UDim2.new(0, 120, 0, 150)
    buttonFrame.Position = UDim2.new(0, 10, 0, 120)
    buttonFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    buttonFrame.BackgroundTransparency = 0.3
    buttonFrame.BorderSizePixel = 0
    buttonFrame.Parent = gui
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = buttonFrame
    
    -- 自动击球开关
    local autoHitButton = Instance.new("TextButton")
    autoHitButton.Name = "AutoHitToggle"
    autoHitButton.Size = UDim2.new(0.8, 0, 0.2, 0)
    autoHitButton.Position = UDim2.new(0.1, 0, 0.1, 0)
    autoHitButton.BackgroundColor3 = Config.AutoHit and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
    autoHitButton.Text = Config.AutoHit and "自动击球: ON" or "自动击球: OFF"
    autoHitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoHitButton.TextSize = 12
    autoHitButton.Font = Enum.Font.SourceSansBold
    autoHitButton.Parent = buttonFrame
    
    autoHitButton.MouseButton1Click:Connect(function()
        Config.AutoHit = not Config.AutoHit
        autoHitButton.BackgroundColor3 = Config.AutoHit and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
        autoHitButton.Text = Config.AutoHit and "自动击球: ON" or "自动击球: OFF"
        print("自动击球: " .. (Config.AutoHit and "开启" or "关闭"))
    end)
    
    -- 自动走位开关
    local autoPosButton = Instance.new("TextButton")
    autoPosButton.Name = "AutoPosToggle"
    autoPosButton.Size = UDim2.new(0.8, 0, 0.2, 0)
    autoPosButton.Position = UDim2.new(0.1, 0, 0.35, 0)
    autoPosButton.BackgroundColor3 = Config.AutoPosition and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
    autoPosButton.Text = Config.AutoPosition and "自动走位: ON" or "自动走位: OFF"
    autoPosButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoPosButton.TextSize = 12
    autoPosButton.Font = Enum.Font.SourceSansBold
    autoPosButton.Parent = buttonFrame
    
    autoPosButton.MouseButton1Click:Connect(function()
        Config.AutoPosition = not Config.AutoPosition
        autoPosButton.BackgroundColor3 = Config.AutoPosition and Color3.fromRGB(0, 180, 0) or Color3.fromRGB(180, 0, 0)
        autoPosButton.Text = Config.AutoPosition and "自动走位: ON" or "自动走位: OFF"
        print("自动走位: " .. (Config.AutoPosition and "开启" or "关闭"))
    end)
    
    -- 关闭按钮
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0.8, 0, 0.2, 0)
    closeButton.Position = UDim2.new(0.1, 0, 0.6, 0)
    closeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 180)
    closeButton.Text = "关闭脚本"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextSize = 12
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.Parent = buttonFrame
    
    closeButton.MouseButton1Click:Connect(function()
        gui:Destroy()
        script:Destroy()
        print("脚本已关闭")
    end)
end

-- 设置热键
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.RightShift then
        Config.AutoHit = not Config.AutoHit
        print("自动击球: " .. (Config.AutoHit and "开启" or "关闭"))
    end
    
    if input.KeyCode == Enum.KeyCode.Insert then
        gui:Destroy()
        script:Destroy()
    end
end)

-- 角色添加事件
LocalPlayer.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = newChar:WaitForChild("Humanoid")
    rootPart = newChar:WaitForChild("HumanoidRootPart")
    print("新角色已加载")
end)

-- 启动脚本
createControlButtons()
print("Volleyball Legends AI 已加载!")
print("使用说明:")
print("1. 右Shift键: 切换自动击球")
print("2. Insert键: 关闭脚本")
print("3. 点击UI按钮控制功能")

-- 启动主循环
RunService.Heartbeat:Connect(mainLoop)
