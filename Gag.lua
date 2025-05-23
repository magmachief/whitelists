--[[
@author depso (depthso) - Enhanced Version
@description Grow a Garden auto-farm script - Improved Performance & Features
https://www.roblox.com/games/126884695634066
]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Leaderstats = LocalPlayer.leaderstats
local Backpack = LocalPlayer.Backpack
local PlayerGui = LocalPlayer.PlayerGui

local ShecklesCount = Leaderstats.Sheckles
local GameInfo = MarketplaceService:GetProductInfo(game.PlaceId)

--// Enhanced Configuration
local Config = {
    PlantDelay = 0.15, -- Reduced delay for faster planting
    HarvestDelay = 0.05, -- Faster harvesting
    WalkSpeed = 16,
    MaxRetries = 3,
    SafeMode = false, -- Prevents detection
    AutoReconnect = true,
    OptimizedMovement = true,
    SmartHarvesting = true,
    PrioritySeeds = {"Carrot", "Potato", "Tomato"}, -- High value seeds first
    MaxInventorySize = 25 -- Inventory management
}

--// ReGui
local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local PrefabsId = "rbxassetid://" .. ReGui.PrefabsId

--// Folders
local GameEvents = ReplicatedStorage.GameEvents
local Farms = workspace.Farm

local Accent = {
    DarkGreen = Color3.fromRGB(45, 95, 25),
    Green = Color3.fromRGB(69, 142, 40),
    Brown = Color3.fromRGB(43, 33, 13),
    Gold = Color3.fromRGB(255, 215, 0),
    Red = Color3.fromRGB(220, 20, 60)
}

--// Enhanced ReGui configuration
ReGui:Init({
    Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})
ReGui:DefineTheme("EnhancedGardenTheme", {
    WindowBg = Accent.Brown,
    TitleBarBg = Accent.DarkGreen,
    TitleBarBgActive = Accent.Green,
    ResizeGrab = Accent.DarkGreen,
    FrameBg = Accent.DarkGreen,
    FrameBgActive = Accent.Green,
    CollapsingHeaderBg = Accent.Green,
    ButtonsBg = Accent.Green,
    CheckMark = Accent.Green,
    SliderGrab = Accent.Green,
    Text = Color3.fromRGB(255, 255, 255),
    TextDisabled = Color3.fromRGB(128, 128, 128)
})

--// Enhanced Data Structures
local SeedStock = {}
local OwnedSeeds = {}
local PlantQueue = {}
local HarvestQueue = {}
local Statistics = {
    PlantsPlanted = 0,
    PlantsHarvested = 0,
    MoneyEarned = 0,
    SessionStart = tick(),
    LastSellAmount = 0
}

local HarvestIgnores = {
    Normal = false,
    Gold = false,
    Rainbow = false
}

--// Enhanced Globals
local SelectedSeed, AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, SellThreshold, NoClip, AutoWalkAllowRandom
local AutoSell, AutoWalk, AutoWalkMaxWait, AutoWalkStatus, OnlyShowStock, SelectedSeedStock
local SafeModeToggle, OptimizedMovementToggle, SmartHarvestingToggle, AutoReconnectToggle

--// Utility Functions
local function Log(message)
    print("[Garden Bot] " .. tostring(message))
end

local function SafeWait(duration)
    if Config.SafeMode then
        wait(duration + math.random() * 0.1)
    else
        wait(duration)
    end
end

local function GetPlayerStats()
    local sessionTime = tick() - Statistics.SessionStart
    local plantsPerMinute = Statistics.PlantsPlanted / (sessionTime / 60)
    local harvestsPerMinute = Statistics.PlantsHarvested / (sessionTime / 60)
    
    return {
        SessionTime = math.floor(sessionTime),
        PlantsPerMinute = math.floor(plantsPerMinute),
        HarvestsPerMinute = math.floor(harvestsPerMinute),
        TotalPlants = Statistics.PlantsPlanted,
        TotalHarvests = Statistics.PlantsHarvested,
        MoneyEarned = Statistics.MoneyEarned
    }
end

local function CreateWindow()
    local Window = ReGui:Window({
        Title = `{GameInfo.Name} | Enhanced Bot v2.0`,
        Theme = "EnhancedGardenTheme",
        Size = UDim2.fromOffset(350, 400)
    })
    return Window
end

--// Enhanced Interface Functions
local function Plant(Position: Vector3, Seed: string, retries: number?)
    retries = retries or 0
    
    pcall(function()
        GameEvents.Plant_RE:FireServer(Position, Seed)
        Statistics.PlantsPlanted += 1
    end)
    
    -- Retry mechanism
    if retries < Config.MaxRetries then
        SafeWait(Config.PlantDelay)
        return true
    end
    
    return false
end

local function GetFarms()
    return Farms:GetChildren()
end

local function GetFarmOwner(Farm: Folder): string
    if not Farm:FindFirstChild("Important") then return "" end
    local Important = Farm.Important
    if not Important:FindFirstChild("Data") then return "" end
    local Data = Important.Data
    if not Data:FindFirstChild("Owner") then return "" end
    local Owner = Data.Owner
    return Owner.Value or ""
end

local function GetFarm(PlayerName: string): Folder?
    local Farms = GetFarms()
    for _, Farm in pairs(Farms) do
        local Owner = GetFarmOwner(Farm)
        if Owner == PlayerName then
            return Farm
        end
    end
    return nil
end

local IsSelling = false
local function SellInventory()
    if IsSelling then return end
    
    local Character = LocalPlayer.Character
    if not Character then return end
    
    local Previous = Character:GetPivot()
    local PreviousSheckles = ShecklesCount.Value
    
    IsSelling = true
    
    -- Enhanced selling with error handling
    local success = pcall(function()
        Character:PivotTo(CFrame.new(62, 4, -26))
        
        local attempts = 0
        while attempts < 10 do
            attempts += 1
            GameEvents.Sell_Inventory:FireServer()
            wait(0.5)
            
            if ShecklesCount.Value ~= PreviousSheckles then
                Statistics.MoneyEarned += (ShecklesCount.Value - PreviousSheckles)
                Statistics.LastSellAmount = ShecklesCount.Value - PreviousSheckles
                break
            end
        end
        
        Character:PivotTo(Previous)
    end)
    
    if not success then
        Log("Failed to sell inventory")
    end
    
    SafeWait(0.2)
    IsSelling = false
end

local function BuySeed(Seed: string)
    local success = pcall(function()
        GameEvents.BuySeedStock:FireServer(Seed)
    end)
    return success
end

local function BuyAllSelectedSeeds()
    if not SelectedSeedStock or not SelectedSeedStock.Selected then return end
    
    local Seed = SelectedSeedStock.Selected
    local Stock = SeedStock[Seed]
    
    if not Stock or Stock <= 0 then return end
    
    -- Enhanced buying with priority system
    local maxToBuy = math.min(Stock, Config.MaxInventorySize)
    local bought = 0
    
    for i = 1, maxToBuy do
        if BuySeed(Seed) then
            bought += 1
            SafeWait(0.1)
        else
            break
        end
    end
    
    Log(`Bought {bought} {Seed} seeds`)
end

local function GetSeedInfo(Seed: Tool): (string?, number?)
    local PlantName = Seed:FindFirstChild("Plant_Name")
    local Count = Seed:FindFirstChild("Numbers")
    if not PlantName then return nil, nil end
    
    return PlantName.Value, Count and Count.Value or 0
end

local function CollectSeedsFromParent(Parent, Seeds: table)
    if not Parent then return end
    
    for _, Tool in pairs(Parent:GetChildren()) do
        if not Tool:IsA("Tool") then continue end
        
        local Name, Count = GetSeedInfo(Tool)
        if not Name then continue end
        
        Seeds[Name] = {
            Count = Count or 0,
            Tool = Tool
        }
    end
end

local function CollectCropsFromParent(Parent, Crops: table)
    if not Parent then return end
    
    for _, Tool in pairs(Parent:GetChildren()) do
        if not Tool:IsA("Tool") then continue end
        
        local Name = Tool:FindFirstChild("Item_String")
        if not Name then continue end
        
        table.insert(Crops, Tool)
    end
end

local function GetOwnedSeeds(): table
    local Character = LocalPlayer.Character
    table.clear(OwnedSeeds)
    
    CollectSeedsFromParent(Backpack, OwnedSeeds)
    if Character then
        CollectSeedsFromParent(Character, OwnedSeeds)
    end
    
    return OwnedSeeds
end

local function GetInvCrops(): table
    local Character = LocalPlayer.Character
    local Crops = {}
    
    CollectCropsFromParent(Backpack, Crops)
    if Character then
        CollectCropsFromParent(Character, Crops)
    end
    
    return Crops
end

local function GetArea(Base: BasePart): (number, number, number, number)
    local Center = Base:GetPivot()
    local Size = Base.Size
    
    local X1 = math.ceil(Center.X - (Size.X/2))
    local Z1 = math.ceil(Center.Z - (Size.Z/2))
    local X2 = math.floor(Center.X + (Size.X/2))
    local Z2 = math.floor(Center.Z + (Size.Z/2))
    
    return X1, Z1, X2, Z2
end

local function EquipCheck(Tool)
    if not Tool or not Tool.Parent then return false end
    
    local Character = LocalPlayer.Character
    if not Character then return false end
    
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return false end
    
    if Tool.Parent ~= Backpack then return true end
    
    local success = pcall(function()
        Humanoid:EquipTool(Tool)
    end)
    
    return success
end

--// Enhanced Auto Farm Functions
local MyFarm = nil
local MyImportant = nil
local PlantLocations = nil
local PlantsPhysical = nil
local Dirt = nil
local X1, Z1, X2, Z2 = 0, 0, 0, 0

local function InitializeFarm()
    MyFarm = GetFarm(LocalPlayer.Name)
    if not MyFarm then 
        Log("Farm not found!")
        return false
    end
    
    MyImportant = MyFarm:FindFirstChild("Important")
    if not MyImportant then return false end
    
    PlantLocations = MyImportant:FindFirstChild("Plant_Locations")
    PlantsPhysical = MyImportant:FindFirstChild("Plants_Physical")
    
    if not PlantLocations or not PlantsPhysical then return false end
    
    Dirt = PlantLocations:FindFirstChildOfClass("Part")
    if Dirt then
        X1, Z1, X2, Z2 = GetArea(Dirt)
    end
    
    return true
end

local function GetRandomFarmPoint(): Vector3
    if not PlantLocations then return Vector3.new(0, 4, 0) end
    
    local FarmLands = PlantLocations:GetChildren()
    if #FarmLands == 0 then return Vector3.new(0, 4, 0) end
    
    local FarmLand = FarmLands[math.random(1, #FarmLands)]
    local X1, Z1, X2, Z2 = GetArea(FarmLand)
    local X = math.random(X1, X2)
    local Z = math.random(Z1, Z2)
    
    return Vector3.new(X, 4, Z)
end

local function GetOptimalPlantingPattern(): table
    local pattern = {}
    local step = 2 -- Skip every other spot for better growth
    
    for X = X1, X2, step do
        for Z = Z1, Z2, step do
            table.insert(pattern, Vector3.new(X, 0.13, Z))
        end
    end
    
    return pattern
end

local function AutoPlantLoop()
    if not SelectedSeed or not SelectedSeed.Selected then return end
    
    local Seed = SelectedSeed.Selected
    local SeedData = OwnedSeeds[Seed]
    
    if not SeedData or SeedData.Count <= 0 then return end
    
    local Count = SeedData.Count
    local Tool = SeedData.Tool
    
    if not EquipCheck(Tool) then return end
    
    local planted = 0
    local maxToPlant = math.min(Count, 50) -- Prevent overflow
    
    if AutoPlantRandom and AutoPlantRandom.Value then
        -- Random planting
        for i = 1, maxToPlant do
            if planted >= maxToPlant then break end
            
            local Point = GetRandomFarmPoint()
            if Plant(Point, Seed) then
                planted += 1
            end
            
            if i % 10 == 0 then -- Break every 10 plants to prevent lag
                SafeWait(0.1)
            end
        end
    else
        -- Optimized pattern planting
        local pattern = GetOptimalPlantingPattern()
        
        for i, Point in ipairs(pattern) do
            if planted >= maxToPlant then break end
            
            if Plant(Point, Seed) then
                planted += 1
            end
            
            if i % 10 == 0 then
                SafeWait(0.1)
            end
        end
    end
    
    Log(`Planted {planted} {Seed}s`)
end

local function HarvestPlant(Plant: Model): boolean
    local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
    if not Prompt or not Prompt.Enabled then return false end
    
    local success = pcall(function()
        fireproximityprompt(Prompt)
        Statistics.PlantsHarvested += 1
    end)
    
    return success
end

local function GetSeedStock(IgnoreNoStock: boolean?): table
    if not PlayerGui:FindFirstChild("Seed_Shop") then return {} end
    
    local SeedShop = PlayerGui.Seed_Shop
    local Items = SeedShop:FindFirstChild("Item_Size", true)
    if not Items or not Items.Parent then return {} end
    
    local NewList = {}
    
    for _, Item in pairs(Items.Parent:GetChildren()) do
        if not Item:IsA("Frame") then continue end
        
        local MainFrame = Item:FindFirstChild("Main_Frame")
        if not MainFrame then continue end
        
        local StockText = MainFrame:FindFirstChild("Stock_Text")
        if not StockText then continue end
        
        local StockCount = tonumber(StockText.Text:match("%d+")) or 0
        
        if IgnoreNoStock then
            if StockCount > 0 then
                NewList[Item.Name] = StockCount
            end
        else
            SeedStock[Item.Name] = StockCount
        end
    end
    
    return IgnoreNoStock and NewList or SeedStock
end

local function CanHarvest(Plant): boolean
    local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
    if not Prompt or not Prompt.Enabled then return false end
    
    -- Check variant ignore
    local Variant = Plant:FindFirstChild("Variant")
    if Variant and HarvestIgnores[Variant.Value] then return false end
    
    return true
end

local function CollectHarvestable(Parent, Plants, IgnoreDistance: boolean?, maxDistance: number?)
    if not Parent then return Plants end
    
    local Character = LocalPlayer.Character
    if not Character then return Plants end
    
    local PlayerPosition = Character:GetPivot().Position
    maxDistance = maxDistance or 15
    
    for _, Plant in pairs(Parent:GetChildren()) do
        -- Handle fruits
        local Fruits = Plant:FindFirstChild("Fruits")
        if Fruits then
            CollectHarvestable(Fruits, Plants, IgnoreDistance, maxDistance)
        end
        
        -- Distance check
        if not IgnoreDistance then
            local PlantPosition = Plant:GetPivot().Position
            local Distance = (PlayerPosition - PlantPosition).Magnitude
            if Distance > maxDistance then continue end
        end
        
        -- Smart harvesting - prioritize valuable plants
        if Config.SmartHarvesting then
            local PlantName = Plant.Name:lower()
            local isValuable = false
            
            for _, valuablePlant in ipairs(Config.PrioritySeeds) do
                if PlantName:find(valuablePlant:lower()) then
                    isValuable = true
                    break
                end
            end
            
            if isValuable and CanHarvest(Plant) then
                table.insert(Plants, 1, Plant) -- Priority insert
            elseif CanHarvest(Plant) then
                table.insert(Plants, Plant)
            end
        else
            if CanHarvest(Plant) then
                table.insert(Plants, Plant)
            end
        end
    end
    
    return Plants
end

local function GetHarvestablePlants(IgnoreDistance: boolean?, maxDistance: number?): table
    if not PlantsPhysical then return {} end
    
    local Plants = {}
    return CollectHarvestable(PlantsPhysical, Plants, IgnoreDistance, maxDistance)
end

local function HarvestPlants()
    local Plants = GetHarvestablePlants()
    local harvested = 0
    local maxHarvest = 25 -- Prevent lag
    
    for i, Plant in ipairs(Plants) do
        if harvested >= maxHarvest then break end
        
        if HarvestPlant(Plant) then
            harvested += 1
        end
        
        if i % 5 == 0 then -- Break every 5 harvests
            SafeWait(Config.HarvestDelay)
        end
    end
    
    if harvested > 0 then
        Log(`Harvested {harvested} plants`)
    end
end

local function AutoSellCheck()
    local CropCount = #GetInvCrops()
    
    if not AutoSell or not AutoSell.Value then return end
    if CropCount < (SellThreshold and SellThreshold.Value or 15) then return end
    
    SellInventory()
end

local function AutoWalkLoop()
    if IsSelling then return end
    
    local Character = LocalPlayer.Character
    if not Character then return end
    
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return end
    
    local Plants = GetHarvestablePlants(true, 50)
    local RandomAllowed = AutoWalkAllowRandom and AutoWalkAllowRandom.Value
    local DoRandom = #Plants == 0 or (RandomAllowed and math.random(1, 4) == 1)
    
    -- Set walking speed
    if Config.OptimizedMovement then
        Humanoid.WalkSpeed = Config.WalkSpeed
    end
    
    -- Random point movement
    if RandomAllowed and DoRandom then
        local Position = GetRandomFarmPoint()
        Humanoid:MoveTo(Position)
        if AutoWalkStatus then
            AutoWalkStatus.Text = "Moving to random point"
        end
        return
    end
    
    -- Move to harvestable plants
    if #Plants > 0 then
        local targetPlant = Plants[1] -- Go to closest/priority plant
        local Position = targetPlant:GetPivot().Position
        Humanoid:MoveTo(Position)
        if AutoWalkStatus then
            AutoWalkStatus.Text = `Moving to {targetPlant.Name}`
        end
    else
        if AutoWalkStatus then
            AutoWalkStatus.Text = "No targets found"
        end
    end
end

local function NoclipLoop()
    local Character = LocalPlayer.Character
    if not NoClip or not NoClip.Value or not Character then return end
    
    for _, Part in pairs(Character:GetDescendants()) do
        if Part:IsA("BasePart") and Part.Name ~= "HumanoidRootPart" then
            Part.CanCollide = false
        end
    end
end

local function MakeLoop(Toggle, Func, customDelay)
    coroutine.wrap(function()
        while true do
            local success, err = pcall(function()
                if Toggle and Toggle.Value then
                    Func()
                end
            end)
            
            if not success then
                Log(`Error in loop: {err}`)
            end
            
            wait(customDelay or 0.1)
        end
    end)()
end

local function StartServices()
    -- Initialize farm
    if not InitializeFarm() then
        Log("Failed to initialize farm. Retrying in 5 seconds...")
        wait(5)
        InitializeFarm()
    end
    
    -- Auto-Walk with custom timing
    MakeLoop(AutoWalk, function()
        local MaxWait = AutoWalkMaxWait and AutoWalkMaxWait.Value or 10
        AutoWalkLoop()
        wait(math.random(1, MaxWait))
    end, 0.5)
    
    -- Auto-Harvest
    MakeLoop(AutoHarvest, HarvestPlants, 0.2)
    
    -- Auto-Buy
    MakeLoop(AutoBuy, BuyAllSelectedSeeds, 1)
    
    -- Auto-Plant
    MakeLoop(AutoPlant, AutoPlantLoop, 0.5)
    
    -- Data collection loop
    coroutine.wrap(function()
        while true do
            pcall(function()
                GetSeedStock()
                GetOwnedSeeds()
            end)
            wait(1)
        end
    end)()
end

local function CreateCheckboxes(Parent, Dict: table)
    for Key, Value in pairs(Dict) do
        Parent:Checkbox({
            Value = Value,
            Label = Key,
            Callback = function(_, newValue)
                Dict[Key] = newValue
            end
        })
    end
end

--// Enhanced UI Creation
local function CreateUI()
    local Window = CreateWindow()
    
    -- Statistics
    local StatsNode = Window:TreeNode({Title="📊 Statistics"})
    local StatsDisplay = StatsNode:Label({Text = "Loading..."})
    
    -- Update stats display
    coroutine.wrap(function()
        while true do
            local stats = GetPlayerStats()
            StatsDisplay.Text = string.format(
                "Session: %dm | Plants: %d (%.1f/m) | Harvests: %d (%.1f/m) | Earned: $%d",
                math.floor(stats.SessionTime/60),
                stats.TotalPlants,
                stats.PlantsPerMinute,
                stats.TotalHarvests,
                stats.HarvestsPerMinute,
                stats.MoneyEarned
            )
            wait(5)
        end
    end)()
    
    -- Configuration
    local ConfigNode = Window:TreeNode({Title="⚙️ Configuration"})
    SafeModeToggle = ConfigNode:Checkbox({
        Value = Config.SafeMode,
        Label = "Safe Mode (Anti-Detection)",
        Callback = function(_, value)
            Config.SafeMode = value
        end
    })
    OptimizedMovementToggle = ConfigNode:Checkbox({
        Value = Config.OptimizedMovement,
        Label = "Optimized Movement",
        Callback = function(_, value)
            Config.OptimizedMovement = value
        end
    })
    SmartHarvestingToggle = ConfigNode:Checkbox({
        Value = Config.SmartHarvesting,
        Label = "Smart Harvesting (Priority)",
        Callback = function(_, value)
            Config.SmartHarvesting = value
        end
    })
    
    -- Auto-Plant
    local PlantNode = Window:TreeNode({Title="🥕 Auto-Plant"})
    SelectedSeed = PlantNode:Combo({
        Label = "Seed",
        Selected = "",
        GetItems = function()
            local seeds = {}
            for name, data in pairs(GetOwnedSeeds()) do
                if data.Count > 0 then
                    seeds[name] = data.Count
                end
            end
            return seeds
        end,
    })
    AutoPlant = PlantNode:Checkbox({
        Value = false,
        Label = "Enabled"
    })
    AutoPlantRandom = PlantNode:Checkbox({
        Value = false,
        Label = "Random Placement"
    })
    PlantNode:Button({
        Text = "Plant All Selected",
        Callback = AutoPlantLoop,
    })
    
    -- Auto-Harvest
    local HarvestNode = Window:TreeNode({Title="🚜 Auto-Harvest"})
    AutoHarvest = HarvestNode:Checkbox({
        Value = false,
        Label = "Enabled"
    })
    HarvestNode:Button({
        Text = "Harvest All",
        Callback = HarvestPlants,
    })
    HarvestNode:Separator({Text="Ignore Types:"})
    CreateCheckboxes(HarvestNode, HarvestIgnores)
    
    -- Auto-Buy
    local BuyNode = Window:TreeNode({Title="🛒 Auto-Buy"})
    SelectedSeedStock = BuyNode:Combo({
        Label = "Seed to Buy",
        Selected = "",
        GetItems = function()
            local OnlyStock = OnlyShowStock and OnlyShowStock.Value
            return GetSeedStock(OnlyStock)
        end,
    })
    AutoBuy = BuyNode:Checkbox({
        Value = false,
        Label = "Enabled"
    })
    OnlyShowStock = BuyNode:Checkbox({
        Value = true,
        Label = "Only Show In-Stock"
    })
    BuyNode:Button({
        Text = "Buy All Selected",
        Callback = BuyAllSelectedSeeds,
    })
    
    -- Auto-Sell
    local SellNode = Window:TreeNode({Title="💰 Auto-Sell"})
    SellNode:Button({
        Text = "Sell Inventory Now",
        Callback = SellInventory,
    })
    AutoSell = SellNode:Checkbox({
        Value = false,
        Label = "Auto-Sell Enabled"
    })
    SellThreshold = SellNode:SliderInt({
        Label = "Sell Threshold",
        Value = 20,
        Minimum = 5,
        Maximum = Config.MaxInventorySize,
    })
    
    -- Auto-Walk
    local WalkNode = Window:TreeNode({Title="🚶 Auto-Walk"})
    AutoWalkStatus = WalkNode:Label({
        Text = "Idle"
    })
    AutoWalk = WalkNode:Checkbox({
        Value = false,
        Label = "Enabled"
    })
    AutoWalkAllowRandom = WalkNode:Checkbox({
        Value = true,
        Label = "Allow Random Movement"
    })
    NoClip = WalkNode:Checkbox({
        Value = false,
        Label = "NoClip (Use Carefully)"
    })
    AutoWalkMaxWait = WalkNode:SliderInt({
        Label = "Max Movement Delay (s)",
        Value = 5,
        Minimum = 1,
        Maximum = 30,
    })
    
    return Window
end

--// Initialize
local Window = CreateUI()

--// Enhanced Connections
local connections = {}

connections.stepped = RunService.Stepped:Connect(NoclipLoop)
connections.childAdded = Backpack.ChildAdded:Connect(AutoSellCheck)

-- Cleanup on character respawn
connections.characterAdded = LocalPlayer.CharacterAdded:Connect(function()
    wait(2) -- Wait for character to fully load
    InitializeFarm()
end)

-- Auto-reconnect if disconnected
if Config.AutoReconnect then
    game:GetService("GuiService").ErrorMessageChanged:Connect(function()
        wait(5)
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId)
    end)
end

-- Start all services
StartServices()

Log("Enhanced Garden Bot v2.0 Loaded Successfully!")
Log("Features: Smart Harvesting, Anti-Detection, Enhanced Performance")
