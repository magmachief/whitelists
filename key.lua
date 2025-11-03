local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Workspace=game:GetService("Workspace")
local StarterGui=game:GetService("StarterGui")
local ContextActionService=game:GetService("ContextActionService")
local UserInputService=game:GetService("UserInputService")
local LocalPlayer=Players.LocalPlayer
local bombName="Bomb"
local customNormalFriction=0.7
local customBombFriction=7
local customAntiSlipperyFriction=0.7
local customBombAntiSlipperyFriction=0.9
local fallbackFriction=0.5
local customHitboxSize=0.1
local bombPassDistance=10
local raySpreadAngle=10
local numRaycasts=5
local AutoPassEnabled=false
local antiSlippery=false
local RemoveHitboxEnabled=false
local AI_AssistanceEnabled=false
local allUIVisible=true\
local originalHitboxSizes = {}


local FrictionController={}
FrictionController.__index=FrictionController
function FrictionController.new()
 local self=setmetatable({},FrictionController)
 self.originalProperties={}
 self.normalFriction=customNormalFriction
 self.bombFriction=customBombFriction
 self.stateMultipliers={Running=1.2,Walking=1.0,Crouching=0.8}
 self.enabled=false
 return self
end
function FrictionController:getSurfaceMaterial(character)
 local hrp=character:FindFirstChild("HumanoidRootPart")
 if not hrp then return Enum.Material.Plastic end
 local rayParams=RaycastParams.new() rayParams.FilterDescendantsInstances={character} rayParams.FilterType=Enum.RaycastFilterType.Blacklist
 local rayResult=Workspace:Raycast(hrp.Position,Vector3.new(0,-5,0),rayParams)
 return rayResult and rayResult.Instance.Material or Enum.Material.Plastic
end
function FrictionController:calculateFriction(character)
 local humanoid=character:FindFirstChild("Humanoid")
 local hrp=character:FindFirstChild("HumanoidRootPart")
 if not (humanoid and hrp) then return self.normalFriction end
 local rayParams=RaycastParams.new() rayParams.FilterDescendantsInstances={character} rayParams.FilterType=Enum.RaycastFilterType.Blacklist
 local rayResult=Workspace:Raycast(hrp.Position,Vector3.new(0,-5,0),rayParams)
 if rayResult then
  local floorPart=rayResult.Instance
  if floorPart:IsA("BasePart") and floorPart.Name=="Floor" and floorPart.Friction<=0.2 then
   return math.clamp(customAntiSlipperyFriction*0.5,0.1,1.0)
  end
 end
 if character:FindFirstChild(bombName) then return self.bombFriction end
 local stateName=humanoid:GetState() local multiplier=self.stateMultipliers[stateName] or 1.0
 return math.clamp(self.normalFriction*multiplier,0.1,1.0)
end
function FrictionController:update()
 local character=LocalPlayer.Character
 if not character then return end
 for _,pn in ipairs({"LeftFoot","RightFoot","LeftLeg","RightLeg"}) do
  local part=character:FindFirstChild(pn)
  if part and part:IsA("BasePart") then
   if not self.originalProperties[part] then
    local elasticity=0.3 local frictionWeight=0.5
    if part.CustomPhysicalProperties then
     elasticity=part.CustomPhysicalProperties.Elasticity
     frictionWeight=part.CustomPhysicalProperties.FrictionWeight
    end
    self.originalProperties[part]=PhysicalProperties.new(customNormalFriction,elasticity,frictionWeight)
   end
   local df=self:calculateFriction(character)
   local elasticity=0.3 local frictionWeight=0.5
   if part.CustomPhysicalProperties then
    elasticity=part.CustomPhysicalProperties.Elasticity
    frictionWeight=part.CustomPhysicalProperties.FrictionWeight
   end
   part.CustomPhysicalProperties=PhysicalProperties.new(df,elasticity,frictionWeight)
  end
 end
end
function FrictionController:restore()
 for part,orig in pairs(self.originalProperties) do if part and part.Parent then part.CustomPhysicalProperties=orig end end
 self.originalProperties={}
end
function FrictionController:enable()
 if self.enabled then return end
 self.enabled=true
	spawn(function() while self.enabled do self:update() wait(0.1) end end)
end
function FrictionController:disable() self.enabled=false self:restore() end

local function applyAntiSlippery(enabled)
 if enabled then
  spawn(function()
   while antiSlippery do
    local character=LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp=character:FindFirstChild("HumanoidRootPart")
    for _,part in pairs(character:GetDescendants()) do
     if part:IsA("BasePart") then
      if character:FindFirstChild(bombName) then
       local speed=hrp and hrp.Velocity.Magnitude or 0
       local fric=customBombAntiSlipperyFriction if speed>10 then fric=fric*1.25 end
       part.CustomPhysicalProperties=PhysicalProperties.new(fric,0.3,0.5)
      else
       part.CustomPhysicalProperties=PhysicalProperties.new(customAntiSlipperyFriction,0.3,0.5)
      end
     end
    end
    wait(0.5)
   end
  end)
 else
  local character=LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
  for _,part in pairs(character:GetDescendants()) do
   if part:IsA("BasePart") then
    part.CustomPhysicalProperties=PhysicalProperties.new(fallbackFriction,0.3,0.5)
   end
  end
 end
end

local function faceNearestBombHolder()
 local myChar=LocalPlayer.Character; if not myChar then return end
 local hrp=myChar:FindFirstChild("HumanoidRootPart"); if not hrp then return end
 local nearest,nearestDist=nil,math.huge
 for _,p in pairs(Players:GetPlayers()) do
  if p~=LocalPlayer and p.Character and p.Character:FindFirstChild(bombName) then
   local pHRP=p.Character:FindFirstChild("HumanoidRootPart")
   if pHRP then local d=(pHRP.Position-hrp.Position).Magnitude if d<nearestDist then nearestDist=d; nearest=p end end
  end
 end
 if nearest and nearest.Character then
  local bombHolderHRP=nearest.Character:FindFirstChild("HumanoidRootPart")
  if bombHolderHRP then
   local cam=Workspace.CurrentCamera
   cam.CameraType=Enum.CameraType.Custom
   cam.CFrame=CFrame.new(cam.CFrame.Position, bombHolderHRP.Position)
  end
 end
end

local CHAR=LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HUMANOID=CHAR:WaitForChild("Humanoid")
local HRP=CHAR:WaitForChild("HumanoidRootPart")

local LoggingModule={}
function LoggingModule.logError(err,ctx) warn("[ERROR] Context: "..tostring(ctx).." | "..tostring(err)) end
function LoggingModule.safeCall(func,ctx) local s,r=pcall(func); if not s then LoggingModule.logError(r,ctx) end; return s,r end

local TargetingModule={}
function TargetingModule.getClosestPlayer()
 local closest,md=nil,math.huge; local myPos=HRP.Position
 for _,p in ipairs(Players:GetPlayers()) do
  if p~=LocalPlayer and p.Character then
   local targetHrp=p.Character:FindFirstChild("HumanoidRootPart")
   if targetHrp and not p.Character:FindFirstChild(bombName) then
    local d=(targetHrp.Position-myPos).Magnitude
    if d<md then md=d; closest=p end
   end
  end
 end
 return closest
end
function TargetingModule.rotateCharacterTowardsTarget(targetPos) end

local VisualModule={}
function VisualModule.animateMarker(marker)
 if not marker then return end
 local tween=TweenService:Create(marker, TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut), {Size=UDim2.new(0,100,0,100)})
 tween:Play()
end
function VisualModule.playPassVFX(target)
 if not target or not target.Character then return end
 local hrp=target.Character:FindFirstChild("HumanoidRootPart")
 if not hrp then return end
 local emitter=Instance.new("ParticleEmitter")
 emitter.Texture="rbxassetid://258128463"
 emitter.Rate=50
 emitter.Lifetime=NumberRange.new(0.3,0.5)
 emitter.Speed=NumberRange.new(2,5)
 emitter.VelocitySpread=30
 emitter.Parent=hrp
 delay(1,function() emitter:Destroy() end)
end

local AINotificationsModule={}
function AINotificationsModule.sendNotification(title,text,dur)
 pcall(function() StarterGui:SetCore("SendNotification",{Title=title,Text=text,Duration=dur or 5}) end)
end


local function applyRemoveHitbox(enable)
    local char = LocalPlayer.Character
    if not char then return end

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
                part.Size = originalHitboxSizes[part] or Vector3.new(1,1,1)
            end
        end
    end
end

local currentTargetMarker,currentTargetPlayer=nil,nil
local function createOrUpdateTargetMarker(player,dist)
 if not player or not player.Character then return end
 local body=player.Character:FindFirstChild("HumanoidRootPart"); if not body then return end
 if currentTargetMarker and currentTargetPlayer==player then
  currentTargetMarker:FindFirstChildOfClass("TextLabel").Text=player.Name.."\n"..math.floor(dist).." studs"
  return
 end
 if currentTargetMarker then currentTargetMarker:Destroy() currentTargetMarker,currentTargetPlayer=nil,nil end
 local marker=Instance.new("BillboardGui")
 marker.Name="BombPassTargetMarker" marker.Adornee=body marker.Size=UDim2.new(0,80,0,80)
 marker.StudsOffset=Vector3.new(0,2,0) marker.AlwaysOnTop=true marker.Parent=body
 local label=Instance.new("TextLabel",marker)
 label.Size=UDim2.new(1,0,1,0) label.BackgroundTransparency=1
 label.Text=player.Name.."\n"..math.floor(dist).." studs" label.TextScaled=true
 label.TextColor3=Color3.new(1,0,0) label.Font=Enum.Font.SourceSansBold
 currentTargetMarker,currentTargetPlayer=marker,player
 VisualModule.animateMarker(marker)
end
local function removeTargetMarker() if currentTargetMarker then currentTargetMarker:Destroy() currentTargetMarker,currentTargetPlayer=nil,nil end end

local function isLineOfSightClearMultiple(startPos,endPos,targetPart)
 local spreadRad=math.rad(raySpreadAngle)
 local direction=(endPos-startPos).Unit local distance=(endPos-startPos).Magnitude
 local rayParams=RaycastParams.new() rayParams.FilterType=Enum.RaycastFilterType.Blacklist
 if LocalPlayer.Character then rayParams.FilterDescendantsInstances={LocalPlayer.Character} end
 local centralResult=Workspace:Raycast(startPos,direction*distance,rayParams)
 if centralResult and not centralResult.Instance:IsDescendantOf(targetPart.Parent) then return false end
 local raysEachSide=math.floor((numRaycasts-1)/2)
 for i=1,raysEachSide do
  local angleOffset=spreadRad*i/raysEachSide
  local leftDirection=(CFrame.fromAxisAngle(Vector3.new(0,1,0),angleOffset)*CFrame.new(direction)).p
  local leftResult=Workspace:Raycast(startPos,leftDirection*distance,rayParams)
  if leftResult and not leftResult.Instance:IsDescendantOf(targetPart.Parent) then return false end
  local rightDirection=(CFrame.fromAxisAngle(Vector3.new(0,1,0),-angleOffset)*CFrame.new(direction)).p
  local rightResult=Workspace:Raycast(startPos,rightDirection*distance,rayParams)
  if rightResult and not rightResult.Instance:IsDescendantOf(targetPart.Parent) then return false end
 end
 return true
end

local function getClosestPlayer()
 local closest,nd=nil,math.huge
 for _,p in ipairs(Players:GetPlayers()) do
  if p~=LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
   local d=(p.Character.HumanoidRootPart.Position-LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
   if d<nd then nd=d; closest=p end
  end
 end
 return closest
end

local function autoPassBomb()
 if not AutoPassEnabled then return end
 pcall(function()
  local Bomb=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(bombName)
  if Bomb then
   local BombEvent=Bomb:FindFirstChild("RemoteEvent")
   local closestPlayer=getClosestPlayer()
   if closestPlayer and closestPlayer.Character then
    local targetPos=closestPlayer.Character.HumanoidRootPart.Position
    local dist=(targetPos-LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
    if dist<=bombPassDistance then BombEvent:FireServer(closestPlayer.Character,closestPlayer.Character:FindFirstChild("CollisionPart")) end
   end
  end
 end)
end

local OrionLib=loadstring(game:HttpGet("https://raw.githubusercontent.com/magmachief/Library-Ui/main/Orion%20Lib%20Transparent%20%20.lua"))()
local Window=OrionLib:MakeWindow({Name="Yon Menu - Advanced (Auto Pass Bomb)",HidePremium=false,SaveConfig=true,ConfigFolder="YonMenu_Advanced",ShowIcon=true})
local AutomatedTab=Window:MakeTab({Name="Automated Settings",Icon="rbxassetid://4483345998",PremiumOnly=false})
local AITab=Window:MakeTab({Name="AI Based Settings",Icon="rbxassetid://7072720870",PremiumOnly=false})
local UITab=Window:MakeTab({Name="UI Elements",Icon="rbxassetid://4483345998",PremiumOnly=false})
AutomatedTab:AddLabel("== Bomb Passing ==",15)
local orionAutoPassToggle=AutomatedTab:AddToggle({Name="Auto Pass Bomb",Default=AutoPassEnabled,Flag="AutoPassBomb",Callback=function(value)
 AutoPassEnabled=value
 if value then if not autoPassConnection then autoPassConnection=RunService.Stepped:Connect(autoPassBomb) end
 else if autoPassConnection then autoPassConnection:Disconnect() autoPassConnection=nil end removeTargetMarker() end
 if mobileToggle then
  if AutoPassEnabled then mobileToggle.Text="On" mobileToggle.BackgroundColor3=Color3.fromRGB(0,255,0)
  else mobileToggle.Text="Off" mobileToggle.BackgroundColor3=Color3.fromRGB(255,0,0) end
 end
end})
AutomatedTab:AddLabel("== Character Settings ==",15)
AutomatedTab:AddToggle({Name="Anti-Slippery",Info="Custom friction: normal (~0.7)/bomb state",Default=false,Callback=function(v)
 antiSlippery=v
 applyAntiSlippery(v)
end})
AutomatedTab:AddTextbox({Name="Custom Anti‑Slippery Friction",Default=tostring(customAntiSlipperyFriction),Flag="CustomAntiSlipperyFrict",TextDisappear=false,Callback=function(value)
 local num=tonumber(value) if num then customAntiSlipperyFriction=num end
end})
AutomatedTab:AddTextbox({Name="Custom Bomb Anti‑Slippery Friction",Default=tostring(customBombAntiSlipperyFriction),Flag="CustomBombAntiSlipperyFrict",TextDisappear=false,Callback=function(value)
 local num=tonumber(value) if num then customBombAntiSlipperyFriction=num end
end})
AutomatedTab:AddToggle({Name="Face Bomb",Info="Face nearest bomb holder",Default=false,Callback=function(v)
 FaceBombEnabled=v
 if v then faceBombConnection=RunService.Heartbeat:Connect(faceNearestBombHolder)
 else if faceBombConnection then faceBombConnection:Disconnect() faceBombConnection=nil end end
end})
AutomatedTab:AddToggle({Name="Remove Hitbox",Default=RemoveHitboxEnabled,Flag="RemoveHitbox",Callback=function(value)
 RemoveHitboxEnabled=value
 applyRemoveHitbox(value)
end})
AutomatedTab:AddTextbox({
    Name="Custom Hitbox Size",
    Default=tostring(customHitboxSize),
    Flag="CustomHitboxSize",
    TextDisappear=false,
    Callback=function(value)
        local num = tonumber(value)
        if num then
            customHitboxSize = num
            if RemoveHitboxEnabled then
                applyRemoveHitbox(true)
            end
        end
    end
})

AITab:AddLabel("== Targeting Settings ==",15)
AITab:AddToggle({Name="AI Assistance",Default=false,Flag="AIAssistance",Callback=function(value) AI_AssistanceEnabled=value end})
AITab:AddTextbox({Name="Bomb Pass Distance",Default=tostring(bombPassDistance),Flag="BombPassDistance",TextDisappear=false,Callback=function(value)
 local num=tonumber(value) if num then bombPassDistance=num end
end})
AITab:AddTextbox({Name="Ray Spread Angle",Default=tostring(raySpreadAngle),Flag="RaySpreadAngle",TextDisappear=false,Callback=function(value)
 local num=tonumber(value) if num then raySpreadAngle=num end
end})
AITab:AddTextbox({Name="Number of Raycasts",Default=tostring(numRaycasts),Flag="NumberOfRaycasts",TextDisappear=false,Callback=function(value)
 local num=tonumber(value) if num then numRaycasts=num end
end})
UITab:AddColorpicker({Name="Menu Main Color",Default=Color3.fromRGB(255,0,0),Flag="MenuMainColor",Save=true,Callback=function(color)
 OrionLib.Themes[OrionLib.SelectedTheme].Main=color
end})
OrionLib:Init()
local orionGui = LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("Orion")
local menuIconButton

if orionGui then
    for _, obj in pairs(orionGui:GetDescendants()) do
        if obj:IsA("ImageButton") and obj.Name:lower():find("icon") then
            menuIconButton = obj
            break
        end
    end
end
local myFrictionController=FrictionController.new()
myFrictionController:enable()

local function setUIVisualStealth(enabled)
 local trans=enabled and 1 or 0
 local function rec(gui)
  for _,obj in ipairs(gui:GetDescendants()) do
   if obj:IsA("GuiObject") then
    pcall(function()
     if obj:IsA("TextLabel") or obj:IsA("TextButton") then obj.TextTransparency=trans end
     if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then obj.ImageTransparency=trans end
     obj.BackgroundTransparency=trans
    end)
   end
  end
 end
 if mobileGui then rec(mobileGui) end
 if ShiftLockScreenGui then rec(ShiftLockScreenGui) end
 for _,gui in ipairs(LocalPlayer:WaitForChild("PlayerGui"):GetChildren()) do
  if gui:IsA("ScreenGui") and gui.Name:match("Orion") then rec(gui) end
 end
 for _,gui in ipairs(game:GetService("CoreGui"):GetChildren()) do
  if gui:IsA("ScreenGui") and gui.Name:match("Orion") then rec(gui) end
 end
end

local function createMobileToggle()
 local mobileGui=Instance.new("ScreenGui")
 mobileGui.Name="MobileToggleGui"
 mobileGui.Parent=LocalPlayer:WaitForChild("PlayerGui")
 local button=Instance.new("TextButton")
 button.Name="AutoPassMobileToggle"
 button.Position=UDim2.new(1,-60,1,-110) button.AnchorPoint=Vector2.new(1,1)
 button.Size=UDim2.new(0,60,0,60)
 button.BackgroundColor3=Color3.fromRGB(255,0,0)
 button.Text="Off" button.TextScaled=true button.Font=Enum.Font.SourceSansBold
 button.ZIndex=100 button.Parent=mobileGui
 local uicorner=Instance.new("UICorner") uicorner.CornerRadius=UDim.new(1,0) uicorner.Parent=button
 local uistroke=Instance.new("UIStroke") uistroke.Thickness=2 uistroke.Color=Color3.fromRGB(0,0,0) uistroke.Parent=button
 button.MouseEnter:Connect(function() TweenService:Create(button,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(255,100,100)}):Play() end)
 button.MouseLeave:Connect(function() if AutoPassEnabled then TweenService:Create(button,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(0,255,0)}):Play() else TweenService:Create(button,TweenInfo.new(0.2),{BackgroundColor3=Color3.fromRGB(255,0,0)}):Play() end end)
 button.MouseButton1Click:Connect(function()
  AutoPassEnabled=not AutoPassEnabled
  if AutoPassEnabled then button.BackgroundColor3=Color3.fromRGB(0,255,0) button.Text="On" if not autoPassConnection then autoPassConnection=RunService.Stepped:Connect(autoPassBomb) end
  else button.BackgroundColor3=Color3.fromRGB(255,0,0) button.Text="Off" if autoPassConnection then autoPassConnection:Disconnect() autoPassConnection=nil end end
  if orionAutoPassToggle then orionAutoPassToggle:Set(AutoPassEnabled) end
 end)
 return mobileGui, button
end
local mobileGui,mobileToggle=createMobileToggle()
LocalPlayer:WaitForChild("PlayerGui").ChildRemoved:Connect(function(child)
 if child.Name=="MobileToggleGui" then wait(1) if not LocalPlayer.PlayerGui:FindFirstChild("MobileToggleGui") then mobileGui,mobileToggle=createMobileToggle() setUIVisualStealth(not allUIVisible) end end
end)

local ShiftLockScreenGui=Instance.new("ScreenGui")
ShiftLockScreenGui.Name="Shiftlock (CoreGui)"
ShiftLockScreenGui.Parent=game:GetService("CoreGui")
ShiftLockScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
ShiftLockScreenGui.ResetOnSpawn=false
local ShiftLockButton=Instance.new("ImageButton")
ShiftLockButton.Parent=ShiftLockScreenGui
ShiftLockButton.BackgroundColor3=Color3.fromRGB(255,255,255)
ShiftLockButton.BackgroundTransparency=1
ShiftLockButton.Position=UDim2.new(0.7,0,0.75,0)
ShiftLockButton.Size=UDim2.new(0.0636,0,0.0661,0)
ShiftLockButton.SizeConstraint=Enum.SizeConstraint.RelativeXX
ShiftLockButton.Image="rbxasset://textures/ui/mouseLock_off@2x.png"
local shiftLockUICorner=Instance.new("UICorner") shiftLockUICorner.CornerRadius=UDim.new(0.2,0) shiftLockUICorner.Parent=ShiftLockButton
local shiftLockUIStroke=Instance.new("UIStroke") shiftLockUIStroke.Thickness=2 shiftLockUIStroke.Color=Color3.fromRGB(0,0,0) shiftLockUIStroke.Parent=ShiftLockButton
local ShiftlockCursor=Instance.new("ImageLabel") ShiftlockCursor.Name="Shiftlock Cursor" ShiftlockCursor.Parent=ShiftLockScreenGui
ShiftlockCursor.Image="rbxasset://textures/MouseLockedCursor.png"
ShiftlockCursor.Size=UDim2.new(0.03,0,0.03,0) ShiftlockCursor.Position=UDim2.new(0.5,0,0.5,0)
ShiftlockCursor.AnchorPoint=Vector2.new(0.5,0.5) ShiftlockCursor.SizeConstraint=Enum.SizeConstraint.RelativeXX
ShiftlockCursor.BackgroundTransparency=1 ShiftlockCursor.BackgroundColor3=Color3.fromRGB(255,0,0)
ShiftlockCursor.Visible=false
local SL_MaxLength=900000 local SL_EnabledOffset=CFrame.new(1.7,0,0) local SL_DisabledOffset=CFrame.new(-1.7,0,0)
local SL_Active=nil
ShiftLockButton.MouseButton1Click:Connect(function()
 if not SL_Active then
  SL_Active=RunService.RenderStepped:Connect(function()
   local char=LocalPlayer.Character
   local hum=char and char:FindFirstChild("Humanoid")
   local root=char and char:FindFirstChild("HumanoidRootPart")
   if hum and root then
    hum.AutoRotate=false
    ShiftLockButton.Image="rbxasset://textures/ui/mouseLock_on@2x.png"
    ShiftlockCursor.Visible=true
    root.CFrame=CFrame.new(root.Position,Vector3.new(Workspace.CurrentCamera.CFrame.LookVector.X*SL_MaxLength,root.Position.Y,Workspace.CurrentCamera.CFrame.LookVector.Z*SL_MaxLength))
    Workspace.CurrentCamera.CFrame=Workspace.CurrentCamera.CFrame*SL_EnabledOffset
   end
  end)
 else
  local char=LocalPlayer.Character
  local hum=char and char:FindFirstChild("Humanoid")
  if hum then hum.AutoRotate=true end
  ShiftLockButton.Image="rbxasset://textures/ui/mouseLock_off@2x.png"
  Workspace.CurrentCamera.CFrame=Workspace.CurrentCamera.CFrame*SL_DisabledOffset
  ShiftlockCursor.Visible=false
  if SL_Active then SL_Active:Disconnect() SL_Active=nil end
 end
end)
LocalPlayer.Chatted:Connect(function(msg)
    msg = msg:lower()
    if msg == "/e" then
        allUIVisible = not allUIVisible
        setUIVisualStealth(allUIVisible)
        AINotificationsModule.sendNotification("UI Toggle", allUIVisible and "UI visible" or "UI hidden", 2)

        if mobileGui then
            mobileGui.Enabled = allUIVisible
            mobileToggle.Visible = allUIVisible
        end
        if ShiftLockButton then
            ShiftLockButton.Visible = allUIVisible
        end
        if orionGui then
            orionGui.Enabled = allUIVisible
        end
        if menuIconButton then
            menuIconButton.Visible = allUIVisible
        end
    end
end)
print("Bomb AI, Anti-Slippery, Shiftlock, Auto Pass, and UI Toggle systems loaded. Menu and features active.")
return {}
