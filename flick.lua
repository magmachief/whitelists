-- LocalScript (StarterPlayerScripts) – MOBILE Flick Assist for Pass The Bomb
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local CAS=game:GetService("ContextActionService")
local Camera=workspace.CurrentCamera
local LP=Players.LocalPlayer

local SPEED=16
local FLICK_TIME=0.055
local FLICK_ANGLE_MIN=22
local FLICK_ANGLE_MAX=38
local TOUCH_THRESHOLD=14

local enabled=true
local flicking=false
local flickStart=0
local flickAngle=0
local lastTouch=nil

local function char()
	local c=LP.Character
	if not c then return end
	local h=c:FindFirstChildOfClass("Humanoid")
	local r=c:FindFirstChild("HumanoidRootPart")
	if h and r then return h,r end
end

local function beginFlick()
	if flicking then return end
	flicking=true
	flickStart=os.clock()
	flickAngle=math.rad(math.random(FLICK_ANGLE_MIN,FLICK_ANGLE_MAX))
end

UIS.TouchStarted:Connect(function(t,g)
	if g then return end
	lastTouch=t.Position
end)

UIS.TouchMoved:Connect(function(t,g)
	if g or not lastTouch then return end
	local d=(t.Position-lastTouch).Magnitude
	if d>=TOUCH_THRESHOLD then
		beginFlick()
		lastTouch=nil
	end
end)

UIS.TouchEnded:Connect(function()
	lastTouch=nil
end)

RunService.RenderStepped:Connect(function(dt)
	if not enabled then return end
	local h,r=char()
	if not h then return end
	h.AutoRotate=false

	local look=Camera.CFrame.LookVector
	look=Vector3.new(look.X,0,look.Z)
	if look.Magnitude>0 then look=look.Unit end

	if flicking then
		local p=(os.clock()-flickStart)/FLICK_TIME
		if p>=1 then
			flicking=false
		else
			local a=flickAngle*(1-p)
			local cf=CFrame.new(r.Position)*CFrame.Angles(0,a,0)
			r.CFrame=CFrame.new(r.Position,r.Position+cf.LookVector)
		end
	end

	r.CFrame=CFrame.new(r.Position,r.Position+look)
	h:Move(look*SPEED,false)
end)

LP.CharacterAdded:Connect(function()
	task.wait(.15)
end)