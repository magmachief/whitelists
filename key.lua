-- FILE 2: AETHER BOMB PASS / complete standalone replacement
-- File 3 is bundled below, so no YOUR_URL download is required.
-- Normal: 3.0 s / 6 studs. Late: 1.2 s / 6 studs. Lead: 0.05 s. Cooldown: 0.5 s.
-- Auto starts OFF. RightShift toggles the Aether window; Settings > Menu Key changes it.
-- Run once in a fresh client session. Unload through Settings before running again.
local CloudUI = (function()
--------------------------------------------------------------------------------
--  AETHER · CLOUD UI  ·  v1.0
--  A premium, responsive, cloud-themed Roblox UI framework.
--  100% custom Instances. No external libraries, no external assets.
--------------------------------------------------------------------------------

--// SERVICES
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local HttpService       = game:GetService("HttpService")
local MarketplaceService= game:GetService("MarketplaceService")
local Stats             = game:GetService("Stats")
local CoreGui           = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    error("[Aether] CloudUI can only be initialized on the client.")
end
local Mouse = LocalPlayer:GetMouse()

--// MODULE
local CloudUI = {}
CloudUI.__index = CloudUI

--// CONSTANTS
local ICONS = {
    Home = "⌂", Main = "✦", Player = "◉", Visuals = "✧",
    Automation = "⟳", Profiles = "☰", Settings = "⚙", About = "ℹ", Cloud = "☁",
}

local FONTS = {
    Display  = { Font = Enum.Font.GothamBold,   Size = 22 },
    Heading  = { Font = Enum.Font.GothamBold,   Size = 20 },
    Section  = { Font = Enum.Font.GothamBold,   Size = 15 },
    Title    = { Font = Enum.Font.GothamMedium, Size = 14 },
    Body     = { Font = Enum.Font.Gotham,       Size = 13 },
    Caption  = { Font = Enum.Font.Gotham,       Size = 11 },
}

--// THEMES
local Themes = {
    AetherCloud = {
        Background = Color3.fromRGB(18, 20, 28),  Surface = Color3.fromRGB(27, 30, 42),
        Elevated   = Color3.fromRGB(34, 38, 54),  Cloud   = Color3.fromRGB(42, 44, 64),
        Primary    = Color3.fromRGB(174, 150, 255), Secondary = Color3.fromRGB(148, 190, 255),
        Pink       = Color3.fromRGB(255, 164, 210),
        Text       = Color3.fromRGB(238, 241, 255), SubText = Color3.fromRGB(172, 180, 205),
        Muted      = Color3.fromRGB(119, 128, 155), Border = Color3.fromRGB(75, 80, 110),
        Success    = Color3.fromRGB(126, 220, 175), Warning = Color3.fromRGB(245, 198, 120),
        Error      = Color3.fromRGB(245, 125, 145),
    },
    LavenderNight = {
        Background = Color3.fromRGB(16, 14, 26),  Surface = Color3.fromRGB(26, 22, 40),
        Elevated   = Color3.fromRGB(33, 28, 52),  Cloud   = Color3.fromRGB(42, 35, 64),
        Primary    = Color3.fromRGB(168, 132, 255), Secondary = Color3.fromRGB(130, 150, 255),
        Pink       = Color3.fromRGB(255, 150, 215),
        Text       = Color3.fromRGB(240, 236, 255), SubText = Color3.fromRGB(178, 170, 210),
        Muted      = Color3.fromRGB(125, 115, 160), Border = Color3.fromRGB(82, 72, 120),
        Success    = Color3.fromRGB(126, 220, 175), Warning = Color3.fromRGB(245, 198, 120),
        Error      = Color3.fromRGB(245, 125, 145),
    },
    SoftRose = {
        Background = Color3.fromRGB(26, 18, 24),  Surface = Color3.fromRGB(36, 26, 34),
        Elevated   = Color3.fromRGB(46, 33, 43),  Cloud   = Color3.fromRGB(56, 40, 52),
        Primary    = Color3.fromRGB(250, 145, 185), Secondary = Color3.fromRGB(255, 190, 205),
        Pink       = Color3.fromRGB(255, 160, 175),
        Text       = Color3.fromRGB(255, 242, 246), SubText = Color3.fromRGB(208, 178, 192),
        Muted      = Color3.fromRGB(160, 132, 148), Border = Color3.fromRGB(110, 82, 96),
        Success    = Color3.fromRGB(126, 220, 175), Warning = Color3.fromRGB(245, 198, 120),
        Error      = Color3.fromRGB(245, 125, 145),
    },
    ArcticMist = {
        Background = Color3.fromRGB(226, 233, 242), Surface = Color3.fromRGB(240, 245, 250),
        Elevated   = Color3.fromRGB(250, 252, 255), Cloud   = Color3.fromRGB(210, 220, 233),
        Primary    = Color3.fromRGB(96, 130, 220),  Secondary = Color3.fromRGB(120, 170, 235),
        Pink       = Color3.fromRGB(235, 140, 190),
        Text       = Color3.fromRGB(30, 40, 60),   SubText = Color3.fromRGB(80, 95, 122),
        Muted      = Color3.fromRGB(125, 140, 165), Border = Color3.fromRGB(185, 198, 216),
        Success    = Color3.fromRGB(60, 160, 120), Warning = Color3.fromRGB(200, 150, 60),
        Error      = Color3.fromRGB(210, 90, 110),
    },
}

local ThemeDisplayNames = {
    ["Aether Cloud"]  = "AetherCloud",
    ["Lavender Night"]= "LavenderNight",
    ["Soft Rose"]     = "SoftRose",
    ["Arctic Mist"]   = "ArcticMist",
}
local ThemeNameToDisplay = {}
for display, key in pairs(ThemeDisplayNames) do
    ThemeNameToDisplay[key] = display
end

--// PURE UTILITIES
local function clamp(v, mn, mx)
    if v < mn then return mn elseif v > mx then return mx end
    return v
end

local function LerpColor(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function Lighten(c, t)
    return Color3.new(c.R + (1 - c.R) * t, c.G + (1 - c.G) * t, c.B + (1 - c.B) * t)
end

local function ToHex(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function FromHex(s)
    s = tostring(s or ""):gsub("#", "")
    if #s == 3 then
        s = s:sub(1,1)..s:sub(1,1)..s:sub(2,2)..s:sub(2,2)..s:sub(3,3)..s:sub(3,3)
    end
    if #s ~= 6 then return nil end
    local r = tonumber(s:sub(1, 2), 16)
    local g = tonumber(s:sub(3, 4), 16)
    local b = tonumber(s:sub(5, 6), 16)
    if r and g and b then return Color3.fromRGB(r, g, b) end
    return nil
end

local function SafeCall(callback, ...)
    if type(callback) ~= "function" then return end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[Aether] callback error:", err)
    end
end

local function FormatDuration(seconds)
    seconds = math.floor(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%d:%02d", m, s)
end

local function KeyDisplayName(key)
    if typeof(key) == "EnumItem" then
        if key.EnumType == Enum.UserInputType then
            return key.Name:gsub("MouseButton", "Mouse ")
        end
        return key.Name
    end
    return "None"
end

local function KeyToString(key)
    if typeof(key) == "EnumItem" then return tostring(key) end
    return "None"
end

local function ParseKey(s)
    if type(s) ~= "string" or s == "None" or s == "" then return nil end
    local a, b = s:match("^Enum%.([%w_]+)%.([%w_]+)$")
    if a and b then
        local ok, result = pcall(function() return Enum[a][b] end)
        if ok then return result end
    end
    return nil
end

--// INSTANCE HELPERS
local function Create(className, props, children)
    local inst = Instance.new(className)
    local parent = nil
    if props then
        for k, v in pairs(props) do
            if k == "Parent" then parent = v else inst[k] = v end
        end
    end
    if children then
        for i = 1, #children do children[i].Parent = inst end
    end
    if parent then inst.Parent = parent end
    return inst
end

local function Corner(r)
    return Create("UICorner", { CornerRadius = UDim.new(0, r or 10) })
end

local function CornerFull()
    return Create("UICorner", { CornerRadius = UDim.new(1, 0) })
end

local function Stroke(color, thickness, transparency)
    return Create("UIStroke", {
        Color = color or Color3.new(1, 1, 1),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
    })
end

local function Pad(top, bottom, left, right)
    return Create("UIPadding", {
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or 0),
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or 0),
    })
end

local function List(padding)
    return Create("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
end

--------------------------------------------------------------------------------
--  CLOUDUI FACTORY
--------------------------------------------------------------------------------
function CloudUI.new(config)
    config = config or {}

    local Name        = tostring(config.Name or "Aether")
    local Version     = tostring(config.Version or "1.0")
    local Subtitle    = tostring(config.Subtitle or "Cloud UI")
    local Developer   = tostring(config.Developer or "YourName")
    local IntroEnabled  = config.IntroEnabled ~= false
    local DemoContent   = config.DemoContent ~= false
    local AutoLoad      = config.AutoLoad ~= false
    local ConfigFolder  = tostring(config.ConfigFolder or "AetherUI")

    local themeKey = config.Theme or "AetherCloud"
    if type(themeKey) == "string" then
        if not Themes[themeKey] then
            themeKey = ThemeDisplayNames[themeKey] or "AetherCloud"
        end
    else
        themeKey = "AetherCloud"
    end

    local UI = { Name = Name, Version = Version, Flags = {}, Themes = Themes }
    local Destroyed = false

    --// STATE
    local State = {
        Theme = themeKey,
        Accent = Themes[themeKey].Primary,
        Scale = 1,
        Transparency = 0,
        Animations = true,
        Clouds = true,
        ReduceMotion = false,
        AnimatedAccent = false,
        AccentSpeed = 1,
        NotificationsEnabled = true,
        Tooltips = true,
        Compact = false,
        SidebarMode = "Auto",
        MenuKey = Enum.KeyCode.RightShift,
        Visible = false,
        Minimized = false,
        CurrentTab = nil,
        SessionStart = os.clock(),
    }
    UI.State = State

    --// CLEANUP MANAGER
    local JanitorItems = {}
    local function CleanAdd(item)
        table.insert(JanitorItems, item)
        return item
    end
    local function RunCleanup()
        for i = #JanitorItems, 1, -1 do
            local item = JanitorItems[i]
            pcall(function()
                if typeof(item) == "RBXScriptConnection" then
                    item:Disconnect()
                elseif typeof(item) == "Instance" then
                    item:Destroy()
                elseif type(item) == "function" then
                    item()
                end
            end)
            JanitorItems[i] = nil
        end
    end

    local function Connect(signal, callback)
        return CleanAdd(signal:Connect(function(...)
            if not Destroyed then callback(...) end
        end))
    end
    local activeTweens = {}
    CleanAdd(function()
        for tween in pairs(activeTweens) do tween:Cancel() end
        table.clear(activeTweens)
    end)
    local runtimeTask = task
    local task = {wait = runtimeTask.wait, cancel = runtimeTask.cancel}
    local scheduled = {}
    for _, method in ipairs({"defer", "spawn", "delay"}) do
        task[method] = function(...)
            if Destroyed then return nil end
            local args = table.pack(...)
            local callbackIndex = method == "delay" and 2 or 1
            local callback = args[callbackIndex]
            local ticket = {}
            scheduled[ticket] = true
            args[callbackIndex] = function(...)
                if Destroyed then scheduled[ticket] = nil; return end
                local ok, err = pcall(callback, ...)
                scheduled[ticket] = nil
                if not ok then warn("[Aether] scheduled callback error:", err) end
            end
            ticket.thread = runtimeTask[method](table.unpack(args, 1, args.n))
            return ticket.thread
        end
    end
    CleanAdd(function()
        for ticket in pairs(scheduled) do
            if ticket.thread then pcall(runtimeTask.cancel, ticket.thread) end
        end
        table.clear(scheduled)
    end)
    --// TWEEN HELPERS
    local function Dur(base)
        if State.ReduceMotion or not State.Animations then return 0.04 end
        return base
    end

    local function Tw(obj, duration, props, style)
        if Destroyed or not obj.Parent then return end
        local tween = TweenService:Create(obj,
            TweenInfo.new(Dur(duration), style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
        activeTweens[tween] = true
        local done
        done = tween.Completed:Connect(function()
            activeTweens[tween] = nil
            if done then done:Disconnect() end
        end)
        tween:Play()
    end

    --// THEME REGISTRY
    local ThemeObjects = {}   -- { obj, prop, key }
    local ThemedGradients = {} -- { gradient, builder }
    local AccentGradients = {}

    local function DefaultProp(obj)
        if obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton") then
            return "TextColor3"
        elseif obj:IsA("UIStroke") then
            return "Color"
        elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
            return "ImageColor3"
        end
        return "BackgroundColor3"
    end

    local function ColorFor(key)
        if key == "Primary" then return State.Accent end
        return Themes[State.Theme][key]
    end

    local function Themed(obj, key, prop)
        prop = prop or DefaultProp(obj)
        local c = ColorFor(key)
        if c then obj[prop] = c end
        table.insert(ThemeObjects, { obj = obj, prop = prop, key = key })
        return obj
    end

    local function MakeLabel(props, themeKey)
        local lbl = Create("TextLabel", props)
        if not lbl.Font then lbl.Font = FONTS.Body.Font end
        if lbl.TextSize == 0 or lbl.TextSize == nil then lbl.TextSize = FONTS.Body.Size end
        if props.BackgroundTransparency == nil then lbl.BackgroundTransparency = 1 end
        if props.TextXAlignment == nil then lbl.TextXAlignment = Enum.TextXAlignment.Left end
        return Themed(lbl, themeKey or "Text")
    end

    local function RegisterGradient(g, builder)
        table.insert(ThemedGradients, { g = g, builder = builder })
        g.Color = builder(Themes[State.Theme])
        return g
    end

    local function AccentGradient(obj, rotation)
        local g = Create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, State.Accent),
                ColorSequenceKeypoint.new(0.5, Themes[State.Theme].Secondary),
                ColorSequenceKeypoint.new(1, Themes[State.Theme].Pink),
            }),
            Rotation = rotation or 0,
            Parent = obj,
        })
        table.insert(AccentGradients, g)
        return g
    end

    local function ApplyThemeColors(instant)
        local theme = Themes[State.Theme]
        for _, entry in ipairs(ThemeObjects) do
            local c = ColorFor(entry.key)
            if c then
                if instant then
                    entry.obj[entry.prop] = c
                else
                    Tw(entry.obj, 0.35, { [entry.prop] = c }, Enum.EasingStyle.Quad)
                end
            end
        end
        for _, reg in ipairs(ThemedGradients) do
            reg.g.Color = reg.builder(theme)
        end
        for _, g in ipairs(AccentGradients) do
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, State.Accent),
                ColorSequenceKeypoint.new(0.5, theme.Secondary),
                ColorSequenceKeypoint.new(1, theme.Pink),
            })
        end
    end

    local AccentPickerHandle = nil

    local function SetAccent(color)
        State.Accent = color
        for _, entry in ipairs(ThemeObjects) do
            if entry.key == "Primary" then
                Tw(entry.obj, 0.3, { [entry.prop] = color }, Enum.EasingStyle.Quad)
            end
        end
        for _, g in ipairs(AccentGradients) do
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, color),
                ColorSequenceKeypoint.new(0.5, Themes[State.Theme].Secondary),
                ColorSequenceKeypoint.new(1, Themes[State.Theme].Pink),
            })
        end
    end

    local function SetTheme(key)
        if not Themes[key] then
            warn("[Aether] unknown theme:", tostring(key))
            return false
        end
        State.Theme = key
        State.Accent = Themes[key].Primary
        ApplyThemeColors(false)
        if AccentPickerHandle then AccentPickerHandle.Set(Themes[key].Primary, nil, true) end
        return true
    end

    -- animated accent (gentle lavender -> blue -> pink)
    local accentPhase, accentAccum = 0, 0
    local function ApplyAnimatedAccent()
        local p = accentPhase < 1 and accentPhase or (2 - accentPhase)
        local theme = Themes[State.Theme]
        local a, b, c = State.Accent, theme.Secondary, theme.Pink
        local seg = p * 3
        local col
        if seg < 1 then col = LerpColor(a, b, seg)
        elseif seg < 2 then col = LerpColor(b, c, seg - 1)
        else col = LerpColor(c, a, seg - 2) end
        for _, entry in ipairs(ThemeObjects) do
            if entry.key == "Primary" then
                entry.obj[entry.prop] = col
            end
        end
        for _, g in ipairs(AccentGradients) do
            g.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, col),
                ColorSequenceKeypoint.new(0.5, theme.Secondary),
                ColorSequenceKeypoint.new(1, theme.Pink),
            })
        end
    end

    --// SCREENGUI (with duplicate protection)
    local guiParent = nil
    if not RunService:IsStudio() then
        pcall(function()
            if gethui then guiParent = gethui() end
        end)

    end
    guiParent = config.Parent or guiParent or LocalPlayer:WaitForChild("PlayerGui")

    for _, child in ipairs(guiParent:GetChildren()) do
        if child:IsA("ScreenGui") and child.Name == Name .. "UI" then
            child:Destroy()
        end
    end

    local ScreenGui = Create("ScreenGui", {
        Name = Name .. "UI",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 100,
        Parent = guiParent,
    })
    CleanAdd(ScreenGui)
    UI.Gui = ScreenGui

    --// NOTIFICATION LAYER
    local NoteLayer = Create("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 16),
        Size = UDim2.new(0, 300, 0.55, 0),
        BackgroundTransparency = 1,
        ZIndex = 80,
        Parent = ScreenGui,
    }, {
        Create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 10),
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
        }),
    })

    local NoteTypes = {
        Success = { Glyph = "✓", Key = "Success", Label = "Success" },
        Info    = { Glyph = "i", Key = "Secondary", Label = "Info" },
        Warning = { Glyph = "!", Key = "Warning", Label = "Warning" },
        Error   = { Glyph = "✕", Key = "Error", Label = "Error" },
    }

    local noteOrder = 0
    local function Notify(cfg)
        if not State.NotificationsEnabled then return nil end
        cfg = cfg or {}
        local kind = NoteTypes[cfg.Type] or NoteTypes.Info
        local color = ColorFor(kind.Key)
        local duration = cfg.Duration or cfg.Time or 4
        noteOrder += 1

        local count = 0
        for _, c in ipairs(NoteLayer:GetChildren()) do
            if c:IsA("CanvasGroup") then count += 1 end
        end
        if count >= 6 then
            for _, c in ipairs(NoteLayer:GetChildren()) do
                if c:IsA("CanvasGroup") then c:Destroy() break end
            end
        end

        local card = Create("CanvasGroup", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.08,
            GroupTransparency = 1,
            Position = UDim2.new(0, 60, 0, 0),
            LayoutOrder = noteOrder,
            Parent = NoteLayer,
        }, {
            Corner(12),
            Pad(12, 24, 12, 12),
            List(6),
        })
        Themed(card, "Surface")
        local cardStroke = Stroke(color, 1, 0.45)
        cardStroke.Parent = card

        local top = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
            Parent = card,
        })
        local iconBack = Create("Frame", {
            Size = UDim2.new(0, 26, 0, 26),
            BackgroundColor3 = color,
            BackgroundTransparency = 0.85,
            Parent = top,
        }, { CornerFull() })
        Create("TextLabel", {
            Text = kind.Glyph, Font = FONTS.Title.Font, TextSize = 12,
            TextColor3 = color, Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, Parent = iconBack,
        })
        MakeLabel({
            Text = cfg.Title or kind.Label,
            Font = FONTS.Section.Font, TextSize = 14,
            Position = UDim2.new(0, 36, 0, 0),
            Size = UDim2.new(1, -58, 0, 26),
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = top,
        }, "Text")
        local closeBtn = Create("TextButton", {
            Text = "✕", Font = FONTS.Caption.Font, TextSize = 11,
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 6),
            Size = UDim2.new(0, 18, 0, 18),
            BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
            AutoButtonColor = false, Parent = top,
        })
        Themed(closeBtn, "Muted")

        MakeLabel({
            Text = cfg.Description or cfg.Content or "",
            Font = FONTS.Body.Font, TextSize = 12,
            TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 2, Parent = card,
        }, "SubText")

        local action
        if cfg.Action and cfg.Action.Text then
            action = Create("TextButton", {
                Text = cfg.Action.Text, Font = FONTS.Title.Font, TextSize = 12,
                Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
                AutoButtonColor = false, LayoutOrder = 3, Parent = card,
            }, { Corner(7), Pad(0, 0, 12, 12) })
            Themed(action, "Primary")
            local st = Stroke(nil, 1, 0.6)
            Themed(st, "Border")
            st.Parent = action
        end

        local progress = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -8),
            Size = UDim2.new(1, -24, 0, 3),
            BackgroundColor3 = color,
            BackgroundTransparency = 0.35,
            Parent = card,
        }, { Corner(2) })

        Tw(card, 0.35, { GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
        TweenService:Create(progress,
            TweenInfo.new(duration, Enum.EasingStyle.Linear),
            { Size = UDim2.new(0, 0, 0, 3) }):Play()

        local closed = false
        local function Dismiss()
            if closed then return end
            closed = true
            Tw(card, 0.3, { GroupTransparency = 1, Position = UDim2.new(0, 60, 0, 0) })
            task.delay(Dur(0.3) + 0.05, function() card:Destroy() end)
        end
        Connect(closeBtn.MouseButton1Click, Dismiss)
        task.delay(duration, Dismiss)
        if action and cfg.Action.Callback then
            Connect(action.MouseButton1Click, function()
                SafeCall(cfg.Action.Callback)
                Dismiss()
            end)
        end
        return { Dismiss = Dismiss, Card = card }
    end

    --// TOOLTIP SYSTEM
    local Tooltip, TooltipLabel = nil, nil
    local function EnsureTooltip()
        if Tooltip then return end
        Tooltip = Create("CanvasGroup", {
            Size = UDim2.new(0, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.08,
            GroupTransparency = 1,
            Visible = false,
            ZIndex = 120,
            Parent = ScreenGui,
        }, { Corner(8), Pad(8, 8, 10, 10) })
        Themed(Tooltip, "Elevated")
        local st = Stroke(nil, 1, 0.55)
        Themed(st, "Border")
        st.Parent = Tooltip
        TooltipLabel = MakeLabel({
            Text = "", Font = FONTS.Caption.Font, TextSize = 11,
            TextWrapped = true, Size = UDim2.new(0, 200, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, Parent = Tooltip,
        }, "SubText")
    end

    local function HideTooltip()
        if Tooltip and Tooltip.Visible then
            Tw(Tooltip, 0.15, { GroupTransparency = 1 })
            task.delay(Dur(0.15) + 0.03, function()
                if Tooltip and Tooltip.GroupTransparency >= 0.99 then
                    Tooltip.Visible = false
                end
            end)
        end
    end

    local function ShowTooltip(text)
        if not State.Tooltips or not text or text == "" then return end
        EnsureTooltip()
        TooltipLabel.Text = text
        Tooltip.Visible = true
        task.defer(function()
            if not Tooltip.Visible then return end
            local vs = ScreenGui.AbsoluteSize
            local w, h = 220, Tooltip.AbsoluteSize.Y
            local x = clamp(Mouse.X - w / 2, 8, math.max(8, vs.X - w - 8))
            local y = Mouse.Y - h - 16
            if y < 8 then y = Mouse.Y + 20 end
            Tooltip.Position = UDim2.new(0, x, 0, y)
            Tw(Tooltip, 0.18, { GroupTransparency = 0 })
        end)
    end

    local function AttachTooltip(obj, text)
        Connect(obj.MouseEnter, function() ShowTooltip(text) end)
        Connect(obj.MouseLeave, HideTooltip)
    end

    --// MODAL SYSTEM
    local ActiveModal = nil
    local function MakeModal(cfg)
        cfg = cfg or {}
        local dim = Create("CanvasGroup", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.5,
            GroupTransparency = 1,
            ZIndex = 100,
            Active = true,
            Parent = ScreenGui,
        })
        local card = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 340, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.05,
            Parent = dim,
        }, { Corner(16), Pad(20, 20, 18, 18), List(8) })
        Themed(card, "Surface")
        local cst = Stroke(nil, 1, 0.4)
        Themed(cst, "Border")
        cst.Parent = card

        MakeLabel({
            Text = cfg.Title or "Are you sure?",
            Font = FONTS.Section.Font, TextSize = 16,
            Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1, Parent = card,
        }, "Text")
        MakeLabel({
            Text = cfg.Description or "",
            Font = FONTS.Body.Font, TextSize = 13,
            TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = card,
        }, "SubText")

        local btnRow = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1,
            LayoutOrder = 3, Parent = card,
        }, {
            Create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        })

        local function DialogButton(text, style)
            local btn = Create("TextButton", {
                Text = text, Font = FONTS.Title.Font, TextSize = 13,
                Size = UDim2.new(0, 104, 1, 0),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 1,
                TextColor3 = Color3.new(1, 1, 1),
                AutoButtonColor = false, Parent = btnRow,
            }, { Corner(10) })
            if style == "Primary" then
                btn.BackgroundTransparency = 0
                AccentGradient(btn, 0)
            elseif style == "Danger" then
                Themed(btn, "Error", "BackgroundColor3")
                btn.BackgroundTransparency = 0.82
                Themed(btn, "Error")
                local st = Stroke(nil, 1, 0.55)
                Themed(st, "Error")
                st.Parent = btn
            else
                Themed(btn, "Elevated", "BackgroundColor3")
                btn.BackgroundTransparency = 0.4
                Themed(btn, "Text")
                local st = Stroke(nil, 1, 0.5)
                Themed(st, "Border")
                st.Parent = btn
            end
            local bs = Create("UIScale", { Scale = 1, Parent = btn })
            Connect(btn.MouseEnter, function()
                Tw(btn, 0.15, { BackgroundTransparency = math.max(btn.BackgroundTransparency - 0.12, 0) })
            end)
            Connect(btn.MouseLeave, function()
                Tw(btn, 0.25, { BackgroundTransparency = style == "Primary" and 0
                    or (style == "Danger" and 0.82 or 0.4) })
            end)
            Connect(btn.MouseButton1Down, function() Tw(bs, 0.08, { Scale = 0.96 }) end)
            Connect(btn.MouseButton1Up, function() Tw(bs, 0.2, { Scale = 1 }) end)
            return btn
        end

        local scale = Create("UIScale", { Scale = 0.94, Parent = card })
        Tw(dim, 0.2, { GroupTransparency = 0 })
        Tw(scale, 0.24, { Scale = 1 })

        local finished = false
        local function Finish(confirmed)
            if finished then return end
            finished = true
            if ActiveModal and ActiveModal.cancel == Finish then ActiveModal = nil end
            Tw(dim, 0.18, { GroupTransparency = 1 })
            task.delay(Dur(0.18) + 0.05, function() dim:Destroy() end)
            if confirmed then
                SafeCall(cfg.OnConfirm)
            else
                SafeCall(cfg.OnCancel)
            end
        end

        local cancel = DialogButton(cfg.CancelText or "Cancel", "Secondary")
        Connect(cancel.MouseButton1Click, function() Finish(false) end)
        local confirm = DialogButton(cfg.ConfirmText or "Confirm", cfg.Danger and "Danger" or "Primary")
        Connect(confirm.MouseButton1Click, function() Finish(true) end)

        ActiveModal = { cancel = function() Finish(false) end }
        return { Close = function() Finish(false) end }
    end

    --// CONTEXT MENU
    local ContextLayer = nil
    local function CloseContextMenu()
        if ContextLayer then
            ContextLayer:Destroy()
            ContextLayer = nil
        end
    end

    local function ShowContextMenu(items, x, y)
        CloseContextMenu()
        if type(items) ~= "table" or #items == 0 then return end
        x = x or Mouse.X
        y = y or Mouse.Y
        local layer = Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, ZIndex = 90, Active = true,
            Parent = ScreenGui,
        })
        ContextLayer = layer
        local menu = Create("Frame", {
            Position = UDim2.new(0, x, 0, y),
            Size = UDim2.new(0, 176, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.05,
            Parent = layer,
        }, { Corner(12), Pad(6, 6, 6, 6), List(2) })
        Themed(menu, "Surface")
        local mst = Stroke(nil, 1, 0.5)
        Themed(mst, "Border")
        mst.Parent = menu

        for i, item in ipairs(items) do
            local b = Create("TextButton", {
                Text = "", Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 1,
                AutoButtonColor = false, LayoutOrder = i, Parent = menu,
            }, { Corner(8) })
            local iconW = item.Icon and 30 or 0
            if item.Icon then
                MakeLabel({
                    Text = item.Icon, Font = FONTS.Title.Font, TextSize = 13,
                    Position = UDim2.new(0, 9, 0, 0), Size = UDim2.new(0, 16, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Center, Parent = b,
                }, item.Danger and "Error" or "Primary")
            end
            MakeLabel({
                Text = tostring(item.Text or item.Name or "Action"),
                Font = FONTS.Body.Font, TextSize = 13,
                Position = UDim2.new(0, 10 + iconW, 0, 0),
                Size = UDim2.new(1, -20 - iconW, 1, 0),
                TextTruncate = Enum.TextTruncate.AtEnd, Parent = b,
            }, item.Danger and "Error" or "SubText")
            Connect(b.MouseEnter, function()
                Tw(b, 0.12, { BackgroundTransparency = 0.93 })
            end)
            Connect(b.MouseLeave, function() Tw(b, 0.2, { BackgroundTransparency = 1 }) end)
            Connect(b.MouseButton1Click, function()
                CloseContextMenu()
                SafeCall(item.Callback)
            end)
        end

        task.defer(function()
            local vs = ScreenGui.AbsoluteSize
            local w, h = menu.AbsoluteSize.X, menu.AbsoluteSize.Y
            menu.Position = UDim2.new(0, clamp(x, 8, math.max(8, vs.X - w - 8)),
                0, clamp(y, 8, math.max(8, vs.Y - h - 8)))
        end)

        Connect(layer.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                local r = menu.AbsoluteRect
                local px, py = input.Position.X, input.Position.Y
                if px < r.X or px > r.X + r.Width or py < r.Y or py > r.Y + r.Height then
                    CloseContextMenu()
                end
            end
        end)
    end

    --// RESPONSIVE SYSTEM
    local Sizes = {
        Window = Vector2.new(740, 520),
        Sidebar = 200,
        Topbar = 56,
        Row = 46,
        RowDesc = 16,
        SectionPad = 16,
        StatColumns = 2,
        Collapsed = false,
    }
    local Breakpoint = "Desktop"
    local RegisteredRows = {}
    local SectionRegistry = {}
    local StatGrids = {}
    local PagePads = {}
    local SearchIndex = {}

    local function GetBreakpoint()
        local w = ScreenGui.AbsoluteSize.X
        if w > 900 then return "Desktop"
        elseif w >= 600 then return "Tablet" end
        return "Phone"
    end

    local function AddSearchRow(frame, text, section)
        table.insert(SearchIndex, {
            frame = frame,
            text = string.lower(tostring(text or "")),
            section = section,
        })
    end

    local function ApplySearch(query)
        query = string.lower(tostring(query or ""))
        local visibleSections = {}
        for _, entry in ipairs(SearchIndex) do
            local match = query == "" or (string.find(entry.text, query, 1, true) ~= nil)
            entry.frame.Visible = match
            if entry.section then
                visibleSections[entry.section] = visibleSections[entry.section] or match
            end
        end
        for _, sec in ipairs(SectionRegistry) do
            sec.Frame.Visible = (query == "") or (visibleSections[sec] == true)
        end
    end

    local NewSectionSafe, MakeToggleSafe, MakeButtonSafe, MakeSliderSafe, MakeDropdownSafe, MakeTextboxSafe, MakeKeybindSafe, MakeColorpickerSafe, MakeParagraphSafe, MakeStatCardSafe
    local AddTabSafe, CloseWindowSafe, SetMinimizedSafe, WindowSelectTabSafe
    -- forward declarations
    local Root, Window, WindowScale, AnimScale
    local Sidebar, Topbar, ContentHolder, PopupLayer, CloudHolder
    local TabScroll, Indicator, TopbarTitle, SearchFrame, SearchInput, DragZone, MiniBrand
    local ChromeBuilt = false
    local Tabs = {}
    local TabLabels = {}
    local SidebarTexts = {}
    local TabBadges = {}
    local Dash = {}
    local KeybindRegistry = {}
    local Binding = { active = false, resolve = nil }
    local ActiveDropdown = nil
    local ActivePicker = nil
    local GlassPanels = {}
    local UpdateChrome = nil
    local Orbs = {}
    local MARGIN = 24

    local function ClampPosition()
        if not Root then return end
        local vs = ScreenGui.AbsoluteSize
        if vs.X < 50 then return end
        local rw, rh = Root.AbsoluteSize.X, Root.AbsoluteSize.Y
        if rw < 10 then
            rw, rh = Sizes.Window.X + MARGIN * 2, Sizes.Window.Y + MARGIN * 2
        end
        local cx = Root.Position.X.Scale * vs.X + Root.Position.X.Offset
        local cy = Root.Position.Y.Scale * vs.Y + Root.Position.Y.Offset
        local minX, maxX = 70 - rw / 2, vs.X - 70 + rw / 2
        local minY, maxY = rh / 2 + 4, vs.Y - 60 + rh / 2
        if minX > maxX then cx = vs.X / 2 else cx = clamp(cx, minX, maxX) end
        if minY > maxY then cy = vs.Y / 2 else cy = clamp(cy, minY, maxY) end
        Root.Position = UDim2.new(0, math.floor(cx + 0.5), 0, math.floor(cy + 0.5))
    end

    local function ApplyResponsive(animate)
        Breakpoint = GetBreakpoint()
        local isPhone = Breakpoint == "Phone"
        local isTablet = Breakpoint == "Tablet"
        Sizes.Row = State.Compact and 38 or (isPhone and 54 or 46)
        Sizes.RowDesc = State.Compact and 12 or (isPhone and 18 or 16)
        Sizes.SectionPad = State.Compact and 10 or (isPhone and 14 or 16)
        Sizes.Topbar = isPhone and 60 or 56
        Sizes.StatColumns = isPhone and 1 or 2
        local vs = ScreenGui.AbsoluteSize
        if vs.X > 900 then
            Sizes.Window = Vector2.new(740, 520)
        elseif vs.X >= 600 then
            Sizes.Window = Vector2.new(math.floor(vs.X * 0.80), math.floor(vs.Y * 0.76))
        elseif vs.X > 50 then
            Sizes.Window = Vector2.new(math.floor(vs.X * 0.94), math.floor(vs.Y * 0.86))
        end
        local collapsed = (State.SidebarMode == "Collapsed")
            or (State.SidebarMode == "Auto" and isPhone)
        Sizes.Collapsed = collapsed
        Sizes.Sidebar = collapsed and 64 or (isTablet and 188 or 200)

        for _, r in ipairs(RegisteredRows) do
            r.frame.Size = UDim2.new(1, 0, 0,
                Sizes.Row + (r.hasDesc and Sizes.RowDesc or 0) + r.extra)
        end
        for _, s in ipairs(SectionRegistry) do
            if s.pad then
                s.pad.PaddingTop = UDim.new(0, Sizes.SectionPad)
                s.pad.PaddingBottom = UDim.new(0, Sizes.SectionPad)
                s.pad.PaddingLeft = UDim.new(0, Sizes.SectionPad)
                s.pad.PaddingRight = UDim.new(0, Sizes.SectionPad)
            end
        end
        for _, g in ipairs(StatGrids) do
            g.CellSize = UDim2.new(1 / Sizes.StatColumns,
                -((Sizes.StatColumns - 1) * 5 + 6), 0, 96)
        end
        for _, pp in ipairs(PagePads) do
            pp.PaddingLeft = UDim.new(0, isPhone and 2 or 4)
            pp.PaddingRight = UDim.new(0, isPhone and 2 or 4)
        end
        NoteLayer.Size = UDim2.new(0, isPhone and 260 or 300, 0.55, 0)
        if SearchFrame then
            SearchFrame.Size = UDim2.new(0, isPhone and 150 or 190, 0, 34)
            DragZone.Size = UDim2.new(1, isPhone and -240 or -300, 1, 0)
        end
        if ChromeBuilt then
            UpdateChrome(animate)
            ClampPosition()
        end
    end

    --// CHROME BUILD
    local function BuildChrome()
        Root = Create("CanvasGroup", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 740 + MARGIN * 2, 0, 520 + MARGIN * 2),
            BackgroundTransparency = 1,
            GroupTransparency = 1,
            Visible = false,
            ZIndex = 10,
            Parent = ScreenGui,
        })
        AnimScale = Create("UIScale", { Scale = 1, Parent = Root })

        -- soft layered shadow
        for i = 1, 3 do
            local pad = 8 + i * 6
            Create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, i * 2),
                Size = UDim2.new(1, -MARGIN * 2 + pad * 2, 1, -MARGIN * 2 + pad * 2),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 0.5 + (i - 1) * 0.14,
                ZIndex = i,
                Parent = Root,
            }, { Corner(18 + pad) })
        end

        Window = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 740, 0, 520),
            BackgroundColor3 = Color3.new(1, 1, 1),
            ClipsDescendants = true,
            ZIndex = 10,
            Parent = Root,
        }, { Corner(18) })
        Themed(Window, "Background")
        WindowScale = Create("UIScale", { Scale = State.Scale, Parent = Window })
        table.insert(GlassPanels, { frame = Window, base = 0 })
        local wst = Stroke(nil, 1, 0.35)
        Themed(wst, "Border")
        wst.Parent = Window
        RegisterGradient(Create("UIGradient", { Rotation = 90, Parent = Window }), function(theme)
            return ColorSequence.new({
                ColorSequenceKeypoint.new(0, Lighten(theme.Background, 0.05)),
                ColorSequenceKeypoint.new(1, theme.Background),
            })
        end)

        -- decorative cloud layer
        CloudHolder = Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            ZIndex = 1,
            Parent = Window,
        })
        local function AddOrb(colorKey, bx, by, sizeScale, transparency)
            for layer = 1, 2 do
                local s = sizeScale * (layer == 1 and 1 or 0.72)
                local orb = Create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(bx, 0, by, 0),
                    Size = UDim2.new(s, 0, s * 0.8, 0),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BackgroundTransparency = transparency + (layer - 1) * 0.05,
                    ZIndex = 1,
                    Parent = CloudHolder,
                }, { CornerFull() })
                Themed(orb, colorKey)
                if layer == 1 then
                    Orbs[#Orbs + 1] = {
                        frame = orb, bx = bx, by = by,
                        amp = 0.025 + math.random() * 0.02,
                        spd = 0.05 + math.random() * 0.04,
                        ph = math.random() * 6.28,
                    }
                end
            end
        end
        AddOrb("Primary", 0.12, 0.16, 0.55, 0.90)
        AddOrb("Secondary", 0.88, 0.12, 0.50, 0.92)
        AddOrb("Pink", 0.86, 0.86, 0.58, 0.93)
        AddOrb("Text", 0.14, 0.9, 0.42, 0.95)
        AddOrb("Primary", 0.52, 0.52, 0.68, 0.965)

        -- SIDEBAR
        Sidebar = Create("Frame", {
            Position = UDim2.new(0, 12, 0, 12),
            Size = UDim2.new(0, 188, 1, -24),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.35,
            ClipsDescendants = true,
            ZIndex = 5,
            Parent = Window,
        }, { Corner(14) })
        Themed(Sidebar, "Surface")
        table.insert(GlassPanels, { frame = Sidebar, base = 0.35 })
        local sst = Stroke(nil, 1, 0.45)
        Themed(sst, "Border")
        sst.Parent = Sidebar

        -- brand area
        local brandIcon = MakeLabel({
            Text = ICONS.Cloud, Font = FONTS.Display.Font, TextSize = 28,
            Position = UDim2.new(0, 16, 0, 14), Size = UDim2.new(0, 34, 0, 34),
            TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6, Parent = Sidebar,
        }, "Text")
        AccentGradient(brandIcon, 45)
        local brandName = MakeLabel({
            Text = string.upper(Name), Font = FONTS.Section.Font, TextSize = 16,
            Position = UDim2.new(0, 54, 0, 16), Size = UDim2.new(1, -96, 0, 18),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6, Parent = Sidebar,
        }, "Text")
        local brandSub = MakeLabel({
            Text = Subtitle .. "  ·  v" .. Version,
            Font = FONTS.Caption.Font, TextSize = 10,
            Position = UDim2.new(0, 54, 0, 34), Size = UDim2.new(1, -96, 0, 12),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6, Parent = Sidebar,
        }, "Muted")
        table.insert(SidebarTexts, { label = brandName, base = 0 })
        table.insert(SidebarTexts, { label = brandSub, base = 0.15 })

        -- tab list
        TabScroll = Create("ScrollingFrame", {
            Position = UDim2.new(0, 8, 0, 68),
            Size = UDim2.new(1, -16, 1, -128),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageTransparency = 0.45,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ZIndex = 6,
            Parent = Sidebar,
        }, { Pad(2, 8, 2, 2), List(6) })
        Themed(TabScroll, "Border")
        Indicator = Create("Frame", {
            Position = UDim2.new(0, 0, 0, 60),
            Size = UDim2.new(0, 3, 0, 20),
            BackgroundColor3 = Color3.new(1, 1, 1),
            ZIndex = 9,
            Parent = TabScroll,
        }, { Corner(2) })
        AccentGradient(Indicator, 90)

        -- user footer
        local footer = Create("Frame", {
            Position = UDim2.new(0, 10, 1, -52),
            Size = UDim2.new(1, -20, 0, 42),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.75,
            ZIndex = 6,
            Parent = Sidebar,
        }, { Corner(10) })
        Themed(footer, "Cloud")
        local avatar = Create("ImageLabel", {
            Position = UDim2.new(0, 8, 0.5, -15),
            Size = UDim2.new(0, 30, 0, 30),
            BackgroundTransparency = 1,
            Image = "",
            ZIndex = 7,
            Parent = footer,
        }, { CornerFull() })
        local ast = Stroke(nil, 1.5, 0.5)
        Themed(ast, "Primary")
        ast.Parent = avatar
        task.spawn(function()
            local ok, content = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId,
                    Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
            end)
            if ok and content then avatar.Image = content end
        end)
        local userName = MakeLabel({
            Text = LocalPlayer.DisplayName, Font = FONTS.Title.Font, TextSize = 12,
            Position = UDim2.new(0, 46, 0, 7), Size = UDim2.new(1, -54, 0, 13),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7, Parent = footer,
        }, "Text")
        local userSub = MakeLabel({
            Text = "@" .. LocalPlayer.Name, Font = FONTS.Caption.Font, TextSize = 10,
            Position = UDim2.new(0, 46, 0, 22), Size = UDim2.new(1, -54, 0, 12),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7, Parent = footer,
        }, "Muted")
        table.insert(SidebarTexts, { label = userName, base = 0 })
        table.insert(SidebarTexts, { label = userSub, base = 0.15 })

        -- TOPBAR
        Topbar = Create("Frame", {
            Position = UDim2.new(0, 200, 0, 12),
            Size = UDim2.new(1, -212, 0, 56),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.35,
            ZIndex = 5,
            Parent = Window,
        }, { Corner(14) })
        Themed(Topbar, "Surface")
        table.insert(GlassPanels, { frame = Topbar, base = 0.35 })
        local tst = Stroke(nil, 1, 0.45)
        Themed(tst, "Border")
        tst.Parent = Topbar

        local function TopIconButton(glyph, xOffset, tooltipText)
            local btn = Create("TextButton", {
                Text = glyph, Font = FONTS.Title.Font, TextSize = 13,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, xOffset, 0.5, 0),
                Size = UDim2.new(0, 34, 0, 34),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 1,
                AutoButtonColor = false,
                ZIndex = 6,
                Parent = Topbar,
            }, { Corner(10) })
            Themed(btn, "SubText")
            Connect(btn.MouseEnter, function()
                Tw(btn, 0.15, { BackgroundTransparency = 0.9 })
            end)
            Connect(btn.MouseLeave, function()
                Tw(btn, 0.25, { BackgroundTransparency = 1 })
            end)
            AttachTooltip(btn, tooltipText)
            return btn
        end

        local sidebarToggle = Create("TextButton", {
            Text = "☰", Font = FONTS.Title.Font, TextSize = 14,
            Position = UDim2.new(0, 10, 0.5, -17),
            Size = UDim2.new(0, 34, 0, 34),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            ZIndex = 6,
            Parent = Topbar,
        }, { Corner(10) })
        Themed(sidebarToggle, "SubText")
        Connect(sidebarToggle.MouseEnter, function() Tw(sidebarToggle, 0.15, { BackgroundTransparency = 0.9 }) end)
        Connect(sidebarToggle.MouseLeave, function() Tw(sidebarToggle, 0.25, { BackgroundTransparency = 1 }) end)
        AttachTooltip(sidebarToggle, "Expand or collapse the sidebar")

        DragZone = Create("Frame", {
            Position = UDim2.new(0, 50, 0, 0),
            Size = UDim2.new(1, -300, 1, 0),
            BackgroundTransparency = 1,
            ZIndex = 2,
            Parent = Topbar,
        })
        TopbarTitle = MakeLabel({
            Text = "Home", Font = FONTS.Section.Font, TextSize = 15,
            Position = UDim2.new(0, 6, 0, 0),
            Size = UDim2.new(1, -12, 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = DragZone,
        }, "SubText")

        MiniBrand = Create("Frame", {
            Position = UDim2.new(0, 50, 0, 0),
            Size = UDim2.new(0, 200, 1, 0),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 4,
            Parent = Topbar,
        })
        local miniIcon = MakeLabel({
            Text = ICONS.Cloud, Font = FONTS.Title.Font, TextSize = 15,
            Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 20, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5, Parent = MiniBrand,
        }, "Primary")
        MakeLabel({
            Text = Name, Font = FONTS.Section.Font, TextSize = 14,
            Position = UDim2.new(0, 26, 0, 0), Size = UDim2.new(0, 160, 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5, Parent = MiniBrand,
        }, "Text")

        SearchFrame = Create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -96, 0.5, 0),
            Size = UDim2.new(0, 190, 0, 34),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.55,
            ZIndex = 6,
            Parent = Topbar,
        }, { Corner(10) })
        Themed(SearchFrame, "Background")
        local searchStroke = Stroke(nil, 1, 0.55)
        Themed(searchStroke, "Border")
        searchStroke.Parent = SearchFrame
        SearchInput = Create("TextBox", {
            Text = "",
            PlaceholderText = "Search settings...",
            Font = FONTS.Body.Font, TextSize = 12,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 0),
            Size = UDim2.new(1, -20, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            ZIndex = 7,
            Parent = SearchFrame,
        })
        Themed(SearchInput, "SubText")
        Themed(SearchInput, "Muted", "PlaceholderColor3")
        Connect(SearchInput.Focused, function()
            Tw(searchStroke, 0.2, { Color = State.Accent, Transparency = 0.2 })
        end)
        Connect(SearchInput.FocusLost, function()
            Tw(searchStroke, 0.25, { Color = Themes[State.Theme].Border, Transparency = 0.55 })
        end)
        Connect(SearchInput:GetPropertyChangedSignal("Text"), function()
            ApplySearch(SearchInput.Text)
        end)

        local minBtn = TopIconButton("—", -48, "Minimize window")
        local closeBtn = TopIconButton("✕", -12, "Hide interface (" .. KeyDisplayName(State.MenuKey) .. ")")

        -- CONTENT
        ContentHolder = Create("Frame", {
            Position = UDim2.new(0, 200, 0, 80),
            Size = UDim2.new(1, -212, 1, -92),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            ZIndex = 5,
            Parent = Window,
        })

        -- POPUP LAYER (color pickers)
        PopupLayer = Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 40,
            Parent = Window,
        })

        -- window controls
        Connect(minBtn.MouseButton1Click, function()
            SetMinimizedSafe(true)
        end)
        Connect(closeBtn.MouseButton1Click, function()
            CloseWindowSafe()
        end)
        Connect(sidebarToggle.MouseButton1Click, function()
            if State.SidebarMode == "Collapsed" then
                State.SidebarMode = (Breakpoint == "Phone") and "Expanded" or "Auto"
            else
                State.SidebarMode = "Collapsed"
            end
            ApplyResponsive(true)
        end)

        -- dragging (with movement threshold)
        local dragging, dragMoved, dragStartInput, dragStartPos
        Connect(DragZone.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragMoved = false
                dragStartInput = input.Position
                local vs = ScreenGui.AbsoluteSize
                dragStartPos = UDim2.new(0,
                    Root.Position.X.Scale * vs.X + Root.Position.X.Offset, 0,
                    Root.Position.Y.Scale * vs.Y + Root.Position.Y.Offset)
                Root.Position = dragStartPos
            end
        end)
        Connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                local dx = input.Position.X - dragStartInput.X
                local dy = input.Position.Y - dragStartInput.Y
                if not dragMoved and (math.abs(dx) > 6 or math.abs(dy) > 6) then
                    dragMoved = true
                end
                if dragMoved then
                    Root.Position = UDim2.new(0, dragStartPos.X.Offset + dx, 0, dragStartPos.Y.Offset + dy)
                    ClampPosition()
                end
            end
        end)
        Connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        -- right-click context menu on the topbar
        Connect(Topbar.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                ShowContextMenu({
                    { Text = "Minimize",  Icon = "—", Callback = function() SetMinimizedSafe(true) end },
                    { Text = "Hide UI",   Icon = "✕", Callback = function() CloseWindowSafe() end },
                    { Text = "Reset position", Icon = "⌂", Callback = function()
                        Root.Position = UDim2.new(0.5, 0, 0.5, 0)
                    end },
                }, input.Position.X, input.Position.Y)
            end
        end)
    end

    --// CHROME LAYOUT
    UpdateChrome = function(animate)
        if not Root then return end
        local PAD = 12
        local topH = Sizes.Topbar
        local winH = State.Minimized and (topH + PAD * 2) or Sizes.Window.Y
        local winW = Sizes.Window.X
        local sw = State.Minimized and 0 or Sizes.Sidebar
        local sideW = math.max(sw - PAD - 8, 0)
        local function set(obj, props)
            if animate then
                Tw(obj, 0.32, props)
            else
                for k, v in pairs(props) do obj[k] = v end
            end
        end
        set(Root, { Size = UDim2.new(0, winW + MARGIN * 2, 0, winH + MARGIN * 2) })
        set(Window, { Size = UDim2.new(0, winW, 0, winH) })
        Sidebar.Visible = not State.Minimized
        set(Sidebar, {
            Position = UDim2.new(0, PAD, 0, PAD),
            Size = UDim2.new(0, sideW, 1, -PAD * 2),
        })
        set(Topbar, {
            Position = UDim2.new(0, sw, 0, PAD),
            Size = UDim2.new(1, -sw - PAD, 0, topH),
        })
        ContentHolder.Visible = not State.Minimized
        set(ContentHolder, {
            Position = UDim2.new(0, sw, 0, topH + PAD * 2),
            Size = UDim2.new(1, -sw - PAD, 1, -(topH + PAD * 3)),
        })
        MiniBrand.Visible = State.Minimized
        SearchFrame.Visible = not State.Minimized
        TopbarTitle.Visible = not State.Minimized and Breakpoint ~= "Phone"
        local showLabels = (not Sizes.Collapsed) and (not State.Minimized)
        for _, entry in ipairs(TabLabels) do
            Tw(entry.label, 0.25, { TextTransparency = showLabels and entry.base or 1 })
        end
        for _, entry in ipairs(SidebarTexts) do
            Tw(entry.label, 0.25, { TextTransparency = showLabels and entry.base or 1 })
        end
        for _, badge in ipairs(TabBadges) do
            badge.Visible = showLabels
        end
    end

    --// TAB / PAGE SYSTEM
    local function SetScrollEnabled(enabled)
        local tab = State.CurrentTab
        if tab and tab.Scroll then
            tab.Scroll.ScrollingEnabled = enabled
        end
    end

    local function PositionIndicator()
        local tab = State.CurrentTab
        if not tab or not tab.Button then return end
        local y = tab.Button.AbsolutePosition.Y - TabScroll.AbsolutePosition.Y
            + TabScroll.CanvasPosition.Y
            + (tab.Button.AbsoluteSize.Y - 20) / 2
        Tw(Indicator, 0.28, { Position = UDim2.new(0, 0, 0, math.max(y, 4)) })
    end

    local function SelectTab(tab, instant)
        if not tab or State.CurrentTab == tab then return end
        local prev = State.CurrentTab
        State.CurrentTab = tab
        for _, t in ipairs(Tabs) do
            local sel = (t == tab)
            Tw(t.Button, 0.2, { BackgroundTransparency = sel and 0.55 or 1 })
            Tw(t.Icon, 0.2, { TextTransparency = sel and 0 or 0.35 })
            local lblEntry = t._labelEntry
            if lblEntry then
                Tw(t.Label, 0.2, { TextTransparency = sel and 0 or lblEntry.base })
            end
        end
        TopbarTitle.Text = tab.Name
        task.defer(PositionIndicator)
        if prev then
            if instant then
                prev.Group.Visible = false
            else
                Tw(prev.Group, 0.16, { GroupTransparency = 1, Position = UDim2.new(0, -10, 0, 0) }, Enum.EasingStyle.Quad)
                task.delay(Dur(0.16) + 0.02, function()
                    if State.CurrentTab ~= prev then
                        prev.Group.Visible = false
                        prev.Group.Position = UDim2.new(0, 0, 0, 0)
                    end
                end)
            end
        end
        tab.Group.Visible = true
        if instant then
            tab.Group.GroupTransparency = 0
            tab.Group.Position = UDim2.new(0, 0, 0, 0)
        else
            tab.Group.Position = UDim2.new(0, 12, 0, 0)
            tab.Group.GroupTransparency = 1
            Tw(tab.Group, 0.2, { GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quad)
        end
        tab.Scroll.CanvasPosition = Vector2.new(0, 0)
    end

    function AddTabSafe(cfg)
        if type(cfg) == "string" then cfg = { Name = cfg } end
        cfg = cfg or {}
        local tab = { Name = cfg.Name or "Tab", Sections = {}, _order = 0 }
        tab.Order = #Tabs + 1

        local btn = Create("TextButton", {
            Text = "", Size = UDim2.new(1, 0, 0, 36),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            LayoutOrder = tab.Order,
            ZIndex = 7,
            Parent = TabScroll,
        }, { Corner(9) })
        local pill = Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            ZIndex = 1,
            Parent = btn,
        }, { Corner(9) })
        AccentGradient(pill, 0)

        local icon = MakeLabel({
            Text = cfg.Icon or "", Font = FONTS.Title.Font, TextSize = 15,
            Position = UDim2.new(0, 23, 0, 0), Size = UDim2.new(0, 18, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTransparency = 0.35, ZIndex = 3, Parent = btn,
        }, "Primary")
        local label = MakeLabel({
            Text = tab.Name, Font = FONTS.Title.Font, TextSize = 13,
            Position = UDim2.new(0, 48, 0, 0), Size = UDim2.new(1, -56, 1, 0),
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextTransparency = 0.25, ZIndex = 3, Parent = btn,
        }, "Text")
        local labelEntry = { label = label, base = 0.25 }
        tab._labelEntry = labelEntry
        table.insert(TabLabels, labelEntry)

        local badge
        if cfg.Badge ~= nil and cfg.Badge ~= "" then
            badge = Create("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.new(0, 0, 0, 17),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.88,
                ZIndex = 3,
                Parent = btn,
            }, { CornerFull(), Pad(0, 0, 8, 8) })
            Themed(badge, "Primary")
            local bst = Stroke(nil, 1, 0.65)
            Themed(bst, "Primary")
            bst.Parent = badge
            MakeLabel({
                Text = tostring(cfg.Badge), Font = FONTS.Caption.Font, TextSize = 9,
                AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4, Parent = badge,
            }, "Primary")
            table.insert(TabBadges, badge)
        end

        Connect(btn.MouseEnter, function()
            if State.CurrentTab and State.CurrentTab.Button == btn then return end
            Tw(btn, 0.15, { BackgroundTransparency = 0.93 })
        end)
        Connect(btn.MouseLeave, function()
            if State.CurrentTab and State.CurrentTab.Button == btn then return end
            Tw(btn, 0.25, { BackgroundTransparency = 1 })
        end)
        Connect(btn.MouseButton1Click, function() SelectTab(tab) end)

        tab.Button = btn
        tab.Icon = icon
        tab.Label = label

        tab.Group = Create("CanvasGroup", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 6,
            Parent = ContentHolder,
        })
        tab.Scroll = Create("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageTransparency = 0.45,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            Parent = tab.Group,
        }, { Pad(6, 20, 4, 4), List(12) })
        Themed(tab.Scroll, "Border")
        table.insert(PagePads, tab.Scroll.UIPadding)
        Create("Frame", {
            Size = UDim2.new(0, 0, 0, 6), BackgroundTransparency = 1,
            LayoutOrder = 999999, Parent = tab.Scroll,
        })

        table.insert(Tabs, tab)
        if #Tabs == 1 then
            task.defer(function() SelectTab(tab, true) end)
        end

        function tab:AddSection(secCfg)
            return NewSectionSafe(tab, secCfg)
        end

        return tab
    end

    --// SECTION SYSTEM
    NewSectionSafe = function(tab, cfg)
        if type(cfg) == "string" then cfg = { Name = cfg } end
        cfg = cfg or {}
        tab._order += 1

        local self = { Rows = {}, RowOrder = 1, Tab = tab }
        self.Frame = Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.25,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ClipsDescendants = true,
            LayoutOrder = tab._order,
            ZIndex = 6,
            Parent = tab.Scroll,
        }, { Corner(14), Pad(Sizes.SectionPad, Sizes.SectionPad, Sizes.SectionPad, Sizes.SectionPad), List(8) })
        Themed(self.Frame, "Surface")
        self.Stroke = Stroke(nil, 1, 0.5)
        Themed(self.Stroke, "Border")
        self.Stroke.Parent = self.Frame
        self.pad = self.Frame.UIPadding

        local titleRow = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            LayoutOrder = 0,
            ZIndex = 7,
            Parent = self.Frame,
        })
        if cfg.Icon then
            MakeLabel({
                Text = cfg.Icon, Font = FONTS.Section.Font, TextSize = 14,
                Position = UDim2.new(0, 0, 0, 1), Size = UDim2.new(0, 20, 0, 18),
                TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = titleRow,
            }, "Primary")
        end
        MakeLabel({
            Text = cfg.Name or "Section", Font = FONTS.Section.Font, TextSize = 15,
            Position = UDim2.new(0, cfg.Icon and 26 or 0, 0, 1),
            Size = UDim2.new(1, cfg.Icon and -26 or 0, 0, 18),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = titleRow,
        }, "Text")
        if cfg.Description then
            MakeLabel({
                Text = cfg.Description, Font = FONTS.Caption.Font, TextSize = 11,
                TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                LayoutOrder = 1, ZIndex = 7, Parent = self.Frame,
            }, "Muted")
        end

        function self:NextOrder()
            self.RowOrder += 1
            return self.RowOrder + 1
        end

        table.insert(SectionRegistry, self)
        AddSearchRow(self.Frame, (cfg.Name or "") .. " " .. (cfg.Description or ""), self)

        function self:AddToggle(c) return MakeToggleSafe(self, c) end
        function self:AddButton(c) return MakeButtonSafe(self, c) end
        function self:AddSlider(c) return MakeSliderSafe(self, c) end
        function self:AddDropdown(c) return MakeDropdownSafe(self, c) end
        function self:AddTextbox(c) return MakeTextboxSafe(self, c) end
        function self:AddKeybind(c) return MakeKeybindSafe(self, c) end
        function self:AddColorpicker(c) return MakeColorpickerSafe(self, c) end
        function self:AddParagraph(c) return MakeParagraphSafe(self, c) end
        function self:AddStatCard(c) return MakeStatCardSafe(self, c) end

        return self
    end

    --// ROW FACTORY
    local function MakeRow(section, cfg, extra)
        local hasDesc = type(cfg.Description) == "string" and cfg.Description ~= ""
        extra = extra or 0
        local row = Create("Frame", {
            Size = UDim2.new(1, 0, 0, Sizes.Row + (hasDesc and Sizes.RowDesc or 0) + extra),
            BackgroundTransparency = 1,
            LayoutOrder = section:NextOrder(),
            ZIndex = 7,
            Parent = section.Frame,
        }, { Corner(10) })
        local hoverPad = Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            ZIndex = 1,
            Parent = row,
        }, { Corner(10) })
        local title = MakeLabel({
            Text = cfg.Name or "Setting", Font = FONTS.Title.Font, TextSize = 14,
            Position = hasDesc and UDim2.new(0, 4, 0, 6) or UDim2.new(0, 4, 0.5, -9),
            Size = UDim2.new(1, -178, 0, 18),
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 2, Parent = row,
        }, "Text")
        local desc
        if hasDesc then
            desc = MakeLabel({
                Text = cfg.Description, Font = FONTS.Caption.Font, TextSize = 11,
                TextWrapped = true,
                Position = UDim2.new(0, 4, 0, 26),
                Size = UDim2.new(1, -178, 0, 14),
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 2, Parent = row,
            }, "Muted")
        end
        local entry = { frame = row, hasDesc = hasDesc, extra = extra }
        table.insert(RegisteredRows, entry)
        AddSearchRow(row, (cfg.Name or "") .. " " .. (cfg.Description or ""), section)
        Connect(row.MouseEnter, function()
            Tw(hoverPad, 0.15, { BackgroundTransparency = 0.965 })
            Tw(section.Stroke, 0.2, { Transparency = 0.35 })
        end)
        Connect(row.MouseLeave, function()
            Tw(hoverPad, 0.25, { BackgroundTransparency = 1 })
            Tw(section.Stroke, 0.3, { Transparency = 0.5 })
        end)
        return row, title, desc, hoverPad, entry
    end

    --// TOGGLE
    local function RegisterFlag(name, handle)
        if not name or name == "" then return end
        UI.Flags[name] = handle
    end

    MakeToggleSafe = function(section, cfg)
        cfg = cfg or {}
        local row = MakeRow(section, cfg)
        local btn = Create("TextButton", {
            Text = "", Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            ZIndex = 3, Parent = row,
        })
        local track = Create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 44, 0, 24),
            ZIndex = 4, Parent = row,
        }, { CornerFull() })
        local trackBG = Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.35,
            ZIndex = 4, Parent = track,
        }, { CornerFull() })
        Themed(trackBG, "Border")
        local fill = Create("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            ZIndex = 5, Parent = track,
        }, { CornerFull() })
        AccentGradient(fill, 0)
        local halo = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(1, 10, 1, 10),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            ZIndex = 3, Parent = track,
        }, { CornerFull() })
        Themed(halo, "Primary")
        local tStroke = Stroke(nil, 1, 0.6)
        Themed(tStroke, "Border")
        tStroke.Parent = track
        local knob = Create("Frame", {
            Size = UDim2.new(0, 18, 0, 18),
            Position = UDim2.new(0, 3, 0.5, -9),
            BackgroundColor3 = Color3.fromRGB(243, 245, 255),
            ZIndex = 6, Parent = track,
        }, { CornerFull(), Stroke(Color3.fromRGB(20, 22, 34), 1, 0.75) })

        local value = cfg.Default == true
        local function Set(v, noCb)
            value = v and true or false
            Tw(fill, 0.18, { BackgroundTransparency = value and 0 or 1 })
            Tw(knob, 0.18, {
                Position = value and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
            }, Enum.EasingStyle.Quad)
            Tw(halo, 0.25, { BackgroundTransparency = value and 0.86 or 1 })
            Tw(tStroke, 0.18, {
                Transparency = value and 0.2 or 0.6,
                Color = value and State.Accent or Themes[State.Theme].Border,
            })
            if not noCb then SafeCall(cfg.Callback, value) end
        end
        Set(value, true)
        Connect(btn.MouseButton1Click, function() Set(not value) end)

        local handle = {
            Set = function(v, noCb) Set(v == true, noCb) end,
            Get = function() return value end,
            Default = value,
        }
        RegisterFlag(cfg.Flag, handle)
        return handle
    end

    --// BUTTON
    MakeButtonSafe = function(section, cfg)
        cfg = cfg or {}
        local style = cfg.Style or "Secondary"
        local btn = Create("TextButton", {
            Text = cfg.Name or "Button",
            Font = FONTS.Title.Font, TextSize = 14,
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundColor3 = Color3.new(1, 1, 1),
            AutoButtonColor = false,
            LayoutOrder = section:NextOrder(),
            ZIndex = 7,
            Parent = section.Frame,
        }, { Corner(10) })
        local disabled = cfg.Disabled == true
        local baseT
        if style == "Primary" then
            btn.BackgroundTransparency = 0
            AccentGradient(btn, 0)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            baseT = 0
        elseif style == "Danger" then
            Themed(btn, "Error", "BackgroundColor3")
            baseT = 0.82
            btn.BackgroundTransparency = baseT
            Themed(btn, "Error")
            local st = Stroke(nil, 1, 0.55)
            Themed(st, "Error")
            st.Parent = btn
        elseif style == "Ghost" then
            baseT = 1
            btn.BackgroundTransparency = 1
            Themed(btn, "Primary")
        else
            Themed(btn, "Elevated", "BackgroundColor3")
            baseT = 0.35
            btn.BackgroundTransparency = baseT
            Themed(btn, "Text")
            local st = Stroke(nil, 1, 0.5)
            Themed(st, "Border")
            st.Parent = btn
        end
        local bs = Create("UIScale", { Scale = 1, Parent = btn })
        Connect(btn.MouseEnter, function()
            if disabled then return end
            if style == "Ghost" then
                Tw(btn, 0.15, { BackgroundTransparency = 0.94 })
            else
                Tw(btn, 0.15, { BackgroundTransparency = math.max(baseT - 0.15, 0) })
            end
        end)
        Connect(btn.MouseLeave, function()
            Tw(btn, 0.25, { BackgroundTransparency = disabled and math.min(baseT + 0.35, 0.85) or baseT })
        end)
        Connect(btn.MouseButton1Down, function()
            if not disabled then Tw(bs, 0.08, { Scale = 0.97 }) end
        end)
        Connect(btn.MouseButton1Up, function() Tw(bs, 0.2, { Scale = 1 }) end)
        Connect(btn.MouseButton1Click, function()
            if disabled then return end
            SafeCall(cfg.Callback)
        end)
        if disabled then
            btn.BackgroundTransparency = math.min(baseT + 0.35, 0.85)
            btn.TextTransparency = 0.5
        end
        AddSearchRow(btn, cfg.Name or "Button", section)
        local handle = {
            SetText = function(t) btn.Text = t end,
            SetEnabled = function(v)
                disabled = not v
                btn.BackgroundTransparency = disabled and math.min(baseT + 0.35, 0.85) or baseT
                btn.TextTransparency = disabled and 0.5 or 0
            end,
        }
        return handle
    end

    --// SLIDER
    MakeSliderSafe = function(section, cfg)
        cfg = cfg or {}
        local min = cfg.Min or 0
        local max = cfg.Max or 100
        if max <= min then max = min + 1 end
        local step = cfg.Step or 1
        if step <= 0 then step = 1 end
        local decimals = step >= 1 and 0 or clamp(math.ceil(-math.log10(step)), 0, 3)
        local hasDesc = type(cfg.Description) == "string" and cfg.Description ~= ""
        local row, title = MakeRow(section, cfg, 26)
        title.Position = UDim2.new(0, 4, 0, hasDesc and 6 or 10)
        local valLbl = MakeLabel({
            Text = "", Font = FONTS.Title.Font, TextSize = 13,
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, hasDesc and 6 or 10),
            Size = UDim2.new(0, 120, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 3, Parent = row,
        }, "Primary")

        local track = Create("Frame", {
            Position = UDim2.new(0, 4, 1, -16),
            Size = UDim2.new(1, -8, 0, 6),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.55,
            ZIndex = 4, Parent = row,
        }, { CornerFull() })
        Themed(track, "Border")
        local fill = Create("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            ZIndex = 5, Parent = track,
        }, { CornerFull() })
        AccentGradient(fill, 0)
        local hStroke = Stroke(nil, 2, 0.2)
        Themed(hStroke, "Primary")
        local handle = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(0, 14, 0, 14),
            BackgroundColor3 = Color3.fromRGB(245, 246, 255),
            ZIndex = 6, Parent = track,
        }, { CornerFull(), hStroke })

        local value = clamp(cfg.Default or min, min, max)
        local dragging = false

        local function Set(v, noCb)
            v = clamp(v, min, max)
            value = tonumber(string.format("%." .. decimals .. "f",
                math.floor((v - min) / step + 0.5) * step + min)) or v
            local pct = (value - min) / (max - min)
            if dragging then
                fill.Size = UDim2.new(pct, 0, 1, 0)
                handle.Position = UDim2.new(pct, 0, 0.5, 0)
            else
                Tw(fill, 0.08, { Size = UDim2.new(pct, 0, 1, 0) })
                Tw(handle, 0.08, { Position = UDim2.new(pct, 0, 0.5, 0) })
            end
            local text
            if cfg.Percent then
                text = tostring(math.floor(value * 100 + 0.5)) .. "%"
            else
                text = string.format("%." .. decimals .. "f", value)
                if cfg.Suffix and cfg.Suffix ~= "" then text = text .. " " .. cfg.Suffix end
            end
            valLbl.Text = text
            if not noCb then SafeCall(cfg.Callback, value) end
        end

        local hit = Create("Frame", {
            Position = UDim2.new(0, 0, 1, -26),
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1,
            ZIndex = 7, Parent = row,
        })
        local function SetFromX(x)
            local pct = clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
            Set(min + (max - min) * pct)
        end
        Connect(hit.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                Tw(handle, 0.15, { Size = UDim2.new(0, 18, 0, 18) }, Enum.EasingStyle.Back)
                SetScrollEnabled(false)
                SetFromX(input.Position.X)
            end
        end)
        Connect(hit.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                Tw(handle, 0.2, { Size = UDim2.new(0, 14, 0, 14) })
                SetScrollEnabled(true)
            end
        end)
        Connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                SetFromX(input.Position.X)
            end
        end)

        Set(value, true)
        local h = {
            Set = function(v, noCb) Set(v, noCb) end,
            Get = function() return value end,
            Default = clamp(cfg.Default or min, min, max),
        }
        RegisterFlag(cfg.Flag, h)
        return h
    end

    --// DROPDOWN
    MakeDropdownSafe = function(section, cfg)
        cfg = cfg or {}
        cfg.Options = cfg.Options or {}
        local SetOpenSafe
        local Multi = cfg.Multi == true
        local selected = {}
        if Multi and type(cfg.Default) == "table" then
            for _, v in ipairs(cfg.Default) do table.insert(selected, v) end
        elseif (not Multi) and cfg.Default ~= nil then
            selected = { cfg.Default }
        end
        local searchEnabled = cfg.Searchable == true or #cfg.Options >= 8
        local open = false
        local outsideConn = nil

        local row = MakeRow(section, cfg)
        local btn = Create("TextButton", {
            Text = "", Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            ZIndex = 3, Parent = row,
        })
        local valueLabel = MakeLabel({
            Text = "", Font = FONTS.Title.Font, TextSize = 12,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -30, 0.5, 0),
            Size = UDim2.new(0, 118, 0, 16),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 2, Parent = row,
        }, "Primary")
        local chevron = MakeLabel({
            Text = "▼", Font = FONTS.Caption.Font, TextSize = 10,
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
            Size = UDim2.new(0, 14, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 2, Parent = row,
        }, "Muted")

        local panel = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            LayoutOrder = section:NextOrder(),
            ZIndex = 8,
            Parent = section.Frame,
        }, { Pad(2, 4, 2, 2), List(6) })

        local chipsFrame, chipsList
        if Multi then
            chipsFrame = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundTransparency = 1,
                LayoutOrder = 1, ZIndex = 9, Parent = panel,
            }, {
                Create("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    Wraps = true, Padding = UDim.new(0, 6),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),
            })
            chipsList = chipsFrame.UIListLayout
        end

        local searchBox
        if searchEnabled then
            local sf = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.6,
                LayoutOrder = (Multi and 2 or 1),
                ZIndex = 9, Parent = panel,
            }, { Corner(8) })
            Themed(sf, "Background")
            local sst = Stroke(nil, 1, 0.55)
            Themed(sst, "Border")
            sst.Parent = sf
            searchBox = Create("TextBox", {
                Text = "", PlaceholderText = "Filter options...",
                Font = FONTS.Body.Font, TextSize = 12,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 8, 0, 0),
                Size = UDim2.new(1, -16, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
                ClearTextOnFocus = false,
                ZIndex = 10, Parent = sf,
            })
            Themed(searchBox, "SubText")
            Themed(searchBox, "Muted", "PlaceholderColor3")
        end

        local listScroll = Create("ScrollingFrame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 2,
            ScrollBarImageTransparency = 0.45,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            LayoutOrder = (Multi and 3 or 2),
            ZIndex = 9, Parent = panel,
        }, { Pad(0, 4, 0, 0), List(2) })
        Themed(listScroll, "Border")

        local optionButtons = {}

        local function CopySelected()
            local out = {}
            for i, v in ipairs(selected) do out[i] = v end
            return out
        end

        local function ValueText()
            if #selected == 0 then
                return cfg.Placeholder or (Multi and "None selected" or "Select...")
            elseif Multi then
                if #selected == 1 then return tostring(selected[1]) end
                return tostring(selected[1]) .. " +" .. (#selected - 1)
            end
            return tostring(selected[1])
        end

        local function MarkSelection()
            for opt, entry in pairs(optionButtons) do
                local on = table.find(selected, opt) ~= nil
                Tw(entry.label, 0.15, {
                    TextColor3 = on and State.Accent or Themes[State.Theme].SubText,
                })
                Tw(entry.check, 0.15, { TextTransparency = on and 0 or 1 })
            end
        end

        local function RebuildChips()
            if not chipsFrame then return end
            for _, c in ipairs(chipsFrame:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            for _, v in ipairs(selected) do
                local chip = Create("TextButton", {
                    Text = "", Size = UDim2.new(0, 0, 0, 24),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BackgroundTransparency = 0.7,
                    AutoButtonColor = false,
                    ZIndex = 10, Parent = chipsFrame,
                }, { CornerFull(), Pad(0, 0, 9, 7), List(3) })
                Themed(chip, "Cloud")
                MakeLabel({
                    Text = tostring(v), Font = FONTS.Caption.Font, TextSize = 11,
                    AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
                    ZIndex = 11, Parent = chip,
                }, "SubText")
                local x = Create("TextLabel", {
                    Text = "✕", Font = FONTS.Caption.Font, TextSize = 9,
                    Size = UDim2.new(0, 12, 1, 0), BackgroundTransparency = 1,
                    ZIndex = 11, Parent = chip,
                })
                Themed(x, "Muted")
                local val = v
                Connect(chip.MouseButton1Click, function()
                    local idx = table.find(selected, val)
                    if idx then table.remove(selected, idx) end
                    RebuildChips()
                    MarkSelection()
                    valueLabel.Text = ValueText()
                    SafeCall(cfg.Callback, Multi and CopySelected() or selected[1])
                end)
            end
        end

        local function RefreshOptions()
            for _, c in ipairs(listScroll:GetChildren()) do
                if c:IsA("TextButton") then c:Destroy() end
            end
            optionButtons = {}
            local q = searchBox and string.lower(searchBox.Text) or ""
            for i, opt in ipairs(cfg.Options) do
                if q == "" or string.find(string.lower(tostring(opt)), q, 1, true) then
                    local optBtn = Create("TextButton", {
                        Text = "", Size = UDim2.new(1, -4, 0, 30),
                        BackgroundColor3 = Color3.new(1, 1, 1),
                        BackgroundTransparency = 1,
                        AutoButtonColor = false,
                        LayoutOrder = i,
                        ZIndex = 10, Parent = listScroll,
                    }, { Corner(8) })
                    local lbl = MakeLabel({
                        Text = tostring(opt), Font = FONTS.Body.Font, TextSize = 13,
                        Position = UDim2.new(0, 10, 0, 0),
                        Size = UDim2.new(1, -40, 1, 0),
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        ZIndex = 11, Parent = optBtn,
                    }, "SubText")
                    local check = MakeLabel({
                        Text = "✓", Font = FONTS.Title.Font, TextSize = 12,
                        AnchorPoint = Vector2.new(1, 0),
                        Position = UDim2.new(1, -8, 0, 0), Size = UDim2.new(0, 18, 1, 0),
                        TextXAlignment = Enum.TextXAlignment.Center,
                        TextTransparency = 1,
                        ZIndex = 11, Parent = optBtn,
                    }, "Primary")
                    optionButtons[opt] = { label = lbl, check = check }
                    Connect(optBtn.MouseEnter, function()
                        Tw(optBtn, 0.12, { BackgroundTransparency = 0.93 })
                    end)
                    Connect(optBtn.MouseLeave, function()
                        Tw(optBtn, 0.2, { BackgroundTransparency = 1 })
                    end)
                    Connect(optBtn.MouseButton1Click, function()
                        if Multi then
                            local idx = table.find(selected, opt)
                            if idx then
                                table.remove(selected, idx)
                            else
                                table.insert(selected, opt)
                            end
                            RebuildChips()
                            MarkSelection()
                            valueLabel.Text = ValueText()
                            SafeCall(cfg.Callback, CopySelected())
                        else
                            selected = { opt }
                            MarkSelection()
                            valueLabel.Text = ValueText()
                            SafeCall(cfg.Callback, selected[1])
                            SetOpenSafe(false)
                        end
                    end)
                end
            end
            MarkSelection()
        end

        local function PanelHeight()
            local h = 8
            if Multi and chipsList then
                h += chipsList.AbsoluteContentSize.Y + 6
            end
            if searchEnabled then h += 36 end
            h += clamp(#cfg.Options, 1, 6) * 32 + 6
            return h
        end

        function SetOpenSafe(state)
            if open == state then return end
            open = state
            Tw(chevron, 0.25, { Rotation = state and 180 or 0 })
            if state then
                RefreshOptions()
                RebuildChips()
                listScroll.Size = UDim2.new(1, 0, 0, clamp(#cfg.Options, 1, 6) * 32)
                Tw(panel, 0.22, { Size = UDim2.new(1, 0, 0, PanelHeight()) })
                ActiveDropdown = SetOpenSafe
                outsideConn = Connect(UserInputService.InputBegan, function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        local rect = section.Frame.AbsoluteRect
                        local px, py = input.Position.X, input.Position.Y
                        if px < rect.X or px > rect.X + rect.Width
                            or py < rect.Y or py > rect.Y + rect.Height then
                            SetOpenSafe(false)
                        end
                    end
                end)
                CleanAdd(outsideConn)
            else
                Tw(panel, 0.22, { Size = UDim2.new(1, 0, 0, 0) })
                if ActiveDropdown == SetOpenSafe then ActiveDropdown = nil end
                if outsideConn then
                    outsideConn:Disconnect()
                    outsideConn = nil
                end
            end
        end

        Connect(btn.MouseButton1Click, function() SetOpenSafe(not open) end)

        valueLabel.Text = ValueText()
        if Multi then RebuildChips() end

        local handle = {
            Set = function(v, noCb)
                selected = {}
                if Multi and type(v) == "table" then
                    for _, x in ipairs(v) do table.insert(selected, x) end
                elseif v ~= nil then
                    selected = { v }
                end
                valueLabel.Text = ValueText()
                if Multi then RebuildChips() end
                MarkSelection()
                if not noCb then
                    SafeCall(cfg.Callback, Multi and CopySelected() or selected[1])
                end
            end,
            Get = function()
                if Multi then return CopySelected() end
                return selected[1]
            end,
            Refresh = function(newOptions)
                cfg.Options = newOptions or cfg.Options
                if open then RefreshOptions() end
            end,
            Default = Multi and CopySelected() or selected[1],
        }
        if Multi then handle.Default = CopySelected() end
        RegisterFlag(cfg.Flag, handle)
        return handle
    end

    --// TEXTBOX
    MakeTextboxSafe = function(section, cfg)
        cfg = cfg or {}
        local row = MakeRow(section, cfg)
        local inputFrame = Create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 168, 0, 30),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.55,
            ZIndex = 4, Parent = row,
        }, { Corner(8) })
        Themed(inputFrame, "Background")
        local ist = Stroke(nil, 1, 0.55)
        Themed(ist, "Border")
        ist.Parent = inputFrame

        local box = Create("TextBox", {
            Text = cfg.Text or cfg.Default or "",
            PlaceholderText = cfg.Placeholder or "Type here...",
            Font = FONTS.Body.Font, TextSize = 12,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0, 0),
            Size = UDim2.new(1, -34, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            MaxLength = cfg.MaxLength or -1,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 5, Parent = inputFrame,
        })
        Themed(box, "SubText")
        Themed(box, "Muted", "PlaceholderColor3")

        local clearBtn = Create("TextButton", {
            Text = "✕", Font = FONTS.Caption.Font, TextSize = 10,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -4, 0.5, 0),
            Size = UDim2.new(0, 20, 0, 20),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Visible = false,
            ZIndex = 6, Parent = inputFrame,
        })
        Themed(clearBtn, "Muted")
        Connect(clearBtn.MouseButton1Click, function()
            box.Text = ""
            box:CaptureFocus()
        end)

        local isPassword = cfg.Password == true
        local isNumeric = cfg.Numeric == true
        local realText = box.Text
        local focused = false

        Connect(box:GetPropertyChangedSignal("Text"), function()
            if isNumeric and focused then
                local t = box.Text
                local cleaned = t:gsub("[^%d%.%-]", "")
                if cleaned ~= t then box.Text = cleaned end
            end
            if focused then realText = box.Text end
            clearBtn.Visible = (box.Text ~= "") and (not isPassword or focused)
        end)

        Connect(box.Focused, function()
            focused = true
            if isPassword then box.Text = realText end
            Tw(ist, 0.2, { Color = State.Accent, Transparency = 0.2 })
        end)
        Connect(box.FocusLost, function(enter)
            focused = false
            realText = box.Text
            if isPassword and realText ~= "" then
                box.Text = string.rep("•", #realText)
            end
            clearBtn.Visible = false
            Tw(ist, 0.25, { Color = Themes[State.Theme].Border, Transparency = 0.55 })
            SafeCall(cfg.Callback, realText, enter)
            if enter then SafeCall(cfg.EnterCallback, realText) end
        end)

        local handle = {
            Set = function(t)
                realText = tostring(t or "")
                box.Text = (isPassword and realText ~= "") and string.rep("•", #realText) or realText
            end,
            Get = function() return realText end,
            Default = cfg.Text or cfg.Default or "",
        }
        RegisterFlag(cfg.Flag, handle)
        return handle
    end

    --// KEYBIND
    MakeKeybindSafe = function(section, cfg)
        cfg = cfg or {}
        local row = MakeRow(section, cfg)
        local bind = cfg.Default
        local registryEntry
        local listening = false
        local pulse = nil

        local chip = Create("TextButton", {
            Text = "", AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 104, 0, 26),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.65,
            AutoButtonColor = false,
            ZIndex = 4, Parent = row,
        }, { Corner(8) })
        Themed(chip, "Cloud")
        local cst = Stroke(nil, 1, 0.55)
        Themed(cst, "Border")
        cst.Parent = chip
        local chipLbl = MakeLabel({
            Text = KeyDisplayName(bind), Font = FONTS.Title.Font, TextSize = 12,
            Size = UDim2.new(1, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 5, Parent = chip,
        }, "SubText")

        Connect(chip.MouseButton1Click, function()
            if listening then return end
            listening = true
            chipLbl.Text = "Press a key…"
            pulse = TweenService:Create(cst,
                TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Transparency = 0.1 })
            pulse:Play()
            Binding.active = true
            Binding.resolve = function(input)
                listening = false
                Binding.active = false
                Binding.resolve = nil
                if pulse then pulse:Cancel() pulse = nil end
                cst.Transparency = 0.55
                local key = nil
                if input.UserInputType == Enum.UserInputType.Keyboard
                    and input.KeyCode ~= Enum.KeyCode.Unknown then
                    key = input.KeyCode
                elseif input.UserInputType == Enum.UserInputType.MouseButton2
                    or input.UserInputType == Enum.UserInputType.MouseButton3 then
                    key = input.UserInputType
                end
                if key then
                    bind = key
                    if registryEntry then registryEntry.Key = key end
                    SafeCall(cfg.OnChanged, key)
                end
                chipLbl.Text = KeyDisplayName(bind)
            end
        end)

        if cfg.Callback then
            registryEntry = {Key = bind, Callback = cfg.Callback}
            table.insert(KeybindRegistry, registryEntry)
        end

        local handle = {
            Set = function(v)
                if type(v) == "string" then
                    local parsed = ParseKey(v)
                    if parsed then bind = parsed end
                elseif typeof(v) == "EnumItem" then
                    bind = v
                end
                if registryEntry then registryEntry.Key = bind end
                chipLbl.Text = KeyDisplayName(bind)
                SafeCall(cfg.OnChanged, bind)
            end,
            Get = function() return KeyToString(bind) end,
            Default = KeyToString(cfg.Default),
        }
        RegisterFlag(cfg.Flag, handle)
        return handle
    end

    --// COLOR PICKER
    MakeColorpickerSafe = function(section, cfg)
        cfg = cfg or {}
        local defaultColor = cfg.Default or Color3.fromRGB(174, 150, 255)
        local H, S, V = Color3.toHSV(defaultColor)
        local Alpha = cfg.Alpha or 1
        local pop, popOpen = nil, false

        local row = MakeRow(section, cfg)
        local btn = Create("TextButton", {
            Text = "", Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            ZIndex = 3, Parent = row,
        })
        local swatch = Create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -10, 0.5, 0),
            Size = UDim2.new(0, 28, 0, 28),
            BackgroundColor3 = defaultColor,
            BackgroundTransparency = 1 - Alpha,
            ZIndex = 4, Parent = row,
        }, { Corner(8), Stroke(Color3.new(1, 1, 1), 1.5, 0.35) })

        local rBox, gBox, bBox, hexBox
        local rgbFocused, hexFocused = false, false
        local svBase, svCursor, hueBar, hueCursor, alphaBar, alphaCursor, previewFill

        local function Update(noCb)
            local col = Color3.fromHSV(H, S, V)
            swatch.BackgroundColor3 = col
            swatch.BackgroundTransparency = 1 - Alpha
            if pop then
                svBase.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
                svCursor.Position = UDim2.new(S, 0, 1 - V, 0)
                hueCursor.Position = UDim2.new(H, 0, 0.5, 0)
                alphaCursor.Position = UDim2.new(Alpha, 0, 0.5, 0)
                alphaBar.BackgroundColor3 = col
                previewFill.BackgroundColor3 = col
                previewFill.BackgroundTransparency = 1 - Alpha
                if not rgbFocused then
                    rBox.Text = tostring(math.floor(col.R * 255 + 0.5))
                    gBox.Text = tostring(math.floor(col.G * 255 + 0.5))
                    bBox.Text = tostring(math.floor(col.B * 255 + 0.5))
                end
                if not hexFocused then hexBox.Text = ToHex(col) end
            end
            if not noCb then SafeCall(cfg.Callback, col, Alpha) end
        end

        local function BuildPopup()
            pop = Create("Frame", {
                Size = UDim2.new(0, 244, 0, 316),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.05,
                Visible = false,
                ZIndex = 41,
                Parent = PopupLayer,
            }, { Corner(14), Pad(12, 12, 12, 12) })
            Themed(pop, "Surface")
            local pst = Stroke(nil, 1, 0.4)
            Themed(pst, "Border")
            pst.Parent = pop

            local preview = Create("Frame", {
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = Color3.fromRGB(120, 124, 140),
                ZIndex = 42, Parent = pop,
            }, { Corner(8) })
            previewFill = Create("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = defaultColor,
                ZIndex = 43, Parent = preview,
            }, { Corner(8) })

            svBase = Create("Frame", {
                Position = UDim2.new(0, 0, 0, 32),
                Size = UDim2.new(1, 0, 0, 110),
                BackgroundColor3 = Color3.fromHSV(H, 1, 1),
                ZIndex = 42, Parent = pop,
            }, { Corner(8) })
            Create("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.new(1, 1, 1),
                ZIndex = 43, Parent = svBase,
            }, { Corner(8), Create("UIGradient", {
                Rotation = 0, Transparency = NumberSequence.new(0, 1),
            }) })
            Create("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundColor3 = Color3.new(0, 0, 0),
                ZIndex = 44, Parent = svBase,
            }, { Corner(8), Create("UIGradient", {
                Rotation = 90, Transparency = NumberSequence.new(1, 0),
            }) })
            svCursor = Create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.new(0, 14, 0, 14),
                BackgroundColor3 = Color3.new(1, 1, 1),
                ZIndex = 46, Parent = svBase,
            }, { CornerFull(), Stroke(Color3.new(0, 0, 0), 1, 0.4) })

            hueBar = Create("Frame", {
                Position = UDim2.new(0, 0, 0, 150),
                Size = UDim2.new(1, 0, 0, 12),
                BackgroundColor3 = Color3.new(1, 1, 1),
                ZIndex = 42, Parent = pop,
            }, { Corner(6), Create("UIGradient", { Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
                ColorSequenceKeypoint.new(1/6, Color3.fromRGB(255, 220, 60)),
                ColorSequenceKeypoint.new(2/6, Color3.fromRGB(80, 255, 120)),
                ColorSequenceKeypoint.new(3/6, Color3.fromRGB(70, 230, 255)),
                ColorSequenceKeypoint.new(4/6, Color3.fromRGB(110, 120, 255)),
                ColorSequenceKeypoint.new(5/6, Color3.fromRGB(230, 100, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 60)),
            }) }) })
            hueCursor = Create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.new(0, 4, 0, 18),
                BackgroundColor3 = Color3.new(1, 1, 1),
                ZIndex = 44, Parent = hueBar,
            }, { Corner(2), Stroke(Color3.new(0, 0, 0), 1, 0.5) })

            alphaBar = Create("Frame", {
                Position = UDim2.new(0, 0, 0, 170),
                Size = UDim2.new(1, 0, 0, 12),
                BackgroundColor3 = defaultColor,
                ZIndex = 42, Parent = pop,
            }, { Corner(6), Create("UIGradient", {
                Rotation = 0, Transparency = NumberSequence.new(0, 1),
            }) })
            alphaCursor = Create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.new(0, 4, 0, 18),
                BackgroundColor3 = Color3.new(1, 1, 1),
                ZIndex = 44, Parent = alphaBar,
            }, { Corner(2), Stroke(Color3.new(0, 0, 0), 1, 0.5) })

            local function NumBox(x, ph)
                local f = Create("Frame", {
                    Position = UDim2.new(0, x, 0, 192),
                    Size = UDim2.new(0, 68, 0, 24),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BackgroundTransparency = 0.55,
                    ZIndex = 42, Parent = pop,
                }, { Corner(6) })
                Themed(f, "Background")
                local st = Stroke(nil, 1, 0.55)
                Themed(st, "Border")
                st.Parent = f
                local b = Create("TextBox", {
                    Text = "", PlaceholderText = ph,
                    Font = FONTS.Caption.Font, TextSize = 11,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    TextXAlignment = Enum.TextXAlignment.Center,
                    ClearTextOnFocus = false, ZIndex = 43, Parent = f,
                })
                Themed(b, "SubText")
                Themed(b, "Muted", "PlaceholderColor3")
                return b
            end
            rBox = NumBox(0, "R")
            gBox = NumBox(76, "G")
            bBox = NumBox(152, "B")

            local hexFrame = Create("Frame", {
                Position = UDim2.new(0, 0, 0, 224),
                Size = UDim2.new(1, 0, 0, 24),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.55,
                ZIndex = 42, Parent = pop,
            }, { Corner(6) })
            Themed(hexFrame, "Background")
            local hst = Stroke(nil, 1, 0.55)
            Themed(hst, "Border")
            hst.Parent = hexFrame
            hexBox = Create("TextBox", {
                Text = ToHex(defaultColor), PlaceholderText = "#RRGGBB",
                Font = FONTS.Caption.Font, TextSize = 11,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Center,
                ClearTextOnFocus = false, ZIndex = 43, Parent = hexFrame,
            })
            Themed(hexBox, "SubText")

            local presets = {
                Color3.fromRGB(174, 150, 255), Color3.fromRGB(148, 190, 255),
                Color3.fromRGB(255, 164, 210), Color3.fromRGB(238, 241, 255),
                Color3.fromRGB(126, 220, 175), Color3.fromRGB(245, 125, 145),
            }
            for i, pc in ipairs(presets) do
                local sw = Create("TextButton", {
                    Text = "", Position = UDim2.new(0, (i - 1) * 36, 0, 258),
                    Size = UDim2.new(0, 22, 0, 22),
                    BackgroundColor3 = pc,
                    AutoButtonColor = false,
                    ZIndex = 42, Parent = pop,
                }, { CornerFull(), Stroke(Color3.new(1, 1, 1), 1, 0.45) })
                Connect(sw.MouseButton1Click, function()
                    H, S, V = Color3.toHSV(pc)
                    Alpha = 1
                    Update()
                end)
            end

            -- dragging
            local dragSV, dragHue, dragAlpha = false, false, false
            Connect(svBase.InputBegan, function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1
                    or i.UserInputType == Enum.UserInputType.Touch then dragSV = true end
            end)
            Connect(hueBar.InputBegan, function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1
                    or i.UserInputType == Enum.UserInputType.Touch then dragHue = true end
            end)
            Connect(alphaBar.InputBegan, function(i)
                if i.UserInputType == Enum.UserInputType.MouseButton1
                    or i.UserInputType == Enum.UserInputType.Touch then dragAlpha = true end
            end)
            for _, bar in ipairs({ svBase, hueBar, alphaBar }) do
                Connect(bar.InputEnded, function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1
                        or i.UserInputType == Enum.UserInputType.Touch then
                        dragSV, dragHue, dragAlpha = false, false, false
                    end
                end)
            end
            Connect(UserInputService.InputChanged, function(i)
                if i.UserInputType ~= Enum.UserInputType.MouseMovement
                    and i.UserInputType ~= Enum.UserInputType.Touch then return end
                if dragSV then
                    S = clamp((i.Position.X - svBase.AbsolutePosition.X) / math.max(svBase.AbsoluteSize.X, 1), 0, 1)
                    V = 1 - clamp((i.Position.Y - svBase.AbsolutePosition.Y) / math.max(svBase.AbsoluteSize.Y, 1), 0, 1)
                    Update()
                elseif dragHue then
                    H = clamp((i.Position.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
                    Update()
                elseif dragAlpha then
                    Alpha = clamp((i.Position.X - alphaBar.AbsolutePosition.X) / math.max(alphaBar.AbsoluteSize.X, 1), 0, 1)
                    Update()
                end
            end)

            for _, b in ipairs({ rBox, gBox, bBox }) do
                Connect(b.Focused, function() rgbFocused = true end)
                Connect(b.FocusLost, function()
                    rgbFocused = false
                    local n = tonumber(b.Text)
                    if n then
                        local col = Color3.fromHSV(H, S, V)
                        local r = clamp(math.floor(b.Text == rBox.Text and n or col.R * 255), 0, 255)
                        local g = clamp(math.floor(b.Text == gBox.Text and n or col.G * 255), 0, 255)
                        local bl = clamp(math.floor(b.Text == bBox.Text and n or col.B * 255), 0, 255)
                        H, S, V = Color3.toHSV(Color3.fromRGB(r, g, bl))
                        Update()
                    else
                        Update(true)
                    end
                end)
            end
            Connect(hexBox.Focused, function() hexFocused = true end)
            Connect(hexBox.FocusLost, function()
                hexFocused = false
                local c = FromHex(hexBox.Text)
                if c then
                    H, S, V = Color3.toHSV(c)
                    Update()
                else
                    Update(true)
                end
            end)

            Update(true)
        end

        local function SetOpen(state)
            if popOpen == state then return end
            popOpen = state
            if state then
                if not pop then BuildPopup() end
                PopupLayer.Visible = true
                PopupLayer.Active = true
                pop.Visible = true
                task.defer(function()
                    local layerPos = PopupLayer.AbsolutePosition
                    local sw = swatch.AbsolutePosition
                    local x = sw.X - layerPos.X - 252
                    local y = sw.Y - layerPos.Y + 36
                    x = clamp(x, 4, math.max(4, PopupLayer.AbsoluteSize.X - 252))
                    y = clamp(y, 4, math.max(4, PopupLayer.AbsoluteSize.Y - 324))
                    pop.Position = UDim2.new(0, x, 0, y)
                end)
                ActivePicker = SetOpen
            else
                pop.Visible = false
                PopupLayer.Visible = false
                PopupLayer.Active = false
                if ActivePicker == SetOpen then ActivePicker = nil end
            end
        end

        Connect(PopupLayer.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                if pop and pop.Visible then
                    local r = pop.AbsoluteRect
                    local px, py = input.Position.X, input.Position.Y
                    if px < r.X or px > r.X + r.Width or py < r.Y or py > r.Y + r.Height then
                        SetOpen(false)
                    end
                end
            end
        end)

        Connect(btn.MouseButton1Click, function() SetOpen(not popOpen) end)
        Update(true)

        local function SetPicker(v, alpha, noCb)
            if type(v) == "table" then
                local c = FromHex(v.Hex)
                if c then H, S, V = Color3.toHSV(c) end
                Alpha = clamp(tonumber(v.Alpha) or 1, 0, 1)
            elseif typeof(v) == "Color3" then
                H, S, V = Color3.toHSV(v)
                if alpha then Alpha = clamp(alpha, 0, 1) end
            end
            Update(noCb)
        end

        local handle = {
            Set = function(v, alpha, noCb) SetPicker(v, alpha, noCb) end,
            Get = function()
                return { Hex = ToHex(Color3.fromHSV(H, S, V)), Alpha = Alpha }
            end,
            Default = { Hex = ToHex(defaultColor), Alpha = Alpha },
        }
        RegisterFlag(cfg.Flag, handle)
        return handle
    end

    --// PARAGRAPH / STAT CARD
    MakeParagraphSafe = function(section, cfg)
        cfg = cfg or {}
        local holder = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            LayoutOrder = section:NextOrder(),
            ZIndex = 7,
            Parent = section.Frame,
        }, { List(4) })
        if cfg.Title then
            MakeLabel({
                Text = cfg.Title, Font = FONTS.Title.Font, TextSize = 14,
                Size = UDim2.new(1, 0, 0, 18), ZIndex = 8, Parent = holder,
            }, "Text")
        end
        local body = MakeLabel({
            Text = cfg.Text or cfg.Content or "",
            Font = FONTS.Body.Font, TextSize = 12,
            TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 8, Parent = holder,
        }, "SubText")
        AddSearchRow(holder, (cfg.Title or "") .. " " .. (cfg.Text or cfg.Content or ""), section)
        return { Set = function(t) body.Text = t end }
    end

    MakeStatCardSafe = function(section, cfg)
        cfg = cfg or {}
        local card = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 96),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.25,
            ZIndex = 7,
            Parent = section.Frame,
        }, { Corner(12), Pad(12, 12, 12, 12) })
        Themed(card, "Surface")
        local cst = Stroke(nil, 1, 0.55)
        Themed(cst, "Border")
        cst.Parent = card
        MakeLabel({
            Text = cfg.Icon or "•", Font = FONTS.Title.Font, TextSize = 16,
            Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 18, 0, 18),
            TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = card,
        }, "Primary")
        MakeLabel({
            Text = string.upper(cfg.Name or "STAT"), Font = FONTS.Caption.Font, TextSize = 10,
            Position = UDim2.new(0, 38, 0, 15), Size = UDim2.new(1, -50, 0, 12),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = card,
        }, "Muted")
        local val = MakeLabel({
            Text = "—", Font = FONTS.Heading.Font, TextSize = 24,
            Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(1, -24, 0, 28),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = card,
        }, "Text")
        local sub = MakeLabel({
            Text = cfg.Description or "", Font = FONTS.Caption.Font, TextSize = 10,
            Position = UDim2.new(0, 12, 0, 68), Size = UDim2.new(1, -24, 0, 12),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = card,
        }, "Muted")
        AddSearchRow(card, (cfg.Name or "") .. " " .. (cfg.Description or ""), section)
        return { Set = function(v) val.Text = tostring(v) end, SetSub = function(s) sub.Text = s end }
    end

    --// ENGINE SETTERS
    local function ApplyUIScale(v)
        State.Scale = clamp(v, 0.75, 1.25)
        if WindowScale then WindowScale.Scale = State.Scale end
    end
    local function ApplyTransparency(v)
        State.Transparency = clamp(v, 0, 1)
        for _, p in ipairs(GlassPanels) do
            p.frame.BackgroundTransparency = math.min(p.base + State.Transparency * 0.35, 0.85)
        end
    end
    local function ApplyClouds(v)
        State.Clouds = v and true or false
        if CloudHolder then CloudHolder.Visible = State.Clouds end
    end
    local function ApplyAnimAccent(v)
        State.AnimatedAccent = v and true or false
        if not State.AnimatedAccent then SetAccent(State.Accent) end
    end

    --// CONFIG SYSTEM
    local FS_OK = (type(writefile) == "function") and (type(readfile) == "function")
        and (type(isfolder) == "function") and (type(makefolder) == "function")
    local memoryConfig = nil
    local FlagOrder = {}

    local oldRegisterFlag = RegisterFlag
    RegisterFlag = function(name, handle)
        if not name or name == "" then return end
        if UI.Flags[name] == nil then table.insert(FlagOrder, name) end
        UI.Flags[name] = handle
    end

    local function ConfigPath()
        return ConfigFolder .. "/" .. tostring(game.PlaceId) .. ".json"
    end

    local function SaveConfig()
        local data = { _v = 1, flags = {}, meta = { pos = nil } }
        for flag, handle in pairs(UI.Flags) do
            local ok, v = pcall(function() return handle.Get() end)
            if ok and v ~= nil then data.flags[flag] = v end
        end
        if Root then
            data.meta.pos = { x = Root.Position.X.Offset, y = Root.Position.Y.Offset,
                xs = Root.Position.X.Scale, ys = Root.Position.Y.Scale }
        end
        local encoded = HttpService:JSONEncode(data)
        if FS_OK then
            local ok = pcall(function()
                if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end
                writefile(ConfigPath(), encoded)
            end)
            if ok then
                Notify({ Title = "Configuration", Description = "Saved to disk.", Type = "Success", Duration = 3 })
                return true
            end
        end
        memoryConfig = encoded
        Notify({ Title = "Configuration", Description = "Saved for this session.", Type = "Info", Duration = 3 })
        return true
    end

    local function LoadConfig(silent)
        local encoded = nil
        if FS_OK then
            pcall(function()
                if isfolder(ConfigFolder) then
                    encoded = readfile(ConfigPath())
                end
            end)
        end
        if (not encoded or encoded == "") and memoryConfig then
            encoded = memoryConfig
        end
        if not encoded or encoded == "" then
            if not silent then
                Notify({ Title = "Configuration", Description = "No saved configuration found.", Type = "Warning", Duration = 3 })
            end
            return false
        end
        local ok, data = pcall(function() return HttpService:JSONDecode(encoded) end)
        if not ok or type(data) ~= "table" then
            if not silent then
                Notify({ Title = "Configuration", Description = "Saved configuration is invalid.", Type = "Error", Duration = 4 })
            end
            return false
        end
        if type(data.flags) == "table" then
            for _, flag in ipairs(FlagOrder) do
                local v = data.flags[flag]
                local handle = v ~= nil and UI.Flags[flag] or nil
                if handle then
                    pcall(function() handle.Set(v) end)
                else
                    warn("[Aether] config loader - unknown flag:", tostring(flag))
                end
            end
        end
        if data.meta and data.meta.pos and Root then
            Root.Position = UDim2.new(tonumber(data.meta.pos.xs) or 0, tonumber(data.meta.pos.x) or 0, tonumber(data.meta.pos.ys) or 0, tonumber(data.meta.pos.y) or 0)
            ClampPosition()
        end
        if not silent then
            Notify({ Title = "Configuration", Description = "Configuration loaded.", Type = "Success", Duration = 3 })
        end
        return true
    end

    local function ResetConfig()
        if FS_OK and type(delfile) == "function" then
            pcall(function()
                if type(isfile) == "function" and isfile(ConfigPath()) then
                    delfile(ConfigPath())
                end
            end)
        end
        memoryConfig = nil
        for _, flag in ipairs(FlagOrder) do
            local handle = UI.Flags[flag]
            if handle then pcall(function() handle.Set(handle.Default) end) end
        end
        if Root then Root.Position = UDim2.new(0.5, 0, 0.5, 0) end
        Notify({ Title = "Configuration", Description = "Reset to defaults.", Type = "Info", Duration = 3 })
    end

    --// WINDOW VISIBILITY
    local function OpenWindow()
        if State.Visible or not Root then return end
        State.Visible = true
        ScreenGui.Enabled = true
        Root.Visible = true
        AnimScale.Scale = 0.94
        Root.GroupTransparency = 0.55
        Tw(AnimScale, 0.34, { Scale = 1 })
        Tw(Root, 0.3, { GroupTransparency = 0 })
        Sidebar.Position = UDim2.new(0, 2, 0, 12)
        task.delay(0.06, function()
            Tw(Sidebar, 0.3, { Position = UDim2.new(0, 12, 0, 12) })
        end)
        if State.CurrentTab and State.CurrentTab.Group then
            local g = State.CurrentTab.Group
            g.GroupTransparency = 0.4
            Tw(g, 0.3, { GroupTransparency = 0 })
        end
        task.defer(PositionIndicator)
    end

    function CloseWindowSafe()
        if not State.Visible or not Root then return end
        State.Visible = false
        if State.CurrentTab then
            Tw(State.CurrentTab.Group, 0.12, { GroupTransparency = 0.7 })
        end
        Tw(AnimScale, 0.2, { Scale = 0.96 })
        Tw(Root, 0.22, { GroupTransparency = 1 })
        task.delay(Dur(0.22) + 0.05, function()
            if not State.Visible then
                Root.Visible = false
            end
        end)
        Notify({
            Title = "Interface hidden",
            Description = "Press " .. KeyDisplayName(State.MenuKey) .. " to reopen.",
            Type = "Info", Duration = 4,
        })
    end

    function SetMinimizedSafe(state)
        if not Root or State.Minimized == state then return end
        State.Minimized = state
        if not state then
            ContentHolder.Visible = true
            Sidebar.Visible = true
        end
        UpdateChrome(true)
        task.delay(Dur(0.32) + 0.05, ClampPosition)
    end

    local function ToggleWindow()
        if State.Visible then
            CloseWindowSafe()
        else
            OpenWindow()
        end
    end

    --// HEARTBEAT (single loop: fps, session, ping, clouds, animated accent)
    local frames, lastSecond, pingTick = 0, os.clock(), 0
    local hbConn = Connect(RunService.Heartbeat, function(dt)
        frames += 1
        local now = os.clock()
        if now - lastSecond >= 1 then
            lastSecond = now
            if Dash.FPS then Dash.FPS.Set(tostring(frames)) end
            if Dash.Session then Dash.Session.Set(FormatDuration(now - State.SessionStart)) end
            frames = 0
            pingTick += 1
            if pingTick >= 5 then
                pingTick = 0
                local ok, v = pcall(function()
                    return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
                end)
                if ok and type(v) == "number" then
                    if Dash.Ping then
                        Dash.Ping.Set(math.floor(v + 0.5))
                        Dash.Ping.SetSub(v < 90 and "Stable" or "Elevated")
                    end
                end
            end
        end
        if Root and Root.Visible then
            if State.Clouds and State.Animations and not State.ReduceMotion then
                for _, o in ipairs(Orbs) do
                    o.frame.Position = UDim2.new(
                        o.bx + math.sin(now * o.spd + o.ph) * o.amp, 0,
                        o.by + math.cos(now * o.spd * 0.8 + o.ph) * o.amp * 0.7, 0)
                end
            end
            if State.AnimatedAccent and State.Animations and not State.ReduceMotion then
                accentPhase = (accentPhase + dt * 0.06 * State.AccentSpeed) % 2
                accentAccum += dt
                if accentAccum >= 0.1 then
                    accentAccum = 0
                    ApplyAnimatedAccent()
                end
            end
        end
    end)
    CleanAdd(hbConn)

    --// GLOBAL INPUT
    local inputConn = Connect(UserInputService.InputBegan, function(input, gp)
        if input.KeyCode == Enum.KeyCode.Escape then
            if Binding.active and Binding.resolve then
                local r = Binding.resolve
                Binding.active = false
                Binding.resolve = nil
                r(input)
            elseif ActiveModal then
                ActiveModal.cancel()
            elseif ActiveDropdown then
                ActiveDropdown(false)
            elseif ActivePicker then
                ActivePicker(false)
            elseif ContextLayer then
                CloseContextMenu()
            end
            return
        end
        if Binding.active and Binding.resolve then
            Binding.resolve(input)
            return
        end
        if gp or UserInputService:GetFocusedTextBox() then return end
        if Root and input.KeyCode == State.MenuKey then
            ToggleWindow()
            return
        end
        if UserInputService:GetFocusedTextBox() == nil then
            for _, kb in ipairs(KeybindRegistry) do
                if kb.Key ~= nil and (input.KeyCode == kb.Key or input.UserInputType == kb.Key) then
                    SafeCall(kb.Callback, kb.Key)
                end
            end
        end
    end)
    CleanAdd(inputConn)

    --// INTRO SEQUENCE
    local function PlayIntro(done)
        local veil = Create("CanvasGroup", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Themes[State.Theme].Background,
            GroupTransparency = 0,
            ZIndex = 200,
            Parent = ScreenGui,
        })
        local holder = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.42, 0),
            Size = UDim2.new(0, 300, 0, 150),
            BackgroundTransparency = 1,
            ZIndex = 201,
            Parent = veil,
        })
        local icon = Create("TextLabel", {
            Text = ICONS.Cloud, Font = FONTS.Display.Font, TextSize = 40,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 30),
            Size = UDim2.new(0, 60, 0, 48),
            BackgroundTransparency = 1, TextTransparency = 1,
            ZIndex = 202, Parent = holder,
        })
        AccentGradient(icon, 45)
        local name = Create("TextLabel", {
            Text = string.upper(Name), Font = FONTS.Display.Font, TextSize = 24,
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86),
            Size = UDim2.new(1, 0, 0, 26),
            TextColor3 = Themes[State.Theme].Text, BackgroundTransparency = 1,
            TextTransparency = 1, ZIndex = 202, Parent = holder,
        })
        local sub = Create("TextLabel", {
            Text = string.upper(Subtitle) .. "  ·  v" .. Version,
            Font = FONTS.Caption.Font, TextSize = 10,
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 114),
            Size = UDim2.new(1, 0, 0, 14),
            TextColor3 = Themes[State.Theme].Muted, BackgroundTransparency = 1,
            TextTransparency = 1, ZIndex = 202, Parent = holder,
        })
        local bar = Create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140),
            Size = UDim2.new(0, 180, 0, 4),
            BackgroundColor3 = Themes[State.Theme].Cloud,
            BackgroundTransparency = 0.2,
            ZIndex = 202, Parent = holder,
        }, { CornerFull() })
        local fill = Create("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            ZIndex = 203, Parent = bar,
        }, { CornerFull() })
        AccentGradient(fill, 0)
        local caption = Create("TextLabel", {
            Text = "Preparing your interface...",
            Font = FONTS.Caption.Font, TextSize = 10,
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 152),
            Size = UDim2.new(1, 0, 0, 14),
            TextColor3 = Themes[State.Theme].Muted, BackgroundTransparency = 1,
            TextTransparency = 1, ZIndex = 202, Parent = holder,
        })

        local skipped = false
        Connect(veil.InputBegan, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1
                or i.UserInputType == Enum.UserInputType.Touch then
                skipped = true
            end
        end)

        task.spawn(function()
            Tw(icon, 0.28, { TextTransparency = 0 })
            task.wait(0.1)
            Tw(name, 0.22, { TextTransparency = 0 })
            Tw(sub, 0.22, { TextTransparency = 0.1 })
            Tw(caption, 0.22, { TextTransparency = 0.2 })
            TweenService:Create(fill, TweenInfo.new(0.75, Enum.EasingStyle.Quint),
                { Size = UDim2.new(1, 0, 1, 0) }):Play()
            local t0 = os.clock()
            repeat task.wait(0.03) until skipped or (os.clock() - t0) > 0.85
            Tw(veil, 0.26, { GroupTransparency = 1 })
            task.delay(Dur(0.26) + 0.03, function() veil:Destroy() end)
            done()
        end)
    end

    --// DEMO PAGES
    local function MakeChip(parent, text, colorKey, props)
        props = props or {}
        local pill = Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.88,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 0, 18),
            Parent = parent,
        }, { CornerFull(), Pad(0, 0, 8, 8) })
        Themed(pill, colorKey)
        local st = Stroke(nil, 1, 0.65)
        Themed(st, colorKey)
        st.Parent = pill
        MakeLabel({
            Text = text, Font = FONTS.Caption.Font, TextSize = 9,
            AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 2, Parent = pill,
        }, colorKey)
        for k, v in pairs(props) do pill[k] = v end
        return pill
    end

    local function AddPageHeading(tab, subtitle)
        local head = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 42),
            BackgroundTransparency = 1,
            LayoutOrder = 0,
            Parent = tab.Scroll,
        }, { List(2) })
        MakeLabel({
            Text = tab.Name, Font = FONTS.Heading.Font, TextSize = 20,
            Size = UDim2.new(1, 0, 0, 24), ZIndex = 7, Parent = head,
        }, "Text")
        if subtitle then
            MakeLabel({
                Text = subtitle, Font = FONTS.Caption.Font, TextSize = 11,
                Size = UDim2.new(1, 0, 0, 14), ZIndex = 7, Parent = head,
            }, "Muted")
        end
        return head
    end

    local function GetGreeting()
        local h = tonumber(os.date("%H")) or 12
        if h < 5 then return "Good night" end
        if h < 12 then return "Good morning" end
        if h < 18 then return "Good afternoon" end
        return "Good evening"
    end

    local function GetDevice()
        local touch = UserInputService.TouchEnabled
        local keyboard = UserInputService.KeyboardEnabled
        if touch and keyboard then return "Tablet" end
        if touch then return "Mobile" end
        return "Desktop"
    end

    local function MakeInfoRow(parent, caption, value)
        local row = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 22),
            BackgroundTransparency = 1,
            Parent = parent,
        })
        MakeLabel({
            Text = caption, Font = FONTS.Caption.Font, TextSize = 11,
            Size = UDim2.new(0.45, 0, 1, 0), ZIndex = 7, Parent = row,
        }, "Muted")
        local val = MakeLabel({
            Text = value or "—", Font = FONTS.Body.Font, TextSize = 11,
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0.55, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7, Parent = row,
        }, "SubText")
        return { Set = function(v) val.Text = tostring(v) end }
    end

    local function MakeQuickButton(parent, text, callback)
        local btn = Create("TextButton", {
            Text = text, Font = FONTS.Title.Font, TextSize = 13,
            Size = UDim2.new(1 / 3, -6, 1, 0),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.55,
            AutoButtonColor = false,
            Parent = parent,
        }, { Corner(10) })
        Themed(btn, "Cloud")
        local st = Stroke(nil, 1, 0.5)
        Themed(st, "Border")
        st.Parent = btn
        Themed(btn, "SubText")
        Connect(btn.MouseEnter, function()
            Tw(btn, 0.15, { BackgroundTransparency = 0.4 })
            Tw(st, 0.15, { Transparency = 0.25, Color = State.Accent })
        end)
        Connect(btn.MouseLeave, function()
            Tw(btn, 0.25, { BackgroundTransparency = 0.55 })
            Tw(st, 0.25, { Transparency = 0.5, Color = Themes[State.Theme].Border })
        end)
        Connect(btn.MouseButton1Click, callback)
        return btn
    end

    local function BuildHomePage(tab)
        AddPageHeading(tab, "Your dashboard at a glance.")

        -- welcome hero
        local hero = Create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.3,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1, ZIndex = 6, Parent = tab.Scroll,
        }, { Corner(16), Pad(18, 18, 18, 18) })
        Themed(hero, "Elevated")
        local hst = Stroke(nil, 1, 0.5)
        Themed(hst, "Border")
        hst.Parent = hero
        local topRow = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 56),
            BackgroundTransparency = 1, ZIndex = 7, Parent = hero,
        })
        local avatar = Create("ImageLabel", {
            Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(0, 56, 0, 56),
            BackgroundTransparency = 1, Image = "", ZIndex = 8, Parent = topRow,
        }, { CornerFull() })
        local ast = Stroke(nil, 2, 0.4)
        Themed(ast, "Primary")
        ast.Parent = avatar
        task.spawn(function()
            local ok, content = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId,
                    Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and content then avatar.Image = content end
        end)
        MakeLabel({
            Text = GetGreeting() .. ",", Font = FONTS.Caption.Font, TextSize = 12,
            Position = UDim2.new(0, 72, 0, 4), Size = UDim2.new(1, -190, 0, 14),
            ZIndex = 8, Parent = topRow,
        }, "Muted")
        MakeLabel({
            Text = LocalPlayer.DisplayName, Font = FONTS.Heading.Font, TextSize = 20,
            Position = UDim2.new(0, 72, 0, 20), Size = UDim2.new(1, -190, 0, 24),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = topRow,
        }, "Text")
        MakeLabel({
            Text = "Welcome back to " .. Name .. ".",
            Font = FONTS.Body.Font, TextSize = 12,
            Position = UDim2.new(0, 72, 0, 44), Size = UDim2.new(1, -190, 0, 14),
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = topRow,
        }, "SubText")
        MakeChip(topRow, "ONLINE", "Success", {
            AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6),
        })
        AddSearchRow(hero, "welcome dashboard home")

        -- stat grid
        local statSec = tab:AddSection({ Name = "System", Description = "Live session statistics." })
        local grid = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 202),
            BackgroundTransparency = 1,
            LayoutOrder = 99, ZIndex = 7, Parent = statSec.Frame,
        }, {
            Create("UIGridLayout", {
                CellSize = UDim2.new(0.5, -5, 0, 96),
                CellPadding = UDim2.new(0, 10, 0, 10),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        })
        table.insert(StatGrids, grid.UIGridLayout)
        local function Stat(name, icon, desc)
            local card = Create("Frame", {
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.25,
                ZIndex = 7, Parent = grid,
            }, { Corner(12), Pad(12, 12, 12, 12) })
            Themed(card, "Surface")
            local cst = Stroke(nil, 1, 0.55)
            Themed(cst, "Border")
            cst.Parent = card
            MakeLabel({
                Text = icon, Font = FONTS.Title.Font, TextSize = 15,
                Position = UDim2.new(0, 12, 0, 12), Size = UDim2.new(0, 16, 0, 16),
                TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 8, Parent = card,
            }, "Primary")
            MakeLabel({
                Text = string.upper(name), Font = FONTS.Caption.Font, TextSize = 10,
                Position = UDim2.new(0, 34, 0, 15), Size = UDim2.new(1, -46, 0, 12),
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = card,
            }, "Muted")
            local val = MakeLabel({
                Text = "—", Font = FONTS.Heading.Font, TextSize = 24,
                Position = UDim2.new(0, 12, 0, 36), Size = UDim2.new(1, -24, 0, 28),
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = card,
            }, "Text")
            local sub = MakeLabel({
                Text = desc or "", Font = FONTS.Caption.Font, TextSize = 10,
                Position = UDim2.new(0, 12, 0, 68), Size = UDim2.new(1, -24, 0, 12),
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = card,
            }, "Muted")
            return { Set = function(v) val.Text = tostring(v) end, SetSub = function(s) sub.Text = s end }
        end
        Dash.FPS = Stat("FPS", "◉", "Measuring…")
        Dash.Ping = Stat("Ping", "◈", "Measuring…")
        Dash.Session = Stat("Session", "◷", "This visit")
        Dash.Device = Stat("Device", "▢", "Detected")
        Dash.Device.Set(GetDevice())
        Dash.Device.SetSub("Input detected")

        -- account info
        local accSec = tab:AddSection({ Name = "Account", Description = "Session and environment details." })
        local rows = {
            MakeInfoRow(accSec.Frame, "Username", "@" .. LocalPlayer.Name),
            MakeInfoRow(accSec.Frame, "Display name", LocalPlayer.DisplayName),
            MakeInfoRow(accSec.Frame, "User ID", tostring(LocalPlayer.UserId)),
            MakeInfoRow(accSec.Frame, "Account age", tostring(LocalPlayer.AccountAge) .. " days"),
            MakeInfoRow(accSec.Frame, "Experience", game.Name),
            MakeInfoRow(accSec.Frame, "Place ID", tostring(game.PlaceId)),
            MakeInfoRow(accSec.Frame, "Job ID", game.JobId ~= "" and (string.sub(game.JobId, 1, 8) .. "…") or "—"),
            MakeInfoRow(accSec.Frame, "Device", GetDevice()),
        }
        task.spawn(function()
            local ok, info = pcall(function()
                return MarketplaceService:GetProductInfo(game.PlaceId)
            end)
            if ok and info and info.Name then rows[5].Set(info.Name) end
        end)

        -- quick actions
        local qaSec = tab:AddSection({ Name = "Quick Actions", Description = "Jump to a frequently used page." })
        local btnRow = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            LayoutOrder = 99, ZIndex = 7, Parent = qaSec.Frame,
        }, {
            Create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 9),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        })
        MakeQuickButton(btnRow, "Open Main", function() WindowSelectTabSafe("Main") end)
        MakeQuickButton(btnRow, "Open Visuals", function() WindowSelectTabSafe("Visuals") end)
        MakeQuickButton(btnRow, "Open Settings", function() WindowSelectTabSafe("Settings") end)
    end

    local function BuildProfilesPage(tab)
        AddPageHeading(tab, "Switch between saved preference sets.")
        local sec = tab:AddSection({ Name = "Profiles", Description = "Visual presets for the framework demo." })
        local profiles = {
            { Name = "Default", Desc = "Balanced defaults for everyday use." },
            { Name = "Competitive", Desc = "Tightened feedback and reduced motion." },
            { Name = "Casual", Desc = "Relaxed pacing with richer effects." },
            { Name = "Custom", Desc = "Your current configuration, as-is." },
        }
        local active = "Default"
        local indicators = {}
        for _, prof in ipairs(profiles) do
            local rowF = Create("Frame", {
                Size = UDim2.new(1, 0, 0, 52),
                BackgroundTransparency = 1,
                LayoutOrder = sec:NextOrder(),
                ZIndex = 7, Parent = sec.Frame,
            })
            MakeLabel({
                Text = prof.Name, Font = FONTS.Title.Font, TextSize = 14,
                Position = UDim2.new(0, 2, 0, 6), Size = UDim2.new(1, -170, 0, 16),
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = rowF,
            }, "Text")
            MakeLabel({
                Text = prof.Desc, Font = FONTS.Caption.Font, TextSize = 11,
                Position = UDim2.new(0, 2, 0, 24), Size = UDim2.new(1, -170, 0, 14),
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8, Parent = rowF,
            }, "Muted")
            local dot = Create("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -92, 0.5, 0),
                Size = UDim2.new(0, 8, 0, 8),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 1,
                ZIndex = 8, Parent = rowF,
            }, { CornerFull() })
            Themed(dot, "Success")
            local activeLbl = MakeLabel({
                Text = "ACTIVE", Font = FONTS.Caption.Font, TextSize = 9,
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -104, 0.5, 0),
                Size = UDim2.new(0, 44, 0, 12),
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTransparency = 1, ZIndex = 8, Parent = rowF,
            }, "Success")
            local loadBtn = Create("TextButton", {
                Text = "Load", Font = FONTS.Title.Font, TextSize = 12,
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.new(0, 64, 0, 28),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.45,
                AutoButtonColor = false, ZIndex = 8, Parent = rowF,
            }, { Corner(8) })
            Themed(loadBtn, "Elevated", "BackgroundColor3")
            Themed(loadBtn, "SubText")
            local lst = Stroke(nil, 1, 0.5)
            Themed(lst, "Border")
            lst.Parent = loadBtn
            indicators[prof.Name] = { dot = dot, label = activeLbl }
            local pname = prof.Name
            Connect(loadBtn.MouseButton1Click, function()
                active = pname
                for name, ind in pairs(indicators) do
                    local on = (name == active)
                    Tw(ind.dot, 0.2, { BackgroundTransparency = on and 0 or 1 })
                    Tw(ind.label, 0.2, { TextTransparency = on and 0 or 1 })
                end
                Notify({ Title = "Profiles", Description = pname .. " profile loaded.", Type = "Success", Duration = 3 })
            end)
            AddSearchRow(rowF, prof.Name .. " " .. prof.Desc, sec)
        end
        local ind = indicators["Default"]
        if ind then
            ind.dot.BackgroundTransparency = 0
            ind.label.TextTransparency = 0
        end
    end

    local function BuildAboutPage(tab)
        AddPageHeading(tab, "About this interface.")
        local brand = tab:AddSection({ Name = "Aether UI" })
        local center = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 96),
            BackgroundTransparency = 1,
            LayoutOrder = 99, ZIndex = 7, Parent = brand.Frame,
        })
        local bigIcon = Create("TextLabel", {
            Text = ICONS.Cloud, Font = FONTS.Display.Font, TextSize = 34,
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2),
            Size = UDim2.new(0, 48, 0, 40), BackgroundTransparency = 1,
            ZIndex = 8, Parent = center,
        })
        AccentGradient(bigIcon, 45)
        MakeLabel({
            Text = string.upper(Name) .. " UI", Font = FONTS.Heading.Font, TextSize = 20,
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46),
            Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 8, Parent = center,
        }, "Text")
        MakeLabel({
            Text = Subtitle .. "  ·  Version " .. Version, Font = FONTS.Caption.Font, TextSize = 11,
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70),
            Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 8, Parent = center,
        }, "Muted")

        local info = tab:AddSection({ Name = "Details" })
        MakeInfoRow(info.Frame, "Designed for", "Desktop / Mobile / Tablet")
        MakeInfoRow(info.Frame, "Developer", Developer)
        MakeInfoRow(info.Frame, "Build", "Stable")
        MakeInfoRow(info.Frame, "Framework", "Aether Cloud UI")

        tab:AddSection({ Name = "Changelog" })
            :AddParagraph({ Text = "v" .. Version .. " — Initial release.\n• Full control suite: toggles, sliders, dropdowns, textboxes, keybinds, color pickers\n• Four themes with live switching and custom accents\n• Responsive layout for phone, tablet and desktop\n• Notifications, modals, tooltips and context menus\n• Configuration save / load / reset with in-memory fallback" })

        tab:AddSection({ Name = "Credits" })
            :AddParagraph({ Text = "Interface design and engineering by " .. Developer .. ".\nBuilt entirely with Roblox Instances — no external assets or dependencies." })

        local social = tab:AddSection({ Name = "Links" })
        local rowF = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 34),
            BackgroundTransparency = 1,
            LayoutOrder = 99, ZIndex = 7, Parent = social.Frame,
        }, {
            Create("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        })
        for _, label in ipairs({ "Discord", "GitHub" }) do
            MakeQuickButton(rowF, label, function()
                Notify({ Title = label, Description = "Placeholder link — configure it in your script.", Type = "Info", Duration = 3 })
            end)
        end
    end

    function WindowSelectTabSafe(name)
        for _, t in ipairs(Tabs) do
            if t.Name == name then SelectTab(t) return end
        end
    end

    local function BuildDemoPages()
        local home = AddTabSafe({ Name = "Home", Icon = ICONS.Home })
        BuildHomePage(home)

        local main = AddTabSafe({ Name = "Main", Icon = ICONS.Main })
        AddPageHeading(main, "Primary example controls.")
        local sec = main:AddSection({ Name = "General", Description = "Main interface controls." })
        sec:AddToggle({
            Name = "Example Toggle", Description = "Demonstration setting.",
            Default = false, Flag = "ExampleToggle",
            Callback = function(v) print("[Aether] toggle:", v) end,
        })
        sec:AddSlider({
            Name = "Example Slider", Min = 0, Max = 100, Default = 50, Step = 1,
            Flag = "ExampleSlider", Callback = function(v) print("[Aether] slider:", v) end,
        })
        sec:AddDropdown({
            Name = "Example Dropdown", Options = { "Option A", "Option B", "Option C" },
            Default = "Option A", Flag = "ExampleDropdown",
            Callback = function(v) print("[Aether] dropdown:", v) end,
        })
        sec:AddButton({
            Name = "Show Notification", Style = "Primary",
            Callback = function()
                Notify({ Title = "Hello there", Description = "This is a premium notification demo.", Type = "Success", Duration = 4 })
            end,
        })
        sec:AddButton({
            Name = "Open Modal", Style = "Secondary",
            Callback = function()
                MakeModal({
                    Title = "Reset configuration?",
                    Description = "This restores every setting to its default value. This cannot be undone.",
                    ConfirmText = "Reset", Danger = true,
                    OnConfirm = function() ResetConfig() end,
                })
            end,
        })

        local player = AddTabSafe({ Name = "Player", Icon = ICONS.Player })
        AddPageHeading(player, "Movement-related placeholders.")
        local mov = player:AddSection({ Name = "Movement", Description = "Adjust movement-related preferences." })
        mov:AddSlider({ Name = "Walk Speed (demo)", Description = "Placeholder — prints only.", Min = 16, Max = 100, Default = 16, Suffix = "st/s", Flag = "DemoSpeed", Callback = function(v) print("[Aether] speed:", v) end })
        mov:AddSlider({ Name = "Jump Power (demo)", Description = "Placeholder — prints only.", Min = 50, Max = 200, Default = 50, Flag = "DemoJump", Callback = function(v) print("[Aether] jump:", v) end })
        mov:AddDropdown({ Name = "Movement Mode", Options = { "Default", "Glide", "Dash" }, Default = "Default", Flag = "DemoMode", Callback = function(v) print("[Aether] mode:", v) end })

        local visuals = AddTabSafe({ Name = "Visuals", Icon = ICONS.Visuals, Badge = "3" })
        AddPageHeading(visuals, "Appearance of in-world effects (demo).")
        local vis = visuals:AddSection({ Name = "Effects", Description = "Harmless visual demonstration." })
        vis:AddToggle({ Name = "Visual Toggle", Description = "Enable the demo effect.", Default = false, Flag = "VisualToggle", Callback = function(v) print("[Aether] visual:", v) end })
        vis:AddColorpicker({ Name = "Effect Color", Description = "Pick any color with alpha.", Default = Color3.fromRGB(255, 164, 210), Flag = "VisualColor", Callback = function(c, a) print("[Aether] color:", ToHex(c), a) end })
        vis:AddSlider({ Name = "Transparency", Min = 0, Max = 1, Default = 0.25, Step = 0.05, Percent = true, Flag = "VisualAlpha", Callback = function(v) print("[Aether] alpha:", v) end })
        vis:AddDropdown({ Name = "Style", Options = { "Soft", "Bold", "Minimal" }, Default = "Soft", Flag = "VisualStyle", Callback = function(v) print("[Aether] style:", v) end })

        local auto = AddTabSafe({ Name = "Automation", Icon = ICONS.Automation })
        AddPageHeading(auto, "Harmless automation placeholders.")
        local aus = auto:AddSection({ Name = "Tasks", Description = "Demonstration-only settings." })
        aus:AddToggle({ Name = "Friendly Reminders", Description = "Occasional gentle notifications.", Default = false, Flag = "AutoReminders", Callback = function(v) print("[Aether] reminders:", v) end })
        aus:AddSlider({ Name = "Reminder Interval", Min = 5, Max = 60, Default = 15, Suffix = "min", Flag = "AutoInterval", Callback = function() end })
        aus:AddDropdown({ Name = "Log Style", Options = { "Minimal", "Detailed" }, Default = "Minimal", Flag = "AutoLog", Callback = function() end })
        aus:AddButton({ Name = "Run Demo Task", Style = "Secondary", Callback = function()
            Notify({ Title = "Task complete", Description = "The demo task finished successfully.", Type = "Success", Duration = 3 })
        end })

        local profiles = AddTabSafe({ Name = "Profiles", Icon = ICONS.Profiles })
        BuildProfilesPage(profiles)

        local settings = AddTabSafe({ Name = "Settings", Icon = ICONS.Settings })
        AddPageHeading(settings, "Customize the interface.")

        local app = settings:AddSection({ Name = "Appearance", Description = "Visual identity of the interface." })
        app:AddDropdown({
            Name = "Theme", Description = "Color palette.",
            Options = { "Aether Cloud", "Lavender Night", "Soft Rose", "Arctic Mist" },
            Default = ThemeNameToDisplay[State.Theme], Flag = "Theme",
            Callback = function(v) SetTheme(ThemeDisplayNames[v]) end,
        })
        AccentPickerHandle = app:AddColorpicker({
            Name = "Accent Color", Description = "Primary highlight color.",
            Default = State.Accent, Flag = "AccentColor",
            Callback = function(c) SetAccent(c) end,
        })
        app:AddSlider({ Name = "UI Scale", Description = "Interface size.", Min = 0.75, Max = 1.25, Default = 1, Step = 0.01, Flag = "UIScale", Callback = function(v) ApplyUIScale(v) end })
        app:AddSlider({ Name = "Transparency", Description = "Glass panel effect.", Min = 0, Max = 1, Default = 0, Step = 0.05, Percent = true, Flag = "Transparency", Callback = function(v) ApplyTransparency(v) end })
        app:AddToggle({ Name = "Animations", Description = "Smooth interface effects.", Default = true, Flag = "Animations", Callback = function(v) State.Animations = v end })
        app:AddToggle({ Name = "Cloud Effects", Description = "Atmospheric background orbs.", Default = true, Flag = "CloudEffects", Callback = function(v) ApplyClouds(v) end })
        app:AddToggle({ Name = "Animated Accent", Description = "Slowly cycle the accent color.", Default = false, Flag = "AnimatedAccent", Callback = function(v) ApplyAnimAccent(v) end })
        app:AddSlider({ Name = "Accent Speed", Min = 0.5, Max = 3, Default = 1, Step = 0.1, Flag = "AccentSpeed", Callback = function(v) State.AccentSpeed = v end })
        app:AddToggle({ Name = "Reduce Motion", Description = "Near-instant transitions.", Default = false, Flag = "ReduceMotion", Callback = function(v) State.ReduceMotion = v end })

        local interf = settings:AddSection({ Name = "Interface", Description = "Behavior of controls." })
        interf:AddToggle({ Name = "Notifications", Default = true, Flag = "Notifications", Callback = function(v) State.NotificationsEnabled = v end })
        interf:AddToggle({ Name = "Tooltips", Default = true, Flag = "Tooltips", Callback = function(v) State.Tooltips = v end })
        interf:AddToggle({ Name = "Compact Mode", Description = "Tighter rows and padding.", Default = false, Flag = "CompactMode", Callback = function(v) State.Compact = v ApplyResponsive(true) end })
        interf:AddDropdown({ Name = "Sidebar Mode", Options = { "Auto", "Expanded", "Collapsed" }, Default = "Auto", Flag = "SidebarMode", Callback = function(v) State.SidebarMode = v ApplyResponsive(true) end })
        interf:AddKeybind({ Name = "Menu Key", Description = "Show or hide the interface.", Default = Enum.KeyCode.RightShift, Flag = "MenuKey", OnChanged = function(key) State.MenuKey = key end })

        local conf = settings:AddSection({ Name = "Configuration", Description = "Persist your settings." })
        conf:AddButton({ Name = "Save Configuration", Style = "Primary", Callback = function() SaveConfig() end })
        conf:AddButton({ Name = "Load Configuration", Style = "Secondary", Callback = function() LoadConfig(false) end })
        conf:AddButton({ Name = "Reset Configuration", Style = "Danger", Callback = function()
            MakeModal({
                Title = "Reset configuration?",
                Description = "This cannot be undone.",
                ConfirmText = "Reset", Danger = true,
                OnConfirm = function() ResetConfig() end,
            })
        end })

        local pos = settings:AddSection({ Name = "Position", Description = "Window placement." })
        pos:AddButton({ Name = "Reset Window Position", Style = "Secondary", Callback = function()
            if Root then Root.Position = UDim2.new(0.5, 0, 0.5, 0) end
        end })

        local about = AddTabSafe({ Name = "About", Icon = ICONS.About })
        BuildAboutPage(about)
    end

    --// CREATE WINDOW
    function UI:CreateWindow(winCfg)
        if Destroyed then return nil end
        if ChromeBuilt then return Window end
        winCfg = winCfg or {}
        BuildChrome()
        ChromeBuilt = true

        Window = {}
        function Window:AddTab(cfg) return AddTabSafe(cfg) end
        function Window:SelectTab(name) WindowSelectTabSafe(name) end
        function Window:Toggle() ToggleWindow() end
        function Window:Minimize() SetMinimizedSafe(true) end
        function Window:Restore() SetMinimizedSafe(false) end

        local sizeConn = Connect(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"), function()
            ApplyResponsive(true)
        end)
        CleanAdd(sizeConn)

        task.defer(function() ApplyResponsive(false) end)

        if DemoContent then
            BuildDemoPages()
        end
        if AutoLoad then
            task.defer(function() LoadConfig(true) end)
        end

        if IntroEnabled and State.Animations and not State.ReduceMotion then
            PlayIntro(OpenWindow)
        else
            OpenWindow()
        end
        return Window
    end

    --// PUBLIC API
    function UI:Notify(cfg) return Notify(cfg) end
    function UI:Modal(cfg) return MakeModal(cfg) end
    function UI:ShowContextMenu(items, x, y) return ShowContextMenu(items, x, y) end

    function UI:SetTheme(name)
        local key = Themes[name] and name or ThemeDisplayNames[name]
        if not key then
            warn("[Aether] unknown theme:", tostring(name))
            return false
        end
        return SetTheme(key)
    end

    function UI:SetAccent(color)
        if type(color) == "string" then
            local c = FromHex(color)
            if not c then
                warn("[Aether] invalid accent hex:", color)
                return false
            end
            color = c
        end
        if typeof(color) ~= "Color3" then return false end
        SetAccent(color)
        return true
    end

    function UI:SetScale(n)
        ApplyUIScale(n)
        return true
    end

    function UI:SaveConfig() return SaveConfig() end
    function UI:LoadConfig(silent) return LoadConfig(silent) end
    function UI:ResetConfig() return ResetConfig() end

    function UI:SetMenuKey(key)
        if typeof(key) ~= "EnumItem" or key.EnumType ~= Enum.KeyCode then return false end
        State.MenuKey = key
        return true
    end
    function UI:SetTransparency(v) ApplyTransparency(v) end
    function UI:SetClouds(v) ApplyClouds(v) end
    function UI:SetAnimatedAccent(v) ApplyAnimAccent(v) end
    function UI:SetReducedMotion(v) State.ReduceMotion = v == true end
    function UI:AddCleanup(callback) return CleanAdd(callback) end

    function UI:Destroy()
        if Destroyed then return end
        Destroyed = true
        RunCleanup()
    end

    CleanAdd(Connect(ScreenGui.Destroying, function() UI:Destroy() end))
    return UI
end

return CloudUI
end)()

-- AETHER BOMB PASS / File 2 integrated with the corrected File 1 controller and File 3 UI.
-- Auto Pass starts off. Both modes require Running/Fused and a valid server-clock deadline.
-- This application body is bundled below its CloudUI dependency in the standalone output.
local UI, cloudTimer, cloudStatus, cloudModeDropdown, timedThresholdSettings
local appDestroyed = false
local appConnections = {}
local function connect(signal, callback)
    if appDestroyed then return nil end
    if #appConnections % 64 == 0 then
        for i = #appConnections, 1, -1 do
            if not appConnections[i].Connected then table.remove(appConnections, i) end
        end
    end
    local connection = signal:Connect(function(...)
        if not appDestroyed then callback(...) end
    end)
    table.insert(appConnections, connection)
    return connection
end
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local bombName = "Bomb"
local customNormalFriction = 0.7
local customBombFriction = 7
local customAntiSlipperyFriction = 0.7
local customBombAntiSlipperyFriction = 0.9
local fallbackFriction = 0.5
local customHitboxSize = 0.1
local bombPassDistance = 6
local raySpreadAngle = 10
local numRaycasts = 5
local AutoPassEnabled = false
local antiSlippery = false
local RemoveHitboxEnabled = false
local AI_AssistanceEnabled = false
local allUIVisible = true
local originalHitboxSizes = {}
-- Shared state is declared before callbacks; AutoPassButton is declared here so
-- setAutoPassEnabled (defined earlier in the file) can see it as an upvalue.
local autoPassConnection, mobileGui, mobileToggle, mobileModeToggle, flickToggle, mobileStatus
local ShiftLockScreenGui, ShiftLockButton, SL_Active, passCore
local cloudAutoPassToggle, cloudLatePassToggle, cloudFlickToggle, cloudLayoutToggle
local mobileTimer
local FaceBombEnabled, faceBombConnection
local AutoPassButton
local refreshMobileButtons = function() end
local updateAutoPassButton = function() end

local FrictionController = {}
FrictionController.__index = FrictionController
function FrictionController.new()
    local self = setmetatable({}, FrictionController)
    self.originalProperties = {}
    self.normalFriction = customNormalFriction
    self.bombFriction = customBombFriction
    self.stateMultipliers = {Running = 1.2, Walking = 1.0, Crouching = 0.8}
    self.enabled = false
    return self
end
function FrictionController:getSurfaceMaterial(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return Enum.Material.Plastic
    end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local rayResult = Workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), rayParams)
    return rayResult and rayResult.Instance.Material or Enum.Material.Plastic
end
function FrictionController:calculateFriction(character)
    local humanoid = character:FindFirstChild("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and hrp) then
        return self.normalFriction
    end
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local rayResult = Workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), rayParams)
    if rayResult then
        local floorPart = rayResult.Instance
        if floorPart:IsA("BasePart") and floorPart.Name == "Floor" and floorPart.Friction <= 0.2 then
            return math.clamp(customAntiSlipperyFriction * 0.5, 0.1, 1.0)
        end
    end
    if character:FindFirstChild(bombName) then
        return self.bombFriction
    end
    local stateName = humanoid:GetState()
    local multiplier = self.stateMultipliers[stateName] or 1.0
    return math.clamp(self.normalFriction * multiplier, 0.1, 1.0)
end
function FrictionController:update()
    if antiSlippery then return end
    local character = LocalPlayer.Character
    if not character then return end
    for _, name in ipairs({"LeftFoot", "RightFoot", "LeftLeg", "RightLeg", "Left Leg", "Right Leg"}) do
        local part = character:FindFirstChild(name)
        if part and part:IsA("BasePart") then
            if not self.originalProperties[part] then
                self.originalProperties[part] = {Value = part.CustomPhysicalProperties}
            end
            local base = part.CurrentPhysicalProperties
            part.CustomPhysicalProperties = PhysicalProperties.new(base.Density,
                math.clamp(self:calculateFriction(character), 0, 2), base.Elasticity,
                base.FrictionWeight, base.ElasticityWeight)
        end
    end
end
function FrictionController:restore()
    for part, original in pairs(self.originalProperties) do
        if part.Parent then part.CustomPhysicalProperties = original.Value end
    end
    self.originalProperties = {}
end

function FrictionController:enable()
    if self.enabled then
        return
    end
    self.enabled = true
    spawn(
        function()
            while self.enabled and not appDestroyed do
                self:update()
                wait(0.1)
            end
        end
    )
end
function FrictionController:disable()
    self.enabled = false
    self:restore()
end

local antiSlipOriginal, antiSlipTask = {}, nil
local function applyAntiSlippery(enabled)
    if antiSlipTask then pcall(task.cancel, antiSlipTask); antiSlipTask = nil end
    if not enabled then
        for part, original in pairs(antiSlipOriginal) do
            if part.Parent then part.CustomPhysicalProperties = original.Value end
        end
        table.clear(antiSlipOriginal)
        return
    end
    antiSlipTask = task.spawn(function()
        while antiSlippery and not appDestroyed do
            local character = LocalPlayer.Character
            if character then
                local friction = character:FindFirstChild(bombName) and customBombAntiSlipperyFriction or customAntiSlipperyFriction
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if not antiSlipOriginal[part] then antiSlipOriginal[part] = {Value = part.CustomPhysicalProperties} end
                        local base = part.CurrentPhysicalProperties
                        part.CustomPhysicalProperties = PhysicalProperties.new(base.Density, math.clamp(friction, 0, 2),
                            base.Elasticity, base.FrictionWeight, base.ElasticityWeight)
                    end
                end
            end
            task.wait(.1)
        end
    end)
end

local function faceNearestBombHolder()
    if passCore and (passCore:IsFlicking()
        or Workspace:GetServerTimeNow() < passCore.NextFlick) then return end
    local myChar = LocalPlayer.Character
    if not myChar then
        return
    end
    local hrp = myChar:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local nearest, nearestDist = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild(bombName) then
            local pHRP = p.Character:FindFirstChild("HumanoidRootPart")
            if pHRP then
                local d = (pHRP.Position - hrp.Position).Magnitude
                if d < nearestDist then
                    nearestDist = d
                    nearest = p
                end
            end
        end
    end
    if nearest and nearest.Character then
        local bombHolderHRP = nearest.Character:FindFirstChild("HumanoidRootPart")
        if bombHolderHRP then
            local cam = Workspace.CurrentCamera
            cam.CameraType = Enum.CameraType.Custom
            cam.CFrame = CFrame.new(cam.CFrame.Position, bombHolderHRP.Position)
        end
    end
end

local CHAR = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HUMANOID = CHAR:WaitForChild("Humanoid")
local HRP = CHAR:WaitForChild("HumanoidRootPart")

local LoggingModule = {}
function LoggingModule.logError(err, ctx)
    warn("[ERROR] Context: " .. tostring(ctx) .. " | " .. tostring(err))
end
function LoggingModule.safeCall(func, ctx)
    local s, r = pcall(func)
    if not s then
        LoggingModule.logError(r, ctx)
    end
    return s, r
end

local TargetingModule = {}
function TargetingModule.getClosestPlayer()
    local closest, md = nil, math.huge
    local myPos = HRP.Position
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local targetHrp = p.Character:FindFirstChild("HumanoidRootPart")
            if targetHrp and not p.Character:FindFirstChild(bombName) then
                local d = (targetHrp.Position - myPos).Magnitude
                if d < md then
                    md = d
                    closest = p
                end
            end
        end
    end
    return closest
end
function TargetingModule.rotateCharacterTowardsTarget(targetPos)
end

local VisualModule = {}
function VisualModule.animateMarker(marker)
    if not marker then
        return
    end
    local tween =
        TweenService:Create(
        marker,
        TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        {Size = UDim2.new(0, 100, 0, 100)}
    )
    tween:Play()
end
function VisualModule.playPassVFX(target)
    if not target or not target.Character then
        return
    end
    local hrp = target.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return
    end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Texture = "rbxassetid://258128463"
    emitter.Rate = 50
    emitter.Lifetime = NumberRange.new(0.3, 0.5)
    emitter.Speed = NumberRange.new(2, 5)
    emitter.VelocitySpread = 30
    emitter.Parent = hrp
    delay(
        1,
        function()
            emitter:Destroy()
        end
    )
end

local AINotificationsModule = {}
function AINotificationsModule.sendNotification(title, text, dur)
    if UI then UI:Notify({Title = title, Description = text, Duration = dur or 5}); return end
    pcall(
        function()
            StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = dur or 5})
        end
    )
end

local function applyRemoveHitbox(enable)
    local char = LocalPlayer.Character
    if not char then
        return
    end

    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name == "Hitbox" then
            if enable then
                if not originalHitboxSizes[part] then
                    originalHitboxSizes[part] = {Size = part.Size, Transparency = part.Transparency, CanCollide = part.CanCollide}
                end
                part.Transparency = 1
                part.CanCollide = false
                part.Size = Vector3.new(customHitboxSize, customHitboxSize, customHitboxSize)
            else
                local original = originalHitboxSizes[part]
                if original then
                    part.Transparency, part.CanCollide, part.Size = original.Transparency, original.CanCollide, original.Size
                    originalHitboxSizes[part] = nil
                end
            end
        end
    end
end

local currentTargetMarker, currentTargetPlayer = nil, nil
local function createOrUpdateTargetMarker(player, dist)
    if not player or not player.Character then
        return
    end
    local body = player.Character:FindFirstChild("HumanoidRootPart")
    if not body then
        return
    end
    if currentTargetMarker and currentTargetPlayer == player then
        currentTargetMarker:FindFirstChildOfClass("TextLabel").Text =
            player.Name .. "\n" .. math.floor(dist) .. " studs"
        return
    end
    if currentTargetMarker then
        currentTargetMarker:Destroy()
        currentTargetMarker, currentTargetPlayer = nil, nil
    end
    local marker = Instance.new("BillboardGui")
    marker.Name = "BombPassTargetMarker"
    marker.Adornee = body
    marker.Size = UDim2.new(0, 80, 0, 80)
    marker.StudsOffset = Vector3.new(0, 2, 0)
    marker.AlwaysOnTop = true
    marker.Parent = body
    local label = Instance.new("TextLabel", marker)
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = player.Name .. "\n" .. math.floor(dist) .. " studs"
    label.TextScaled = true
    label.TextColor3 = Color3.new(1, 0, 0)
    label.Font = Enum.Font.SourceSansBold
    currentTargetMarker, currentTargetPlayer = marker, player
    VisualModule.animateMarker(marker)
end
local function removeTargetMarker()
    if currentTargetMarker then
        currentTargetMarker:Destroy()
        currentTargetMarker, currentTargetPlayer = nil, nil
    end
end

local function isLineOfSightClearMultiple(startPos, endPos, targetPart)
    local spreadRad = math.rad(raySpreadAngle)
    local direction = (endPos - startPos).Unit
    local distance = (endPos - startPos).Magnitude
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    if LocalPlayer.Character then
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end
    local centralResult = Workspace:Raycast(startPos, direction * distance, rayParams)
    if centralResult and not centralResult.Instance:IsDescendantOf(targetPart.Parent) then
        return false
    end
    local raysEachSide = math.floor((numRaycasts - 1) / 2)
    for i = 1, raysEachSide do
        local angleOffset = spreadRad * i / raysEachSide
        local leftDirection = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), angleOffset) * CFrame.new(direction)).p
        local leftResult = Workspace:Raycast(startPos, leftDirection * distance, rayParams)
        if leftResult and not leftResult.Instance:IsDescendantOf(targetPart.Parent) then
            return false
        end
        local rightDirection = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -angleOffset) * CFrame.new(direction)).p
        local rightResult = Workspace:Raycast(startPos, rightDirection * distance, rayParams)
        if rightResult and not rightResult.Instance:IsDescendantOf(targetPart.Parent) then
            return false
        end
    end
    return true
end

-- BEGIN PASS CONTROLLER (plain Lua; also exercised by the local test harness)
local PassController = {}
PassController.__index = PassController

local function finiteNumber(value)
    return type(value) == "number" and value == value
        and value > -math.huge and value < math.huge
end

function PassController.remaining(bomb, now)
    local state = bomb:GetAttribute("BombState")
    if state ~= "Running" and state ~= "Fused" then
        return nil, "State: " .. tostring(state or "missing")
    end
    local startTime = bomb:GetAttribute("BombStartTime")
    local duration = bomb:GetAttribute("BombDuration")
    if not finiteNumber(startTime) then return nil, "BombStartTime missing or invalid" end
    if not finiteNumber(duration) or duration <= 0 then return nil, "BombDuration missing or invalid" end
    if not finiteNumber(now) then return nil, "Server time unavailable" end
    -- Same fractional deadline as the game's BombClient; never round before gating.
    return startTime + duration - now
end

function PassController.eligible(mode, remaining, distance, config)
    if mode ~= "Normal" and mode ~= "Late" then return false end
    if not finiteNumber(distance) or distance < 0 then return false end
    if not finiteNumber(remaining) or remaining <= 0 then return false end
    local window = mode == "Late" and config.LateWindow or config.NormalWindow
    local maxDist = mode == "Late" and config.LateDistance or config.NormalDistance
    return finiteNumber(window) and window > 0 and finiteNumber(maxDist) and maxDist > 0
        and remaining <= window and distance <= maxDist
end

local function isBomb(instance)
    return instance:IsA("Tool")
        and (instance.Name == "Bomb" or instance:GetAttribute("BombClientManaged") == true)
end

local function livingParts(character)
    if not character or not character.Parent then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
        return nil
    end
    return root, humanoid
end

function PassController.new(services, config, hooks)
    return setmetatable({
        Services = services, Config = config, Hooks = hooks,
        Pending = nil, Flick = nil, NextRequest = 0, NextFlick = 0,
        LastStatus = "", HeldBomb = nil, HeldCharacter = nil, FlickedForPossession = false,
    }, PassController)
end

function PassController:Status(message)
    if message ~= self.LastStatus then
        self.LastStatus = message
        self.Hooks.status(message)
    end
end

function PassController:GetBomb(character, now)
    local named = character:FindFirstChild("Bomb")
    if self.Config.Mode ~= "Late" and named and isBomb(named) then return named end
    local first, earliest, earliestTime
    for _, child in ipairs(character:GetChildren()) do
        if isBomb(child) then
            first = first or child
            local remaining = self.remaining(child, now)
            if remaining and remaining > 0 and (not earliestTime or remaining < earliestTime) then
                earliest, earliestTime = child, remaining
            end
        end
    end
    if self.Config.Mode == "Late" then return earliest or first end
    return first
end

function PassController:GetTarget(root)
    local best, bestCharacter, bestRoot, bestPart, distance = nil, nil, nil, nil, math.huge
    for _, player in ipairs(self.Services.Players:GetPlayers()) do
        if player ~= self.Services.LocalPlayer then
            local character = player.Character
            local targetRoot = livingParts(character)
            local part = character and (character:FindFirstChild("CollisionPart") or targetRoot)
            if targetRoot and part and part:IsA("BasePart") then
                local current = (part.Position - root.Position).Magnitude
                if current < distance then
                    best, bestCharacter, bestRoot, bestPart, distance = player, character, targetRoot, part, current
                end
            end
        end
    end
    return best, bestCharacter, bestRoot, bestPart, distance
end

function PassController:ClearPending()
    if self.Pending and self.Pending.Connection then self.Pending.Connection:Disconnect() end
    self.Pending = nil
end

function PassController:ObserveTransfer(pending)
    if self.Pending ~= pending then return end
    -- Disappearance, death, unequipping and respawn are NOT pass confirmation.
    if pending.Target.Character == pending.TargetCharacter
        and pending.Bomb.Parent == pending.TargetCharacter then
        pending.Confirmed = true
        local flick = self.Flick
        if flick and not flick.ConfirmedAt and flick.Character == pending.Character and flick.Root.Parent then
            flick.ConfirmedAt = self.Services.Workspace:GetServerTimeNow()
        end
    elseif pending.Bomb.Parent ~= pending.Character then
        pending.LeftCharacter = true
    end
end

local function flatDirection(vector)
    local flat = Vector3.new(vector.X, 0, vector.Z)
    return flat.Magnitude > 0.001 and flat.Unit or nil
end

local function canTurn(humanoid)
    if humanoid.Health <= 0 or humanoid.Sit or humanoid.PlatformStand then return false end
    local state = humanoid:GetState()
    return state ~= Enum.HumanoidStateType.Dead and state ~= Enum.HumanoidStateType.Physics
        and state ~= Enum.HumanoidStateType.Ragdoll and state ~= Enum.HumanoidStateType.Swimming
        and state ~= Enum.HumanoidStateType.Climbing
end

function PassController:IsFlicking()
    return self.Flick ~= nil
end

function PassController:CameraRelative()
    return self.Hooks.shiftLocked()
        or (self.Hooks.cameraRelative and self.Hooks.cameraRelative() == true)
        or false
end

function PassController:ReturnRotation(flick)
    local direction
    if self:CameraRelative() then
        local camera = self.Services.Workspace.CurrentCamera
        if camera and camera.CameraSubject == flick.Humanoid then
            direction = flatDirection(camera.CFrame.LookVector)
        end
    elseif flick.OriginalAutoRotate then
        direction = flatDirection(flick.Humanoid.MoveDirection)
    end
    return direction and CFrame.lookAt(Vector3.zero, direction) or flick.OriginalRotation
end

function PassController:EndFlick(restoreFacing)
    local flick = self.Flick
    if not flick then return end
    self.Flick = nil
    if flick.Connection then flick.Connection:Disconnect() end
    if flick.Humanoid.Parent then
        if restoreFacing and self.Services.LocalPlayer.Character == flick.Character
            and flick.Root.Parent and not flick.Root.Anchored and canTurn(flick.Humanoid) then
            -- Never rewind position, velocity, camera or joystick input.
            flick.Root.CFrame = CFrame.new(flick.Root.Position) * self:ReturnRotation(flick)
        end
        if self.Hooks.shiftLocked() then
            flick.Humanoid.AutoRotate = false
        else
            flick.Humanoid.AutoRotate = flick.OriginalAutoRotate
        end
    end
end

local function smoothstep(alpha)
    return alpha * alpha * (3 - 2 * alpha)
end

-- Pure timing helper: larger turns take a little longer, never a fixed 180-degree snap.
function PassController.flickProfile(turnDegrees, preferredDuration)
    if not finiteNumber(turnDegrees) then turnDegrees = 0 end
    if not finiteNumber(preferredDuration) then preferredDuration = 0.18 end
    local scale = math.clamp(math.abs(turnDegrees) / 90, 0.60, 1.35)
    local total = math.clamp(math.clamp(preferredDuration, 0.10, 0.30) * scale, 0.10, 0.30)
    return {Total = total, Turn = total * 0.40, Follow = total * 0.10, Return = total * 0.50}
end

function PassController:BeginFlickReturn(flick, atTime, duration, rotation)
    flick.ReleaseAt = atTime
    flick.ReleaseDuration = duration
    flick.ReleaseRotation = rotation or flick.Root.CFrame.Rotation
end

function PassController:ManualTurnDetected(flick)
    local cameraRelative = self:CameraRelative()
    if self.Hooks.shiftLocked() ~= flick.InitialShiftLocked
        or cameraRelative ~= flick.InitialCameraRelative then return true end
    if cameraRelative then
        local camera = self.Services.Workspace.CurrentCamera
        if camera ~= flick.Camera then return true end
        local direction = camera and flatDirection(camera.CFrame.LookVector)
        -- Camera translation and pitch alone do not cancel a horizontal body turn.
        return direction ~= nil and flick.InitialCameraDirection ~= nil
            and direction:Dot(flick.InitialCameraDirection) < math.cos(math.rad(10))
    end
    if flick.OriginalAutoRotate then
        local movement = flatDirection(flick.Humanoid.MoveDirection)
        if (movement == nil) ~= (flick.InitialMoveDirection == nil) then return true end
        return movement ~= nil and flick.InitialMoveDirection ~= nil
            and movement:Dot(flick.InitialMoveDirection) < math.cos(math.rad(50))
    end
    return false
end

function PassController:UpdateFlick(flick)
    if self.Flick ~= flick then return end
    local root, humanoid = flick.Root, flick.Humanoid
    if not self.Config.Enabled or not self.Config.FlickEnabled
        or self.Services.LocalPlayer.Character ~= flick.Character or not root.Parent
        or root.Anchored or not humanoid.Parent or not canTurn(humanoid) then
        self:EndFlick(true)
        return
    end
    local now = self.Services.Workspace:GetServerTimeNow()
    local elapsed = math.max(0, now - flick.Started)
    -- Do not replay a stale turn after a large frame hitch.
    if elapsed >= flick.Profile.Total + 0.08 then self:EndFlick(true); return end

    if not flick.InputYielded and self:ManualTurnDetected(flick) then
        flick.InputYielded = true
        self:BeginFlickReturn(flick, now, math.min(0.06, flick.Profile.Return))
    end

    local rotation
    if not flick.ReleaseAt then
        local turnEnd = flick.Started + flick.Profile.Turn
        local releaseAt = turnEnd + flick.Profile.Follow
        if flick.ConfirmedAt then
            -- A fast acknowledgement must not cut the target turn down to one frame.
            releaseAt = math.min(releaseAt, math.max(turnEnd, flick.ConfirmedAt))
        end
        if now < turnEnd then
            local alpha = math.clamp(elapsed / flick.Profile.Turn, 0, 1)
            rotation = flick.OriginalRotation:Lerp(flick.TargetRotation, smoothstep(alpha))
        elseif now < releaseAt then
            local alpha = math.clamp((now - turnEnd) / flick.Profile.Follow, 0, 1)
            rotation = flick.TargetRotation:Lerp(flick.SweepRotation, smoothstep(alpha))
        else
            local alpha = math.clamp((releaseAt - turnEnd) / flick.Profile.Follow, 0, 1)
            local peak = flick.TargetRotation:Lerp(flick.SweepRotation, smoothstep(alpha))
            self:BeginFlickReturn(flick, releaseAt, flick.Profile.Return, peak)
        end
    end
    if flick.ReleaseAt then
        local alpha = math.clamp((now - flick.ReleaseAt) / flick.ReleaseDuration, 0, 1)
        if alpha >= 1 then self:EndFlick(true); return end
        -- Return to LIVE camera/movement intent, not the heading captured at pickup.
        rotation = flick.ReleaseRotation:Lerp(self:ReturnRotation(flick), smoothstep(alpha))
    end
    root.CFrame = CFrame.new(root.Position) * rotation
end

function PassController:StartFlick(character, root, humanoid, targetRoot, now)
    if not self.Config.FlickEnabled or self.FlickedForPossession or now < self.NextFlick or self.Flick
        or root.Anchored or not canTurn(humanoid) then return end
    local direction = flatDirection(targetRoot.Position - root.Position)
    local facing = flatDirection(root.CFrame.LookVector)
    if not direction or not facing then return end
    local camera = self.Services.Workspace.CurrentCamera
    if camera and (camera.CameraType ~= Enum.CameraType.Custom or camera.CameraSubject ~= humanoid) then return end

    local turnDegrees = math.deg(math.acos(math.clamp(facing:Dot(direction), -1, 1)))
    -- Consume this possession's visual attempt even when already facing the target.
    -- Passing retries should not manufacture a new flick after you start moving.
    self.FlickedForPossession = true
    if turnDegrees < 6 then return end

    local flick = {
        Character = character, Root = root, Humanoid = humanoid,
        OriginalAutoRotate = humanoid.AutoRotate, OriginalRotation = root.CFrame.Rotation,
        TargetRotation = CFrame.lookAt(Vector3.zero, direction), Started = now,
        Profile = self.flickProfile(turnDegrees, self.Config.FlickDuration),
        Camera = camera, InitialCameraDirection = camera and flatDirection(camera.CFrame.LookVector),
        InitialMoveDirection = flatDirection(humanoid.MoveDirection),
        InitialShiftLocked = self.Hooks.shiftLocked(), InitialCameraRelative = self:CameraRelative(),
    }
    local resumeDirection = self:ReturnRotation(flick).LookVector
    local crossY = direction.Z * resumeDirection.X - direction.X * resumeDirection.Z
    local sign = crossY < 0 and -1 or 1
    local followAngle = finiteNumber(self.Config.FlickAngle) and self.Config.FlickAngle or 0
    flick.SweepRotation = flick.TargetRotation
        * CFrame.Angles(0, sign * math.rad(math.clamp(followAngle, 0, 60)), 0)
    self.Flick = flick
    self.NextFlick = now + 0.70
    humanoid.AutoRotate = false
    -- No instant target snap and no waiting before the unchanged FireServer call.
    -- Only current-position body rotation is animated; the camera stays under your control.
    flick.Connection = connect(self.Services.RunService.PreSimulation, function()
        local ok, err = pcall(function() self:UpdateFlick(flick) end)
        if not ok then
            pcall(function() self:EndFlick(false) end)
            warn("[Pass Flick] " .. tostring(err))
        end
    end)
end

function PassController:Reset()
    self:ClearPending()
    self:EndFlick(true)
    self.HeldBomb, self.HeldCharacter = nil, nil
    self.FlickedForPossession = false
    self.NextRequest, self.NextFlick = 0, 0
end

function PassController:Step()
    if not self.Config.Enabled then return end
    local now = self.Services.Workspace:GetServerTimeNow()
    if not finiteNumber(now) then self:Status("Server time unavailable"); return end
    local character = self.Services.LocalPlayer.Character
    local root, humanoid = livingParts(character)
    if not root then self:Reset(); self:Status("Waiting for character"); return end

    local pending = self.Pending
    if pending then
        if character ~= pending.Character then
            self:Reset()
        else
            self:ObserveTransfer(pending)
            if pending.Confirmed then
                self.HeldBomb = nil
                self.FlickedForPossession = false
                self:Status("Transfer observed: " .. pending.Target.Name)
                self:ClearPending()
                return
            elseif now - pending.SentAt < self.Config.AckTimeout then
                self:Status("Pass requested; awaiting transfer")
                return
            else
                self:ClearPending()
            end
        end
    end

    local bomb = self:GetBomb(character, now)
    if not bomb then
        self.HeldBomb = nil
        self.FlickedForPossession = false
        self:Status("No equipped bomb")
        return
    end
    if self.HeldBomb ~= bomb or self.HeldCharacter ~= character then
        self.HeldBomb, self.HeldCharacter = bomb, character
        self.FlickedForPossession = false
        -- Preserve the cooldown across rapid possession changes.
    end

    -- remaining is a static helper. A colon call would pass the controller as the bomb.
    local remaining, reason = PassController.remaining(bomb, now)
    if remaining == nil then self:Status(reason); return end
    if remaining <= 0 then self:Status("Bomb deadline reached"); return end
    local remote = bomb:FindFirstChild("RemoteEvent")
    if not remote or not remote:IsA("RemoteEvent") then
        self:Status("Unsupported: Bomb.RemoteEvent missing"); return
    end
    local target, targetCharacter, targetRoot, collision, distance = self:GetTarget(root)
    if not target then self:Status("Waiting for a living target"); return end
    local late = self.Config.Mode == "Late"
    local window = late and self.Config.LateWindow or self.Config.NormalWindow
    local maxDistance = late and self.Config.LateDistance or self.Config.NormalDistance
    local adjusted = remaining - self.Config.Lead
    if distance > maxDistance then
        self:Status(string.format("OUT OF RANGE: %.1f / %.1f studs", distance, maxDistance))
    elseif adjusted > window then
        self:Status(string.format("ARMED: %.3f s | window %.2f + lead %.2f s", remaining, window, self.Config.Lead))
    elseif adjusted <= 0 then
        self:Status("Inside lead margin; waiting for bomb state")
    elseif now < self.NextRequest then
        self:Status("Pass cooldown")
    end
    if not PassController.eligible(self.Config.Mode, adjusted, distance, self.Config)
        or now < self.NextRequest then return end

    -- Re-read ownership, target part, server time, and fractional fuse at the final gate.
    if bomb.Parent ~= character or target.Character ~= targetCharacter then return end
    local freshRoot = livingParts(targetCharacter)
    local freshPart = targetCharacter:FindFirstChild("CollisionPart") or freshRoot
    if freshRoot ~= targetRoot or freshPart ~= collision or not collision:IsA("BasePart") then return end
    local sendNow = self.Services.Workspace:GetServerTimeNow()
    if not finiteNumber(sendNow) or sendNow < self.NextRequest then return end
    remaining = PassController.remaining(bomb, sendNow)
    local currentDistance = (collision.Position - root.Position).Magnitude
    if not finiteNumber(remaining) or remaining <= 0
        or not PassController.eligible(self.Config.Mode, remaining - self.Config.Lead, currentDistance, self.Config) then return end

    pending = {Bomb = bomb, Character = character, Target = target,
        TargetCharacter = targetCharacter, SentAt = sendNow}
    self.Pending = pending
    pending.Connection = connect(bomb.AncestryChanged, function() self:ObserveTransfer(pending) end)
    self.NextRequest = sendNow + self.Config.Cooldown
    local flickOK, flickError = pcall(function()
        self:StartFlick(character, root, humanoid, targetRoot, sendNow)
    end)
    if not flickOK then
        pcall(function() self:EndFlick(false) end)
        warn("[Pass Flick] " .. tostring(flickError))
    end
    local ok, err = pcall(function() remote:FireServer(targetCharacter, collision) end)
    if not ok then
        self:ClearPending()
        self:EndFlick(true)
        self:Status("Pass request failed (see console)")
        warn("[Auto Pass] " .. tostring(err))
    else
        self:Status(string.format("REQUESTED: %.3f s | %s | %.1f studs", remaining, target.Name, currentDistance))
    end
end

-- END PASS CONTROLLER

local passConfig = {
    Enabled = false, Mode = "Late",
    NormalWindow = 3.0, NormalDistance = bombPassDistance,
    LateWindow = 1.2, LateDistance = 6, Lead = 0.05, Cooldown = 0.5,
    FlickEnabled = false, FlickAngle = 0, FlickDuration = 0.18, AckTimeout = 0.1,
}

passCore = PassController.new({
    Players = Players, LocalPlayer = LocalPlayer,
    Workspace = Workspace, RunService = RunService,
}, passConfig, {
    shiftLocked = function() return SL_Active ~= nil end,
    cameraRelative = function()
        -- Read the standard mode only. Never toggle the game's own shift-lock setting.
        local ok, rotationType = pcall(function()
            return UserSettings():GetService("UserGameSettings").RotationType
        end)
        return ok and rotationType == Enum.RotationType.CameraRelative
    end,
    status = function(message)
        if mobileStatus and mobileStatus.Parent then mobileStatus.Text = message end
        if cloudStatus then cloudStatus.Set(message) end
    end,
})

local function autoPassBomb()
    passConfig.NormalDistance = bombPassDistance
    local ok, err = pcall(function() passCore:Step() end)
    if not ok then
        -- A failed update is visible and stops further requests.
        AutoPassEnabled, passConfig.Enabled = false, false
        if autoPassConnection then autoPassConnection:Disconnect(); autoPassConnection = nil end
        passCore:Reset()
        if cloudAutoPassToggle then
            pcall(function() cloudAutoPassToggle.Set(false, true) end)
        end
        passCore:Status("Auto pass stopped: see console")
        refreshMobileButtons()
        updateAutoPassButton()
        warn("[Auto Pass] " .. tostring(err))
    end
end

local syncingCloud = false
local function syncToggle(toggle, value)
    if toggle and not syncingCloud then
        syncingCloud = true
        local ok, err = pcall(function() toggle.Set(value, true) end)
        syncingCloud = false
        if not ok then warn("[Auto Pass UI] " .. tostring(err)) end
    end
end

updateAutoPassButton = function()
    if not AutoPassButton then return end
    AutoPassButton.Text = AutoPassEnabled and "AUTO\nON" or "AUTO\nOFF"
    AutoPassButton.BackgroundColor3 = AutoPassEnabled
        and Color3.fromRGB(25, 128, 77) or Color3.fromRGB(115, 52, 64)
end

local function setAutoPassEnabled(value)
    AutoPassEnabled = value == true
    passConfig.Enabled = AutoPassEnabled
    if AutoPassEnabled then
        if not autoPassConnection then
            -- Evaluate on each simulation frame using the shared fractional timer.
            autoPassConnection = connect(RunService.PreSimulation, autoPassBomb)
        end
    else
        if autoPassConnection then autoPassConnection:Disconnect(); autoPassConnection = nil end
        passCore:Reset()
        passCore:Status("Auto pass off")
        removeTargetMarker()
    end
    refreshMobileButtons()
    updateAutoPassButton()
    syncToggle(cloudAutoPassToggle, AutoPassEnabled)
end

local function setLatePassEnabled(value)
    local mode = value and "Late" or "Normal"
    if passConfig.Mode ~= mode then passCore:Reset(); passConfig.Mode = mode end
    passCore:Status(AutoPassEnabled and (mode == "Late" and "Timed mode armed; waiting for a bomb" or "Normal mode ready")
        or "AUTO IS OFF — enable Auto to pass")
    refreshMobileButtons()
    if cloudModeDropdown then cloudModeDropdown.Set(mode, true) end
end

local function setPassFlickEnabled(value)
    passConfig.FlickEnabled = value == true
    if not passConfig.FlickEnabled then passCore:EndFlick(true) end
    refreshMobileButtons()
    syncToggle(cloudFlickToggle, passConfig.FlickEnabled)
end

connect(LocalPlayer.CharacterRemoving, function() passCore:Reset() end)

-- A passive timer view, independent of Auto Pass, targets, remotes and pass messages.
local timerElapsed = 0
local timerLastError
local timerConnection = connect(RunService.RenderStepped, function(deltaTime)
    timerElapsed = timerElapsed + deltaTime
    if timerElapsed < 1 / 30 then return end
    timerElapsed = 0
    if appDestroyed then return end
    local timerDisplay = mobileTimer or {}
    if AI_AssistanceEnabled then
        local root = livingParts(LocalPlayer.Character)
        local target, distance
        if root then
            local player, _, _, _, studs = passCore:GetTarget(root)
            target, distance = player, studs
        end
        if target then createOrUpdateTargetMarker(target, distance) else removeTargetMarker() end
    end
    local ok, err = pcall(function()
        local now = Workspace:GetServerTimeNow()
        local character = LocalPlayer.Character
        local bomb = character and passCore:GetBomb(character, now)
        local stowed = false
        if not bomb then
            local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
            bomb = backpack and passCore:GetBomb(backpack, now)
            stowed = bomb ~= nil
        end
        if not bomb then
            if cloudTimer then cloudTimer.Set("—"); cloudTimer.SetSub("No bomb equipped") end
            timerDisplay.Text = "YOUR BOMB: --\nNot carrying a Bomb Tool"
            timerDisplay.TextColor3 = Color3.fromRGB(190, 202, 220)
            return
        end
        local remaining, reason = PassController.remaining(bomb, now)
        if remaining == nil then
            if cloudTimer then cloudTimer.Set("Unavailable"); cloudTimer.SetSub(reason) end
            timerDisplay.Text = "BOMB TIMER UNAVAILABLE\n" .. reason
            timerDisplay.TextColor3 = Color3.fromRGB(255, 200, 100)
            return
        end
        local heading = stowed and "STOWED BOMB" or "YOUR BOMB"
        if cloudTimer then
            cloudTimer.Set(string.format("%.3f s", math.max(0, remaining)))
            cloudTimer.SetSub((stowed and "Stowed · " or "Equipped · ") .. tostring(bomb:GetAttribute("BombState")))
        end
        timerDisplay.Text = heading .. string.format(": %.3f s\n", math.max(0, remaining))
            .. tostring(bomb:GetAttribute("BombState"))
        timerDisplay.TextColor3 = remaining <= passConfig.LateWindow
            and Color3.fromRGB(255, 132, 119) or Color3.fromRGB(215, 233, 250)
    end)
    if not ok then
        timerDisplay.Text = "BOMB TIMER: read error"
        if tostring(err) ~= timerLastError then warn("[Bomb Timer] " .. tostring(err)) end
        timerLastError = tostring(err)
    else
        timerLastError = nil
    end
end)

-- Layout edits are opt-in. Gameplay taps never reposition a locked control.
local layoutEditing = false
local layoutPositions = {}
local buttonSizes = {
    auto = UserInputService.TouchEnabled and 72 or 52,
    shift = UserInputService.TouchEnabled and 72 or 52,
}
local layoutBindings = {}
local layoutPlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local layoutHttp = game:GetService("HttpService")
local layoutAttribute = "YonPassLayoutV3"
local layoutFile = "YonMenu_Advanced/ipad-layout-v3.json"

local function decodeLayout(text)
    if type(text) ~= "string" then return false end
    local ok, data = pcall(function() return layoutHttp:JSONDecode(text) end)
    if not ok or type(data) ~= "table" or data.version ~= 3 or type(data.positions) ~= "table" then
        return false
    end
    for _, key in ipairs({"panel", "auto", "shift", "settings"}) do
        local point = data.positions[key]
        if type(point) == "table" and finiteNumber(point.x) and finiteNumber(point.y) then
            layoutPositions[key] = {x = math.clamp(point.x, 0, 1), y = math.clamp(point.y, 0, 1)}
        end
    end
    if type(data.sizes) == "table" then
        for _, key in ipairs({"auto", "shift"}) do
            if finiteNumber(data.sizes[key]) then
                buttonSizes[key] = math.clamp(math.floor(data.sizes[key] + 0.5), 44, 160)
            end
        end
    end
    return true
end

local loadedLayout = decodeLayout(layoutPlayerGui:GetAttribute(layoutAttribute))
if not loadedLayout and type(readfile) == "function" then
    local ok, text = pcall(function() return readfile(layoutFile) end)
    if ok then decodeLayout(text) end
end

local function saveLayout()
    local ok, text = pcall(function()
        return layoutHttp:JSONEncode({
            version = 3,
            positions = layoutPositions,
            sizes = buttonSizes
        })
    end)

    if not ok then return end
    layoutPlayerGui:SetAttribute(layoutAttribute, text)

    if type(writefile) == "function" then
        if type(makefolder) == "function" then
            pcall(makefolder, "YonMenu_Advanced")
        end

        pcall(function()
            writefile(layoutFile, text)
        end)
    end
end

local function setButtonSize(key, value)
    local number = tonumber(value)
    if not finiteNumber(number) then return end
    local size = math.clamp(math.floor(number + 0.5), 44, 160)
    buttonSizes[key] = size
    local button = key == "auto" and AutoPassButton or ShiftLockButton
    if button then
        button.Size = UDim2.fromOffset(size, size)
        if key == "auto" then button.TextSize = math.clamp(math.floor(size * 0.26), 12, 28) end
    end
    saveLayout()
end

local function setLayoutEditing(value)
    layoutEditing = value == true
    if not layoutEditing then
        for binding in pairs(layoutBindings) do binding:CancelGesture() end
        saveLayout()
    end
    refreshMobileButtons()
    syncToggle(cloudLayoutToggle, layoutEditing)
end

local function makeDraggable(element, handle, key)
    handle = handle or element
    local state = {dragInput = nil, moved = false}
    local parent = element.Parent
    local screen = element:FindFirstAncestorOfClass("ScreenGui")
    local connections = {}
    local function dragConnect(signal, callback)
        table.insert(connections, connect(signal, callback))
    end
    local function enabled()
        return element.Parent == parent and parent.Parent and element.Visible
            and (not screen or screen.Enabled)
    end
    local function ranges()
        local bounds, size = parent.AbsoluteSize, element.AbsoluteSize
        if bounds.X <= 0 or bounds.Y <= 0 then return nil end
        return math.max(0, bounds.X - size.X - 8), math.max(0, bounds.Y - size.Y - 8)
    end
    local function place(x, y, remember)
        local maxX, maxY = ranges()
        if not maxX then return end
        x, y = math.clamp(x, 4, 4 + maxX), math.clamp(y, 4, 4 + maxY)
        element.AnchorPoint = Vector2.new(0, 0)
        element.Position = UDim2.fromOffset(x, y)
        if remember then
            layoutPositions[key] = {
                x = maxX > 0 and (x - 4) / maxX or 0,
                y = maxY > 0 and (y - 4) / maxY or 0,
            }
        end
    end
    local function restorePosition()
        if not element.Parent then return end
        local maxX, maxY = ranges()
        if not maxX then return end
        local point = layoutPositions[key]
        if point then
            place(4 + point.x * maxX, 4 + point.y * maxY, false)
        else
            local current = element.AbsolutePosition - parent.AbsolutePosition
            place(current.X, current.Y, true)
        end
    end
    function state:CancelGesture()
        if self.dragInput then self.moved = true end
        self.dragInput = nil
    end
    local function update(input)
        if not layoutEditing or not state.dragInput or not enabled() then return end
        if input ~= state.dragInput and not
            (state.dragInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement) then return end
        local delta = input.Position - state.dragStart
        if delta.X * delta.X + delta.Y * delta.Y >= 100 then state.moved = true end
        if state.moved then place(state.startPos.X + delta.X, state.startPos.Y + delta.Y, true) end
    end
    handle.Active = true
    dragConnect(handle.InputBegan, function(input)
        if state.dragInput or not enabled() then return end
        if input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            state.moved = false
            -- A locked button still accepts clean taps, but never starts a drag.
            if not layoutEditing then return end
            state.dragInput, state.dragStart = input, input.Position
            state.startPos = element.AbsolutePosition - parent.AbsolutePosition
        end
    end)
    dragConnect(UserInputService.InputChanged, update)
    dragConnect(UserInputService.InputEnded, function(input)
        if input == state.dragInput then
            update(input)
            state.dragInput = nil
        end
    end)
    dragConnect(element:GetPropertyChangedSignal("AbsoluteSize"), restorePosition)
    dragConnect(parent:GetPropertyChangedSignal("AbsoluteSize"), function()
        state:CancelGesture()
        task.defer(restorePosition)
    end)
    if screen then
        dragConnect(screen:GetPropertyChangedSignal("Enabled"), function()
            if not screen.Enabled then state:CancelGesture() end
        end)
    end
    connect(element.Destroying, function()
        for _, connection in ipairs(connections) do connection:Disconnect() end
        layoutBindings[state] = nil
        state.dragInput = nil
    end)
    function state:ShouldActivate(input)
        if not enabled() then return false end
        if input and input.UserInputType ~= Enum.UserInputType.Touch
            and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return true end
        return not self.moved
    end
    layoutBindings[state] = true
    task.defer(restorePosition)
    return state
end


local function uiNew(class, properties, parent)
    local item = Instance.new(class)
    for key, value in pairs(properties or {}) do item[key] = value end
    item.Parent = parent
    return item
end
local function uiRound(item, radius)
    return uiNew("UICorner", {CornerRadius = UDim.new(0, radius)}, item)
end

-- File 3's native CloudUI API. Demo pages are disabled; every tab below is this app.
UI = CloudUI.new({
    Name = "Aether", Version = "1.1", Theme = "AetherCloud",
    Subtitle = "Bomb Pass", Developer = "Custom interface",
    DemoContent = false, AutoLoad = false, IntroEnabled = true,
    ConfigFolder = "AetherBombPass",
})
local Window = UI:CreateWindow()
local function toggleSettings()
    if not allUIVisible then
        allUIVisible = true
        if mobileGui then mobileGui.Enabled = true end
        if ShiftLockScreenGui then ShiftLockScreenGui.Enabled = true end
    end
    UI.Gui.Enabled = true
    Window:Toggle()
end

local Main = Window:AddTab({Name = "Main", Icon = "✦", Badge = "LIVE"})
local Live = Main:AddSection({Name = "Your bomb", Description = "The live server countdown stays active with Auto Pass off."})
cloudTimer = Live:AddStatCard({Name = "Fuse remaining", Icon = "◷", Description = "Waiting for a bomb"})
cloudStatus = Live:AddParagraph({Title = "Pass status", Text = "Auto pass off"})
local General = Main:AddSection({Name = "Pass controls", Description = "Both modes use the real fuse deadline."})
cloudAutoPassToggle = General:AddToggle({Name = "Auto Pass Bomb", Default = false, Flag = "AutoPassBomb", Callback = setAutoPassEnabled})
cloudModeDropdown = General:AddDropdown({Name = "Pass mode", Options = {"Normal", "Late"}, Default = passConfig.Mode,
    Flag = "PassMode", Callback = function(v) setLatePassEnabled(v == "Late") end})
cloudFlickToggle = General:AddToggle({Name = "Adaptive body flick", Description = "Ease toward the receiver, then return naturally.",
    Default = false, Flag = "BodyFlick", Callback = setPassFlickEnabled})
local Timing = Main:AddSection({Name = "Timing & range", Description = "Lead is subtracted before the window check. The countdown itself is never rounded."})
Timing:AddSlider({Name = "Normal window", Min = .2, Max = 5, Default = passConfig.NormalWindow, Step = .05, Suffix = "s",
    Flag = "NormalWindow", Callback = function(v) passConfig.NormalWindow = v end})
timedThresholdSettings = Timing:AddSlider({Name = "Late window", Min = .2, Max = 2, Default = passConfig.LateWindow, Step = .05, Suffix = "s",
    Flag = "LateWindow", Callback = function(v) passConfig.LateWindow = v; refreshMobileButtons() end})
Timing:AddSlider({Name = "Normal distance", Min = 1, Max = 12, Default = passConfig.NormalDistance, Step = .5, Suffix = "studs",
    Flag = "NormalDistance", Callback = function(v) bombPassDistance = v; passConfig.NormalDistance = v end})
Timing:AddSlider({Name = "Late distance", Min = 1, Max = 6, Default = passConfig.LateDistance, Step = .5, Suffix = "studs",
    Flag = "LateDistance", Callback = function(v) passConfig.LateDistance = v; refreshMobileButtons() end})
Timing:AddSlider({Name = "Lead", Description = "Small timing allowance; 0.05 seconds by default.", Min = 0, Max = .15,
    Default = passConfig.Lead, Step = .01, Suffix = "s", Flag = "Lead", Callback = function(v) passConfig.Lead = v end})
Timing:AddSlider({Name = "Pass cooldown", Min = .1, Max = 1.5, Default = passConfig.Cooldown, Step = .05, Suffix = "s",
    Flag = "Cooldown", Callback = function(v) passConfig.Cooldown = v end})
local Flick = Main:AddSection({Name = "Flick feel", Description = "Manual turning takes priority over the temporary body turn."})
Flick:AddSlider({Name = "Follow-through", Min = 0, Max = 60, Default = passConfig.FlickAngle, Step = 1, Suffix = "°",
    Flag = "FlickAngle", Callback = function(v) passConfig.FlickAngle = v end})
Flick:AddSlider({Name = "Base duration", Min = .1, Max = .3, Default = passConfig.FlickDuration, Step = .01, Suffix = "s",
    Flag = "FlickDuration", Callback = function(v) passConfig.FlickDuration = v end})

local Player = Window:AddTab({Name = "Player", Icon = "◉"})
local Movement = Player:AddSection({Name = "Character", Description = "Your existing character controls."})
Movement:AddToggle({Name = "Anti-Slippery", Default = false, Flag = "AntiSlippery",
    Callback = function(v) antiSlippery = v; applyAntiSlippery(v) end})
Movement:AddSlider({Name = "Normal anti-slip friction", Min = .1, Max = 2, Default = customAntiSlipperyFriction, Step = .05,
    Flag = "AntiSlipFriction", Callback = function(v) customAntiSlipperyFriction = v end})
Movement:AddSlider({Name = "Bomb anti-slip friction", Min = .1, Max = 2, Default = customBombAntiSlipperyFriction, Step = .05,
    Flag = "BombAntiSlipFriction", Callback = function(v) customBombAntiSlipperyFriction = v end})
Movement:AddToggle({Name = "Face nearest bomb holder", Default = false, Flag = "FaceBomb",
    Callback = function(v)
        FaceBombEnabled = v
        if faceBombConnection then faceBombConnection:Disconnect(); faceBombConnection = nil end
        if v then faceBombConnection = connect(RunService.Heartbeat, faceNearestBombHolder) end
    end})
Movement:AddToggle({Name = "Remove Hitbox", Default = false, Flag = "RemoveHitbox",
    Callback = function(v) RemoveHitboxEnabled = v; applyRemoveHitbox(v) end})
Movement:AddSlider({Name = "Custom hitbox size", Min = .1, Max = 3, Default = customHitboxSize, Step = .1, Flag = "HitboxSize",
    Callback = function(v) customHitboxSize = v; if RemoveHitboxEnabled then applyRemoveHitbox(true) end end})
local Targeting = Player:AddSection({Name = "Targeting", Description = "Nearest living receiver, using CollisionPart or HumanoidRootPart."})
Targeting:AddToggle({Name = "AI Assistance", Description = "Show the nearest receiver with a target marker.", Default = false, Flag = "AIAssistance",
    Callback = function(v) AI_AssistanceEnabled = v; if not v then removeTargetMarker() end end})
Targeting:AddSlider({Name = "Ray spread angle", Description = "Retained ray helper setting; does not change the pass timer gate.",
    Min = 0, Max = 45, Default = raySpreadAngle, Step = 1, Suffix = "°", Flag = "RaySpreadAngle",
    Callback = function(v) raySpreadAngle = v end})
Targeting:AddSlider({Name = "Number of raycasts", Min = 1, Max = 15, Default = numRaycasts, Step = 2, Flag = "NumberOfRaycasts",
    Callback = function(v) numRaycasts = v end})

local Layout = Window:AddTab({Name = "Layout", Icon = "▦"})
local Touch = Layout:AddSection({Name = "Touch controls", Description = "Unlock, drag controls to a comfortable position, then lock to save."})
cloudLayoutToggle = Touch:AddToggle({Name = "Edit button positions", Default = false, Flag = "EditLayout", Callback = setLayoutEditing})
for _, item in ipairs({{key = "auto", name = "Auto Pass button size"}, {key = "shift", name = "Shift Lock button size"}}) do
    Touch:AddSlider({Name = item.name, Min = 44, Max = 160, Default = buttonSizes[item.key], Step = 1,
        Suffix = "px", Flag = "Size_" .. item.key, Callback = function(v) setButtonSize(item.key, v) end})
end

local Settings = Window:AddTab({Name = "Settings", Icon = "⚙"})
local Appearance = Settings:AddSection({Name = "Cloud atmosphere", Description = "Lavender, rose, ice blue, and a little movement."})
Appearance:AddDropdown({Name = "Theme", Options = {"Aether Cloud", "Lavender Night", "Soft Rose", "Arctic Mist"},
    Default = "Aether Cloud", Flag = "Theme", Callback = function(v) UI:SetTheme(v) end})
Appearance:AddColorpicker({Name = "Accent", Default = Color3.fromRGB(174, 150, 255), Flag = "AccentColor",
    Callback = function(c) UI:SetAccent(c) end})
Appearance:AddSlider({Name = "UI scale", Min = .75, Max = 1.25, Default = 1, Step = .01, Percent = true,
    Flag = "UIScale", Callback = function(v) UI:SetScale(v) end})
Appearance:AddSlider({Name = "Glass transparency", Min = 0, Max = 1, Default = 0, Step = .05, Percent = true,
    Flag = "Transparency", Callback = function(v) UI:SetTransparency(v) end})
Appearance:AddToggle({Name = "Cloud effects", Default = true, Flag = "CloudEffects", Callback = function(v) UI:SetClouds(v) end})
Appearance:AddToggle({Name = "Animated accent", Default = false, Flag = "AnimatedAccent", Callback = function(v) UI:SetAnimatedAccent(v) end})
Appearance:AddToggle({Name = "Reduce motion", Default = false, Flag = "ReduceMotion", Callback = function(v) UI:SetReducedMotion(v) end})
local Interface = Settings:AddSection({Name = "Interface", Description = "RightShift opens and closes the window by default."})
Interface:AddKeybind({Name = "Menu Key", Default = Enum.KeyCode.RightShift, Flag = "MenuKey",
    OnChanged = function(key) UI:SetMenuKey(key) end})
local Profiles = Settings:AddSection({Name = "Configuration", Description = "Save to disk when available; otherwise keep a session copy."})
Profiles:AddButton({Name = "Save configuration", Style = "Primary", Callback = function() UI:SaveConfig() end})
Profiles:AddButton({Name = "Load configuration", Callback = function() UI:LoadConfig(false) end})
Profiles:AddButton({Name = "Reset configuration", Style = "Danger", Callback = function()
    UI:Modal({Title = "Reset configuration?", Description = "Restore all controls to their defaults and remove the saved profile.",
        Danger = true, OnConfirm = function() UI:ResetConfig(); setAutoPassEnabled(false) end})
end})
Profiles:AddButton({Name = "Unload Aether", Style = "Danger", Callback = function()
    UI:Modal({Title = "Close this session?", Description = "Stop passing, release shift lock, and remove all Aether controls.",
        Danger = true, ConfirmText = "Unload", OnConfirm = function() UI:Destroy() end})
end})
Window:SelectTab("Main")

local myFrictionController = FrictionController.new()
myFrictionController:enable()

local function setUIVisualStealth(enabled)
    local visible = not enabled
    if mobileGui then mobileGui.Enabled = visible end
    if ShiftLockScreenGui then ShiftLockScreenGui.Enabled = visible end
    if UI and UI.Gui then UI.Gui.Enabled = visible end
end

local function createMobileToggle()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MobileToggleGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.DisplayOrder = 50
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Enabled = allUIVisible
    local safeArea = Instance.new("Frame")
    safeArea.Size = UDim2.fromScale(1, 1)
    safeArea.BackgroundTransparency = 1
    safeArea.Parent = gui

    local panel = Instance.new("Frame")
    panel.Name = "TouchPanel"
    panel.Size = UDim2.fromOffset(280, 378)
    panel.Position = UDim2.new(1, -304, 0.20, 0)
    panel.BackgroundColor3 = Color3.fromRGB(27, 30, 42)
    panel.BackgroundTransparency = 0.08
    panel.BorderSizePixel = 0
    panel.Parent = safeArea
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = panel

    local handle = Instance.new("TextLabel")
    handle.Name = "DragHandle"
    handle.Size = UDim2.new(1, 0, 0, 44)
    handle.TextSize = 17
    handle.Font = Enum.Font.GothamBold
    handle.TextColor3 = Color3.fromRGB(204, 214, 230)
    handle.BackgroundTransparency = 1
    handle.Parent = panel

    local function button(name, top, height)
        local item = Instance.new("TextButton")
        item.Name = name
        item.Size = UDim2.new(1, -16, 0, height or 52)
        item.Position = UDim2.fromOffset(8, top)
        item.TextSize = 17
        item.Font = Enum.Font.GothamBold
        item.TextColor3 = Color3.new(1, 1, 1)
        item.AutoButtonColor = true
        item.Parent = panel
        local rounding = Instance.new("UICorner")
        rounding.CornerRadius = UDim.new(0, 10)
        rounding.Parent = item
        return item
    end
    uiNew("UIStroke", {Color=Color3.fromRGB(73,80,111),Transparency=.25}, panel)
    local autoButton = button("AutoPassMobileToggle", 116)
    local modeButton = button("PassModeMobileToggle", 116)
    local flickButton = button("PassFlickMobileToggle", 176)
    local layoutButton = button("LayoutLockToggle", 176)
    autoButton.Size=UDim2.new(.5,-12,0,52)
    flickButton.Size=autoButton.Size
    modeButton.Size=autoButton.Size; modeButton.Position=UDim2.new(.5,4,0,116)
    layoutButton.Size=autoButton.Size; layoutButton.Position=UDim2.new(.5,4,0,176)
    modeButton.TextSize=14; modeButton.TextWrapped=true
    layoutButton.TextSize=14
    local settingsButton=button("Settings",236,44)
    settingsButton.Text="Aether  ·  Open menu"
    settingsButton.BackgroundColor3=Color3.fromRGB(47,54,76)
    connect(settingsButton.Activated, toggleSettings)
    local triggerLabel=uiNew("TextLabel",{Text="Pass at ≤ seconds",TextSize=14,Font=Enum.Font.Gotham,
        TextColor3=Color3.fromRGB(200,211,236),BackgroundTransparency=1,TextXAlignment=Enum.TextXAlignment.Left,
        Position=UDim2.fromOffset(12,288),Size=UDim2.new(1,-112,0,40)},panel)
    local trigger=uiNew("TextBox",{Text=string.format("%.2f",passConfig.LateWindow),TextSize=18,
        ClearTextOnFocus=false,Font=Enum.Font.GothamBold,TextColor3=Color3.fromRGB(231,235,255),
        BackgroundColor3=Color3.fromRGB(47,54,76),BorderSizePixel=0,
        Position=UDim2.new(1,-94,0,286),Size=UDim2.fromOffset(82,44)},panel)
    uiRound(trigger,9)
    connect(trigger.FocusLost, function()
        local number=tonumber(trigger.Text)
        if finiteNumber(number) then passConfig.LateWindow=math.clamp(number,.2,2) end
        trigger.Text=string.format("%.2f",passConfig.LateWindow)
        if timedThresholdSettings then timedThresholdSettings.Set(passConfig.LateWindow, true) end
        refreshMobileButtons()
    end)
    local function fitPanel()
        local size=safeArea.AbsoluteSize
        if size.X<=0 or size.Y<=0 then return end
        panel.Size=UDim2.fromOffset(math.min(280,size.X-16),378)
        local position=panel.AbsolutePosition-safeArea.AbsolutePosition
        panel.AnchorPoint=Vector2.zero
        panel.Position=UDim2.fromOffset(math.clamp(position.X,8,math.max(8,size.X-panel.AbsoluteSize.X-8)),
            math.clamp(position.Y,8,math.max(8,size.Y-panel.AbsoluteSize.Y-8)))
    end
    connect(safeArea:GetPropertyChangedSignal("AbsoluteSize"), fitPanel)
    task.defer(fitPanel)

    local timer = Instance.new("TextLabel")
    timer.Name = "ActualBombTimer"
    timer.Size = UDim2.new(1, -24, 0, 60)
    timer.Position = UDim2.fromOffset(12, 46)
    timer.BackgroundTransparency = 1
    timer.TextWrapped = true
    timer.TextSize = 20
    timer.Font = Enum.Font.GothamBold
    timer.TextColor3 = Color3.fromRGB(215, 233, 250)
    timer.Text = "YOUR BOMB: --"
    timer.Parent = panel
    mobileTimer = timer

    local status = Instance.new("TextLabel")
    status.Name = "PassStatus"
    status.Size = UDim2.new(1, -16, 0, 40)
    status.Position = UDim2.fromOffset(8, 334)
    status.BackgroundTransparency = 1
    status.TextWrapped = true
    status.TextSize = 14
    status.Font = Enum.Font.Gotham
    status.TextColor3 = Color3.fromRGB(190, 202, 220)
    status.Text = passCore.LastStatus ~= "" and passCore.LastStatus or "Auto pass off"
    status.Parent = panel
    mobileStatus = status

    refreshMobileButtons = function()
        if not gui.Parent then return end
        autoButton.Text = AutoPassEnabled and "AUTO ON" or "AUTO OFF"
        autoButton.BackgroundColor3 = AutoPassEnabled
            and Color3.fromRGB(25, 128, 77) or Color3.fromRGB(115, 52, 64)
        modeButton.Text = passConfig.Mode == "Late" and string.format("LATE / %.1f", passConfig.LateDistance) or "NORMAL"
        triggerLabel.Text=passConfig.Mode == "Late" and "Pass at ≤ seconds" or "Timed threshold (s)"
        if not trigger:IsFocused() then trigger.Text=string.format("%.2f",passConfig.LateWindow) end
        modeButton.BackgroundColor3 = passConfig.Mode == "Late"
            and Color3.fromRGB(127, 73, 172) or Color3.fromRGB(51, 80, 122)
        flickButton.Text = passConfig.FlickEnabled and "FLICK: ON" or "FLICK: OFF"
        flickButton.BackgroundColor3 = passConfig.FlickEnabled
            and Color3.fromRGB(37, 103, 177) or Color3.fromRGB(63, 70, 84)
        layoutButton.Text = layoutEditing and "UNLOCKED" or "LOCKED"
        layoutButton.BackgroundColor3 = layoutEditing
            and Color3.fromRGB(20, 115, 130) or Color3.fromRGB(63, 70, 84)
        handle.Text = layoutEditing and "DRAG HEADER TO MOVE" or "AETHER · BOMB PASS"
    end
    connect(autoButton.Activated, function() setAutoPassEnabled(not AutoPassEnabled) end)
    connect(modeButton.Activated, function() setLatePassEnabled(passConfig.Mode ~= "Late") end)
    connect(flickButton.Activated, function() setPassFlickEnabled(not passConfig.FlickEnabled) end)
    connect(layoutButton.Activated, function() setLayoutEditing(not layoutEditing) end)
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    makeDraggable(panel, handle, "panel")
    refreshMobileButtons()
    return gui, autoButton, modeButton, flickButton
end


mobileGui, mobileToggle, mobileModeToggle, flickToggle = createMobileToggle()
connect(layoutPlayerGui.ChildRemoved, function(child)
    if child == mobileGui then
        task.delay(1, function()
            if not appDestroyed and not LocalPlayer.PlayerGui:FindFirstChild("MobileToggleGui") then
                mobileGui, mobileToggle, mobileModeToggle, flickToggle = createMobileToggle()
            end
        end)
    end
end)

-- ============================================================================
-- SHIFT LOCK + AUTO PASS BUTTONS
-- Both buttons are freely draggable anywhere on screen. Dragging never
-- activates the button; only a clean tap/click does.
-- ============================================================================



ShiftLockScreenGui = Instance.new("ScreenGui")
ShiftLockScreenGui.Name = "Shiftlock (CoreGui)"
ShiftLockScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ShiftLockScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ShiftLockScreenGui.ResetOnSpawn = false
ShiftLockScreenGui.IgnoreGuiInset = false
ShiftLockScreenGui.DisplayOrder = 51
local touchButtonArea = Instance.new("Frame")
touchButtonArea.Name = "TouchButtonSafeArea"
touchButtonArea.Size = UDim2.fromScale(1, 1)
touchButtonArea.BackgroundTransparency = 1
touchButtonArea.Parent = ShiftLockScreenGui

-- Shift Lock Button (default near the right edge; drag it wherever you want)
ShiftLockButton = Instance.new("ImageButton")
ShiftLockButton.Parent = touchButtonArea
ShiftLockButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ShiftLockButton.BackgroundTransparency = 1
ShiftLockButton.AnchorPoint = Vector2.new(1, 0.5)
ShiftLockButton.Position = UDim2.new(1, -120, 0.72, 0)
ShiftLockButton.Size = UDim2.fromOffset(UserInputService.TouchEnabled and 72 or 52, UserInputService.TouchEnabled and 72 or 52)
ShiftLockButton.Size = UDim2.fromOffset(buttonSizes.shift, buttonSizes.shift)
ShiftLockButton.SizeConstraint = Enum.SizeConstraint.RelativeXX
ShiftLockButton.Image = "rbxasset://textures/ui/mouseLock_off@2x.png"
local shiftLockUICorner = Instance.new("UICorner")
shiftLockUICorner.CornerRadius = UDim.new(0.2, 0)
shiftLockUICorner.Parent = ShiftLockButton
local shiftLockUIStroke = Instance.new("UIStroke")
shiftLockUIStroke.Thickness = 2
shiftLockUIStroke.Color = Color3.fromRGB(0, 0, 0)
shiftLockUIStroke.Parent = ShiftLockButton

-- AutoPass Toggle Button (default above the shift lock; also draggable)
AutoPassButton = Instance.new("TextButton")
AutoPassButton.Name = "AutoPassToggle"
AutoPassButton.Parent = touchButtonArea
AutoPassButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
AutoPassButton.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoPassButton.Font = Enum.Font.GothamBold
AutoPassButton.TextSize = 18
AutoPassButton.AnchorPoint = Vector2.new(1, 0.5)
AutoPassButton.Position = UDim2.new(1, -120, 0.72, UserInputService.TouchEnabled and -86 or -66)
AutoPassButton.Size = ShiftLockButton.Size
AutoPassButton.Size = UDim2.fromOffset(buttonSizes.auto, buttonSizes.auto)
AutoPassButton.TextSize = math.clamp(math.floor(buttonSizes.auto * 0.26), 12, 28)
AutoPassButton.SizeConstraint = Enum.SizeConstraint.RelativeXX
local apCorner = Instance.new("UICorner")
apCorner.CornerRadius = UDim.new(0.2, 0)
apCorner.Parent = AutoPassButton
local apStroke = Instance.new("UIStroke")
apStroke.Thickness = 2
apStroke.Color = Color3.fromRGB(0, 0, 0)
apStroke.Parent = AutoPassButton

local shiftLockDrag = makeDraggable(ShiftLockButton, nil, "shift")
local autoPassDrag = makeDraggable(AutoPassButton, nil, "auto")
updateAutoPassButton()

-- Click actions: a drag is consumed and never toggles the feature.
connect(AutoPassButton.Activated, function(input)
    if not autoPassDrag:ShouldActivate(input) then return end
    setAutoPassEnabled(not AutoPassEnabled)
end)

-- Shift lock cursor
local ShiftlockCursor = Instance.new("ImageLabel")
ShiftlockCursor.Name = "Shiftlock Cursor"
ShiftlockCursor.Parent = ShiftLockScreenGui
ShiftlockCursor.Image = "rbxasset://textures/MouseLockedCursor.png"
ShiftlockCursor.Size = UDim2.new(0.03, 0, 0.03, 0)
ShiftlockCursor.Position = UDim2.new(0.5, 0, 0.5, 0)
ShiftlockCursor.AnchorPoint = Vector2.new(0.5, 0.5)
ShiftlockCursor.SizeConstraint = Enum.SizeConstraint.RelativeXX
ShiftlockCursor.BackgroundTransparency = 1
ShiftlockCursor.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
ShiftlockCursor.Visible = false

-- Shift lock logic
local shiftLockHumanoid
local shiftLockOriginalAutoRotate
local shiftLockRenderName = "YonAdvancedShiftLock"

local function takeShiftLock(humanoid)
    if shiftLockHumanoid ~= humanoid then
        shiftLockHumanoid = humanoid
        shiftLockOriginalAutoRotate = humanoid.AutoRotate
        if passCore.Flick and passCore.Flick.Humanoid == humanoid then
            shiftLockOriginalAutoRotate = passCore.Flick.OriginalAutoRotate
        end
    end
    humanoid.AutoRotate = false
end

connect(ShiftLockButton.Activated, function(input)
    if not shiftLockDrag:ShouldActivate(input) then return end
    if not SL_Active then
        SL_Active = true
        ShiftLockButton.Image = "rbxasset://textures/ui/mouseLock_on@2x.png"
        ShiftlockCursor.Visible = true
        RunService:BindToRenderStep(shiftLockRenderName, Enum.RenderPriority.Camera.Value + 1, function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local camera = Workspace.CurrentCamera
            if not hum or not root or hum.Health <= 0 or not camera then return end
            if camera.CameraType ~= Enum.CameraType.Custom or camera.CameraSubject ~= hum then return end
            takeShiftLock(hum)
            if not passCore:IsFlicking() and not root.Anchored and not hum.Sit
                and not hum.PlatformStand then
                local look = camera.CFrame.LookVector
                local flat = Vector3.new(look.X, 0, look.Z)
                if flat.Magnitude > 0.001 then
                    root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
                end
            end
            -- Apply after the standard camera update so offsets do not accumulate.
            camera.CFrame = camera.CFrame * CFrame.new(1.7, 0, 0)
        end)
    else
        SL_Active = nil
        RunService:UnbindFromRenderStep(shiftLockRenderName)
        if shiftLockHumanoid and shiftLockHumanoid.Parent then
            if passCore.Flick and passCore.Flick.Humanoid == shiftLockHumanoid then
                passCore.Flick.OriginalAutoRotate = shiftLockOriginalAutoRotate
            else
                shiftLockHumanoid.AutoRotate = shiftLockOriginalAutoRotate
            end
        end
        shiftLockHumanoid = nil
        ShiftLockButton.Image = "rbxasset://textures/ui/mouseLock_off@2x.png"
        ShiftlockCursor.Visible = false
    end
end)

-- ============================================================================
-- /e command toggle – hides every UI element including both draggable buttons
-- ============================================================================

connect(LocalPlayer.Chatted, 
    function(msg)
        msg = msg:lower()
        if msg == "/e" then
            allUIVisible = not allUIVisible
            setUIVisualStealth(not allUIVisible)
            AINotificationsModule.sendNotification("UI Toggle", allUIVisible and "UI visible" or "UI hidden", 2)

            if mobileGui then
                mobileGui.Enabled = allUIVisible
                mobileToggle.Visible = allUIVisible
            end
            if ShiftLockButton then
                ShiftLockButton.Visible = allUIVisible
            end
            if AutoPassButton then
                AutoPassButton.Visible = allUIVisible
            end

        end
    end
)
setUIVisualStealth(not allUIVisible)
-- One cleanup path handles both the menu and all original controller connections.
UI:AddCleanup(function()
    if appDestroyed then return end
    appDestroyed = true
    AutoPassEnabled, passConfig.Enabled = false, false
    antiSlippery, FaceBombEnabled, AI_AssistanceEnabled = false, false, false
    SL_Active = nil
    passCore:Reset()
    RunService:UnbindFromRenderStep(shiftLockRenderName)
    if shiftLockHumanoid and shiftLockHumanoid.Parent then
        shiftLockHumanoid.AutoRotate = shiftLockOriginalAutoRotate
    end
    applyAntiSlippery(false)
    myFrictionController:disable()
    if RemoveHitboxEnabled then applyRemoveHitbox(false) end
    removeTargetMarker()
    for _, connection in ipairs(appConnections) do connection:Disconnect() end
    table.clear(appConnections)
    if mobileGui then mobileGui:Destroy(); mobileGui = nil end
    if ShiftLockScreenGui then ShiftLockScreenGui:Destroy(); ShiftLockScreenGui = nil end
    cloudTimer, cloudStatus = nil, nil
end)
UI:Notify({Title = "Aether ready", Description = "Choose your mode, set the timing, and enable Auto Pass. RightShift toggles the menu.", Type = "Success", Duration = 5})
print("Aether Bomb Pass ready. Live server timer; Normal and Late fuse gates; 0.05 s lead; 0.5 s cooldown.")
return {UI = UI, Window = Window, Controller = passCore, Config = passConfig,
    Destroy = function() UI:Destroy() end}

